local dual_icon = require("lib.dual-item-icon").dual_icon
local dual_icon_reversed = require("lib.dual-item-icon").dual_icon_reversed

local function crushing_icon(icon_dir,icon_size)
return {
    {
        icon = icon_dir,
        icon_size=64,
        --scale=0.3,
        shift = {0,-3},
        scale=50/128,
        draw_background = true
    },
    {
        icon = "__muluna-graphics__/graphics/icons/generic-crushing.png",
        icon_size=64,
        scale=0.5,
        draw_background = true
    },
}

end

local function advanced_crushing_icon(icon_dir,product_1,product_2)
    return {
        {
            icon = product_1,
            icon_size=64,
            scale = 0.25,
            shift = {-8,8},
            draw_background = true
        },
        {
            icon = product_1,
            icon_size=64,
            scale = 0.25,
            shift = {8,-8},
            draw_background = true
        },
        {
            icon = product_2,
            icon_size=64,
            scale = 0.25,
            shift = {-8,-8},
            draw_background = true
        },
        {
            icon = product_2,
            icon_size=64,
            scale = 0.25,
            shift = {8,8},
            draw_background = true
        },
        {
            icon = icon_dir,
            icon_size=64,
            scale=0.4,
            -- shift = {0,-3},
            --scale = 0.5,
            --scale=50/128,
            draw_background = true
        },
        
        -- {
        --     icon = "__muluna-graphics__/graphics/icons/generic-crushing.png",
        --     icon_size=64,
        --     scale=0.5,
        --     draw_background = true
        -- },
    }

end
-- New icons

table.insert(data.raw["character"]["character"].crafting_categories,
"crushing"    

)

local anorthite_crushing = table.deepcopy(data.raw["recipe"]["oxide-asteroid-crushing"])
anorthite_crushing.name = "anorthite-crushing"


anorthite_crushing.icons = {
{
    icon = "__muluna-graphics__/graphics/icons/anorthite-chunk.png",
    icon_size=64,
    --scale=0.3,
    shift = {0,-3},
    scale=50/128,
    draw_background = true
},
{
    icon = "__muluna-graphics__/graphics/icons/asteroid-crushing.png",
    icon_size=64,
    scale=0.5,
    draw_background = true
},

}
anorthite_crushing.order="b-a-d"
anorthite_crushing.results = {{type = "item",name = "alumina",amount = 20},{type = "item", name = "anorthite-chunk", amount = 1, probability = 0.2}}
anorthite_crushing.ingredients = {{type = "item",name = "anorthite-chunk",amount = 1}}

-- anorthite_crushing.surface_conditions={
--     PlanetsLib.surface_conditions.restrict_to_surface("muluna")
-- }


local advanced_anorthite_crushing = util.merge{table.deepcopy(anorthite_crushing),

{
    name = "advanced-anorthite-crushing",
    order = "g[advanced-anorthite-crushing]",
    icons = advanced_crushing_icon(
        "__muluna-graphics__/graphics/icons/anorthite-chunk.png",
        data.raw["item"]["alumina"].icon,
        data.raw["item"]["silicon"].icon
    ),
}


}

advanced_anorthite_crushing.results = {{type = "item",name = "alumina",amount = 10},{type = "item",name = "silicon",amount = 4},{type = "item", name = "anorthite-chunk", amount = 1, probability = 0.05}}
advanced_anorthite_crushing.hide_from_signal_gui = false

data:extend{advanced_anorthite_crushing}



local alumina_crushing=table.deepcopy(anorthite_crushing)
alumina_crushing.icons = crushing_icon(data.raw["item"]["alumina"].icon,64)
alumina_crushing.name="alumina-crushing"
alumina_crushing.results = {{type = "item", name = "alumina", amount = 1,ignored_by_productivity=1, probability = 1/20 },{type = "item",name = "alumina-crushed",amount = 2}}
alumina_crushing.ingredients = {{type = "item",name = "alumina",amount = 1}}
alumina_crushing.energy_required = 1
alumina_crushing.order="b-aa-a"

local aluminum_crushing=table.deepcopy(anorthite_crushing)
aluminum_crushing.icons = crushing_icon("__muluna-graphics__/graphics/icons/metal-plate-aluminium.png",64)
aluminum_crushing.name="aluminum-crushing"
aluminum_crushing.results = {{type = "item", name = "aluminum-plate", amount = 1,ignored_by_productivity=1, probability = 1/20 },{type = "item",name = "aluminum-crushed",amount = 2}}
aluminum_crushing.ingredients = {{type = "item",name = "aluminum-plate",amount = 1}}
aluminum_crushing.energy_required = 1
aluminum_crushing.order="b-aa-b"

local stone_crushing=table.deepcopy(anorthite_crushing)

stone_crushing.results = {{type = "item", name = "stone", amount = 1,ignored_by_productivity=1, probability = 1/10},{type = "item",name = "stone-crushed",amount = 3}}
stone_crushing.ingredients = {{type = "item",name = "stone",amount = 2}}
stone_crushing.name="stone-crushing"
stone_crushing.energy_required=1
stone_crushing.order="b-aa-c"
stone_crushing.icons = crushing_icon(data.raw.item["stone"].icon,data.raw.item["stone"].icon_size)



