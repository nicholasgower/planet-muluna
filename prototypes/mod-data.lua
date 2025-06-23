--Custom mod data for control stage
if data.raw["container"]["bottomless-chest"] then
    local rocket_part_recipe_data = {
    type = "mod-data",
    name = "Planetslib-rocket-part-recipe",
    data_type = "recipe",
    data = {
        default = "rocket-part", --Used for surfaces not specified.
        --muluna = "rocket-part-muluna",
        --maraxsis = {} --Means to skip, let script from non-Planetslib mod take over.
    }
    }
    data:extend{rocket_part_recipe_data}

    data.raw["mod-data"]["Planetslib-rocket-part-recipe"]["muluna"] = "rocket-part-muluna"
end
