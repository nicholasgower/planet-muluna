-- Data-stage checks for the Muluna planet, its surface, and asteroid content.
local results = require("lib.results")

local SUITE = "planet"

if not settings.startup["planet-muluna-funit-enable-data-fixtures"].value then
  results.record(SUITE, "fixtures-disabled", true, "data fixtures disabled by startup setting")
  return
end

results.check(SUITE, "planet-prototype-exists", function()
  assert(data.raw["planet"]["muluna"], "planet muluna is missing")
end)

results.check(SUITE, "surface-property-is-muluna", function()
  assert(data.raw["surface-property"]["is-muluna"], "is-muluna surface property is missing")
end)

results.check(SUITE, "planet-surface-properties", function()
  local planet = data.raw["planet"]["muluna"]
  assert(planet.surface_properties, "Muluna has no surface_properties")
  assert(planet.surface_properties["is-muluna"] == 1, "Muluna is-muluna property is not 1")
  assert((planet.surface_properties.gravity or 0) > 0, "Muluna gravity is not positive")
  assert((planet.surface_properties.pressure or 0) > 0, "Muluna pressure is not positive")
end)

results.check(SUITE, "planet-map-gen-settings", function()
  local planet = data.raw["planet"]["muluna"]
  assert(planet.map_gen_settings, "Muluna has no map_gen_settings")
  assert(planet.map_gen_settings.autoplace_controls, "Muluna has no autoplace_controls")
  assert(planet.map_gen_settings.autoplace_controls["muluna_cliff"], "Muluna cliff autoplace control is missing")
end)

results.check(SUITE, "asteroid-chunk", function()
  assert(data.raw["asteroid-chunk"]["anorthite-chunk"], "anorthite-chunk is missing")
  for _, size in pairs({ "small", "medium", "big", "huge" }) do
    assert(data.raw["asteroid"][size .. "-anorthite-asteroid"], size .. "-anorthite-asteroid is missing")
  end
end)

results.check(SUITE, "space-connection-reachable", function()
  local distance = Muluna.telescopes.shortest_space_distance("nauvis", "muluna")
  assert(distance and distance > 0, "no space-connection path from nauvis to muluna")
end)

results.check(SUITE, "planet-order-and-magnitude", function()
  local planet = data.raw["planet"]["muluna"]
  assert(planet.magnitude and planet.magnitude > 0, "Muluna magnitude is missing or not positive")
  assert(planet.orientation ~= nil, "Muluna orientation is missing")
end)
