

local asteroid_list={"metallic-asteroid","carbonic-asteroid","oxide-asteroid"}
local quality_chance = 0.15 --Chance of upgrading the quality of an asteroid 
local loss_chance = 0.2 -- Chance of a craft being a complete loss
local i = 0
for _,asteroid_name in pairs(asteroid_list) do
    i = i + 1
    local asteroid = asteroid_name .. "-chunk"
    local new_recipe = Muluna.rro.merge(data.raw["recipe"]["metallic-asteroid-reprocessing"],{
        name = "muluna-" .. asteroid .. "-upcycling",
        
        type = "recipe",
        categories ={"muluna-crusher-2"},
        icons =  Muluna.icons.dual_icon(asteroid,"muluna-astronomical-data"),
        ingredients = {
            {type = "item",name = asteroid,amount=1},
            {type = "fluid", name = "muluna-astronomical-data",amount=1,fluidbox_index=30}
        },
        results = {
            {type ="item",name = asteroid,amount=1,shared_probability={min = loss_chance,max = 1-quality_chance}},
            {type ="item",name = asteroid,amount=1,shared_probability={min = 1-quality_chance,max = 1},quality_change = 1},
        },
        order = data.raw["recipe"]["oxide-asteroid-reprocessing"].order .. "-" ..  tostring(i),
        allow_quality=true,
        enabled = false,
        hide_from_signal_gui = false,
    })
    data:extend{new_recipe}
    table.insert(data.raw["technology"]["muluna-asteroid-upcycling"].effects, {
        type = "unlock-recipe",
        recipe = new_recipe.name
    })
end
