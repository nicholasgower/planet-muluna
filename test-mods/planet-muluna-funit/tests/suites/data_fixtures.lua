-- Converts data-stage fixture results into FUnit tests.
local runner = require("__funit__.test_runner")

local results = prototypes.mod_data["planet-muluna-funit-results"]

runner.test("data fixtures: startup fixtures are enabled", function()
  runner.assert(
    settings.startup["planet-muluna-funit-enable-data-fixtures"].value,
    "planet-muluna-funit-enable-data-fixtures is disabled; enable it to run the data-stage checks"
  )
end)

runner.test("data fixtures: result bag exists", function()
  runner.assert(results, "planet-muluna-funit-results mod-data is missing")
  runner.assert(type(results.data) == "table", "result bag data is not a table")
end)

if results and results.data then
  for suite, checks in pairs(results.data) do
    for id, check in pairs(checks) do
      runner.test("data/" .. tostring(suite) .. "/" .. tostring(id), function()
        runner.assert(check.ok, check.err or "data fixture failed")
      end)
    end
  end
end
