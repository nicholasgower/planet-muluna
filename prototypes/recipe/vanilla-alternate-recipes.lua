local rro = require("lib.remove-replace-object")
--Muluna-specific alternative recipes for vanilla items

local dual_icon = require("lib.dual-item-icon").dual_icon
local dual_icon_reversed = require("lib.dual-item-icon").dual_icon_reversed



local motor_carbon = table.deepcopy(data.raw["recipe"]["electric-engine-unit"])

motor_carbon.name="electric-engine-unit-from-carbon"
motor_carbon.auto_recycle=false
local lubricant_amount = 15
local carbon_amount = 1
if mods["aai-industry"] then
    lubricant_amount = 40
    carbon_amount = 3
end

rro.replace(motor_carbon.ingredients,
{type = "fluid", name = "lubricant", amount = lubricant_amount},
{type = "item", name = "carbon", amount = carbon_amount}
)
motor_carbon.icons=dual_icon("electric-engine-unit","carbon")
-- motor_carbon.icons= {
--     {
--         icon=data.raw["item"]["electric-engine-unit"].icon,
--         icon_size=data.raw["item"]["electric-engine-unit"].icon_size,
--         scale=0.35
--     },
--     {
--         icon=data.raw["item"]["carbon"].icon,
--         icon_size=data.raw["item"]["carbon"].icon_size,
--         scale=0.30,
--         shift = {10,-10},
--     },
-- }

-- local rocket_fuel_thruster_fuel = table.deepcopy(data.raw["recipe"]["rocket_fuel"])

-- rocket_fuel_thruster_fuel.name="rocket-fuel-from-thruster-fuel"


local aluminum_rocket_fuel=table.deepcopy(data.raw["recipe"]["rocket-fuel"])
aluminum_rocket_fuel.name="rocket-fuel-aluminum"
aluminum_rocket_fuel.ingredients = {{type = "item",name = "alumina-crushed",amount = 20},{type = "item",name = "ice",amount = 4},{type = "fluid",name = "water",amount = 200}}

aluminum_rocket_fuel.auto_recycle=false
aluminum_rocket_fuel.icons= dual_icon_reversed("rocket-fuel","alumina-crushed")
aluminum_rocket_fuel.allow_decomposition = false

local carbon_nanotubes_lds = table.deepcopy(data.raw["recipe"]["low-density-structure"])

carbon_nanotubes_lds.name = "low-density-structure-from-aluminum"

--carbon_nanotubes_lds.ingredients = {{type = "item", name = "iron-plate", amount = 5}, {type = "item", name = "plastic-bar", amount = 5}, {type = "item", name = "aluminum-plate", amount = 20}}
--rro.replace(carbon_nanotubes_lds.ingredients, {type = "item", name = "copper-plate", amount = 20},{type = "item", name = "aluminum-plate", amount = 20})
rro.replace_name(carbon_nanotubes_lds.ingredients,"copper-plate","aluminum-plate")
carbon_nanotubes_lds.energy_required=30
carbon_nanotubes_lds.icons = dual_icon("low-density-structure","aluminum-plate")
carbon_nanotubes_lds.allow_decomposition = false
carbon_nanotubes_lds.allow_as_intermediate = false
carbon_nanotubes_lds.surface_conditions = {{
    property = "oxygen",
    min = 0,
    max = 0,
}}
carbon_nanotubes_lds.auto_recycle=false
local landfill_crushed_stone=table.deepcopy(data.raw["recipe"]["landfill"])
--landfill_crushed_stone.category="crafting-with-fluid"
local stone_cost = landfill_crushed_stone.ingredients[1].amount
landfill_crushed_stone.ingredients = {{type = "item",name = "stone-crushed",amount = math.ceil(40/50*stone_cost)},{type = "item",name = "concrete",amount = math.ceil(5/50*stone_cost)}}
landfill_crushed_stone.name="landfill-stone-crushed"

landfill_crushed_stone.icons=dual_icon("landfill","stone-crushed")
landfill_crushed_stone.auto_recycle=false
local bricks_crushed_stone=table.deepcopy(data.raw["recipe"]["stone-brick"])

bricks_crushed_stone.ingredients = {{type = "item",name = "stone-crushed",amount = 2}}
bricks_crushed_stone.name="stone-bricks-stone-crushed"
bricks_crushed_stone.enabled=false
bricks_crushed_stone.icons = dual_icon("stone-brick","stone-crushed")
bricks_crushed_stone.auto_recycle=false


-- local aluminum_green_circuit = table.deepcopy(data.raw["recipe"]["electronic-circuit"])
-- local aluminum_red_circuit = table.deepcopy(data.raw["recipe"]["advanced-circuit"])

