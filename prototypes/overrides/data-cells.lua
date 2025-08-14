local rro = Muluna.rro

for _, category in pairs({"item", "tool"}) do
    if data.raw[category] then
        for name, prototype in pairs(data.raw[category]) do
            if prototype.data_capacity ~= nil then
                local data_cell = table.deepcopy(prototype)
                data_cell.name = name .. "-astronomical-data"
                data_cell.data_capacity = nil

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
                    category = "crafting-with-fluid-and-data",
                    enabled = false,
                    ingredients = { 
                        {type = "item",name = prototype.name, amount = 1},
                        {type = "fluid", name = "muluna-astronomical-data", amount = prototype.data_capacity, fluidbox_index = 2},
                    },
                    results = {{type = "item" , name = data_cell.name, amount = 1, fluidbox_index = 2}},
                    main_product = data_cell.name,
                    energy_required = 5
                }

                local recipe_empty = {
                    type = "recipe",
                    name = recipe.name .. "-empty",
                    category = "crafting-with-fluid-and-data",
                    enabled = false,
                    ingredients = recipe.results,
                    results = recipe.ingredients,
                    energy_required = 5,
                    icons = Muluna.icons.dual_icon("muluna-astronomical-data",prototype.name)
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

-- Add a new fluidbox port to assembling-machine-3 for the 'data' category
local am3 = data.raw["assembling-machine"]["assembling-machine-3"]
if am3 and am3.fluid_boxes then
    table.insert(am3.fluid_boxes, 

    {
        production_type = "input",
        --pipe_picture = assembler3pipepictures(),
        --pipe_covers = pipecoverspictures(),
        volume = 1000,
        pipe_connections = {{ flow_direction="input", direction = defines.direction.east, position = {1, 0} , connection_category = "data"}},
        secondary_draw_orders = { north = -1 },
        connection_category = "data",
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
      }
    )
    table.insert(am3.crafting_categories, "crafting-with-fluid-and-data")
    data:extend {

        {
            type = "recipe-category",
            name = "crafting-with-fluid-and-data",
            order = "a[fluid]-b[data]"
        }
    }

end


