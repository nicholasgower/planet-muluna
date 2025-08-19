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