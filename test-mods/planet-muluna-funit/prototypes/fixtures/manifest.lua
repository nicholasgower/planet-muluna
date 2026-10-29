-- Fixture manifest for the Muluna FUnit suite.
--
-- Each list holds fixture module names inside prototypes/fixtures/. They are
-- required by the matching stage entry point (data.lua / data-updates.lua /
-- data-final-fixes.lua).
return {
  data = {
    "data_cells_setup",
  },
  data_updates = {
    "science_discovery_setup",
  },
  data_final_fixes = {
    "data_cells",
    "lunar_rocks",
    "planet",
    "science",
    "science_discovery",
    "science_legacy_snapshot",
    "telescope",
    "heat_roboport",
    "nav_beacon",
    "ground_diggers",
    "cargo_drops",
    "api_helpers",
    "muluna_tiles",
    "prototype_integrity",
    "content_references",
    "any_planet_start",
    "aai",
    "brevven",
    "planets",
  },
}
