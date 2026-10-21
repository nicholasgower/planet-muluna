-- Data-stage checks for telescopes, telescope combinators, and observation recipes.
local results = require("lib.results")

local SUITE = "telescope"

results.check(SUITE, "telescope-entity", function()
  local entity = data.raw["assembling-machine"]["muluna-telescope"]
  assert(entity, "muluna-telescope entity is missing")
  assert(Muluna.constants.telescopes["muluna-telescope"], "muluna-telescope is not registered in Muluna.constants.telescopes")
  assert(entity.crafting_categories and #entity.crafting_categories > 0, "muluna-telescope has no crafting categories")
end)

results.check(SUITE, "telescope-combinator-generated", function()
  assert(data.raw["constant-combinator"]["muluna-telescope-combinator"], "muluna-telescope-combinator is missing")
  assert(Muluna.constants.telescopes and next(Muluna.constants.telescopes), "Muluna.constants.telescopes is empty")
end)

results.check(SUITE, "telescope-observation-recipes", function()
  assert(data.raw["recipe"]["muluna-telescope-observation-muluna"], "Muluna observation recipe is missing")
  assert(data.raw["recipe"]["muluna-telescope-observation-nauvis"], "Nauvis observation recipe is missing")
  assert(data.raw["recipe"]["muluna-telescope-observation-space-platform"], "space platform observation recipe is missing")
end)

results.check(SUITE, "muluna-observation-amount", function()
  local recipe = data.raw["recipe"]["muluna-telescope-observation-muluna"]
  assert(recipe.results[1].name == "muluna-astronomical-data", "Muluna observation result is not astronomical data")
  assert(recipe.results[1].amount == 5, "Muluna observation should produce 5 astronomical data, got " .. tostring(recipe.results[1].amount))
end)

results.check(SUITE, "space-platform-observation-recipe", function()
  local recipe = data.raw["recipe"]["muluna-telescope-observation-space-platform"]
  assert(recipe.results[1].amount == 100, "space platform observation should produce 100 astronomical data")
  local has_chunk = false
  for _, ingredient in pairs(recipe.ingredients or {}) do
    if ingredient.name == "promethium-asteroid-chunk" then has_chunk = true end
  end
  assert(has_chunk, "space platform observation does not consume promethium asteroid chunks")
end)

results.check(SUITE, "telescope-technology-unlocks", function()
  local tech = data.raw["technology"]["muluna-telescope"]
  assert(tech, "muluna-telescope technology is missing")
  local unlocked = {}
  for _, effect in pairs(tech.effects or {}) do
    if effect.type == "unlock-recipe" then unlocked[effect.recipe] = true end
  end
  assert(unlocked["muluna-telescope-observation-muluna"], "telescope technology does not unlock the Muluna observation recipe")
  local space_tech = data.raw["technology"]["muluna-space-telescope"]
  assert(space_tech, "muluna-space-telescope technology is missing")
  local space_unlocked = false
  for _, effect in pairs(space_tech.effects or {}) do
    if effect.type == "unlock-recipe" and effect.recipe == "muluna-telescope-observation-space-platform" then
      space_unlocked = true
    end
  end
  assert(space_unlocked, "space telescope technology does not unlock the space platform observation recipe")
end)

results.check(SUITE, "telescope-surface-conditions", function()
  local recipe = data.raw["recipe"]["muluna-telescope-observation-muluna"]
  local planet = data.raw["planet"]["muluna"]
  local conditions = {}
  for _, condition in pairs(recipe.surface_conditions or {}) do
    conditions[condition.property] = condition
  end
  assert(conditions["pressure"], "Muluna observation recipe has no pressure condition")
  assert(conditions["gravity"], "Muluna observation recipe has no gravity condition")
  assert(conditions["pressure"].min == (planet.surface_properties["pressure"] or data.raw["surface-property"]["pressure"].default_value), "pressure condition does not match Muluna")
  assert(conditions["gravity"].min == (planet.surface_properties["gravity"] or data.raw["surface-property"]["gravity"].default_value), "gravity condition does not match Muluna")
end)
