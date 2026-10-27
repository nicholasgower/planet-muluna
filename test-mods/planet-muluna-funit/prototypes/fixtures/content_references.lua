-- Data-stage checks that every prototype name Muluna stores or references still
-- resolves in data.raw once every mod has run.
--
-- These are regression guards for crashes caused by another mod removing or
-- renaming content that Muluna still pointed at:
--   #386 / #447 / #388 - the cargo-pod cargo tables held items (tungsten-plate,
--                        gold-plate, platinum-plate, ...) that other mods had
--                        removed, which crashed Muluna surface generation.
--   #477               - control-stage modules indexed prototypes taken from
--                        Muluna.constants and crashed when one was missing.
--   #422               - a technology or recipe referenced an item/recipe name
--                        that no longer existed.
--
-- The fixture runs at data-final-fixes, after Muluna's own patches, so it sees
-- the prototype set that ships to players. It only checks names Muluna owns or
-- stores in its constants; optional cross-mod content Muluna deliberately
-- tolerates is skipped and the reason is recorded next to the skip.
local results = require("lib.results")

local SUITE = "content_references"

local CONSTANTS_PROTOTYPE = "muluna-constants"
local MULUNA_PREFIX = "muluna-"

-- data.raw.item only holds plain items: modules, ammo, tools, armor, capsules and
-- the other item subtypes each live in their own data.raw table. This pseudo type
-- matches any of them, so a recipe that consumes a speed-module is not reported
-- as a missing item. The subtype list comes from defines.prototypes.item, which
-- the data stage exposes, with the Factorio 2.1 subtype list as a fallback.
local ITEM_ANY = "item*"

local ITEM_SUBTYPES_2_1 = {
  "ammo",
  "armor",
  "blueprint",
  "blueprint-book",
  "capsule",
  "copy-paste-tool",
  "deconstruction-item",
  "gun",
  "item",
  "item-with-entity-data",
  "item-with-inventory",
  "item-with-label",
  "item-with-tags",
  "module",
  "rail-planner",
  "repair-tool",
  "selection-tool",
  "space-platform-starter-pack",
  "spidertron-remote",
  "tool",
  "upgrade-item",
}

-- Table-valued Muluna.constants entries whose prototype names are resolved by a
-- check in this fixture. Keep this in sync with the coverage guard in the
-- "constants-mod-data" check.
local HANDLED_CONSTANTS = {
  telescopes = true,
  heat_assembling_machines = true,
  vacuum_roboports = true,
  cargo_drop_spawn_imports = true,
  cargo_drop_rare_drops = true,
  recycling_recipes_to_fix = true,
  robot_names = true,
  names = true,
  planet_has_lightning = true,
  telescope_entities = true,
}

-- Table-valued Muluna.constants entries this fixture deliberately does not
-- resolve, and why. A new table-valued constant that is neither handled nor
-- listed here fails "constants-mod-data" so it cannot be added without coverage.
local IGNORED_CONSTANTS = {
  -- Entity names from optional mods, only used to skip an oxygen surface
  -- condition. A stale name is harmless: data-final-fixes.lua compares it with
  -- rro.contains() and never indexes data.raw with it.
  oxygen_restriction_blacklist = "optional cross-mod entity names, only passed to rro.contains()",
}

-- Prototype fields stored in each compound-entity constants entry, and the
-- data.raw type each one must resolve in.
local COMPOUND_CONSTANTS = {
  telescopes = {
    { field = "assembling-machine", prototype_type = "assembling-machine" },
    { field = "constant-combinator", prototype_type = "constant-combinator" },
  },
  heat_assembling_machines = {
    { field = "assembling-machine", prototype_type = "assembling-machine" },
    { field = "reactor", prototype_type = "reactor" },
  },
  vacuum_roboports = {
    { field = "roboport", prototype_type = "roboport" },
    -- The refueler half of a vacuum roboport is an assembling machine, not a
    -- roboport (prototypes/final-fixes/burner-roboports.lua).
    { field = "refueler", prototype_type = "assembling-machine" },
  },
}

-- Fields inside a cargo-drop spawn import that hold prototype references, and the
-- data.raw types they may resolve in. Only these exact field names are treated as
-- references; everything else is left alone.
local IMPORT_REFERENCE_FIELDS = {
  name = { ITEM_ANY, "fluid" },
  names = { ITEM_ANY, "fluid" },
  item = { ITEM_ANY },
  items = { ITEM_ANY },
  fluid = { "fluid" },
  fluids = { "fluid" },
}

