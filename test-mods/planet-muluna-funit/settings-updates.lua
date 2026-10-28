-- Make the test profile's energy-per-scan differ from scan_area. The nav-beacon
-- scan-size regression test can then tell which statistic the runtime scan path
-- uses as the base value.
local setting = data.raw["double-setting"]
  and data.raw["double-setting"]["platform-power-consumption"]
if setting then
  setting.default_value = 200
end

-- Pin the Any Planet Start profile to Muluna. The FUnit runner and CI use fresh
-- mod settings, so this default is what the game sees for the "muluna-start"
-- mod set. Any future FUnit mod set that loads any-planet-start with a
-- different starting planet needs a different profile mechanism.
local aps_planet = data.raw["string-setting"]
  and data.raw["string-setting"]["aps-planet"]
if aps_planet then
  aps_planet.default_value = "muluna"
end