local aluminum_plate = table.deepcopy(data.raw["recipe"]["iron-plate"])
aluminum_plate.ingredients = {{type = "item",name = "alumina",amount = 1}}
aluminum_plate.results = {{type = "item",name = "aluminum-plate",amount = 1}}
aluminum_plate.name = "aluminum-plate"
aluminum_plate.enabled = false

local aluminum_cable = table.deepcopy(data.raw["recipe"]["copper-cable"])

aluminum_cable.name = "aluminum-cable"
aluminum_cable.ingredients = {{type = "item",name = "aluminum-plate",amount = 1}}
aluminum_cable.auto_recycle = false

aluminum_cable.localised_name = {"item-name.aluminum-cable"}
aluminum_cable.icons = dual_icon("copper-cable","aluminum-plate")
aluminum_cable.subgroup="muluna-products"
aluminum_cable.allow_decomposition = false
aluminum_cable.allow_as_intermediate = false
--aluminum_cable.results = {{type = "item",name = "aluminum-cable",amount = 2}}

-- table.insert(data.raw["technology"]["asteroid-productivity"].effects, {
--     effect = "enable-recipe",
--     recipe = ""
-- })


local wood_crushing = table.deepcopy(anorthite_crushing)
wood_crushing.name = "woodchips"
--wood_crushing.ingredients = {{type = "item",name = "wood",amount = 6}}
--wood_crushing.results = {{type = "item",name = "woodchips",amount = 10},{type = "item", name = "wood", amount = 1,ignored_by_productivity=1}}

wood_crushing.results = {{type = "item", name = "wood", amount = 1,ignored_by_productivity=1, probability = 1/20 },{type = "item",name = "woodchips",amount = 2}}
wood_crushing.ingredients = {{type = "item",name = "wood",amount = 1}}
wood_crushing.energy_required = 0.5

wood_crushing.icons=crushing_icon(data.raw.item["wood"].icon,data.raw.item["wood"].icon_size)
wood_crushing.order="b-aa-c"

local tree_crushing = table.deepcopy(wood_crushing)

tree_crushing.name = "muluna-tree-crushing"

tree_crushing.results = {{type = "item", name = "muluna-sapling", amount = 1,ignored_by_productivity=1, probability = 1/20 },{type = "item",name = "wood",amount = 4}}
tree_crushing.ingredients = {{type = "item",name = "muluna-sapling",amount = 1}}
tree_crushing.icons=crushing_icon(data.raw.item["muluna-sapling"].icon,data.raw.item["muluna-sapling"].icon_size)
tree_crushing.order="b-aa-b"


local regolith_sorting = {
    type = "recipe",
    name = "muluna-regolith-sorting",
    group = "intermediate-products",
    subgroup = "muluna-products",
    category = "crushing",
    --additional_categories = {"recycling"},
    auto_recycle = false,
    enabled = false,
    ingredients = {
        {
            type = "item",
            name = "muluna-lunar-regolith",
            amount = 1,
        }
    },
    energy_required = 1,
    results = {
        {
            type = "item",
            name = "stone",
            amount = 2,
            --probability = 0.50,
        },
        {
            type = "item",
            name = "stone-crushed",
            amount = 1,
            --probability = 0.50,
        },
        {
            type = "item",
            name = "uranium-ore",
            amount = 1,
            probability = 0.01,
        }


    },
    icons = crushing_icon(data.raw.item["muluna-lunar-regolith"].icon,data.raw.item["muluna-lunar-regolith"].icon_size)
}


local regolith_recycling = table.deepcopy(regolith_sorting)
local recycling_lib = require("__quality__.prototypes.recycling")

regolith_recycling.name = "muluna-regolith-recycling"
regolith_recycling.category = "recycling"
regolith_recycling.energy_required = regolith_sorting.energy_required / 4
regolith_recycling.results[3].probability = 0.02
regolith_recycling.icons = generate_recycling_recipe_icons_from_item(data.raw.item["muluna-lunar-regolith"])

local recipes = {anorthite_crushing,alumina_crushing,aluminum_crushing,stone_crushing,aluminum_plate,aluminum_cable,wood_crushing,tree_crushing,regolith_sorting,regolith_recycling}

for _,recipe in pairs(recipes) do
    if #recipe.results > 1 then  
          recipe.hide_from_signal_gui = false
    end 
end

data:extend(recipes)




if not data.raw["recipe"]["silicon-cell"] then

data:extend{{ --Moshine recipe
    type = "recipe",
    name = "silicon-cell",
    category = "electronics",
    energy_required = 2,
    ingredients =
    {
      {type = "item", name = "silicon", amount = 5},
      {type = "item", name = "electronic-circuit", amount = 1},
    },
    results = {{type = "item", name = "silicon-cell", amount = 1}},
    allow_productivity = true,
    enabled = false,
  }}

end