-- Technology effect types that name a prototype, with the effect field and the
-- data.raw types it must resolve in.
local TECHNOLOGY_EFFECT_REFERENCES = {
  ["unlock-recipe"] = { field = "recipe", prototype_types = { "recipe" } },
  ["change-recipe-productivity"] = { field = "recipe", prototype_types = { "recipe" } },
  -- Planets are top-level `planet` prototypes in 2.1, not `space-location`.
  ["unlock-space-location"] = { field = "space_location", prototype_types = { "space-location", "planet" } },
  ["unlock-quality"] = { field = "quality", prototype_types = { "quality" } },
  ["give-item"] = { field = "item", prototype_types = { ITEM_ANY } },
}

---Return the data.raw bucket for a prototype type, or nil when that type is not
---present at all.
---@param prototype_type string
---@return table|nil
local function raw_bucket(prototype_type)
  if type(prototype_type) ~= "string" then return nil end
  local bucket = data.raw[prototype_type]
  if type(bucket) ~= "table" then return nil end
  return bucket
end

---@param prototype_type string
---@param name string
---@return boolean
local function prototype_exists(prototype_type, name)
  local bucket = raw_bucket(prototype_type)
  return bucket ~= nil and bucket[name] ~= nil
end

---@return string[]
local function item_subtypes()
  local subtypes = {}
  local defined = type(defines) == "table" and defines.prototypes and defines.prototypes.item
  if type(defined) == "table" then
    for type_name in pairs(defined) do
      subtypes[#subtypes + 1] = type_name
    end
  end
  if #subtypes == 0 then
    subtypes = ITEM_SUBTYPES_2_1
  end
  return subtypes
end

---True when `name` is an item of any subtype (plain item, module, ammo, ...).
---@param name string
---@return boolean
local function item_exists(name)
  for _, prototype_type in ipairs(item_subtypes()) do
    if prototype_exists(prototype_type, name) then return true end
  end
  return false
end

---@param prototype_types string[]
---@param name string
---@return boolean
local function reference_exists(prototype_types, name)
  for _, prototype_type in ipairs(prototype_types) do
    if prototype_type == ITEM_ANY then
      if item_exists(name) then return true end
    elseif prototype_exists(prototype_type, name) then
      return true
    end
  end
  return false
end

---@param prototype_types string[]
---@return string
local function type_label(prototype_types)
  local labels = {}
  for _, prototype_type in ipairs(prototype_types) do
    if prototype_type == ITEM_ANY then
      labels[#labels + 1] = "item"
    else
      labels[#labels + 1] = prototype_type
    end
  end
  return table.concat(labels, " or ")
end

---@param name any
---@return boolean
local function is_plain_prototype_name(name)
  -- Prototype names may only contain alphanumerics, dashes and underscores, so a
  -- dot means this is a LocalisedString key such as "item-name.wood" and not a
  -- prototype reference.
  return type(name) == "string" and name ~= "" and not string.find(name, ".", 1, true)
end

---Assert that `name` is a usable prototype name and that it exists in one of
---`prototype_types`.
---@param owner string Human readable owner, e.g. "recipe 'muluna-x' ingredient".
---@param prototype_types string[]
---@param name any
local function assert_prototype_any(owner, prototype_types, name)
  assert(
    type(name) == "string" and name ~= "",
    owner .. " does not store a prototype name (got " .. tostring(name) .. ")"
  )
  assert(
    is_plain_prototype_name(name),
    owner .. " stores a localised string instead of a prototype name: " .. name
  )
  assert(
    reference_exists(prototype_types, name),
    owner .. " references " .. type_label(prototype_types) .. " prototype '" .. name
      .. "', which does not exist in data.raw"
  )
end

---Assert that `name` exists in exactly one prototype type.
---@param owner string
---@param prototype_type string
---@param name any
local function assert_prototype(owner, prototype_type, name)
  assert_prototype_any(owner, { prototype_type }, name)
end

---Assert that `name` is an item of any subtype.
---@param owner string
---@param name any
local function assert_item(owner, name)
  assert_prototype_any(owner, { ITEM_ANY }, name)
end

---Resolve the constants carried between stages by the muluna-constants mod-data.
---@return table
local function get_constants()
  local mod_data = raw_bucket("mod-data")
  assert(mod_data, "data.raw['mod-data'] is missing")
  local prototype = mod_data[CONSTANTS_PROTOTYPE]
  assert(prototype, "the '" .. CONSTANTS_PROTOTYPE .. "' mod-data prototype is missing")
  assert(
    type(prototype.data) == "table",
    "the '" .. CONSTANTS_PROTOTYPE .. "' mod-data prototype has no data table"
  )
  return prototype.data
end

---@param name any
---@return boolean
local function is_muluna_name(name)
  return type(name) == "string" and string.sub(name, 1, #MULUNA_PREFIX) == MULUNA_PREFIX
end

---Extract a prototype name from a recipe ingredient/product or a technology
---research ingredient. data.raw normalises recipe ingredients into
---`{type=..., name=...}` but leaves technology research ingredients in the
---`{name, amount}` shorthand.
---@param entry any
---@return string|nil
local function reference_name(entry)
  if type(entry) == "string" then return entry end
  if type(entry) ~= "table" then return nil end
  if type(entry.name) == "string" then return entry.name end
  if type(entry[1]) == "string" then return entry[1] end
  return nil
end

---Walk a cargo-drop spawn import and assert every item/fluid name field resolves.
---Only fields named in IMPORT_REFERENCE_FIELDS are treated as references, and
---only string values are checked, so unrelated data (localised names, functions,
---numbers) is never mistaken for a prototype name.
---@param owner string
---@param node any
---@param depth integer
---@param seen table
---@param counter table {checked = integer}
local function walk_import(owner, node, depth, seen, counter)
  if type(node) ~= "table" then return end
  if seen[node] then return end
  seen[node] = true
  if depth > 4 then return end

  for key, value in pairs(node) do
    local prototype_types = type(key) == "string" and IMPORT_REFERENCE_FIELDS[key] or nil
    if prototype_types then
      if type(value) == "string" then
        -- Conservative: only strings that look like prototype names are checked,
        -- so a bare LocalisedString key is never reported as a missing prototype.
        if is_plain_prototype_name(value) then
          assert_prototype_any(owner .. "." .. key, prototype_types, value)
          counter.checked = counter.checked + 1
        end
      elseif type(value) == "table" then
        for _, element in ipairs(value) do
          if type(element) == "string" then
            if is_plain_prototype_name(element) then
              assert_prototype_any(owner .. "." .. key .. "[]", prototype_types, element)
              counter.checked = counter.checked + 1
            end
          elseif type(element) == "table" then
            walk_import(owner .. "." .. key .. "[]", element, depth + 1, seen, counter)
          end
        end
      end
    elseif type(value) == "table" then
      walk_import(owner .. "." .. tostring(key), value, depth + 1, seen, counter)
    end
  end
end

results.check(SUITE, "constants-mod-data", function()
  local constants = get_constants()

  local required = {
    "telescopes",
    "heat_assembling_machines",
    "vacuum_roboports",
    "cargo_drop_spawn_imports",
    "cargo_drop_rare_drops",
    "recycling_recipes_to_fix",
    "robot_names",
    "names",
    "planet_has_lightning",
  }
  for _, key in ipairs(required) do
    assert(type(constants[key]) == "table", "Muluna.constants." .. key .. " is missing")
    assert(next(constants[key]) ~= nil, "Muluna.constants." .. key .. " is empty")
  end

  -- Coverage guard: every table-valued constant must be resolved by a check in
  -- this fixture, or explicitly ignored with a reason. This keeps the fixture from
  -- silently missing a new table of prototype names.
  for key, value in pairs(constants) do
    if type(value) == "table" and not HANDLED_CONSTANTS[key] and not IGNORED_CONSTANTS[key] then
      error(
        "Muluna.constants." .. tostring(key) .. " is a table of unknown shape and is not covered by the"
          .. " content_references fixture. Add a check for it, or add it to IGNORED_CONSTANTS with the"
          .. " reason its names do not need to resolve."
      )
    end
  end
end)

results.check(SUITE, "constants-compound-entities", function()
  local constants = get_constants()
  local checked = 0

  for table_name, fields in pairs(COMPOUND_CONSTANTS) do
    local entries = constants[table_name]
    assert(type(entries) == "table", "Muluna.constants." .. table_name .. " is missing")
    assert(next(entries) ~= nil, "Muluna.constants." .. table_name .. " is empty")

    for entry_key, entry in pairs(entries) do
      local owner = "Muluna.constants." .. table_name .. "[" .. tostring(entry_key) .. "]"
      assert(type(entry) == "table", owner .. " is not a table")
      for _, spec in ipairs(fields) do
        -- Every compound entity is described by all of its parts, so a missing
        -- field means control-stage code will index nil.
        assert(entry[spec.field] ~= nil, owner .. " has no " .. spec.field .. " field")
        assert_prototype(owner .. "." .. spec.field, spec.prototype_type, entry[spec.field])
        checked = checked + 1
      end
    end
  end

  -- `telescope_entities` is not populated today (prototypes/entity/telescopes.lua
  -- soft_inserts into a nil list, which discards the entry). Check it when it
  -- appears: each entry holds the placeable item name.
  for _, entry in ipairs(constants.telescope_entities or {}) do
    assert(type(entry) == "table", "Muluna.constants.telescope_entities entry is not a table")
    assert_item("Muluna.constants.telescope_entities[].name", entry.name)
    checked = checked + 1
  end

  assert(checked > 0, "no compound entity prototype references were checked")
end)

results.check(SUITE, "cargo-drop-spawn-imports", function()
  local constants = get_constants()
  local imports = constants.cargo_drop_spawn_imports
  assert(type(imports) == "table", "Muluna.constants.cargo_drop_spawn_imports is missing")
  assert(#imports > 0, "Muluna.constants.cargo_drop_spawn_imports is empty")

  local counter = { checked = 0 }
  for _, import in ipairs(imports) do
    assert(type(import) == "string", "cargo_drop_spawn_imports holds a non-string entry: " .. tostring(import))
    local ok, spawn = pcall(require, import)
    assert(ok, "cargo drop spawn import failed to load: " .. import .. " (" .. tostring(spawn) .. ")")
    assert(type(spawn) == "table", "cargo drop spawn import did not return a table: " .. import)
    -- Imports return either a single spawn table or a list of them; the walker
    -- handles both because it descends into any nested table.
    walk_import(import, spawn, 1, {}, counter)
  end

  -- #386/#447/#388: every import has to name at least one item, otherwise this
  -- check would pass while testing nothing.
  assert(counter.checked > 0, "no item or fluid names were found in the cargo drop spawn imports")
end)

results.check(SUITE, "cargo-drop-rare-drops", function()
  local constants = get_constants()
  local rare = constants.cargo_drop_rare_drops
  assert(type(rare) == "table", "Muluna.constants.cargo_drop_rare_drops is missing")
  assert(next(rare) ~= nil, "Muluna.constants.cargo_drop_rare_drops is empty")

  local total, enforced = 0, 0
  for key, item_name in pairs(rare) do
    local owner = "Muluna.constants.cargo_drop_rare_drops[" .. tostring(key) .. "]"
    total = total + 1
    assert(
      type(item_name) == "string" and item_name ~= "",
      owner .. " does not store an item name (got " .. tostring(item_name) .. ")"
    )

    -- scripts/new-surface.lua only spawns a rare drop when `mods[mod]` is true, so
    -- that exact gate decides whether a missing item can reach the spawn code. An
    -- entry keyed by a planet name instead of a mod name (for example
    -- "dea-dia-system") is never reached by production code, so it is not
    -- enforced here either.
    if mods[key] == true then
      assert_item(owner, item_name)
      enforced = enforced + 1
    end
  end

  assert(total > 0, "Muluna.constants.cargo_drop_rare_drops is empty")
  log(
    "[funit] content_references: cargo_drop_rare_drops checked " .. tostring(total)
      .. " entries, enforced " .. tostring(enforced) .. " (the rest belong to inactive mods)"
  )
end)

results.check(SUITE, "recycling-recipe-constants", function()
  local constants = get_constants()
  local recipes = constants.recycling_recipes_to_fix
  assert(type(recipes) == "table", "Muluna.constants.recycling_recipes_to_fix is missing")
  assert(#recipes > 0, "Muluna.constants.recycling_recipes_to_fix is empty")

  for _, recipe_name in ipairs(recipes) do
    -- data-final-fixes.lua deep-copies `<recipe>-recycling` for every entry, so
    -- both names have to exist by the end of the data stage (#422).
    assert_prototype("Muluna.constants.recycling_recipes_to_fix", "recipe", recipe_name)
    assert_prototype(
      "Muluna.constants.recycling_recipes_to_fix",
      "recipe",
      recipe_name .. "-recycling"
    )
  end
end)

results.check(SUITE, "constants-named-prototypes", function()
  local constants = get_constants()

  -- prototypes/vacuum-robots.lua iterates these item names.
  local robot_names = constants.robot_names
  assert(type(robot_names) == "table", "Muluna.constants.robot_names is missing")
  local robot_count = 0
  for _, item_name in ipairs(robot_names) do
    assert_item("Muluna.constants.robot_names", item_name)
    robot_count = robot_count + 1
  end
  assert(robot_count > 0, "Muluna.constants.robot_names is empty")

  -- lib/names.lua maps Muluna's canonical item names to the name the active mod
  -- set actually uses. An empty value means "not available"; cargo drop spawns
  -- resolve that to nil and skip the item, so it is not a crash.
  local names = constants.names
  assert(type(names) == "table", "Muluna.constants.names is missing")
  local name_count = 0
  for key, item_name in pairs(names) do
    assert(
      type(item_name) == "string",
      "Muluna.constants.names['" .. tostring(key) .. "'] is not a string"
    )
    if item_name ~= "" then
      assert_item("Muluna.constants.names['" .. tostring(key) .. "']", item_name)
      name_count = name_count + 1
    end
  end
  assert(name_count > 0, "no Muluna.constants.names entries were checked")

  -- prototypes/overrides/telescope-data.lua keys this by planet name.
  local planet_has_lightning = constants.planet_has_lightning
  assert(type(planet_has_lightning) == "table", "Muluna.constants.planet_has_lightning is missing")
  local planet_count = 0
  for planet_name in pairs(planet_has_lightning) do
    assert_prototype("Muluna.constants.planet_has_lightning", "planet", planet_name)
    planet_count = planet_count + 1
  end
  assert(planet_count > 0, "Muluna.constants.planet_has_lightning is empty")
end)

results.check(SUITE, "muluna-recipes", function()
  local recipes = raw_bucket("recipe")
  assert(recipes, "data.raw.recipe is missing")

  local recipe_count, reference_count = 0, 0
  for name, recipe in pairs(recipes) do
    -- `parameter = true` recipes are templates whose ingredient names are
    -- placeholders, not prototypes.
    if is_muluna_name(name) and recipe.parameter ~= true then
      recipe_count = recipe_count + 1
      local owner = "recipe '" .. name .. "'"

      for _, ingredient in ipairs(recipe.ingredients or {}) do
        -- data.raw normalises ingredients to `{type=..., name=...}`, but tolerate
        -- the `{name, amount}` shorthand so a mod that writes it cannot crash the
        -- fixture itself.
        local prototype_type = type(ingredient) == "table" and ingredient.type or "item"
        local referenced = reference_name(ingredient)
        if prototype_type == "fluid" then
          assert_prototype(owner .. " ingredient", "fluid", referenced)
        elseif prototype_type == "item" then
          assert_item(owner .. " ingredient", referenced)
        else
          -- Ingredients with a type other than item/fluid do not name a
          -- prototype.
          prototype_type = nil
        end
        if prototype_type then reference_count = reference_count + 1 end
      end

      for _, product in ipairs(recipe.results or {}) do
        local prototype_type = type(product) == "table" and product.type or "item"
        local referenced = reference_name(product)
        if prototype_type == "fluid" then
          assert_prototype(owner .. " result", "fluid", referenced)
        elseif prototype_type == "item" then
          assert_item(owner .. " result", referenced)
        else
          -- Products with a type other than item/fluid (research-progress, ...)
          -- do not name a prototype.
          prototype_type = nil
        end
        if prototype_type then reference_count = reference_count + 1 end
      end
    end
  end

  assert(recipe_count > 0, "no muluna-* recipes were found in data.raw.recipe")
  assert(reference_count > 0, "no muluna-* recipe ingredient or result references were checked")
end)

results.check(SUITE, "muluna-technologies", function()
  local technologies = raw_bucket("technology")
  assert(technologies, "data.raw.technology is missing")

  local technology_count, reference_count = 0, 0
  for name, technology in pairs(technologies) do
    if is_muluna_name(name) then
      technology_count = technology_count + 1
      local owner = "technology '" .. name .. "'"

      for _, prerequisite in ipairs(technology.prerequisites or {}) do
        assert_prototype(owner .. " prerequisite", "technology", prerequisite)
        reference_count = reference_count + 1
      end

      for _, ingredient in ipairs(technology.unit and technology.unit.ingredients or {}) do
        assert_item(owner .. " research ingredient", reference_name(ingredient))
        reference_count = reference_count + 1
      end

      for _, effect in ipairs(technology.effects or {}) do
        local spec = TECHNOLOGY_EFFECT_REFERENCES[effect.type]
        if spec then
          assert_prototype_any(owner .. " " .. effect.type .. " effect", spec.prototype_types, effect[spec.field])
          reference_count = reference_count + 1
        end
      end
    end
  end

  assert(technology_count > 0, "no muluna-* technologies were found in data.raw.technology")
  assert(reference_count > 0, "no muluna-* technology references were checked")
end)
