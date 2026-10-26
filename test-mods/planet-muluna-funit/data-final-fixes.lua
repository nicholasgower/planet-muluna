-- Final data-stage fixtures for the Muluna FUnit suite.
--
-- This runs after planet-muluna's data-final-fixes, so the fixtures see the
-- final prototype state that ships to players.
if settings.startup["planet-muluna-funit-enable-data-fixtures"].value then
  local manifest = require("prototypes.fixtures.manifest")
  for _, fixture in ipairs(manifest.data_final_fixes or {}) do
    require("prototypes.fixtures." .. fixture)
  end
end
