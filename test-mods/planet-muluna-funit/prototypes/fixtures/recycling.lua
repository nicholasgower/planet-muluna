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

-- The condenser turbine must be a regular generator so that the game derives its
-- available power from the actual input temperature and the prototype's
-- maximum_temperature. FusionGeneratorPrototype has no maximum_temperature, so a
-- fusion-generator reports the fluid's maximum temperature instead of the current
-- steam temperature when it is not at full load.
-- https://github.com/nicholasgower/planet-muluna/issues/533
results.check(SUITE, "cycling-steam-turbine-uses-generator-temperature", function()
  local fusion = data.raw["fusion-generator"] and data.raw["fusion-generator"]["muluna-cycling-steam-turbine"]
  assert(
    not fusion,
    "muluna-cycling-steam-turbine is still a fusion-generator, which ignores maximum_temperature"
  )

  local generator = data.raw["generator"] and data.raw["generator"]["muluna-cycling-steam-turbine"]
  assert(generator, "muluna-cycling-steam-turbine is missing from the generator prototypes")

  local steam = data.raw["fluid"]["steam"]
  local expected_max_temperature = math.max(500, steam.max_temperature or 500)
  assert(
    generator.maximum_temperature == expected_max_temperature,
    "muluna-cycling-steam-turbine maximum_temperature is "
      .. tostring(generator.maximum_temperature)
      .. ", expected "
      .. tostring(expected_max_temperature)
  )

  assert(
    generator.minimum_input_temperature == 165,
    "muluna-cycling-steam-turbine minimum_input_temperature is "
      .. tostring(generator.minimum_input_temperature)
      .. ", expected 165"
  )

  assert(
    generator.fluid_box and generator.fluid_box.filter == "steam",
    "muluna-cycling-steam-turbine does not accept steam"
  )
  assert(
    generator.output_fluid_box and generator.output_fluid_box.filter == "cooled-steam",
    "muluna-cycling-steam-turbine does not output cooled-steam"
  )

  local expected_usage = mods["Krastorio2-spaced-out"] and (100 / 60) or 1.5
  assert(
    math.abs((generator.fluid_usage_per_tick or 0) - expected_usage) < 1e-9,
    "muluna-cycling-steam-turbine fluid_usage_per_tick is "
      .. tostring(generator.fluid_usage_per_tick)
      .. ", expected "
      .. tostring(expected_usage)
  )

  local expected_max_power = mods["Krastorio2-spaced-out"] and "190MW" or "9MW"
  assert(
    generator.max_power_output == expected_max_power,
    "muluna-cycling-steam-turbine max_power_output is "
      .. tostring(generator.max_power_output)
      .. ", expected "
      .. tostring(expected_max_power)
  )
end)
