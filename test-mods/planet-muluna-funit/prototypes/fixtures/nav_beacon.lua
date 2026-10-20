-- Data-stage checks for the satellite radar / nav beacon.
local results = require("lib.results")

local SUITE = "nav_beacon"

results.check(SUITE, "nav-beacon-prototypes", function()
  assert(data.raw["item"]["muluna-satellite-radar"], "muluna-satellite-radar item is missing")
  assert(data.raw["accumulator"]["muluna-satellite-radar"], "muluna-satellite-radar entity is missing")
  assert(data.raw["recipe"]["muluna-satellite-radar"], "muluna-satellite-radar recipe is missing")
  assert(data.raw["technology"]["muluna-satellite-radar"], "muluna-satellite-radar technology is missing")
end)

results.check(SUITE, "nav-beacon-radar-data", function()
  local radar_data = data.raw["mod-data"]["muluna-satellite-radar"]
  assert(radar_data and radar_data.data, "muluna-satellite-radar mod-data is missing")
  assert(type(radar_data.data.energy_per_scan_expression) == "string", "energy_per_scan_expression is missing")
  assert(type(radar_data.data.scan_size_expression) == "string", "scan_size_expression is missing")
  assert(radar_data.data.entities["muluna-satellite-radar"], "radar entity statistics are missing")
end)

results.check(SUITE, "nav-beacon-test-profile-has-distinct-scan-energy", function()
  local base = data.raw["mod-data"]["muluna-satellite-radar"].data.entities["muluna-satellite-radar"]
  assert(base.energy_per_scan == 200, "test profile should set platform-power-consumption to 200, got " .. tostring(base.energy_per_scan))
  assert(base.scan_area == 100, "scan_area should stay 100, got " .. tostring(base.scan_area))
end)

results.check(SUITE, "nav-beacon-surface-condition", function()
  local entity = data.raw["accumulator"]["muluna-satellite-radar"]
  local has_gravity = false
  for _, condition in pairs(entity.surface_conditions or {}) do
    if condition.property == "gravity" then has_gravity = true end
  end
  assert(has_gravity, "satellite radar has no gravity surface condition")
end)

results.check(SUITE, "nav-beacon-tech-prerequisites", function()
  local tech = data.raw["technology"]["muluna-satellite-radar"]
  local found = false
  for _, prereq in pairs(tech.prerequisites or {}) do
    if prereq == "interstellar-science-pack" then found = true end
  end
  assert(found, "satellite radar technology does not require interstellar-science-pack")
end)
