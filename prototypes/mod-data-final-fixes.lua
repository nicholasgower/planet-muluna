for _,planet in pairs(data.raw["planet"]) do
    if data.raw["mod-data"]["Planetslib-rocket-part-recipe"][planet.name] == nil then
        data.raw["mod-data"]["Planetslib-rocket-part-recipe"][planet.name] = "rocket-part"
    end


end