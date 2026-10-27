-- Data-final-fixes integrity checks over the final prototype set.
--
-- Each check covers a data-stage crash class from a historical report:
--
--   #486 space-chest-muluna icon entry invalid        -> icon-fields-valid
--   #111 item icon layer invalid                      -> icon-fields-valid
--   #168 item icon missing                            -> icon-fields-valid
--   #397 / #256 icon missing on a technology          -> icon-fields-valid
--   #478 fuel_category removed                        -> item-fuel-fields-valid
--   #275 effect_receivers wrong type                  -> effect-receiver-is-table
--   #395 duplicate technology prerequisite            -> technology-integrity
--   #258 next_upgrade bounding-box mismatch           -> entity-next-upgrade-valid
--   #116 working_visualisations not a list            -> working-visualisations-are-lists
--   #259 unknown decorative name                      -> planet-map-gen-names-resolve
--
-- #168, #256, #397 and #486 all had the same shape: a mod removed the
-- prototype Muluna copied an icon from, so an `icons` layer ended up with a
-- nil or non-string `icon`. That is what `icon-fields-valid` checks. It does
-- not require every prototype to have an icon, because Factorio tolerates a
-- missing icon (it draws a placeholder) and Muluna itself has technologies
-- that only get a placeholder icon from its data-updates pass.
--
-- The fixtures run at data-final-fixes, so `data.raw` is the state that ships
-- to players (barring a mod that depends on Muluna and patches afterwards).
-- Every check asserts that it actually examined something, and failure
-- messages name the prototype type and name.
local results = require("lib.results")

local SUITE = "prototype_integrity"

-- These prototype types define `icon` as a Sprite (a table), not as a file
-- path string, so the string-icon rule must not be applied to them.
local ICON_IS_SPRITE = {
  ["airborne-pollutant"] = true,
  ["burner-usage"] = true,
}

---Readable "type/name" label for messages.
---@param prototype_type string
---@param name any
---@return string
local function label(prototype_type, name)
  return tostring(prototype_type) .. "/" .. tostring(name)
end

---Length of a Lua array, or nil when the value is not an array.
---A table with string keys, a [0] entry or a hole is not an array.
---@param value any
---@return integer|nil
local function list_length(value)
  if type(value) ~= "table" then
    return nil
  end
  local count = 0
  for key in pairs(value) do
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
      return nil
    end
    count = count + 1
  end
  for index = 1, count do
    if value[index] == nil then
      return nil
    end
  end
  return count
end

---Describe a value for a failure message without dumping the whole table.
---@param value any
---@return string
local function describe(value)
  if value == nil then
    return "nil"
  end
  if type(value) ~= "table" then
    return type(value) .. " (" .. tostring(value) .. ")"
  end
  local count = list_length(value)
  if count then
    return "an array of " .. tostring(count) .. " entries"
  end
  return "a table that is not an array"
end

---Format a bounding box for a failure message.
---@param box any
---@return string
local function format_box(box)
  if type(box) ~= "table" or type(box[1]) ~= "table" or type(box[2]) ~= "table" then
    return tostring(box)
  end
  return string.format("{{%s, %s}, {%s, %s}}",
    tostring(box[1][1]), tostring(box[1][2]),
    tostring(box[2][1]), tostring(box[2][2]))
end

---A missing collision_box means the empty box, which is the engine default.
---@param box any
---@return table
local function box_or_empty(box)
  if box == nil then
    return { { 0, 0 }, { 0, 0 } }
  end
  return box
end

---Compare two bounding boxes, treating nil as the empty box.
---@param left any
---@param right any
---@return boolean
local function boxes_equal(left, right)
  local a = box_or_empty(left)
  local b = box_or_empty(right)
  for index = 1, 2 do
    local a_point, b_point = a[index], b[index]
    if type(a_point) ~= "table" or type(b_point) ~= "table" then
      return false
    end
    for axis = 1, 2 do
      if a_point[axis] ~= b_point[axis] then
        return false
      end
    end
  end
  return true
end

-- Fields that entity prototypes have and non-entity prototypes generally do
-- not. Used only as a fallback when a next_upgrade target is not of the same
-- prototype type as its source.
local ENTITY_MARKER_FIELDS = {
  "collision_box",
  "selection_box",
  "map_generator_bounding_box",
  "collision_mask",
  "max_health",
  "minable",
  "placeable_by",
  "fast_replaceable_group",
  "next_upgrade",
  "tile_width",
  "tile_height",
  "drawing_box",
  "sticker_box",
}

