-- Make the test profile's energy-per-scan differ from scan_area. The nav-beacon
-- scan-size regression test can then tell which statistic the runtime scan path
-- uses as the base value.
local setting = data.raw["double-setting"]
  and data.raw["double-setting"]["platform-power-consumption"]
if setting then
  setting.default_value = 200
end
