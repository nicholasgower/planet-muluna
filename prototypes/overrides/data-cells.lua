local rro = Muluna.rro

for _, category in pairs({"item", "tool"}) do
    if data.raw[category] then
        for name, prototype in pairs(data.raw[category]) do
            if prototype.data_capacity ~= nil then
                local data_cell = table.deepcopy(prototype)
                data_cell.name = name .. "-astronomical-data"
                data_cell.data_capacity = nil
                data_cell.localised_name = {"item-name.muluna-databank-filled",{"item-name."..name}}
                data_cell.icons = {
                    {
                        icon = prototype.icon,
                        icon_size = prototype.icon_size,
                        scale = 0.5,
                    },
                    {
                        icon = data.raw["fluid"]["muluna-astronomical-data"].icon,
                        icon_size = data.raw["fluid"]["muluna-astronomical-data"].icon_size,
                        scale = 0.4,
                        --shift = {0,-4},
                    }
                }
                data_cell.icon = nil

                local recipe = {
                    type = "recipe",
                    name = data_cell.name,
                    localised_name = data_cell.localised_name,
                    category = "crafting-with-fluid-and-data",
                    enabled = false,
                    ingredients = { 
                        {type = "item",name = prototype.name, amount = 1,ignored_by_stats = 1},
                        {type = "fluid", name = "muluna-astronomical-data", amount = prototype.data_capacity, fluidbox_index = 2,ignored_by_stats = prototype.data_capacity},
                    },
                    results = {{type = "item" , name = data_cell.name, amount = 1, fluidbox_index = 2,ignored_by_stats = 1}},
                    main_product = data_cell.name,
                    energy_required = 5,
                    allow_quality = false,
                    
                }

                local recipe_empty = {
                    type = "recipe",
                    name = recipe.name .. "-empty",
                    localised_name = {"recipe-name.muluna-load-data-from-X",{"item-name."..name}},
                    category = "crafting-with-fluid-and-data",
                    subgroup = "muluna-telescope",
                    order = data_cell.order .. "a",
                    enabled = false,
                    ingredients = recipe.results,
                    results = recipe.ingredients,
                    energy_required = 5,
                    icons = Muluna.icons.dual_icon("muluna-astronomical-data",prototype.name),
                    auto_recycle = false,
                    allow_quality = false,
                }

                for _,recipe in pairs({recipe,recipe_empty}) do
                    rro.soft_insert(data.raw["technology"]["muluna-telescope"].effects , 
                    
                    {
                        type = "unlock-recipe",
                        recipe = recipe.name
                    }
                    )
                end

                data:extend{data_cell,recipe,recipe_empty}


                

                
            end
        end
    end
end





-- -- Add a new fluidbox port to assembling-machine-3 for the 'data' category
for _,am3 in pairs(data.raw["assembling-machine"]) do
    if am3.name == "assembling-machine-3" or rro.contains_all(am3.crafting_categories,{"basic-crafting", "crafting", "advanced-crafting", "crafting-with-fluid"}) and am3.crafting_speed >= 1.25 and am3.module_slots >= 4 then
        if am3.fluid_boxes then
            table.insert(am3.fluid_boxes, 

            {
                production_type = "input",
                --pipe_picture = assembler3pipepictures(),
                --pipe_covers = pipecoverspictures(),
                volume = 1000,
                pipe_connections = {{ flow_direction="input", direction = defines.direction.east, position = {1, 0} , connection_category = "data"}},
                secondary_draw_orders = { north = -1 },
                connection_category = "data",
                filter = "muluna-astronomical-data",
            }
        )   
            table.insert(am3.fluid_boxes, 
                {
                production_type = "output",
                --pipe_picture = assembler3pipepictures(),
                --pipe_covers = pipecoverspictures(),
                volume = 1000,
                pipe_connections = {{ flow_direction="output", direction = defines.direction.west, position = {-1, 0} , connection_category = "data"}},
                secondary_draw_orders = { north = -1 },
                connection_category = "data",
                filter = "muluna-astronomical-data",
            }
            )
            table.insert(am3.crafting_categories, "crafting-with-fluid-and-data")
            data:extend {

                {
                    type = "recipe-category",
                    name = "crafting-with-fluid-and-data",
                    order = "a[fluid]-b[data]",
                    category = "intermediate-products",
                }
            }

        end
    end
        


end
local am3 = data.raw["assembling-machine"]["assembling-machine-3"]

