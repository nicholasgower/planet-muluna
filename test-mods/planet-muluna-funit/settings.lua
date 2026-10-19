-- Startup settings for the Muluna FUnit data fixtures.
--
-- The fixtures are gated so a save can still be loaded with them disabled.
data:extend({
  {
    type = "bool-setting",
    setting_type = "startup",
    name = "planet-muluna-funit-enable-data-fixtures",
    default_value = true,
    order = "a",
  },
})
