require("wood-gasification.settings")
data:extend{
    {
        type = "bool-setting",
        name = "override-space-connection",
        setting_type = "startup",
        default_value = false,
        order = "ya",
      },
      {
        type = "bool-setting",
        name = "disable-muluna-music",
        setting_type = "startup",
        default_value = false,
        order = "yb",
      },
      {
        type = "bool-setting",
        name = "muluna-hardcore-restrict-crusher",
        setting_type = "startup",
        default_value = false,
        order = "ab",
      },
      {
        type = "bool-setting",
        name = "muluna-hardcore-restrict-asteroid-collector",
        setting_type = "startup",
        default_value = false,
        order = "ac",
      },
      -- {
      --   type = "bool-setting",
      --   name = "muluna-hardcore-require-helium-3-in-fusion-cell",
      --   setting_type = "startup",
      --   default_value = false,
      --   order = "ad",
      -- },
      {
        type = "bool-setting",
        name = "muluna-hardcore-remove-steam-furnaces",
        setting_type = "startup",
        default_value = false,
        order = "ae",
      },
      {
        type = "bool-setting",
        name = "muluna-hardcore-remove-starting-cargo-pods",
        setting_type = "startup",
        default_value = false,
        order = "af",
      },
      {
        type = "bool-setting",
        name = "muluna-hardcore-classic-wood-gasification",
        setting_type = "startup",
        default_value = false,
        order = "ag",
      },
      {
        type = "bool-setting",
        name = "muluna-easy-vanilla-rocket-part-costs",
        setting_type = "startup",
        default_value = false,
        order = "ba",
      },
      {
        type = "bool-setting",
        name = "muluna-easy-vanilla-advanced-thruster-fuel-costs",
        setting_type = "startup",
        default_value = false,
        order = "bb",
      },
      {
        type = "bool-setting",
        name = "muluna-easy-wood-gasification-productivity",
        setting_type = "startup",
        default_value = false,
        order = "bc",
      },
      {
        type = "bool-setting",
        name = "muluna-easy-simple-wood-gasification",
        setting_type = "startup",
        default_value = false,
        order = "bd",
      },
      
      {
        type = "bool-setting",
        name = "muluna-change-quality-science-pack-drain",
        setting_type = "startup",
        default_value = true,
        order = "ee",
      },
      {
        type = "int-setting",
        name = "space-science-pack-output",
        setting_type = "startup",
        default_value = 2,
        minimum_value = 1,
        maximum_value = 10,
        order = "ca",
      },
      {
        type = "double-setting",
        name = "space-science-pack-energy",
        setting_type = "startup",
        default_value = 7,
        minimum_value = 0.01,
        maximum_value = 60,
        order = "cb",
      },
      {
        type = "int-setting",
        name = "muluna-interstellar-science-pack-packs-required",
        setting_type = "startup",
        default_value = 2,
        minimum_value = 1,
        --maximum_value = 10,
        order = "cc",
      },
      {
        type = "double-setting",
        name = "muluna-balance-fulgoran-cargo-drop-radius",
        setting_type = "startup",
        default_value = 64,
        minimum_value = 16,
        maximum_value = 512,
        order = "cd"

      },
      {
        type = "double-setting",
        name = "muluna-balance-fulgoran-cargo-drop-item-multiplier",
        setting_type = "startup",
        default_value = 1,
        minimum_value = 0,
        maximum_value = 10,
        order = "ce"
      },

    --   {
    --     type = "double-setting",
    --     name = "planet-power-consumption",
    --     setting_type = "startup",
    --     default_value = 300,
    --     minimum_value = 1,
    --     maximum_value = 1000,
    --     order = "a"
    -- },
    {
        type = "double-setting",
        name = "platform-power-consumption",
        setting_type = "startup",
        default_value = 100,
        minimum_value = 0.3,
        maximum_value = 1000,
        order = "db"
    },
    {
      type = "bool-setting",
      name = "enable-nav-beacon",
      localised_name = {"mod-setting-name.enable-muluna-satellite-radar"},
      setting_type = "startup",
      default_value = true,
      order = "fa"
    },
    {
      type = "bool-setting",
      name = "muluna-graphics-enable-footstep-animations",
      setting_type = "startup",
      default_value = true,
      order = "ea"
    },
    {
      type = "double-setting",
      name = "nav-beacon-update-ticks",
      setting_type="startup",
      default_value = 60,
      minimum_value = 1,
      maximum_value = 360,
      order = "eb",
    },
    {
      type = "double-setting",
      name = "muluna-telescope-combinator-update-ticks",
      setting_type="startup",
      default_value = 6,
      minimum_value = 1,
      maximum_value = 180,
      order = "ec",
    },
    {
      type = "bool-setting",
      name = "nav-beacon-display-alert",
      setting_type = "runtime-per-user",
      default_value = true,
      order = "ba"
    },
    -- {
    --   type = "bool-setting",
    --   name = "muluna-new-interstellar-pack-recipe",
    --   setting_type = "startup",
    --   default_value = false,
    --   order = "za"
    -- },
    -- {
    --   type = "bool-setting",
    --   name = "muluna-old-interstellar-pack-recipe",
    --   setting_type = "startup",
    --   default_value = false,
    --   order = "za"
    -- },

}

if mods["any-planet-start"] then
  APS.add_choice("muluna")
end
