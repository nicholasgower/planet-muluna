-- Runtime FUnit scenario for planet-muluna.
--
-- The scenario lives inside the development-only companion mod so it is not
-- included in release builds. Run it with factorio-docker or the local runner
-- as: --start-server-load-scenario planet-muluna-funit/__funit__muluna
require("__base__/script/freeplay/control.lua")

local runner = require("__funit__.test_runner")
runner.register("planet-muluna")
runner.report("muluna")

local manifest = require("__planet-muluna-funit__.tests.manifest")
for _, suite in ipairs(manifest) do
  require(suite)
end
