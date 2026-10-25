-- Suites are loaded in order. Data fixture results are registered first so a
-- load-time data regression is reported before longer runtime tests run.
return {
  "__planet-muluna-funit__.tests.suites.data_fixtures",
  "__planet-muluna-funit__.tests.suites.smoke",
  "__planet-muluna-funit__.tests.suites.lunar_rock_removal",
  "__planet-muluna-funit__.tests.suites.science",
  "__planet-muluna-funit__.tests.suites.telescope",
  "__planet-muluna-funit__.tests.suites.heat_assembling_machine",
  "__planet-muluna-funit__.tests.suites.burner_roboport",
  "__planet-muluna-funit__.tests.suites.compound_blueprints",
  "__planet-muluna-funit__.tests.suites.nav_beacon",
  "__planet-muluna-funit__.tests.suites.ground_diggers",
  "__planet-muluna-funit__.tests.suites.walking_particles",
}
