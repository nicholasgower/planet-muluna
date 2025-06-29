local rro = require("lib.remove-replace-object")
local all = {}

local space_boiler = table.deepcopy(data.raw["item"]["boiler"])

space_boiler.name = "muluna-advanced-boiler"
space_boiler.place_result = "muluna-advanced-boiler"
space_boiler.icon="__muluna-graphics__/graphics/thermal-plant/thermal-plant-icon.png"
space_boiler.localised_name = {"entity-name.muluna-advanced-boiler"}
space_boiler.order = "b[steam-power]-aa[muluna-advanced-boiler]"
space_boiler.weight = 4 * kg


local crusher_2 = table.deepcopy(data.raw["item"]["crusher"])

crusher_2.name = "crusher-2"
crusher_2.place_result = "crusher-2"
crusher_2.icon = "__muluna-graphics__/graphics/icons/crusher-2.png"
crusher_2.localised_name = {"",{"item-name.crusher"}," 2"}
crusher_2.order = "cb[crusher-2]"
crusher_2.weight = crusher_2.weight*2
--local crusher_2=nil
if data.raw["lab"]["biolab"] then
    local cryolab=table.deepcopy(data.raw["item"]["biolab"])

    cryolab.name="cryolab"
    cryolab.place_result= "cryolab"

    cryolab.icons = {
        {
            icon="__muluna-graphics__/graphics/photometric-lab/photometric-lab-icon.png",
            icon_size=64,
            scale=0.25,
            --tint = {r=0.7,g=0.7,b=1}
        },
        
    }
    cryolab.default_import_location = "muluna"
    data:extend{cryolab}
end
    

local space_platform_advanced = table.deepcopy(data.raw["item"]["space-platform-foundation"])
space_platform_advanced.place_as_tile.result = "advanced-space-platform-foundation"
space_platform_advanced.name = "advanced-space-platform-foundation"
space_platform_advanced.weight = space_platform_advanced.weight / 2

local space_chest = table.deepcopy(data.raw["item"]["steel-chest"])

space_chest=util.merge{space_chest,
    {
        name="space-chest-muluna",
        place_result="space-chest-muluna",
        icons = {
            {
            icon=space_chest.icon,
            icon_size=space_chest.icon_size,
            tint = {0.7,0.7,0.7},
            
            },
            
        },
        subgroup = "space-platform",
        order = "ca[space-chest-muluna]",
        default_import_location = "muluna",
    }

}

local greenhouse = util.merge{table.deepcopy(data.raw["item"]["chemical-plant"]),
    {
        name = "muluna-greenhouse",
        icon = "__muluna-graphics__/graphics/greenhouse/sprites/greenhouse-icon.png",
        icon_size = 64,
        --place_result = "muluna-greenhouse",
        subgroup = "agriculture",
        order = "az-[muluna-greenhouse]",
        default_import_location = "muluna",
    }
    
}

greenhouse.place_result = nil

local greenhouse_wood = util.merge{table.deepcopy(data.raw["item"]["chemical-plant"]),
    {
        name = "muluna-greenhouse-wood",
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
        subgroup = "agriculture",
        place_result = "muluna-greenhouse-wood",
        order = "az-[muluna-greenhouse]-a[muluna-greenhouse-wood]",
        default_import_location = "muluna",
    }
    
}

local low_density_space_platform_foundation = table.deepcopy(data.raw["item"]["space-platform-foundation"])
low_density_space_platform_foundation = util.merge{low_density_space_platform_foundation,
{
    name = "low-density-space-platform-foundation",
    icon = "__muluna-graphics__/graphics/icons/low-density-space-platform-foundation.png",
    order = "aa[low-density-space-platform-foundation]",
    weight = low_density_space_platform_foundation.weight / 2,
    default_import_location = "muluna",
}
}
low_density_space_platform_foundation.place_as_tile.result = "low-density-space-platform-foundation"


local recycling_turbine = util.merge{table.deepcopy(data.raw["item"]["fusion-generator"]),
    {
        name = "muluna-cycling-steam-turbine",
        place_result = "muluna-cycling-steam-turbine",
        icon = "__muluna-graphics__/graphics/icons/advanced-steam-turbine.png",
        icon_size = 64,
        order = "f[nuclear-energy]-g[muluna-cycling-steam-turbine]",
        default_import_location = "muluna",
    }

}


data:extend{space_boiler,crusher_2,space_chest,greenhouse,greenhouse_wood,low_density_space_platform_foundation,recycling_turbine}