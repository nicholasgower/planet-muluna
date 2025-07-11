if true then
    for _,name in pairs({"steel-furnace","stone-furnace","crusher"}) do

    local original  = data.raw["furnace"][name]
    if not original  
        then original = data.raw["assembling-machine"][name] 
    --elseif settings.startup["muluna-hardcore-remove-steam-furnaces"].value == false then
    --    break 
    end
    if original.type == "assembling-machine" or settings.startup["muluna-hardcore-remove-steam-furnaces"].value == false then
        

        local steam_furnace = table.deepcopy(original)
        steam_furnace = util.merge{steam_furnace ,
            {
                name = "muluna-steam-".. name,
            }




        }

        steam_furnace.minable.result = "muluna-steam-".. name
        steam_furnace.surface_conditions = nil
        -- data:extend{
        --     type = "fuel-category",
        --     name = "steam",

        -- }

        steam_furnace.energy_source = {
            type = 'fluid',
            --fuel_categories = { fluid_name },
            maximum_temperature = 500,
            --burns_fluid = burns,
            scale_fluid_usage = true,
            effectivity = 0.35,
            fluid_box = {
                production_type = "input",
                filter = "steam",
                volume = 50,
                base_area = 1,
                height = 2,
                base_level = -1,
                pipe_connections = {
                    { flow_direction = "input-output", direction = defines.direction.east, position = {0.59, -0.5}},
                    { flow_direction = "input-output", direction = defines.direction.west, position = {-0.59, -0.5}}
                },
                pipe_picture = assembler2pipepictures(),
                pipe_covers = pipecoverspictures(),
            }
        }
        if name == "crusher" then
            steam_furnace.energy_source.fluid_box.pipe_connections = {
                { flow_direction = "input-output", direction = defines.direction.north, position = {0.59, -1}},
                { flow_direction = "input-output", direction = defines.direction.south, position = {0.59, 1}}
            }
            steam_furnace.module_slots = 0
            --steam_furnace.energy_source.fluid_box.pipe_picture = images.pipe_picture
            --steam_furnace.energy_source.fluid_box.pipe_covers = images.pipe_covers
        end

        local recipe = table.deepcopy(data.raw["recipe"][name])
        recipe.name = "muluna-steam-".. name
        recipe.ingredients = {
            {type = "item", name = name, amount = 1},
            {type = "item", name = "pipe", amount = 4},
        }
        if name == "crusher" then
            recipe.ingredients = {
                {type = "item", name = "steel-plate", amount = 10},
                {type = "item", name = "pipe", amount = 6},
                {type = "item", name = "engine-unit", amount = 10}
            }
        end
        recipe.results = {{type = "item", name = "muluna-steam-".. name, amount = 1}}
        -- if name == "stone-furnace" then recipe.enabled = true


        -- elseif name == "steel-furnace" then
        --     table.insert(data.raw["technology"]["advanced-material-processing"].effects,
        --     {
        --         type = "unlock-recipe",
        --         recipe = "muluna-steam-".. name
        --     }
        -- )
        -- elseif name == "crusher" then 
            
        -- end



        local item = table.deepcopy(data.raw["item"][name])
        local steam_icon = {
            icon = data.raw["fluid"]["steam"].icon,
            icon_size = data.raw["fluid"]["steam"].icon_size,
            scale = 0.25,
            shift = {10,-10},
            draw_background = true,
        }
        if item.icons then
            table.insert(item.icons,steam_icon)
        else
            item.icons = {
                {
                    icons = data.raw["item"][name].icons,
                    icon = data.raw["item"][name].icon,
                    icon_size = 64,
                },
                steam_icon
            }
        end
        recipe.enabled = false
        item.name = "muluna-steam-".. name
        item.place_result = "muluna-steam-".. name
        if not name == "crusher" then
            data.raw["item"][name].order = item.order .. "a"
        else 
            item.order = item.order .. "a"
        end
        

        data:extend{steam_furnace,recipe,item}

    end
    end

    -- data:extend{
    --     util.merge{),
    --     {
    --         name = "muluna-steam-".. name,
    --         ingredients = {
    --             {}
    --         }
    --     }
    --     }
    -- }
end