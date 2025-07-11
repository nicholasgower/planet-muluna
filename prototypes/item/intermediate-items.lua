local rro = require("lib.remove-replace-object")
local item_sounds = require("__base__.prototypes.item_sounds")
local item_tints = require("__base__.prototypes.item-tints")

local iron_ore=data.raw["item"]["iron-ore"]
data:extend{{
    type="item",
    name="alumina",
    icon="__muluna-graphics__/graphics/icons/scrap-metal-aluminium-1.png",
    pictures =
    {
        {size = 64, filename = "__muluna-graphics__/graphics/icons/scrap-metal-aluminium-1.png",scale = 0.5, mipmap_count = 4},
        {size = 64, filename = "__muluna-graphics__/graphics/icons/scrap-metal-aluminium-2.png",scale = 0.5, mipmap_count = 4},
        {size = 64, filename = "__muluna-graphics__/graphics/icons/scrap-metal-aluminium-3.png",scale = 0.5, mipmap_count = 4},
    },
    stack_size=iron_ore.stack_size,
    order="a[alumina]",
    subgroup="muluna-products",
    group="intermediate-products",
    weight=iron_ore.weight,
},
{
    type="item",
    name="alumina-crushed",
    icon = "__muluna-graphics__/graphics/icons/crushed-alumina.png",
    pictures =
    {
        {size = 64, filename = "__muluna-graphics__/graphics/icons/crushed-alumina.png",scale = 0.5, mipmap_count = 4},
        {size = 64, filename = "__muluna-graphics__/graphics/icons/crushed-alumina-1.png",scale = 0.5, mipmap_count = 4},
        {size = 64, filename = "__muluna-graphics__/graphics/icons/crushed-alumina-2.png",scale = 0.5, mipmap_count = 4},
    },
    -- icons={
    --     {
    --         icon="__muluna-graphics__/graphics/icons/scrap-metal-aluminium-1.png",
    --         scale=0.25,
    --         shift={0.25,0}
    --     },
    --     {
    --         icon="__muluna-graphics__/graphics/icons/scrap-metal-aluminium-3.png",
    --         scale=0.25,
    --         shift={0,0.25}
    --     },
    --     {
    --         icon="__muluna-graphics__/graphics/icons/scrap-metal-aluminium-2.png",
    --         scale=0.25,
    --         shift={0,-0.25}
    --     },
    --     {
    --         icon="__muluna-graphics__/graphics/icons/scrap-metal-aluminium-2.png",
    --         scale=0.25,
    --         shift={-0.25,0}
    --     },
    -- },
    stack_size=iron_ore.stack_size*2,
    order="b[alumina-crushed]",
    subgroup="muluna-products",
    --recipe_group="intermediate-products",
    weight=iron_ore.weight*2/3,
    default_import_location = "muluna",
},
{
    type="item", --Intended to be compatible with Bio-industries, whenever it gets updated to 2.0
    name="stone-crushed",
    icon="__muluna-graphics__/graphics/icons/crushed-stone.png", --icon from bio-industries crushed stone
    icon_size=64,
    -- icons ={
    --     {
            
    --     }
        
    -- },
    
    stack_size=data.raw.item["stone"].stack_size*2,
    order="c[stone-crushed]",
    subgroup="muluna-products",
    group=data.raw.item["stone"].group,
    weight=data.raw.item["stone"].weight/2,
},
{
    type="item",
    name="aluminum-plate",
    icon="__muluna-graphics__/graphics/icons/metal-plate-aluminium.png",
    icon_size=64,
    -- icons ={
    --     {
            
    --     }
        
    -- },
    
    stack_size=data.raw.item["iron-plate"].stack_size,
    order=data.raw.item["iron-plate"].order,
    subgroup="muluna-products",
    group=data.raw.item["iron-plate"].group,
    weight=data.raw.item["iron-plate"].weight,
    default_import_location = "muluna",
},
{
    type="item",
    name="muluna-sapling",
    icon="__base__/graphics/icons/tree-01.png",
    icon_size=64,
    -- icons ={
    --     {
            
    --     }
        
    -- },
    
    stack_size=1,
    order=data.raw.item["tree-seed"].order .. "a",
    subgroup=data.raw.item["tree-seed"].subgroup,
    group=data.raw.item["tree-seed"].group,
    weight=iron_ore.weight*50,
    default_import_location = "nauvis",
    --plant_result = "tree-01",
    place_result = "muluna-placed-tree",
},
-- {
--     type="item",
--     name="aluminum-cable",
--     icon="__muluna-graphics__/graphics/icons/aluminum-cable.png",
--     icon_size=64,
--     -- icons ={
--     --     {
            
--     --     }
        
--     -- },
    
--     stack_size=data.raw.item["copper-cable"].stack_size,
--     order=data.raw.item["copper-cable"].order,
--     subgroup="muluna-products",
--     group=data.raw.item["copper-cable"].group,
--     weight=data.raw.item["copper-cable"].weight,
--     default_import_location = "muluna",
-- },
{
    type="item",
    name="cellulose",
    icons={
        {
            icon="__muluna-graphics__/graphics/icons/scrap-metal-aluminium-1.png",
            --scale=0.25,
            --shift={0.25,0}
            tint = {1,0.8,0.4}
        },
    },
    pictures =
    {
        {size = 64, filename = "__muluna-graphics__/graphics/icons/scrap-metal-aluminium-1.png",scale = 0.5, mipmap_count = 4,tint = {1,0.8,0.4}},
        {size = 64, filename = "__muluna-graphics__/graphics/icons/scrap-metal-aluminium-2.png",scale = 0.5, mipmap_count = 4,tint = {1,0.8,0.4}},
        {size = 64, filename = "__muluna-graphics__/graphics/icons/scrap-metal-aluminium-3.png",scale = 0.5, mipmap_count = 4,tint = {1,0.8,0.4}},
    },
    stack_size=iron_ore.stack_size*4,
    order="b[cellulose]",
    subgroup="muluna-forestry",
    --recipe_group="intermediate-products",
    weight=iron_ore.weight*1/2,
    fuel_value = "1MJ",
    fuel_category=data.raw["item"]["wood"].fuel_category,
},
{ --Copied from Wooden industries
    type = "item",
    name = "woodchips",
    icon = "__muluna-graphics__/graphics/icons/woodchips.png",
    icon_size = 64,
    pictures = {
      {size=64, filename="__muluna-graphics__/graphics/icons/woodchips.png", scale=0.5, mipmap_count=4},
      {size=64, filename="__muluna-graphics__/graphics/icons/woodchips-1.png", scale=0.5, mipmap_count=4},
      {size=64, filename="__muluna-graphics__/graphics/icons/woodchips-2.png", scale=0.5, mipmap_count=4},
      {size=64, filename="__muluna-graphics__/graphics/icons/woodchips-3.png", scale=0.5, mipmap_count=4}
    },
    -- icons={
    --     {
    --         icon="__muluna-graphics__/graphics/icons/scrap-metal-aluminium-1.png",
    --         --scale=0.25,
    --         --shift={0.25,0}
    --         tint = {1,0.8,0.4}
    --     },
    -- },
    fuel_category = "chemical",
    fuel_value = "1MJ",
    subgroup = "muluna-forestry",
    order = "a[wood]-c[chips]",
    inventory_move_sound = item_sounds.wood_inventory_move,
    pick_sound = item_sounds.wood_inventory_pickup,
    drop_sound = item_sounds.wood_inventory_move,
    stack_size = 200,
    weight = 1*kg
  },
-- {
--     type="item",
--     name="wood-crushed",
--     icons={
--         {
--             icon="__muluna-graphics__/graphics/icons/scrap-metal-aluminium-1.png",
--             --scale=0.25,
--             --shift={0.25,0}
--             tint = {1,0.8,0.4}
--         },
--     },
--     stack_size=iron_ore.stack_size*4,
--     order="b[cellulose]",
--     subgroup="muluna-products",
--     --recipe_group="intermediate-products",
--     weight=iron_ore.weight*1/2,
--     fuel_value = "1MJ",
--     fuel_category=data.raw["item"]["wood"].fuel_category,
-- },
}

