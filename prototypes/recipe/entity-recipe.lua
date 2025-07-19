local rro = Muluna.rro

local space_boiler = table.deepcopy(data.raw["recipe"]["boiler"])
space_boiler.icon = "__muluna-graphics__/graphics/thermal-plant/thermal-plant-icon.png"
space_boiler.name = "muluna-advanced-boiler"
space_boiler.place_result = "muluna-advanced-boiler"

space_boiler.ingredients = {
    {type = "item", name = "boiler", amount = 3},
    {type = "item", name = "pipe", amount = 4},
    {type = "item", name = "steel-plate", amount = 8},
}
space_boiler.energy_required = 5


space_boiler.results = {{type = "item",name = "muluna-advanced-boiler",amount = 1}}

local vacuum_heating_tower = table.deepcopy(space_boiler)
vacuum_heating_tower.name = "muluna-vacuum-heating-tower"
vacuum_heating_tower.results[1].name = "muluna-vacuum-heating-tower"
vacuum_heating_tower.ingredients = {
    
        {
            type = "item",
            name = "heating-tower",
            amount = 3,
        },
        {
            type = "item",
            name = "pipe",
            amount = 20,
        },
        {
            type = "item",
            name = "refined-concrete",
            amount = 30,
        },
        {
            type = "item",
            name = "heat-pipe",
            amount = 10
        }
    
}
vacuum_heating_tower.energy_required = 10
--vacuum_heating_tower.enabled = true

local crusher_2 = table.deepcopy(data.raw["recipe"]["crusher"])

crusher_2.surface_conditions=nil
crusher_2.name = "crusher-2"
--space_boiler.place_result = "space-boiler"
crusher_2.localised_name = {"",{"item-name.crusher"}," 2"}
crusher_2.ingredients = {
    {type = "item",name = "tungsten-plate",amount = 10},
    {type = "item",name = "uranium-238",amount = 10},
    {type = "item",name = "aluminum-plate",amount = 10},
    {type = "item",name = "crusher",amount = 1}
}
if settings.startup["muluna-hardcore-restrict-crusher"].value == true then
    crusher_2.surface_conditions = {{property = "oxygen", max = 0, min = 0},{property = "gravity", max = 0.1, min = 0.1}}
    
end
crusher_2.results = {{type = "item",name = "crusher-2",amount = 1}}


if true or data.raw["recipe"]["biolab"] then
    local cryolab = table.deepcopy(data.raw["recipe"]["biolab"])

    cryolab.name="cryolab"
    cryolab.category="cryogenics"
    --cryolab.recipe_group="production"
    --cryolab.subgroup="production-machine"

    --cryolab.enabled=true
    cryolab.icons={{
        icon="__muluna-graphics__/graphics/photometric-lab/photometric-lab-icon.png",
        icon_size=64,
        scale=0.25,
        --tint = {r=0.7,g=0.7,b=1}
    },}
    cryolab.localised_name={"entity-name.cryolab"}
    cryolab.results = {{type = "item",name = "cryolab",amount = 1}}
    cryolab.ingredients = {
        {type = "item", name = "quantum-processor", amount = 10},
        {type = "item", name = "biolab", amount = 1},
        {type = "item", name = "aluminum-plate", amount = 20},
        {type = "fluid", name = "fluoroketone-cold", amount = 100},
        {type = "fluid", name = "helium-3", amount = 100},
        {type = "item", name = "biter-egg", amount = 5},
        {type = "item", name = "pentapod-egg", amount = 5},
    }
    cryolab.surface_conditions = {
        {
            property = "temperature",
            max = 265,
        },
        {
            property = "oxygen",
            min = 0,
            max = 0,
        },
    }
    data:extend{cryolab}
end
    

local space_platform_advanced = table.deepcopy(data.raw["recipe"]["space-platform-foundation"])
space_platform_advanced.name = "advanced-space-platform-foundation"
space_platform_advanced.ingredients = {
    {type = "item", name = "aluminum-plate", amount = 10},
    {type = "item", name = "carbon-fiber", amount = 10},
    {type = "item", name = "aluminum-cable", amount = 20},
    {type = "item", name = "space-platform-foundation", amount = 1},

}
space_platform_advanced.results = {
    {type = "item", name = "advanced-space-platform-foundation", amount = 1}
}