-- aluminum_green_circuit.auto_recycle=false
-- aluminum_red_circuit.auto_recycle=false
-- aluminum_red_circuit.allow_decomposition = false
-- aluminum_green_circuit.allow_decomposition = false
-- aluminum_red_circuit.allow_as_intermediate = false
-- aluminum_green_circuit.allow_as_intermediate = false
-- --rro.replace(aluminum_green_circuit.ingredients,{type = "item",name = "copper-cable",amount = 3},{type = "item",name = "aluminum-cable",amount = 3})
-- --rro.replace(aluminum_red_circuit.ingredients,{type = "item",name = "copper-cable",amount = 4},{type = "item",name = "aluminum-cable",amount = 4})
-- --rro.replace(aluminum_red_circuit.ingredients,{type = "item",name = "copper-cable",amount = 3},{type = "item",name = "aluminum-cable",amount = 3})
-- rro.replace_name(aluminum_green_circuit.ingredients,"copper-cable","aluminum-cable")
-- rro.replace_name(aluminum_red_circuit.ingredients,"copper-cable","aluminum-cable")
-- aluminum_green_circuit.name="electronic-circuit-aluminum"
-- aluminum_red_circuit.name="advanced-circuit-aluminum"

-- aluminum_green_circuit.icons = dual_icon("electronic-circuit","aluminum-cable")
-- aluminum_red_circuit.icons = dual_icon("advanced-circuit","aluminum-cable")

local bio_plastic = table.deepcopy(data.raw["recipe"]["plastic-bar"])
bio_plastic.allow_decomposition = false
bio_plastic.name = "plastic-from-wood"
bio_plastic.subgroup = "muluna-forestry"
bio_plastic.icons = dual_icon("plastic-bar","cellulose")
rro.replace(bio_plastic.ingredients,{type = "item",name = "coal",amount = 1},{type = "item",name = "cellulose",amount = 4})
rro.replace(bio_plastic.ingredients,{type = "item",name = "carbon-black",amount = 1},{type = "item",name = "cellulose",amount = 4})
rro.replace(bio_plastic.ingredients,{type = "item",name = "crushed-coal",amount = 2},{type = "item",name = "cellulose",amount = 3})
rro.replace(bio_plastic.ingredients,{type = "item",name = "crushed-coal",amount = 3},{type = "item",name = "cellulose",amount = 4})
rro.replace(bio_plastic.ingredients,{type = "item",name = "resin",amount = 1},{type = "item",name = "cellulose",amount = 4}) --Wooden industries
rro.replace(bio_plastic.ingredients,{type = "item",name = "resin",amount = 2},{type = "item",name = "cellulose",amount = 4})
rro.replace(bio_plastic.ingredients,{type = "fluid",name = "petroleum-gas",amount = 15},{type = "fluid",name = "petroleum-gas",amount = 20})

--fixed bio_plastic
rro.remove(bio_plastic.ingredients,{type = "fluid",name = "organotins",amount = 5})
if data.raw["technology"]["plastic-bar-productivity"] then
    rro.soft_insert(data.raw["technology"]["plastic-bar-productivity"].effects,{type="change-recipe-productivity",recipe="plastic-from-wood",change=0.1})
end



local solar_panel = util.merge{data.raw["recipe"]["solar-panel"],
    {
        name = "muluna-silicon-solar-panel",
        icons = dual_icon("solar-panel","silicon-cell"),
        subgroup = data.raw["item"]["solar-panel"].subgroup,
        order = data.raw["item"]["solar-panel"].order .. "a"
    }
}
rro.replace_name(solar_panel.ingredients,"copper-plate","silicon-cell")
rro.replace_name(solar_panel.ingredients,"steel-plate","aluminum-plate")

--local recipes = {motor_carbon, aluminum_rocket_fuel, carbon_nanotubes_lds, landfill_crushed_stone, bricks_crushed_stone,aluminum_green_circuit,aluminum_red_circuit, bio_plastic}
local recipes = {motor_carbon,aluminum_rocket_fuel, carbon_nanotubes_lds, landfill_crushed_stone, bricks_crushed_stone,solar_panel}
--, ,aluminum_green_circuit,aluminum_red_circuit,
for _,recipe in pairs(recipes) do
    if recipe.subgroup ~= data.raw["item"]["solar-panel"].subgroup then
        recipe.subgroup = "muluna-products"
    end
    recipe.hide_from_signal_gui = false
    recipe.auto_recycle = false
end

table.insert(recipes,bio_plastic)

data:extend(recipes)


--Productivity technologies 
if data.raw["technology"]["low-density-structure-productivity"] then
    rro.soft_insert(data.raw["technology"]["low-density-structure-productivity"].effects,
    {
        type = "change-recipe-productivity",
        recipe = "low-density-structure-from-aluminum",
        change = 0.1
    }
) 
end



if mods["Krastorio2-spaced-out"] then
    local recipes = {
        "kr-automation-core",
        --"kr-electrolysis-plant"
    }
    for i,recipe_name in ipairs(recipes) do
        local recipe = data.raw["recipe"][recipe_name]
        local new_recipe = table.deepcopy(recipe)
        new_recipe.name = recipe.name .. "-from-aluminum"
        new_recipe.icons = dual_icon(recipe.name,"aluminum-plate")
        new_recipe.localised_name={"recipe-name.x-from-aluminum",{"item-name."..recipe.name}}
        for _,ingredient in pairs(new_recipe.ingredients) do
            if ingredient.name == "copper-plate" then
                ingredient.name = "aluminum-plate"
            end
        end
        rro.soft_insert(data.raw["technology"]["muluna-aluminum-processing"].effects, 
        {
            type = "unlock-recipe",
            recipe = new_recipe.name
        }
    )
        data:extend{new_recipe}
    end
end
    






