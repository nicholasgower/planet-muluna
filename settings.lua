data:extend{
    {
        type = "bool-setting",
        name = "override-space-connection",
        setting_type = "startup",
        default_value = false,
        order = "aa",
      },
      {
        type = "bool-setting",
        name = "disable-muluna-music",
        setting_type = "startup",
        default_value = false,
        order = "ab",
      },
      {
        type = "int-setting",
        name = "space-science-pack-output",
        setting_type = "startup",
        default_value = 2,
        min = 1,
        max = 10,
        order = "ac",
      },
      {
        type = "double-setting",
        name = "space-science-pack-energy",
        setting_type = "startup",
        default_value = 7,
        min = 0.01,
        max = 60,
        order = "ad",
      },
      {
        type = "double-setting",
        name = "planet-power-consumption",
        setting_type = "startup",
        default_value = 300,
        minimum_value = 1,
        maximum_value = 1000,
        order = "a"
    },
    {
        type = "double-setting",
        name = "platform-power-consumption",
        setting_type = "startup",
        default_value = 50,
        minimum_value = 0.3,
        maximum_value = 1000,
        order = "a"
    }
}

if mods["any-planet-start"] then
  APS.add_choice("muluna")
end
