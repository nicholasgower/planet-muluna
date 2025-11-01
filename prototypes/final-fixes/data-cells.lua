local rro =Muluna.rro

-- Add a new fluidbox port to assembling-machine-3 for the 'data' category
local am3 = data.raw["assembling-machine"]["assembling-machine-3"]


for _,recipe in pairs(data.raw["recipe"]) do
    if recipe.category == "crafting-with-fluid"  then
        for _,input in pairs({recipe.ingredients,recipe.results}) do
            local i = 1
            if rro.count(input,function(entry) return entry.type == "fluid" end) == 1 then
                for _,recipe in pairs(input) do
                    if recipe.type == "fluid" and recipe.fluidbox_index == nil then
                        recipe.fluidbox_index = i
                        i = i + 1
                    end
                end
            end
        end
    end

end

-- -- Add a new fluidbox port to assembling-machine-3 for the 'data' category
for _,am3 in pairs(data.raw["assembling-machine"]) do
    if am3.name == "assembling-machine-3" or rro.contains_all(am3.crafting_categories,{"basic-crafting", "crafting", "advanced-crafting", "crafting-with-fluid"}) and am3.energy_source.type == "electric" and am3.crafting_speed >= 1.25 and am3.module_slots >= 4 then
        if am3.fluid_boxes then
            table.insert(am3.fluid_boxes, 

            {
                production_type = "input",
                --pipe_picture = assembler3pipepictures(),
                --pipe_covers = pipecoverspictures(),
                volume = 1000,
                pipe_connections = {{ flow_direction="input", direction = defines.direction.east, position = {(am3.fluid_boxes[1].pipe_connections.position or {x=0,y=1}).y, 0} , connection_category = "data"}},
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
                pipe_connections = {{ flow_direction="output", direction = defines.direction.west, position = {-(am3.fluid_boxes[2].pipe_connections.position or {x=0,y=1}).y, 0} , connection_category = "data"}},
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