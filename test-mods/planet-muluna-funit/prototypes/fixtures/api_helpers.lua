-- Data-stage checks for Muluna's public helper libraries and extend() behaviour.
local results = require("lib.results")

local SUITE = "api_helpers"

results.check(SUITE, "rro-deep-equals", function()
  assert(Muluna.rro.deep_equals({ "space-science-pack", 1 }, { "space-science-pack", 1 }), "deep_equals rejected equal tables")
  assert(not Muluna.rro.deep_equals({ "space-science-pack", 1 }, { "space-science-pack", 2 }), "deep_equals accepted different tables")
  assert(Muluna.rro.deep_equals({ "space-science-pack", 1 }, { "_any", "_any" }), "deep_equals wildcard failed")
end)

results.check(SUITE, "rro-soft-insert", function()
  local list = { "a" }
  Muluna.rro.soft_insert(list, "a")
  assert(#list == 1, "soft_insert duplicated a value")
  Muluna.rro.soft_insert(list, "b")
  assert(#list == 2 and list[2] == "b", "soft_insert did not append a new value")
end)

results.check(SUITE, "extend-normalises-recipe-and-tech", function()
  local recipe_name = "muluna-funit-extend-recipe"
  local tech_name = "muluna-funit-extend-tech"
  Muluna:extend({
    {
      type = "recipe",
      name = recipe_name,
      icon = "__base__/graphics/icons/iron-plate.png",
      icon_size = 64,
      ingredients = {},
      results = {},
    },
    {
      type = "technology",
      name = tech_name,
      icon = "__base__/graphics/technology/automation-1.png",
      icon_size = 256,
      research_trigger = { type = "build-entity", entity = "radar" },
      unit = { count = 1, time = 1, ingredients = {} },
      effects = {},
    },
  })
  local recipe = data.raw["recipe"][recipe_name]
  local tech = data.raw["technology"][tech_name]
  assert(recipe, "extend did not add the fixture recipe")
  assert(recipe.hide_from_recipe_gui == false, "extend did not set hide_from_recipe_gui")
  assert(tech, "extend did not add the fixture technology")
  assert(tech.research_trigger.entities and tech.research_trigger.entities[1] == "radar", "extend did not normalise research_trigger.entity")
end)

results.check(SUITE, "telescope-probability", function()
  local normal = Muluna.get_telescope_probability(100, "normal")
  assert(math.abs(normal) < 0.0001, "telescope probability at min pollution should be 0, got " .. tostring(normal))
  local max = Muluna.get_telescope_probability(1000, "normal")
  assert(math.abs(max - 1) < 0.0001, "telescope probability at max pollution should be 1, got " .. tostring(max))
  assert(Muluna.get_telescope_min_pollution("normal") == 100, "min pollution changed")
  assert(Muluna.get_telescope_max_pollution("normal") == 1000, "max pollution changed")
end)

results.check(SUITE, "multiply-energy", function()
  assert(Muluna.multiply_energy(10, 2) == 20, "multiply_energy failed on numbers")
end)

results.check(SUITE, "icons-dual-icon", function()
  local icons = Muluna.icons.dual_icon("iron-plate", "copper-plate")
  assert(type(icons) == "table" and #icons >= 2, "dual_icon did not return two layers")
end)
