local rro = Muluna.rro

local function technology_icon_constant_productivity(technology_icon,new_icon_size)
    local icon_size = new_icon_size or 256
    local icons =
    {
      {
        icon = technology_icon,
        icon_size = icon_size
      },
      {
        icon = "__core__/graphics/icons/technology/constants/constant-mining-productivity.png",
        icon_size = 128,
        scale = 0.5,
        shift = {50, 50},
        floating = true
      }
    }
    return icons
  end
  local function technology_icon_constant_recipe_productivity(technology_icon,new_icon_size)
    local icon_size = new_icon_size or 256
    local icons =
    {
      {
        icon = technology_icon,
        icon_size = icon_size
      },
      {
        icon = "__core__/graphics/icons/technology/constants/constant-recipe-productivity.png",
        icon_size = 128,
        scale = 0.5,
        shift = {50, 50},
        floating = true
      }
    }
    return icons
  end


local function technology_icon_moon_complete(moon_icon, icon_size)
	icon_size = icon_size or 256
	local icons = util.technology_icon_constant_planet(moon_icon)
    icons[3]=icons[2]
    icons[2]=icons[1]
    icons[1] = {
        icon = "__muluna-graphics__/graphics/technology/planet-technology.png",
        icon_size = 256,
        shift = {0,10},
    }
	icons[2].icon_size = icon_size
    icons[2].scale = 0.8*128/icon_size
    icons[2].shift = {0,10}
	icons[3].icon = "__PlanetsLib__/graphics/icons/moon-technology-symbol.png"
	-- End result is an icons object ressembling the following, as of 2.0.37. Future API changes might change this code,
	-- which is why this function is written to reference the base function instead of copying it by hand.
	-- local icons = {
	-- 	{
	-- 		icon = moon_icon,
	-- 		icon_size = icon_size,
	-- 	},
	-- 	{
	-- 		icon = "__PlanetsLib__/graphics/icons/moon-technology-symbol.png",
	-- 		icon_size = 128,
	-- 		scale = 0.5,
	-- 		shift = { 50, 50 },
	-- 		floating = true
	-- 	},
	-- }
	return icons
end


