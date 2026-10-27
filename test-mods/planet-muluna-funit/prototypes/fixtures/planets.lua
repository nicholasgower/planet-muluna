-- Data-stage checks for the top planet mods on the mod portal.
--
-- This fixture is registered only when at least one of the planet mods is
-- active, so the other FUnit mod sets can require the file without recording
-- results.
local results = require("lib.results")

local SUITE = "planets"

local PLANET_MODS = {
  { mod = "maraxsis", tech = "planet-discovery-maraxsis" },
  { mod = "Cerys-Moon-of-Fulgora", tech = "moon-discovery-cerys" },
  { mod = "Moshine", tech = "planet-discovery-moshine" },
  { mod = "corrundum", tech = "planet-discovery-corrundum" },
  { mod = "secretas", tech = "planet-discovery-secretas" },
  { mod = "Paracelsin", tech = "planet-discovery-paracelsin" },
  { mod = "rubia", tech = "planet-discovery-rubia" },
}

local any_planet = false
for _, planet in ipairs(PLANET_MODS) do
  if mods[planet.mod] then
    any_planet = true
  end
end
if not any_planet then
  return
end

results.check(SUITE, "planet-mods-loaded", function()
  local missing = {}
  for _, planet in ipairs(PLANET_MODS) do
    if not mods[planet.mod] then
      missing[#missing + 1] = planet.mod
    end
  end
  assert(#missing == 0, "missing planet mods: " .. table.concat(missing, ", "))
end)

results.check(SUITE, "planet-discovery-technologies", function()
  for _, planet in ipairs(PLANET_MODS) do
    assert(
      data.raw["technology"][planet.tech],
      planet.mod .. " is missing its discovery technology " .. planet.tech
    )
  end
end)

results.check(SUITE, "corrundum-oxygen-restrictions", function()
  if not mods["corrundum"] then
    return
  end

  local boiler = data.raw["boiler"]["red-boiler"]
  assert(boiler, "corrundum red-boiler is missing")
  local oxygen
  for _, condition in ipairs(boiler.surface_conditions or {}) do
    if condition.property == "oxygen" then
      oxygen = condition
    end
  end
  assert(oxygen, "corrundum red-boiler has no oxygen surface condition")
  assert(oxygen.min == 1, "corrundum red-boiler oxygen min is " .. tostring(oxygen.min) .. ", expected 1")

  local engine = data.raw["generator"]["red-steam-engine"]
  assert(engine, "corrundum red-steam-engine is missing")
  assert(
    engine.energy_source
      and engine.energy_source.emissions_per_minute
      and engine.energy_source.emissions_per_minute.pollution == 20,
    "corrundum red-steam-engine pollution is not 20"
  )

  local recipe = data.raw["recipe"]["controlled-petrol-combustion"]
  assert(recipe, "corrundum controlled-petrol-combustion is missing")
  assert(recipe.icons and #recipe.icons >= 2, "controlled-petrol-combustion does not have a dual icon")
end)

results.check(SUITE, "maraxsis-pressure-restriction", function()
  if not mods["maraxsis"] then
    return
  end

  local recipe = data.raw["recipe"]["maraxsis-hydrolox-rocket-fuel"]
  assert(recipe, "maraxsis-hydrolox-rocket-fuel is missing")
  local pressure
  for _, condition in ipairs(recipe.surface_conditions or {}) do
    if condition.property == "pressure" then
      pressure = condition
    end
  end
  assert(pressure, "maraxsis-hydrolox-rocket-fuel has no pressure surface condition")
  assert(
    pressure.min == 200000,
    "maraxsis-hydrolox-rocket-fuel pressure min is " .. tostring(pressure.min) .. ", expected 200000"
  )
end)

results.check(SUITE, "cerys-oxygen-blacklist", function()
  if not mods["Cerys-Moon-of-Fulgora"] then
    return
  end

  local blacklist = data.raw["mod-data"]["muluna-constants"].data.oxygen_restriction_blacklist
  assert(blacklist, "oxygen_restriction_blacklist is missing from muluna-constants")
  local found = false
  for _, name in ipairs(blacklist) do
    if name == "cerys-radiative-tower" then
      found = true
      break
    end
  end
  assert(found, "cerys-radiative-tower is not in the oxygen restriction blacklist")
end)