local placed_tree = table.deepcopy(data.raw["plant"]["tree-plant"])
placed_tree.name = "muluna-placed-tree"
placed_tree.growth_ticks = 1
data:extend{placed_tree}
    


if not data.raw["item"]["silicon"] then --Copied from Moshine
    data:extend{{
        type = "item",
        name = "silicon",
        icon = "__muluna-graphics__/graphics/icons/silicon.png",
        subgroup = "muluna-products",
        order = "bbb",
        inventory_move_sound = item_sounds.metal_small_inventory_move,
        pick_sound = item_sounds.metal_small_inventory_pickup,
        drop_sound = item_sounds.metal_small_inventory_move,
        default_import_location = "muluna",
        random_tint_color = item_tints.iron_rust,
        stack_size = 50,
        weight = 20*kg,
      }}
end
if not data.raw["item"]["silicon-cell"] then
      data:extend{{
        type = "item",
        name = "silicon-cell",
        icon = "__muluna-graphics__/graphics/icons/silicon-cell.png",
        subgroup = "muluna-products",
        order = "eee",
        inventory_move_sound = item_sounds.metal_small_inventory_move,
        pick_sound = item_sounds.metal_small_inventory_pickup,
        drop_sound = item_sounds.metal_small_inventory_move,
        default_import_location = "muluna",
        stack_size = 50,
        weight = 20*kg,
      }}
end


-- rro.soft_insert(data.raw["tree"]["tree-01"].flags,"placeable-player")

-- data.raw["tree"]["tree-01"].autoplace =
-- {
--   probability_expression = 0,
--   -- required to show agricultural tower plots
--   tile_restriction =
--   {
--     "grass-1", "grass-2", "grass-3", "grass-4",
--     "dry-dirt", "dirt-1", "dirt-2", "dirt-3", "dirt-4", "dirt-5", "dirt-6", "dirt-7",
--     "red-desert-0", "red-desert-1", "red-desert-2", "red-desert-3"
--   }
-- }


-- if not data.raw["item"]["sand"] then
--     data:extend{ --Copied from Crushing Industry
--         type = "item",
--         name = "sand",
--         icon = "__crushing-industry__/graphics/icons/sand.png",
--         pictures = {
--           {size=64, filename="__muluna-graphics__/graphics/icons/sand.png", scale=0.5, mipmap_count=4},
--           {size=64, filename="__muluna-graphics__/graphics/icons/sand-1.png", scale=0.5, mipmap_count=4},
--           {size=64, filename="__muluna-graphics__/graphics/icons/sand-2.png", scale=0.5, mipmap_count=4},
--         },
--         subgroup = "raw-resource",
--         order = "d[stone]-c[crushed]",
--         inventory_move_sound = item_sounds.resource_inventory_move,
--         pick_sound = item_sounds.resource_inventory_pickup,
--         drop_sound = item_sounds.resource_inventory_move,
--         stack_size = 200,
--         weight = 1 * kg
--       }
    
-- end