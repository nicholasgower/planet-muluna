-- Fixture manifest for the Muluna FUnit suite.
--
-- Each list holds fixture module names inside prototypes/fixtures/. They are
-- required by the matching stage entry point (data.lua / data-updates.lua /
-- data-final-fixes.lua).
return {
  data = {
    "data_cells_setup",
    "resized_assembler_compat_setup",
  },
  data_updates = {},
  data_final_fixes = {
    "data_cells",
    "resized_assembler_compat",
    "lunar_rocks",
    "planet",
    "science",
    "telescope",
    "heat_roboport",
    "nav_beacon",
    "ground_diggers",
    "cargo_drops",
    "api_helpers",
    "muluna_tiles",
  },
}