local space_chest = table.deepcopy(data.raw["recipe"]["steel-chest"])

space_chest = util.merge{space_chest,
    {   
        name = "space-chest-muluna",
        results = {{type = "item", name = "space-chest-muluna", amount = 1}},
        ingredients = {
            {type = "item", name = "aluminum-plate", amount = 8},
            {type = "item", name = "low-density-structure", amount = 1},
            {type = "item", name = "processing-unit", amount = 1},
            },
        subgroup = "space-platform",
        order = "ca[space-chest-muluna]"
        --auto_recycle = false
    }
}

local greenhouse = util.merge{table.deepcopy(data.raw["recipe"]["chemical-plant"]),
    {
        name = "muluna-greenhouse",
        
        results = {{type = "item", name = "muluna-greenhouse", amount = 1}}
    }
}
greenhouse.ingredients = {
    {type = "item", name = "aluminum-plate", amount = 25},
    {type = "item", name = "steel-plate", amount = 10},
    {type = "item", name = "small-lamp", amount = 20},
    {type = "item", name = "pipe", amount = 10},
    {type = "item", name = "chemical-plant", amount = 5},
}

local greenhouse_wood = util.merge{table.deepcopy(data.raw["recipe"]["chemical-plant"]),
    {
        name = "muluna-greenhouse-wood",
        category = "crafting",
        icons = {
            {
                icon = "__muluna-graphics__/graphics/greenhouse/sprites/greenhouse-icon.png",
                icon_size = 64,
            },
            {
                icon = data.raw["item"]["wood"].icon,
                icon_size = data.raw["item"]["wood"].icon_size,
                scale = 0.25,
                shift = {10,-10},
                draw_background = true,
            }
        },
        main_product = "muluna-greenhouse-wood",
        energy_required = 10,
        results = {
            {type = "item", name = "muluna-greenhouse-wood", amount = 1,ignored_by_productivity=1},
            --{type = "fluid", name = "oxygen", amount = 100000,ignored_by_productivity=100000},}
        }
    }
}
greenhouse_wood.ingredients = {
    {type = "item", name = "muluna-greenhouse", amount = 1},
    --{type = "fluid", name = "carbon-dioxide", amount = 100000},
    {type = "item", name = "muluna-sapling", amount = 100},
    --{type = "fluid", name = "water", amount = 10000},
    {type = "item", name = "landfill", amount = 10},
}

local low_density_space_platform_foundation = util.merge{table.deepcopy(data.raw["recipe"]["space-platform-foundation"]),
{
    name = "low-density-space-platform-foundation",
    results = {{type = "item",name = "low-density-space-platform-foundation", amount = 2}},
    energy_required = 30,
    ingredients = {
        {
            type = "item",
            name = "space-platform-foundation",
            amount = 1,
        },
        {
            type = "item",
            name = "aluminum-plate",
            amount = 2,
        },
        {type = "item", name = "muluna-microcellular-plastic", amount = 5},
        {
            type = "item",
            name = "low-density-structure",
            amount = 2,
        },
        
    }
}
}

local recycling_turbine = util.merge{table.deepcopy(data.raw["recipe"]["fusion-generator"]),
{
    name = "muluna-cycling-steam-turbine",
    results = {{type = "item",name = "muluna-cycling-steam-turbine", amount = 1}},
    energy_required = 10,
    
    ingredients = {
        {
            type = "item",
            name = "steam-turbine",
            amount = 1,
        },
        {
            type = "item",
            name = "tungsten-plate",
            amount = 10,
        },
        {
            type = "item",
            name = "aluminum-plate",
            amount = 10,
        },
        {
            type = "item",
            name = "superconductor",
            amount = 10,
        },
        {
            type = "item",
            name = "pipe",
            amount = 20,
        },
    }
}
}
recycling_turbine.category = "crafting"
recycling_turbine.surface_conditions = nil
recycling_turbine.factoriopedia_description = nil

local buggy = table.deepcopy(data.raw["recipe"]["car"])

buggy.name = "muluna-rocket-buggy"

buggy.results[1].name = "muluna-rocket-buggy"


data:extend{space_boiler,vacuum_heating_tower, crusher_2,space_chest,greenhouse,greenhouse_wood,low_density_space_platform_foundation,recycling_turbine,buggy}