---@param prototype any
---@return boolean
local function looks_like_entity(prototype)
  if type(prototype) ~= "table" then
    return false
  end
  for _, field in ipairs(ENTITY_MARKER_FIELDS) do
    if prototype[field] ~= nil then
      return true
    end
  end
  return false
end

---Find a prototype by name, preferring the source entity's prototype type.
---@param name string
---@param source_type string
---@return table|nil
local function find_entity_like(name, source_type)
  local same_type = data.raw[source_type] and data.raw[source_type][name]
  if type(same_type) == "table" then
    return same_type
  end
  local fallback
  for _, prototypes in pairs(data.raw) do
    if type(prototypes) == "table" then
      local candidate = prototypes[name]
      if looks_like_entity(candidate) then
        if candidate.type == source_type then
          return candidate
        end
        fallback = fallback or candidate
      end
    end
  end
  return fallback
end

---Validate one icon layer array (icons, dark_background_icons, ...).
---Appends actionable messages to `violations`.
---@param where string
---@param icons any
---@param violations string[]
local function check_icon_layers(where, icons, violations)
  local count = list_length(icons)
  if count == nil or count == 0 then
    violations[#violations + 1] = where .. ": must be a non-empty array, got " .. describe(icons)
    return
  end
  for index, entry in ipairs(icons) do
    local entry_where = where .. "[" .. tostring(index) .. "]"
    if type(entry) ~= "table" then
      violations[#violations + 1] = entry_where .. ": must be a table, got " .. describe(entry)
    else
      if type(entry.icon) ~= "string" then
        violations[#violations + 1] = entry_where .. ".icon: must be a file path string, got " .. describe(entry.icon)
      elseif entry.icon == "" then
        violations[#violations + 1] = entry_where .. ".icon: file path is empty"
      end
      if entry.icon_size ~= nil and (type(entry.icon_size) ~= "number" or entry.icon_size <= 0) then
        violations[#violations + 1] = entry_where .. ".icon_size: must be a positive number, got " .. describe(entry.icon_size)
      end
    end
  end
end

-- #486, #111, #168, #256, #397: every icon field and icon layer must have the
-- shape the engine expects. `icon` is a file path string, `icon_size` a
-- positive number, and each `icons` entry an IconData table with a string
-- `icon`. A layer whose source prototype was removed shows up here as a nil
-- `icon` on the entry.
results.check(SUITE, "icon-fields-valid", function()
  local examined = 0
  local violations = {}

  for prototype_type, prototypes in pairs(data.raw) do
    if type(prototypes) == "table" then
      for name, prototype in pairs(prototypes) do
        if type(prototype) == "table" then
          local has_icon = prototype.icon ~= nil
          local has_icons = prototype.icons ~= nil
          local has_icon_size = prototype.icon_size ~= nil
          local has_dark_icons = prototype_type == "item" and (prototype.dark_background_icon ~= nil
            or prototype.dark_background_icons ~= nil
            or prototype.dark_background_icon_size ~= nil)
          if has_icon or has_icons or has_icon_size or has_dark_icons then
            examined = examined + 1
            local where = label(prototype_type, name)

            if has_icon and not ICON_IS_SPRITE[prototype_type] then
              if type(prototype.icon) ~= "string" then
                violations[#violations + 1] = where .. ": icon must be a file path string, got " .. describe(prototype.icon)
              elseif prototype.icon == "" then
                violations[#violations + 1] = where .. ": icon file path is empty"
              end
            end

            if has_icon_size and (type(prototype.icon_size) ~= "number" or prototype.icon_size <= 0) then
              violations[#violations + 1] = where .. ": icon_size must be a positive number, got " .. describe(prototype.icon_size)
            end

            if has_icons then
              check_icon_layers(where .. ".icons", prototype.icons, violations)
            end

            -- ItemPrototype also has dark background icon fields. They follow
            -- the same IconData rules and are not covered by the fields above.
            if prototype_type == "item" then
              if prototype.dark_background_icon ~= nil then
                if type(prototype.dark_background_icon) ~= "string" then
                  violations[#violations + 1] = where .. ": dark_background_icon must be a file path string, got " .. describe(prototype.dark_background_icon)
                elseif prototype.dark_background_icon == "" then
                  violations[#violations + 1] = where .. ": dark_background_icon file path is empty"
                end
              end
              if prototype.dark_background_icon_size ~= nil
                and (type(prototype.dark_background_icon_size) ~= "number" or prototype.dark_background_icon_size <= 0) then
                violations[#violations + 1] = where .. ": dark_background_icon_size must be a positive number, got " .. describe(prototype.dark_background_icon_size)
              end
              if prototype.dark_background_icons ~= nil then
                check_icon_layers(where .. ".dark_background_icons", prototype.dark_background_icons, violations)
              end
            end
          end
        end
      end
    end
  end

  assert(#violations == 0, table.concat(violations, "; "))
  assert(examined > 0, "no prototype defines icon, icon_size or icons")
end)

-- #478: `fuel_category` (singular) was removed in Factorio 2.0. Fuel is
-- declared with a non-empty `fuel_categories` string array, and an item with a
-- positive fuel_value must declare at least one category.
results.check(SUITE, "item-fuel-fields-valid", function()
  local items = data.raw["item"]
  assert(type(items) == "table" and next(items) ~= nil, "data.raw.item is missing or empty")

  local with_categories = 0
  local violations = {}
  for name, item in pairs(items) do
    if type(item) == "table" then
      local where = label("item", name)

      if item.fuel_category ~= nil then
        violations[#violations + 1] = where .. ": legacy fuel_category is set (" .. tostring(item.fuel_category) .. "); use fuel_categories"
      end

      local categories = item.fuel_categories
      local category_count = 0
      if categories ~= nil then
        with_categories = with_categories + 1
        local count = list_length(categories)
        if count == nil or count == 0 then
          violations[#violations + 1] = where .. ": fuel_categories must be a non-empty array of strings, got " .. describe(categories)
        else
          category_count = count
          for index, category in ipairs(categories) do
            if type(category) ~= "string" then
              violations[#violations + 1] = where .. ": fuel_categories[" .. tostring(index) .. "] must be a string, got " .. describe(category)
            end
          end
        end
      end

      if type(item.fuel_value) == "number" and item.fuel_value > 0 and category_count == 0 then
        violations[#violations + 1] = where .. ": fuel_value is set but fuel_categories is missing or empty"
      end
    end
  end

  assert(#violations == 0, table.concat(violations, "; "))
  assert(with_categories > 0, "no item defines fuel_categories")
end)

-- #275: effect receivers are a struct (`effect_receiver` in 2.1, the older
-- `effect_receivers` list before that), never a plain string. A string here
-- makes the prototype fail to load.
results.check(SUITE, "effect-receiver-is-table", function()
  local examined = 0
  local violations = {}

  for prototype_type, prototypes in pairs(data.raw) do
    if type(prototypes) == "table" then
      for name, prototype in pairs(prototypes) do
        if type(prototype) == "table" then
          if prototype.effect_receiver ~= nil then
            examined = examined + 1
            if type(prototype.effect_receiver) ~= "table" then
              violations[#violations + 1] = label(prototype_type, name)
                .. ": effect_receiver must be a table, got " .. describe(prototype.effect_receiver)
            end
          end
          -- Legacy plural field. It does not exist in 2.1, but other mods may
          -- still set it, and a string there is the shape from #275.
          if prototype.effect_receivers ~= nil and type(prototype.effect_receivers) ~= "table" then
            violations[#violations + 1] = label(prototype_type, name)
              .. ": effect_receivers must be a table, got " .. describe(prototype.effect_receivers)
          end
        end
      end
    end
  end

  assert(#violations == 0, table.concat(violations, "; "))
  assert(examined > 0, "no prototype defines effect_receiver")
end)

-- #395: prerequisite lists must not contain duplicates and must only name
-- existing technologies. Also verifies every technology is researchable and
-- that unlock effects point at recipes that exist.
results.check(SUITE, "technology-integrity", function()
  local technologies = data.raw["technology"]
  assert(type(technologies) == "table" and next(technologies) ~= nil, "data.raw.technology is missing or empty")
  local recipes = data.raw["recipe"] or {}

  local examined = 0
  local prerequisites_examined = 0
  local unlocks_examined = 0
  local violations = {}

  for name, technology in pairs(technologies) do
    if type(technology) == "table" then
      examined = examined + 1
      local where = label("technology", name)

      if technology.unit == nil and technology.research_trigger == nil then
        violations[#violations + 1] = where .. ": has neither unit nor research_trigger"
      end

      local prerequisites = technology.prerequisites
      if prerequisites ~= nil then
        local count = list_length(prerequisites)
        if count == nil then
          violations[#violations + 1] = where .. ": prerequisites must be an array, got " .. describe(prerequisites)
        else
          local seen = {}
          for index, prerequisite in ipairs(prerequisites) do
            prerequisites_examined = prerequisites_examined + 1
            if type(prerequisite) ~= "string" then
              violations[#violations + 1] = where .. ": prerequisites[" .. tostring(index) .. "] must be a technology name, got " .. describe(prerequisite)
            elseif seen[prerequisite] then
              violations[#violations + 1] = where .. ": duplicate prerequisite " .. prerequisite
            else
              seen[prerequisite] = true
              if technologies[prerequisite] == nil then
                violations[#violations + 1] = where .. ": prerequisite " .. prerequisite .. " does not exist"
              end
            end
          end
        end
      end

      local effects = technology.effects
      if effects ~= nil then
        local count = list_length(effects)
        if count == nil then
          violations[#violations + 1] = where .. ": effects must be an array, got " .. describe(effects)
        else
          for index, effect in ipairs(effects) do
            if type(effect) ~= "table" then
              violations[#violations + 1] = where .. ": effects[" .. tostring(index) .. "] must be a table, got " .. describe(effect)
            elseif effect.type == "unlock-recipe" or effect.type == "change-recipe-productivity" then
              unlocks_examined = unlocks_examined + 1
              local recipe = effect.recipe
              if type(recipe) ~= "string" then
                violations[#violations + 1] = where .. ": " .. tostring(effect.type) .. " effect has no recipe name"
              elseif recipes[recipe] == nil then
                violations[#violations + 1] = where .. ": " .. tostring(effect.type) .. " references missing recipe " .. recipe
              end
            end
          end
        end
      end
    end
  end

  assert(#violations == 0, table.concat(violations, "; "))
  assert(examined > 0, "no technology prototypes were examined")
  assert(prerequisites_examined > 0, "no technology prerequisites were examined")
  assert(unlocks_examined > 0, "no unlock-recipe or change-recipe-productivity effects were examined")
end)

-- #258: next_upgrade must name an existing entity with the same bounding box.
-- The engine rejects a mismatch, but this reports which prototype is wrong
-- instead of only failing later with a generic prototype error.
results.check(SUITE, "entity-next-upgrade-valid", function()
  local examined = 0
  local violations = {}

  for prototype_type, prototypes in pairs(data.raw) do
    if type(prototypes) == "table" then
      for name, prototype in pairs(prototypes) do
        if type(prototype) == "table" and prototype.next_upgrade ~= nil then
          examined = examined + 1
          local where = label(prototype_type, name)
          local target_name = prototype.next_upgrade
          if type(target_name) ~= "string" then
            violations[#violations + 1] = where .. ": next_upgrade must be an entity name, got " .. describe(target_name)
          else
            local target = find_entity_like(target_name, prototype_type)
            if target == nil then
              violations[#violations + 1] = where .. ": next_upgrade target " .. target_name .. " does not exist"
            elseif not boxes_equal(prototype.collision_box, target.collision_box) then
              violations[#violations + 1] = where .. ": next_upgrade target " .. target_name
                .. " has collision_box " .. format_box(target.collision_box)
                .. ", expected " .. format_box(prototype.collision_box)
            end
          end
        end
      end
    end
  end

  assert(#violations == 0, table.concat(violations, "; "))
  assert(examined > 0, "no prototype defines next_upgrade")
end)

-- #116: working_visualisations is an array of WorkingVisualisation tables. A
-- single table or a name-keyed map is not a list and crashes the graphics
-- setup.
results.check(SUITE, "working-visualisations-are-lists", function()
  local examined = 0
  local violations = {}

  for prototype_type, prototypes in pairs(data.raw) do
    if type(prototypes) == "table" then
      for name, prototype in pairs(prototypes) do
        if type(prototype) == "table" and prototype.graphics_set ~= nil then
          local where = label(prototype_type, name)
          local graphics_set = prototype.graphics_set
          if type(graphics_set) ~= "table" then
            violations[#violations + 1] = where .. ": graphics_set must be a table, got " .. describe(graphics_set)
          elseif graphics_set.working_visualisations ~= nil then
            examined = examined + 1
            local visualisations = graphics_set.working_visualisations
            local count = list_length(visualisations)
            if count == nil then
              violations[#violations + 1] = where .. ": graphics_set.working_visualisations must be an array, got " .. describe(visualisations)
            else
              for index, visualisation in ipairs(visualisations) do
                if type(visualisation) ~= "table" then
                  violations[#violations + 1] = where .. ": graphics_set.working_visualisations[" .. tostring(index) .. "] must be a table, got " .. describe(visualisation)
                end
              end
            end
          end
        end
      end
    end
  end

  assert(#violations == 0, table.concat(violations, "; "))
  assert(examined > 0, "no prototype defines graphics_set.working_visualisations")
end)

-- #259: planet map generation must only name decorative and autoplace-control
-- prototypes that exist. Lunar rock decoratives can be removed by another mod,
-- and a dangling name fails world generation.
results.check(SUITE, "planet-map-gen-names-resolve", function()
  local planets = data.raw["planet"]
  assert(type(planets) == "table" and next(planets) ~= nil, "data.raw.planet is missing or empty")

  -- Decorative prototypes live under "optimized-decorative" in 2.1. Keep the
  -- old "decorative" type as a fallback for older builds.
  local decorative_type = data.raw["optimized-decorative"] and "optimized-decorative" or "decorative"
  local decoratives = data.raw[decorative_type]
  assert(type(decoratives) == "table" and next(decoratives) ~= nil,
    "no decorative prototypes were found under data.raw." .. decorative_type)
  local autoplace_controls = data.raw["autoplace-control"] or {}

  local decorative_names = 0
  local control_names = 0
  local violations = {}

  for planet_name, planet in pairs(planets) do
    local where = label("planet", planet_name)
    if type(planet) ~= "table" then
      violations[#violations + 1] = where .. ": is not a table"
    else
      local map_gen = planet.map_gen_settings
      if map_gen ~= nil and type(map_gen) ~= "table" then
        violations[#violations + 1] = where .. ": map_gen_settings must be a table, got " .. describe(map_gen)
      elseif type(map_gen) == "table" then
        local controls = map_gen.autoplace_controls
        if controls ~= nil then
          if type(controls) ~= "table" then
            violations[#violations + 1] = where .. ": map_gen_settings.autoplace_controls must be a table, got " .. describe(controls)
          else
            for control_name in pairs(controls) do
              if type(control_name) == "string" then
                control_names = control_names + 1
                if autoplace_controls[control_name] == nil then
                  violations[#violations + 1] = where .. ": autoplace_controls references unknown autoplace control " .. control_name
                end
              end
            end
          end
        end

        local autoplace_settings = map_gen.autoplace_settings
        if autoplace_settings ~= nil then
          if type(autoplace_settings) ~= "table" then
            violations[#violations + 1] = where .. ": map_gen_settings.autoplace_settings must be a table, got " .. describe(autoplace_settings)
          else
            -- Only the "decorative" kind is checked. Entity and tile settings
            -- can name any prototype type, so a name lookup is not cheap or
            -- unambiguous here.
            local decorative_settings = autoplace_settings.decorative
            if decorative_settings ~= nil then
              if type(decorative_settings) ~= "table" then
                violations[#violations + 1] = where .. ": autoplace_settings.decorative must be a table, got " .. describe(decorative_settings)
              elseif decorative_settings.settings ~= nil then
                local settings = decorative_settings.settings
                if type(settings) ~= "table" then
                  violations[#violations + 1] = where .. ": autoplace_settings.decorative.settings must be a table, got " .. describe(settings)
                else
                  for decorative_name in pairs(settings) do
                    if type(decorative_name) == "string" then
                      decorative_names = decorative_names + 1
                      if decoratives[decorative_name] == nil then
                        violations[#violations + 1] = where .. ": decorative autoplace references unknown decorative " .. decorative_name
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  assert(#violations == 0, table.concat(violations, "; "))
  assert(decorative_names > 0, "no planet decorative autoplace settings were examined")
  assert(control_names > 0, "no planet autoplace controls were examined")
end)
