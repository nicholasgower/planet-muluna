-- Data-stage checks for Muluna's replacement recycling recipes.
local results = require("lib.results")

local SUITE = "recycling"
local RECIPE = "copper-cable-recycling-muluna"

results.check(SUITE, "muluna-copper-cable-recycling-is-unlocked", function()
  local recipe = data.raw["recipe"][RECIPE]
  assert(recipe, RECIPE .. " recipe is missing")
  if recipe.enabled then return end

  local technology = data.raw["technology"] and data.raw["technology"]["recycling"]
  assert(technology, "recycling technology is missing, so " .. RECIPE .. " can never be unlocked")

  local unlocked = false
  for _, effect in pairs(technology.effects or {}) do
    if effect.type == "unlock-recipe" and effect.recipe == RECIPE then
      unlocked = true
      break
    end
  end
  assert(unlocked, RECIPE .. " is disabled and is not unlocked by the recycling technology")
end)
