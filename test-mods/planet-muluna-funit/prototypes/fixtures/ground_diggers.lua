-- Data-stage checks for PlanetsLib ground diggers on Muluna.
local results = require("lib.results")

local SUITE = "ground_diggers"

results.check(SUITE, "regolith-recipe", function()
  local recipe = data.raw["recipe"]["muluna-regolith-digging"]
  assert(recipe, "muluna-regolith-digging recipe is missing")
  assert(recipe.categories and recipe.categories[1] == "ground-digging", "regolith recipe has the wrong category")
  assert(recipe.enabled == false, "regolith recipe should start disabled")
  local has_regolith = false
  for _, product in pairs(recipe.results or {}) do
    if product.name == "muluna-lunar-regolith" then has_regolith = true end
  end
  assert(has_regolith, "regolith recipe does not produce muluna-lunar-regolith")
end)

results.check(SUITE, "planetslib-ground-digger-config", function()
  local config = PlanetsLib.constants.ground_diggers["muluna"]
  assert(config, "PlanetsLib has no ground digger config for Muluna")
  assert(config.recipe == "muluna-regolith-digging", "Muluna ground digger recipe is wrong")
  assert(config.diggers and next(config.diggers), "Muluna ground digger config has no diggers")
end)

results.check(SUITE, "ground-digger-prototypes", function()
  local config = PlanetsLib.constants.ground_diggers["muluna"]
  for item_name, info in pairs(config.diggers) do
    assert(data.raw["assembling-machine"][info.digger], "ground digger prototype is missing: " .. tostring(info.digger))
    assert(data.raw["item"][item_name], "ground digger item is missing: " .. tostring(item_name))
  end
end)

results.check(SUITE, "ground-digger-surface-property", function()
  local property = data.raw["surface-property"]["PlanetsLib-has-ground-diggers"]
  assert(property, "PlanetsLib ground digger surface property is missing")
  assert(data.raw["planet"]["muluna"].surface_properties[property.name] == 1, "Muluna is not marked as a ground digger planet")
end)

results.check(SUITE, "regolith-tech-exists", function()
  local tech = data.raw["technology"]["muluna-regolith-digging"]
  assert(tech, "muluna-regolith-digging technology is missing")
  assert(tech.research_trigger, "regolith technology is not a trigger technology")
end)
