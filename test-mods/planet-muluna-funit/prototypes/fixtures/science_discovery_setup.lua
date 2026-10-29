-- Synthetic prototypes for the dynamic exploration science pack discovery tests.
--
-- This fixture intentionally runs in data-updates so the prototypes exist before
-- planet-muluna's data-final-fixes pass recomputes the pack list.
local SUITE = "science"

local results = require("lib.results")

local function add_lab_input(item_name)
  local lab = data.raw["lab"]["lab"]
  assert(lab and lab.inputs, "vanilla lab is missing")
  for _, input in ipairs(lab.inputs) do
    if input == item_name then return end
  end
  table.insert(lab.inputs, item_name)
end

local function add_science_pack_item(item_name)
  local item = table.deepcopy(data.raw["item"]["automation-science-pack"])
  item.name = item_name
  item.localised_name = {"item-name.automation-science-pack"}
  item.order = "z[" .. item_name .. "]"
  data:extend{item}
  add_lab_input(item_name)
  return item
end

local function add_recipe(recipe_name, item_name, surface_conditions, categories)
  local item = data.raw["item"][item_name]
  data:extend{{
    type = "recipe",
    name = recipe_name,
    categories = categories or {"crafting"},
    enabled = false,
    hidden = true,
    icon = item.icon,
    icon_size = item.icon_size or 64,
    ingredients = {
      {type = "item", name = "iron-plate", amount = 1},
    },
    results = {
      {type = "item", name = item_name, amount = 1},
    },
    energy_required = 1,
    surface_conditions = surface_conditions,
  }}
end

local function add_technology(technology_name, recipe_name, extra)
  local technology = {
    type = "technology",
    name = technology_name,
    icon = "__base__/graphics/technology/automation-science-pack.png",
    icon_size = 256,
    effects = recipe_name and {{type = "unlock-recipe", recipe = recipe_name}} or {},
    unit = {
      count = 1,
      time = 1,
      ingredients = {{"space-science-pack", 1}},
    },
    enabled = true,
    hidden = true,
    order = "zzz[" .. technology_name .. "]",
  }
  for key, value in pairs(extra or {}) do
    technology[key] = value
  end
  data:extend{technology}
end

results.check(SUITE, "science-discovery-setup", function()
  data:extend{{
    type = "surface-property",
    name = "muluna-funit-exploration-test",
    default_value = 0,
    order = "zzz",
    hidden_in_factoriopedia = true,
  }}

  local muluna = data.raw["planet"]["muluna"]
  assert(muluna, "Muluna planet is missing")
  muluna.surface_properties = muluna.surface_properties or {}
  muluna.surface_properties["muluna-funit-exploration-test"] = 1

  add_science_pack_item("muluna-funit-science-pack")
  add_recipe(
    "muluna-funit-science-pack",
    "muluna-funit-science-pack",
    {{property = "muluna-funit-exploration-test", min = 1, max = 1}}
  )
  add_technology("muluna-funit-science-pack", "muluna-funit-science-pack", {
    prerequisites = {"planet-discovery-muluna"},
  })

  -- A second pack on the same planet must not contribute; only the first
  -- unlocked pack on Muluna should remain. Any Planet Start removes every
  -- prerequisite that points at planet-discovery-muluna, so under the
  -- muluna-start mod set the discovery technology cannot reach either pack and
  -- selection falls back to distance from the prerequisite-free technologies.
  add_science_pack_item("muluna-funit-aaa-science-pack")
  add_recipe(
    "muluna-funit-aaa-science-pack",
    "muluna-funit-aaa-science-pack",
    {{property = "muluna-funit-exploration-test", min = 1, max = 1}}
  )
  add_technology("muluna-funit-aaa-science", "muluna-funit-aaa-science-pack", {
    prerequisites = {"muluna-funit-science-pack"},
  })

  -- An alternative recipe for the same synthetic pack, craftable on Vulcanus.
  add_recipe(
    "muluna-funit-science-pack-alt",
    "muluna-funit-science-pack",
    {{property = "pressure", min = 4000, max = 4000}}
  )
  add_technology("muluna-funit-science-pack-alt", "muluna-funit-science-pack-alt")

  -- An alternative recipe for a hardcoded vanilla pack. It is deliberately not
  -- planet-specific, proving that eligibility is attached to the pack item.
  add_recipe("muluna-funit-alt-metallurgic-science-pack", "metallurgic-science-pack")
  add_technology("muluna-funit-alt-metallurgic-science", "muluna-funit-alt-metallurgic-science-pack")

  -- A recycling recipe must never make its technology a contributor.
  add_recipe(
    "muluna-funit-science-pack-recycling",
    "muluna-funit-science-pack",
    nil,
    {"recycling"}
  )
  add_technology("muluna-funit-recycling-science", "muluna-funit-science-pack-recycling")

  -- Rigor Module generates large numbers of scaled recipe variants. They must
  -- not be treated as separate science pack recipes.
  add_recipe(
    "muluna-funit-science-pack__rigor_module_mod__25",
    "muluna-funit-science-pack"
  )
  add_technology("muluna-funit-rigor-science", "muluna-funit-science-pack__rigor_module_mod__25")

  -- A shared pack (no surface conditions) must not become a dynamic pack,
  -- even when an alternative recipe is restricted to one planet.
  add_science_pack_item("muluna-funit-shared-science-pack")
  add_recipe("muluna-funit-shared-science-pack", "muluna-funit-shared-science-pack")
  add_technology("muluna-funit-shared-science-pack", "muluna-funit-shared-science-pack")
  add_recipe(
    "muluna-funit-shared-science-pack-alt",
    "muluna-funit-shared-science-pack",
    {{property = "muluna-funit-exploration-test", min = 1, max = 1}}
  )
  add_technology("muluna-funit-shared-science-pack-alt", "muluna-funit-shared-science-pack-alt")

  -- Explicit opt-out from the technology field.
  add_science_pack_item("muluna-funit-forced-false-science-pack")
  add_recipe(
    "muluna-funit-forced-false-science-pack",
    "muluna-funit-forced-false-science-pack",
    {{property = "muluna-funit-exploration-test", min = 1, max = 1}}
  )
  add_technology("muluna-funit-forced-false-science-pack", "muluna-funit-forced-false-science-pack", {
    muluna_adds_progress_to_exploration_science_pack = false,
  })

  -- Explicit opt-in for a technology that does not unlock a science pack.
  add_technology("muluna-funit-forced-true-tech", nil, {
    muluna_adds_progress_to_exploration_science_pack = true,
  })

  -- Rabbasca's athletic pack is in the frozen legacy list but its recipe has no
  -- surface conditions, so dynamic detection cannot classify it. Create a
  -- faithful synthetic stand-in when Rabbasca is not installed so the legacy
  -- fallback is covered in every mod set.
  if not data.raw["technology"]["athletic-science-pack"]
    and not data.raw["item"]["athletic-science-pack"]
  then
    add_science_pack_item("athletic-science-pack")
    add_recipe("athletic-science-pack", "athletic-science-pack")
    add_technology("athletic-science-pack", "athletic-science-pack")
  end
end)
