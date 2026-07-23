local rro =Muluna.rro

-- Add a new fluidbox port to assembling-machine-3 for the 'data' category
local am3 = data.raw["assembling-machine"]["assembling-machine-3"]

local max_fluid_boxes=30 --Assuming that no modded machines have this many fluidboxes.
local dummy_fluidboxes = max_fluid_boxes-2

for _,recipe in pairs(data.raw["recipe"]) do
    if rro.contains(recipe.categories,"crafting-with-fluid")  then
        for _,input in pairs({recipe.ingredients,recipe.results}) do
            local i = 1
            if rro.count(input,function(entry) return entry.type == "fluid" end) <= 1 then
                for _,recipe in pairs(input) do
                    if recipe.type == "fluid" and recipe.fluidbox_index == nil then
                        recipe.fluidbox_index = i
                        recipe.optional_fluidbox_indexes = rro.range(2,25)
                        i = i + 1
                    end
                end
            end
        end
    end

end

local function rotate_position(position)
    local x = position.x or position[1]
    local y = position.y or position[2]

    return {-y,x}
end



-- -- Add a new fluidbox port to assembling-machine-3 for the 'data' category
for _,am3 in pairs(data.raw["assembling-machine"]) do
    if rro.contains({"assembling-machine-3","mini-assembler-3","micro-assembler-3","aop-advanced-assembling-machine"},am3.name) or rro.contains_all(am3.crafting_categories,{"crafting", "advanced-crafting", "crafting-with-fluid"}) and am3.energy_source.type == "electric" and am3.crafting_speed >= 1.25 and am3.module_slots >= 4 then
        local linked_connection_id=100
        if am3.fluid_boxes then
            local input=table.deepcopy(am3.fluid_boxes[1])
            local output = table.deepcopy(am3.fluid_boxes[2])
            for _,box in pairs({input,output}) do
                for i = 1,dummy_fluidboxes do
                    linked_connection_id = linked_connection_id + 1
                    table.insert(am3.fluid_boxes,Muluna.data_fluids.dummy_fluidbox(box.production_type,box.pipe_connections[1].flow_direction,linked_connection_id))
                end
                box.pipe_picture = nil
                box.pipe_covers = nil
                for _,connection in pairs(box.pipe_connections) do
                    connection.position = rotate_position(connection.position)
                    connection.connection_category="data"
                    if connection.direction == defines.direction.north then
                        connection.direction = defines.direction.east
                    elseif connection.direction == defines.direction.south then
                        connection.direction = defines.direction.west
                    elseif connection.direction == defines.direction.east then
                        connection.direction = defines.direction.north
                    elseif connection.direction == defines.direction.west then
                        connection.direction = defines.direction.south
                    end
                end
                table.insert(am3.fluid_boxes,box)
            end
            am3.use_mirroring=true
            

        --     table.insert(am3.fluid_boxes, 

        --     {
        --         production_type = "input",
        --         --pipe_picture = assembler3pipepictures(),
        --         --pipe_covers = pipecoverspictures(),
        --         volume = 1000,
        --         pipe_connections = {{ flow_direction="input", direction = defines.direction.east, position = {(am3.fluid_boxes[1].pipe_connections.position or {x=0,y=1}).y, 0} , connection_category = "data"}},
        --         secondary_draw_orders = { north = -1 },
        --         connection_category = "data",
        --         filter = "muluna-astronomical-data",
        --     }
        -- )   
        --     table.insert(am3.fluid_boxes, 
        --         {
        --         production_type = "output",
        --         --pipe_picture = assembler3pipepictures(),
        --         --pipe_covers = pipecoverspictures(),
        --         volume = 1000,
        --         pipe_connections = {{ flow_direction="output", direction = defines.direction.west, position = {-(am3.fluid_boxes[2].pipe_connections.position or {x=0,y=1}).y, 0} , connection_category = "data"}},
        --         secondary_draw_orders = { north = -1 },
        --         connection_category = "data",
        --         filter = "muluna-astronomical-data",
        --     }
        --     )
            table.insert(am3.crafting_categories, "crafting-with-fluid-and-data")
            data:extend {

                {
                    type = "recipe-category",
                    name = "crafting-with-fluid-and-data",
                    order = "a[fluid]-b[data]",
                    categories = {"intermediate-products"},
                }
            }

        end
    end
        


end
local crusher_2 = data.raw["assembling-machine"]["crusher-2"]

crusher_2.fluid_boxes = {

}
local crusher_linked_connection_id=100
while #crusher_2.fluid_boxes <= dummy_fluidboxes do
        crusher_linked_connection_id = crusher_linked_connection_id + 1
        table.insert(crusher_2.fluid_boxes,Muluna.data_fluids.dummy_fluidbox("input","input",crusher_linked_connection_id))
    end

table.insert(crusher_2.fluid_boxes, {production_type = "input",
                volume = 50,
                base_area = 1,
                height = 2,
                base_level = -1,
                pipe_connections = {
                    {connection_category="data", flow_direction = "input", direction = defines.direction.east, position = {0.5, -1}},
                },
                
                })