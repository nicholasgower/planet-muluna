local rro = Muluna.rro
for _,robot_name in pairs(Muluna.constants.robot_names) do
    local replacement_name = "muluna-vacuum-" .. robot_name
    local recipe = table.deepcopy(data.raw["recipe"][robot_name])
    local robot = table.deepcopy(data.raw[robot_name][robot_name])
    local item = table.deepcopy(data.raw["item"][robot_name])
    local prototypes = {recipe,robot,item}
    for _,prototype in pairs(prototypes) do
        rro.deep_replace(prototype,robot_name,replacement_name)
        if prototype.type == "construction-robot" or prototype.type == "logistic-robot" then
            prototype.surface_conditions = {
                {
                    property = "gravity",
                    max = 2,
                    min = 2,
                }
            }
        end
        if prototype.type == "recipe" then
            rro.replace(prototype.ingredients,{type = "item" , name = "flying-robot-frame", amount = "_any"},
                                                {type = "item" , name = "muluna-vacuum-flying-robot-frame", amount = function(other) return other end})
            
        end
    end

    data:extend(prototypes)
    
end

data:extend {
    rro.merge(data.raw["item"]["flying-robot-frame"]{
        type = "item",
        name = "muluna-vacuum-flying-robot-frame",
        
    }),
    rro.merge(data.raw["recipe"]["flying-robot-frame"]{
        type = "recipe",
        name = "muluna-vacuum-flying-robot-frame",
        ingredients = {
            {type = "item", name = "steel-plate", count = 1},
            {type = "item", name = "iron-pipe", count = 2},
            {type = "item", name = "electronic-circuit", count = 3},
            {type = "item", name = "engine-unit", count = 1}
        
        },
        results = {{type = "item", name = "muluna-vacuum-flying-robot-frame", count = 1}}
    }),
}