local function technology_icon_constant_planet(technology_icon,icon_size)
    local icons =
    {
      {
        icon = technology_icon,
        icon_size = 1482,
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

local function crushing_technology_icon(item_sprite,item_sprite_size)
    if not item_sprite_size then item_sprite_size = 64 end

    return  {
        {
            icon = "__muluna-graphics__/graphics/technology/comminution.png",
            icon_size = 968,
        },  
        {
            icon = item_sprite,
            icon_size=item_sprite_size,
            --scale=0.3,
            shift = {45,45},
            scale=0.75,
        },
        
    }
end

local function digging_technology_icon(item_sprite,item_sprite_size)
    if not item_sprite_size then item_sprite_size = 64 end

    return  {
        {
            icon = data.raw["technology"]["electric-mining-drill"].icon,
            icon_size = data.raw["technology"]["electric-mining-drill"].icon_size,
        },  
        {
            icon = item_sprite,
            icon_size=item_sprite_size,
            --scale=0.3,
            shift = {45,45},
            scale=0.75,
        },
        
    }
end

local function greenhouse_technology_icon(item_sprite,item_sprite_size)
    if not item_sprite_size then item_sprite_size = 64 end

    return  {
        {
            icon = "__muluna-graphics__/graphics/greenhouse/sprites/greenhouse-icon-big.png",
            icon_size = 640,
        },  
        {
            icon = item_sprite,
            icon_size=item_sprite_size,
            --scale=0.3,
            shift = {45,45},
            scale=0.75,
        },
        
    }
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
        essential = true,
        unit= {
            count = 500,
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
            "crusher"
        },
        icon = "__muluna-graphics__/graphics/technology/asteroid-collector(ai-upscaled).png",
        icon_size=256,
    },
    {
        type = "technology",
        name = "crusher",
        localised_name = {"entity-name.crusher"},
        localised_description = {"entity-description.crusher"},
        essential = true,
        unit= {
            count = 500,
            time = 60,
            ingredients = data.raw["technology"]["planet-discovery-vulcanus"].unit.ingredients
        },
        effects = {
            {
                type = "unlock-recipe",
                recipe = "crusher"
            }
        },
        prerequisites = {
            "space-science-pack", "muluna-anorthite-processing"
        },
        icons = Muluna.img.blur_technology_icon({{
        icon = data.raw["item"]["crusher"].icon,
        icon_size=64,
        }},16)
    },
    {
        type = "technology",
        name = "muluna-rocket-buggy",
        localised_name = {"entity-name.muluna-rocket-buggy"},
        localised_description = {"entity-description.muluna-rocket-buggy"},
        unit= {
            count = 250,
            time = 60,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1},
                {"chemical-science-pack", 1},
                {"military-science-pack", 1},
                {"space-science-pack", 1},
            }
        },
        effects = {
            {
                type = "unlock-recipe",
                recipe = "muluna-rocket-buggy"
            }
        },
        prerequisites = {
            "space-science-pack", "automobilism", "rocketry"
        },
        icon = data.raw["technology"]["automobilism"].icon,
        icon_size = data.raw["technology"]["automobilism"].icon_size
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
        name = "metallic-asteroid-crushing",
        localised_name = {"recipe-name.metallic-asteroid-crushing"},
        research_trigger = {
            type = "mine-entity",
            entity = "metallic-asteroid-chunk"
        },
        --localised_name = {"item-name.crusher"},
        --localised_description = {"entity-description.crusher"},
        effects = {
            -- {
            --     type = "unlock-recipe",
            --     recipe = "crusher"
            -- },
            {
                type = "unlock-recipe",
                recipe = "metallic-asteroid-crushing"
            },
            
            
            
            
        },
        prerequisites = {
             "planet-discovery-muluna"
        },
        -- icons = {
        --     {
        --         icon = "__muluna-graphics__/graphics/technology/comminution.png",
        --         icon_size = 968,
        --     },  
        -- }
        icons = crushing_technology_icon(data.raw["item"]["metallic-asteroid-chunk"].icon,data.raw["item"]["metallic-asteroid-chunk"].icon_size)
    },
    {
        type = "technology",
        name = "muluna-regolith-digging",
        localised_name = {"recipe-name.muluna-regolith-digging"},
        localised_description = {"recipe-description.muluna-regolith-digging"},
        research_trigger = {
            type = "build-entity",
            entity = "electric-mining-drill-ground-digger"
        },
        --localised_name = {"item-name.crusher"},
        --localised_description = {"entity-description.crusher"},
        effects = {
            -- {
            --     type = "unlock-recipe",
            --     recipe = "crusher"
            -- },
            {
                type = "unlock-recipe",
                recipe = "muluna-regolith-digging"
            },
            {
                type = "unlock-recipe",
                recipe = "muluna-regolith-sorting"
            },
            
            
            
            
        },
        prerequisites = {
             "planet-discovery-muluna"
        },
        -- icons = {
        --     {
        --         icon = "__muluna-graphics__/graphics/technology/comminution.png",
        --         icon_size = 968,
        --     },  
        -- }
        icons = digging_technology_icon(data.raw["item"]["muluna-lunar-regolith"].icon,data.raw["item"]["muluna-lunar-regolith"].icon_size)
    },
    {
        type = "technology",
        name = "muluna-advanced-stone-processing",
        unit= {
            count = 500,
            time = 30,
            ingredients = table.deepcopy(data.raw["technology"]["coal-liquefaction"].unit.ingredients)
        },
        effects = {
            {
                type = "unlock-recipe",
                recipe = "stone-crushing"
            },
            {
                type = "unlock-recipe",
                recipe = "landfill-stone-crushed"
            },
            {
                type = "unlock-recipe",
                recipe = "stone-bricks-stone-crushed"
            },
        },
        icons = {
            {
                icon = "__muluna-graphics__/graphics/technology/comminution.png",
                icon_size = 968,
            },  
            {
                icon = data.raw["item"]["stone"].icon,
                icon_size=data.raw["item"]["stone"].icon_size,
                --scale=0.3,
                shift = {45,45},
                scale=0.75,
            },
            
        },
        prerequisites = {
            "metallurgic-science-pack"
        },
    },
    {
        type = "technology",
        name = "oxide-asteroid-crushing",
        localised_name = {"recipe-name.oxide-asteroid-crushing"},
        research_trigger = {
            type = "mine-entity",
            entity = "oxide-asteroid-chunk"
        },
        effects = {
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
            "planet-discovery-muluna"
        },
        icons = crushing_technology_icon(data.raw["item"]["oxide-asteroid-chunk"].icon,data.raw["item"]["oxide-asteroid-chunk"].icon_size),
        -- icon = data.raw["technology"]["steam-power"].icon,
        -- icon_size = data.raw["technology"]["steam-power"].icon_size,
    },
    {
        type = "technology",
        name = "muluna-anorthite-processing",
        research_trigger = {
            type = "mine-entity",
            entity = "anorthite-chunk"
        },
        effects = {
            {
                type = "unlock-recipe",
                recipe = "anorthite-crushing"
            },
            
            -- {
            --     type = "unlock-recipe",
            --     recipe = "electronic-circuit-aluminum",
            -- },
            -- {
            --     type = "unlock-recipe",
            --     recipe = "advanced-circuit-aluminum",
            -- },
        },
        prerequisites = {
            "metallic-asteroid-crushing"
        },
        icons = {
            {
                icon = "__muluna-graphics__/graphics/technology/comminution.png",
                icon_size = 968,
            },  
            {
                icon = "__muluna-graphics__/graphics/icons/anorthite-chunk.png",
                icon_size=64,
                --scale=0.3,
                shift = {45,45},
                scale=0.75,
            },
            
        }
    },
    {
        type = "technology",
        name = "muluna-alumina-processing",
        prerequisites = {"muluna-anorthite-processing"},
        research_trigger = {
            type = "craft-item",
            item = "alumina",
            count = 20,
        },
        effects = {
            {
                type = "unlock-recipe",
                recipe = "alumina-crushing"
            },
            {
                type = "unlock-recipe",
                recipe = "aluminum-plate"
            },
            
        },
        icons = crushing_technology_icon("__muluna-graphics__/graphics/icons/scrap-metal-aluminium-1.png")
    },
    {
        type = "technology",
        name = "muluna-aluminum-processing",
        prerequisites = {"muluna-alumina-processing",},
        research_trigger = {
            type = "craft-item",
            item = "aluminum-plate",
            count = 20,
        },
        effects = {
            {
                type = "unlock-recipe",
                recipe = "aluminum-cable",
            },
            {
                type = "unlock-recipe",
                recipe = "low-density-structure-from-aluminum",
            },
        }
    },
    {
        type = "technology",
        name = "muluna-alice-propellant",
        localised_name = {"recipe-name.rocket-fuel-aluminum"},
        localised_description = {"recipe-description.rocket-fuel-aluminum"},
        prerequisites = {"muluna-alumina-processing","oxide-asteroid-crushing"},
        research_trigger = {
            type = "craft-item",
            item = "alumina-crushed",
            count = 20,
        },
        effects = {
            {
                type = "unlock-recipe",
                recipe = "rocket-fuel-aluminum"
            },
        }
    },
    {
        type = "technology",
        name = "muluna-oxygen",
        prerequisites = {"metallic-asteroid-crushing","oxide-asteroid-crushing"},
        research_trigger = {
            type = "craft-item",
            item = "ice",
            count = 20,
        },
        effects = {
            {
                type = "unlock-recipe",
                recipe = "muluna-oxygen-from-oxidizer"
            },
            -- {
            --     type = "unlock-recipe",
            --     recipe="muluna-electrolysis"
            -- },
            {
                type = "unlock-recipe",
                recipe = "maraxsis-atmosphere"
            },
            {
                type = "unlock-recipe",
                recipe = "atmosphere-oxygen-separation"
            },
            {
                type = "unlock-recipe",
                recipe = "muluna-carbon-dioxide"
            },
            
            
            
        }
    },
    {
        type = "technology",
        name = "muluna-advanced-boiler",
        localised_name = {"entity-name.muluna-advanced-boiler"},
        localised_description = {"entity-description.muluna-advanced-boiler"},
        prerequisites = {"oxide-asteroid-crushing","carbonic-asteroid-crushing","muluna-oxygen"},
        research_trigger = {
            type = "craft-item",
            item = "carbon",
            count = 20,
        },
        icon = "__muluna-graphics__/graphics/thermal-plant/thermal-plant-icon-big.png",
        icon_size = 640,
        effects = {
            {
                type = "unlock-recipe",
                recipe = "muluna-advanced-boiler"
            },
            {
                type = "unlock-recipe",
                recipe = "advanced-water-boiling"
            },
            {
                type = "unlock-recipe",
                recipe = "advanced-water-boiling-atmosphere"
            },
            {
                type = "unlock-recipe",
                recipe="advanced-water-melting-atmosphere"
            },
            {
                type = "unlock-recipe",
                recipe="advanced-water-melting-oxygen"
            },
            {
                type = "unlock-recipe",
                recipe="controlled-combustion"
            },
            {
                type = "unlock-recipe",
                recipe="controlled-combustion-atmosphere"
            },
            {
                type = "unlock-recipe",
                recipe = "muluna-steam-crusher",
            },
            
            
        }
    },
    {
        type = "technology",
        name = "muluna-wood-cultivation",
        prerequisites = {"muluna-advanced-boiler"},
        research_trigger = {
            type = "craft-fluid",
            fluid = "carbon-dioxide",
            amount = 100,
        },
        effects = {
            {
                type = "unlock-recipe",
                recipe="muluna-tree-growth-greenhouse"
            },
            {
                type = "unlock-recipe",
                recipe="muluna-tree-growth-greenhouse-water-saving"
            },
            -- {
            --     type = "unlock-recipe",
            --     recipe="muluna-tree-growth-greenhouse-quick"
            -- },
            {
                type = "unlock-recipe",
                recipe="muluna-tree-crushing"
            },
            {
                type = "unlock-recipe",
                recipe="wood-processing"
            },
            
            
        }
    },
    {
        type = "technology", 
        name = "muluna-greenhouses",
        prerequisites = {"muluna-wood-cultivation","muluna-aluminum-processing"},
        icon = "__muluna-graphics__/graphics/greenhouse/sprites/greenhouse-icon-big.png",--data.raw["technology"]["tree-seeding"].icon,
        icon_size = 640,--data.raw["technology"]["tree-seeding"].icon_size,
        research_trigger = {
            type = "craft-item",
            item = "wood",
            count = 40,
        },
        effects = {
            {
                type = "unlock-recipe",
                recipe = "muluna-greenhouse",
            },
            -- {
            --     type = "unlock-recipe",
            --     recipe = "muluna-sapling-growth-greenhouse",
            -- },
            {
                type = "unlock-recipe",
                recipe = "muluna-greenhouse-wood",
            },
        }
    },
    {
        type = "technology",
        name = "muluna-gas-venting",
        prerequisites = {"muluna-wood-cultivation"},
        research_trigger = {
            type = "craft-item",
            item = "tree-seed",
            count = 50,
        },
        effects = {
            {
                type = "unlock-recipe",
                recipe = "carbon-dioxide-venting"
            },
            {
                type = "unlock-recipe",
                recipe = "oxygen-venting"
            },
            -- {
            --     type = "unlock-recipe",
            --     recipe = "hydrogen-venting"
            -- },
        }
    },
    {
        type = "technology",
        name = "muluna-silicon-processing",
        unit = {
            count = 100,
            time = 30,
            ingredients = {
                    {"automation-science-pack", 1},
                    {"logistic-science-pack", 1},
                    {"chemical-science-pack", 1},
                    {"production-science-pack", 1},
                    --{"utility-science-pack", 1},
                    --{"space-science-pack", 1},
            }
        },
        prerequisites = {
            "muluna-anorthite-processing",
            --"space-science-pack",
            "production-science-pack",
            --"utility-science-pack",
        },
        icon = "__muluna-graphics__/graphics/technology/moshine-tech-silicon-cell.png",
        icon_size = 256,
        effects = {
            {
                type = "unlock-recipe",
                recipe = "advanced-anorthite-crushing",
            },
            {
                type = "unlock-recipe",
                recipe = "silicon-cell",
            },
            {
                type = "unlock-recipe",
                recipe = "muluna-silicon-solar-panel",
            },
        }
    },
    {
        type = "technology",
        name = "thruster-oxidizer",
        localised_name = {"fluid-name.thruster-oxidizer"},
        icons = Muluna.img.blur_technology_icon({{icon = data.raw["fluid"]["thruster-oxidizer"].icon, icon_size = 64}},16),
        prerequisites = {"space-platform-thruster"},
        research_trigger = {
            type = "build-entity",
            entity = "thruster"
        },
        effects = {
            
            {
                type = "unlock-recipe",
                recipe = "thruster-oxidizer"
            },
            

        }
    },
    {
        type = "technology",
        name = "thruster-fuel",
        localised_name = {"fluid-name.thruster-fuel"},
        prerequisites = {"thruster-oxidizer"},
        research_trigger = {
            type = "craft-fluid",
            fluid = "thruster-oxidizer"
        },
        effects = {
            
            {
                type = "unlock-recipe",
                recipe = "thruster-fuel-from-rocket-fuel"
            },
            

    }
    },
    {
        type = "technology",
        name = "planet-discovery-muluna",
        essential = true,
        research_trigger = {
            type = "craft-fluid",
            fluid = "thruster-fuel"
        },
        effects = {
            {
                type = "unlock-space-location",
                space_location = "muluna"
            },
            {
                type="unlock-recipe",
                recipe="rocket-part-muluna"
            }
        },
        prerequisites = {
            "thruster-fuel"
        },
        icons = technology_icon_moon_complete("__muluna-graphics__/graphics/moon-icon.png",1482),
        localised_description={"space-location-description.muluna"},
        -- icons = {
        --     {
        --         icon = data.raw["planet"]["muluna"].icon,
        --         icon_size = data.raw["planet"]["muluna"].icon_size,
        --     }
        -- }
        
    },
    {
        type = "technology",
        name = "muluna-fertilized-greenhouses",
        icons = greenhouse_technology_icon(data.raw.item.nutrients.icon,64),
        localised_name = {"recipe-name.muluna-tree-growth-greenhouse-nutrients"},
        unit = {
            count = 2000,
            time = 60,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1},
                {"chemical-science-pack", 1},
                {"production-science-pack", 1},
                {"utility-science-pack", 1},
                {"space-science-pack", 1},
                --{"metallurgic-science-pack", 1},
                {"agricultural-science-pack", 1},
                --{"interstellar-science-pack",1}
            }
        },
        prerequisites = {"agricultural-science-pack","muluna-greenhouses"},
        effects = {

        }
    },
    {
        type = "technology",
        name = "muluna-fertilized-greenhouses-vulcanus",
        icons = greenhouse_technology_icon(data.raw.fluid["fluoroketone-cold"].icon,64),
        localised_name = {"recipe-name.muluna-tree-growth-greenhouse-vulcanus"},
        unit = {
            count = 3000,
            time = 60,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1},
                {"chemical-science-pack", 1},
                {"production-science-pack", 1},
                {"utility-science-pack", 1},
                {"space-science-pack", 1},
                {"metallurgic-science-pack", 1},
                {"agricultural-science-pack", 1},
                {"cryogenic-science-pack", 1},
                {"electromagnetic-science-pack", 1},
                --{"interstellar-science-pack",1}
            }
        },
        prerequisites = {"cryogenic-science-pack","muluna-fertilized-greenhouses"},
        effects = {

        }
    },
    {
        type = "technology",
        name = "cryolab",
        localised_name = {"entity-name.cryolab"},
        --localised_description = {"entity-description.asteroid-collector"},
        unit= {
            count = 5000,
            time = 60,
            ingredients = --Normally, I would base these costs on vanilla technologies to increase tolerance of other mods, but since this tech is intended to 
                {
                    {"automation-science-pack", 1},
                    {"logistic-science-pack", 1},
                    {"chemical-science-pack", 1},
                    {"production-science-pack", 1},
                    {"utility-science-pack", 1},
                    {"space-science-pack", 1},
                    {"metallurgic-science-pack", 1},
                    {"agricultural-science-pack", 1},
                    {"electromagnetic-science-pack", 1},
                    {"cryogenic-science-pack", 1},
                    {"interstellar-science-pack",1}
              },
        },
        effects = {
            {
                type = "unlock-recipe",
                recipe = "cryolab"
            }
        },
        prerequisites = {
            "biolab","quantum-processor","muluna-helium-enrichment"
        },
        icons = {
            {
                icon = "__muluna-graphics__/graphics/photometric-lab/photometric-lab-icon-big.png",
                icon_size = 640
                --icon=data.raw["technology"]["biolab"].icon,
                --icon_size=data.raw["technology"]["biolab"].icon_size,
                --tint = {r=0.7,g=0.7,b=1}
            },
        }
        --icon = "__muluna-graphics__/graphics/technology/asteroid-collector(ai-upscaled).png",
        --icon_size=256,
    },
    {
        type = "technology",
        name = "muluna-helium-enrichment",
        --localised_name = {"entity-name.cryolab"},
        --localised_description = {"entity-description.asteroid-collector"},
        unit= {
            count = 500,
            time = 60,
            ingredients = --Normally, I would base these costs on vanilla technologies to increase tolerance of other mods, but since this tech is intended to 
                {
                    {"automation-science-pack", 1},
                    {"logistic-science-pack", 1},
                    {"chemical-science-pack", 1},
                    {"production-science-pack", 1},
                    {"utility-science-pack", 1},
                    {"space-science-pack", 1},
                    {"metallurgic-science-pack", 1},
                    {"agricultural-science-pack", 1},
                    {"electromagnetic-science-pack", 1},
                    {"cryogenic-science-pack", 1},
                    {"interstellar-science-pack",1}
              },
        },
        effects = {
            -- {
            --     type = "unlock-recipe",
            --     recipe = "interstellar-science-pack-helium-4"
            -- },
            {
                type = "unlock-recipe",
                recipe = "helium-separation"
            },
            {
                type = "unlock-recipe",
                recipe = "kovarex-helium-enrichment"
            },
        },
        prerequisites = {
            "interstellar-science-pack",
            "cryogenic-science-pack"
        },
        icons = {
            {
                icon="__muluna-graphics__/graphics/technology/molecule-noble-gas.png",
                icon_size=644,
                tint = {r=0.7,g=0.7,b=1}
            },
        }
        --icon = "__muluna-graphics__/graphics/technology/asteroid-collector(ai-upscaled).png",
        --icon_size=256,
    },
    {
        type = "technology",
        name = "thruster-fuel-productivity",
        icons = technology_icon_constant_recipe_productivity(data.raw["technology"]["space-platform-thruster"].icon),
        --icons = {
            --{
                --icon= data.raw["technology"]["space-platform-thruster"].icon,
                --icon_size=data.raw["technology"]["space-platform-thruster"].icon_size,
                --tint = {r=0.7,g=0.7,b=1}
            --},
        --},
        max_level = "infinite",
        prerequisites = {"interstellar-science-pack","production-science-pack","space-science-pack"},
        upgrade = true,
        unit = {
            count_formula = "2000*1.5^(L-1)",
            time = 60,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1},
                {"chemical-science-pack", 1},
                {"production-science-pack", 1},
                --{"utility-science-pack", 1},
                {"space-science-pack", 1},
                {"interstellar-science-pack",1},
            }
        },
        effects = {
            {
                type = "change-recipe-productivity",
                recipe = "thruster-oxidizer",
                change = 0.1,
            },
            {
                type = "change-recipe-productivity",
                recipe = "thruster-fuel",
                change = 0.1,
            },
            {
                type = "change-recipe-productivity",
                recipe = "advanced-thruster-oxidizer",
                change = 0.1,
            },
            {
                type = "change-recipe-productivity",
                recipe = "advanced-thruster-fuel",
                change = 0.1,
            },
            {
                type = "change-recipe-productivity",
                recipe = "thruster-fuel-from-rocket-fuel",
                change = 0.1,
            },
        },
    },
    {
        type = "technology",
        name = "advanced-space-science-pack",
        prerequisites = {"interstellar-science-pack","space-science-pack","production-science-pack","utility-science-pack"},
        icons = {
            {
                icon = data.raw["technology"]["space-science-pack"].icon,
                icon_size = data.raw["technology"]["space-science-pack"].icon_size,
            },
            {
                icon = data.raw["item"]["asteroid-collector"].icon,
                icon_size = data.raw["item"]["asteroid-collector"].icon_size,
                shift = {36,-36},
                scale = 0.75,
            },
        },
        unit = {
            count = 500,
            time = 60,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1},
                {"chemical-science-pack", 1},
                {"production-science-pack", 1},
                {"utility-science-pack", 1},
                {"space-science-pack", 1},
                {"interstellar-science-pack",1},
            }
        },

        effects = {
            {
                type = "unlock-recipe",
                recipe = "space-science-pack"
            }
        }
    },
    {
        type = "technology",
        name = "crusher-2",
        unit = {
            count = 2000,
            time = 60,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1},
                {"chemical-science-pack", 1},
                {"production-science-pack", 1},
                {"utility-science-pack", 1},
                {"space-science-pack", 1},
                {"interstellar-science-pack",1},
                {"metallurgic-science-pack",1},
            }
        },
        effects = {
            {
                type = "unlock-recipe",
                recipe="crusher-2"
            }
        },
        prerequisites = {
            "interstellar-science-pack", "metallic-asteroid-crushing","metallurgic-science-pack"
        },
        icons = {
            {
                icon = "__muluna-graphics__/graphics/technology/comminution.png",
                icon_size = 968,
            },  
            {
                icon = data.raw["item"]["tungsten-plate"].icon,
                icon_size=data.raw["item"]["tungsten-plate"].icon_size,
                --scale=0.3,
                shift = {45,45},
                scale=0.75,
            },
            
        },
        localised_name={"",{"item-name.crusher"}," 2"},
        --localised_description={"space-location-description.muluna"},
        -- icons = {
        --     {
        --         icon = data.raw["planet"]["muluna"].icon,
        --         icon_size = data.raw["planet"]["muluna"].icon_size,
        --     }
        -- }
        
    },
    {
        type = "technology",
        name = "carbonic-asteroid-crushing",
        localised_name = {"recipe-name.carbonic-asteroid-crushing"},
        research_trigger = {
            type = "mine-entity",
            entity = "carbonic-asteroid-chunk"
        },
        prerequisites = {
            "planet-discovery-muluna"
        },
        effects = {
            {
                type = "unlock-recipe",
                recipe = "carbonic-asteroid-crushing"
            },
            {
                type = "unlock-recipe",
                recipe = "electric-engine-unit-from-carbon"
            },
            {
                type = "unlock-recipe",
                recipe = "thruster-fuel"
            },
            
            
            -- {
            --     type = "unlock-recipe",
            --     recipe="muluna-electrolysis"
            -- },
            -- {
            --     type = "unlock-recipe",
            --     recipe="cellulose"
            -- },
            
            
            
            
            -- {
            --     type = "unlock-recipe",
            --     recipe = "muluna-tree-growth-greenhouse-11x11"
            -- }

        },
        icons = crushing_technology_icon(data.raw["item"]["carbonic-asteroid-chunk"].icon,data.raw["item"]["carbonic-asteroid-chunk"].icon_size),
        
    },
    {
        type = "technology",
        name = "space-chest-muluna",
        localised_name = {"entity-name.space-chest-muluna"},
        icon = "__muluna-graphics__/graphics/technology/packaging.png",
        icon_size = 1024,
        unit = {
            count = 1000,
            time = 60,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1},
                {"chemical-science-pack", 1},
                {"production-science-pack", 1},
                --{"utility-science-pack", 1},
                {"space-science-pack", 1},
                {"interstellar-science-pack",1},
            }
        },
        prerequisites = {
            "interstellar-science-pack", "production-science-pack", "space-science-pack"
        },
        effects = {
            {
                type = "unlock-recipe",
                recipe="space-chest-muluna"
            },
        }
    },
    {
        type = "technology",
        name = "low-density-space-platform-foundation",
        localised_name = {"item-name.low-density-space-platform-foundation"},
        icon = data.raw["technology"]["space-platform"].icon,
        icon_size = data.raw["technology"]["space-platform"].icon_size,
        -- unit = {
        --     count = 2000,
        --     time = 60,
        --     ingredients = {
        --         {"automation-science-pack", 1},
        --         {"logistic-science-pack", 1},
        --         {"chemical-science-pack", 1},
        --         --{"production-science-pack", 1},
        --         {"utility-science-pack", 1},
        --         {"space-science-pack", 1},
        --         {"interstellar-science-pack",1},
        --         {"agricultural-science-pack",1},
        --     }
        -- },
        research_trigger = {
            type = "craft-item",
            item = "muluna-microcellular-plastic",
            amount = 10,
        },
        prerequisites = {
            "muluna-nanofoamed-polymers"
        },
        effects = {
            {
                type = "unlock-recipe",
                recipe="low-density-space-platform-foundation"
            },
        }
    },
    {
        type = "technology",
        name = "muluna-nanofoamed-polymers",
        --localised_name = {"item-name.muluna-microcellular-plastic"},
        localised_description = {"technology-description.muluna-nanofoamed-polymers",tostring(settings.startup["muluna-interstellar-science-pack-packs-required"].value)},
        icon = "__muluna-graphics__/graphics/technology/polymers.png",
        icon_size = 1024,
        unit = {
            count = 1,
            time = 1,
            ingredients = {

            }
        },
        prerequisites = {
            "kovarex-enrichment-process",
            "muluna-anorthite-processing",
            "asteroid-collector"
        },
        effects = {
            {type = "unlock-recipe", recipe = "muluna-microcellular-plastic-diffusion"},
            {type = "unlock-recipe", recipe = "muluna-microcellular-plastic-curing"},
        }
    },
    {
        type = "technology",
        name = "muluna-cycling-steam-turbine",
        icon = "__muluna-graphics__/graphics/icons/advanced-steam-turbine.png",
        icon_size = 64,
        unit = {
            count = 2000,
            time = 60,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1},
                {"chemical-science-pack", 1},
                --{"production-science-pack", 1},
                {"utility-science-pack", 1},
                {"space-science-pack", 1},
                {"interstellar-science-pack",1},
                {"electromagnetic-science-pack",1},
                {"metallurgic-science-pack",1},
            }
        },
        prerequisites = {
            "interstellar-science-pack","electromagnetic-science-pack","metallurgic-science-pack"
        },
        effects = {
            {
                type = "unlock-recipe",
                recipe= "muluna-cycling-steam-turbine"
            },
            {
                type = "unlock-recipe",
                recipe= "muluna-steam-condensation"
            },
           
        }
    },
    {
        type = "technology",
        name = "water-recycling-productivity",
        icons = technology_icon_constant_recipe_productivity("__muluna-graphics__/graphics/technology/filtration.png",1024),
        icon = data.raw["technology"]["space-platform"].icon,
        icon_size = data.raw["technology"]["space-platform"].icon_size,
        max_level = "infinite",
        unit = {
            --count = 1000,
            count_formula = "250*1.5^(L-1)",
            time = 60,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1},
                {"chemical-science-pack", 1},
                --{"production-science-pack", 1},
                {"utility-science-pack", 1},
                {"space-science-pack", 1},
                {"interstellar-science-pack",1},
                {"electromagnetic-science-pack",1},
                {"metallurgic-science-pack",1},
            }
        },
        prerequisites = {
            "interstellar-science-pack","muluna-cycling-steam-turbine"
        },
        effects = {
            {
                type = "change-recipe-productivity",
                recipe = "muluna-steam-condensation",
                change = 0.1,
            },
           
        }
    },
    
    -- {
    --     type = "technology",
    --     name = "wood-liquifaction",
    --     unit = {
    --                 count = 100,
    --                 time = 60,
    --                 ingredients = {
    --                     --{"automation-science-pack", 1},
    --                     --{"logistic-science-pack", 1},
    --                     --{"chemical-science-pack", 1},
    --                     --{"production-science-pack", 1},
    --                     --{"utility-science-pack", 1},
    --                     {"space-science-pack", 1},
    --                     --{"agricultural-science-pack", 1},
    --                     --{"interstellar-science-pack",1},
    --                 }
    --             },
    --     prerequisites = {
    --         "space-science-pack"
    --     },
    --     effects = {
    --         {
    --             type = "unlock-recipe",
    --             recipe="wood-crushing"
    --         },
    --         {
    --             type = "unlock-recipe",
    --             recipe="cellulose"
    --         },
    --         -- {
    --         --     type = "unlock-recipe",
    --         --     recipe="heavy-oil-cellulose"
    --         -- },

    --     },
    -- }
    
    -- {
    --     type = "technology",
    --     name = "advanced-space-platform-foundation",
    --     unit = {
    --         count = 500,
    --         time = 60,
    --         ingredients = {
    --             {"automation-science-pack", 1},
    --             {"logistic-science-pack", 1},
    --             {"chemical-science-pack", 1},
    --             {"production-science-pack", 1},
    --             {"utility-science-pack", 1},
    --             {"space-science-pack", 1},
    --             {"agricultural-science-pack", 1},
    --             {"interstellar-science-pack",1},
    --         }
    --     },
    --     effects = {
    --         {
    --             type = "unlock-recipe",
    --             recipe="advanced-space-platform-foundation"
    --         }
    --     },
    --     prerequisites = {
    --         "interstellar-science-pack"
    --     },
    --     icon = data.raw["technology"]["space-platform"].icon,
    --     icon_size = data.raw["technology"]["space-platform"].icon_size,
    -- }

}
if settings.startup["muluna-easy-wood-gasification-productivity"].value == true then-- or  then
    local gasification_prod = {
        type = "technology",
        name = "wood-gas-processing-productivity",
        icons = technology_icon_constant_recipe_productivity(data.raw["technology"]["wood-gas-processing"].icon),
        --icons = {
            --{
                --icon= data.raw["technology"]["space-platform-thruster"].icon,
                --icon_size=data.raw["technology"]["space-platform-thruster"].icon_size,
                --tint = {r=0.7,g=0.7,b=1}
            --},
        --},
        max_level = "infinite",
        prerequisites = {"wood-gas-processing","space-science-pack"},
        upgrade = true,
        unit = {
            count_formula = "1500*1.5^(L-1)",
            time = 60,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1},
                {"chemical-science-pack", 1},
                {"production-science-pack", 1},
                {"space-science-pack",1}
            }
        },
        effects = {
            {
                type = "change-recipe-productivity",
                recipe = "wood-gasification",
                change = 0.1,
            },
            {
                type = "change-recipe-productivity",
                recipe = "advanced-wood-gasification",
                change = 0.1,
            },
        },
    }
    if (settings.startup["aps-planet"] and settings.startup["aps-planet"].value == "muluna") then
        gasification_prod.unit= {
            count_formula = "100*1.5^(L-1)",
            time = 60,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1},
                {"space-science-pack",1}
            }
        }
        rro.remove(gasification_prod.prerequisites,"space-science-pack")
    end
    data:extend{gasification_prod}
end

if settings.startup["muluna-hardcore-remove-steam-furnaces"].value == false then
    local boiler = data.raw["technology"]["muluna-advanced-boiler"]
    table.insert(boiler.effects,{
                type = "unlock-recipe",
                recipe = "muluna-steam-stone-furnace"
            })
      table.insert(boiler.effects,{
                type = "unlock-recipe",
                recipe = "muluna-steam-steel-furnace"
            })      
            
end

if not data.raw["lab"]["biolab"] then
    data.raw["technology"]["cryolab"] = nil
  end


