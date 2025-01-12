local function technology_icon_constant_planet(technology_icon,icon_size)
    local icons =
    {
      {
        icon = technology_icon,
        icon_size = 1920,
      },
      {
        icon = "__core__/graphics/icons/technology/constants/constant-planet.png",
        icon_size = 128,
        scale = 0.5,
        shift = {50, 50}
      }
    }
    return icons
  end

data:extend{
    -- {
    --     type = "technology",
    --     name = "planet-discovery-muluna",
    --     unit= {
    --         count = 500,
    --         time = 60,
    --         ingredients = data.raw["technology"]["rocket-silo"].unit.ingredients
    --     },
    --     prerequisites = {
    --         "space-science-pack"
    --     },
    --     effects = {
    --         {
    --             type = "unlock-space-location",
    --             space_location = "muluna"
    --         }
    --     },
        
    -- },
    {
        type = "technology",
        name = "asteroid-collector",
        localised_name = {"entity-name.asteroid-collector"},
        localised_description = {"entity-description.asteroid-collector"},
        unit= {
            count = 300,
            time = 60,
            ingredients = data.raw["technology"]["planet-discovery-vulcanus"].unit.ingredients
        },
        effects = {
            {
                type = "unlock-recipe",
                recipe = "asteroid-collector"
            }
        },
        prerequisites = {
            "space-science-pack"
        },
        icon = "__planet-muluna__/graphics/technology/asteroid-collector(ai-upscaled).png",
        icon_size=256,
    },
    -- {
    --     type = "technology",
    --     name = "cargo-bay",
    --     localised_name = {"entity-name.cargo-bay"},
    --     unit = {
    --         count = 100,
    --         time = 60,
    --         ingredients = data.raw["technology"]["planet-discovery-vulcanus"].unit.ingredients
    --     },
    --     effects = {
    --         {
    --             type = "unlock-recipe",
    --             recipe = "cargo-bay"
    --         }
    --     },
    --     prerequisites = {
    --         "space-science-pack"
    --     },
    --     icon = data.raw["item"]["cargo-bay"].icon
    -- },
    {
        type = "technology",
        name = "crusher",
        research_trigger = {
            type = "mine-entity",
            entity = "metallic-asteroid-chunk"
        },
        localised_name = {"item-name.crusher"},
        localised_description = {"entity-description.crusher"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "crusher"
            },
            {
                type = "unlock-recipe",
                recipe = "metallic-asteroid-crushing"
            },
            
            {
                type = "unlock-recipe",
                recipe = "carbonic-asteroid-crushing"
            },
            {
                type = "unlock-recipe",
                recipe = "electric-engine-unit-from-carbon"
            },
        },
        prerequisites = {
             "planet-discovery-muluna"
        },
        icons = {
            {
                icon = "__planet-muluna__/graphics/technology/comminution.png",
                icon_size = 968,
            },  
        }
    },
    {
        type = "technology",
        name = "space-boiler",
        research_trigger = {
            type = "mine-entity",
            entity = "oxide-asteroid-chunk"
        },
        localised_name = {"entity-name.space-boiler"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "space-boiler"
            },
            {
                type = "unlock-recipe",
                recipe = "oxide-asteroid-crushing"
            },
            {
                type = "unlock-recipe",
                recipe = "ice-melting"
            },
        },
        prerequisites = {
            "crusher"
        },
        icon = data.raw["technology"]["steam-power"].icon,
        icon_size = data.raw["technology"]["steam-power"].icon_size,
    },
    {
        type = "technology",
        name = "anorthite-processing",
        research_trigger = {
            type = "mine-entity",
            entity = "anorthite-chunk"
        },
        effects = {
            {
                type = "unlock-recipe",
                recipe = "anorthite-crushing"
            },
            {
                type = "unlock-recipe",
                recipe = "alumina-crushing"
            },
            {
                type = "unlock-recipe",
                recipe = "rocket-fuel-aluminum"
            },
        },
        prerequisites = {
            "crusher"
        },
        icons = {
            {
                icon = "__planet-muluna__/graphics/technology/comminution.png",
                icon_size = 968,
            },  
            {
                icon = "__planet-muluna__/graphics/icons/anorthite-chunk.png",
                icon_size=64,
                --scale=0.3,
                shift = {45,45},
                scale=0.75,
            },
            
        }
    },
    {
        type = "technology",
        name = "planet-discovery-muluna",
        research_trigger = {
            type = "build-entity",
            entity = "thruster"
        },
        effects = {
            {
                type = "unlock-space-location",
                space_location = "muluna"
            }
        },
        prerequisites = {
            "space-platform-thruster"
        },
        icons = PlanetsLib.technology_icons_moon("__planet-muluna__/graphics/moon-icon.png",1920),
        localised_description={"space-location-description.muluna"},
        -- icons = {
        --     {
        --         icon = data.raw["planet"]["muluna"].icon,
        --         icon_size = data.raw["planet"]["muluna"].icon_size,
        --     }
        -- }
        
    }

}

