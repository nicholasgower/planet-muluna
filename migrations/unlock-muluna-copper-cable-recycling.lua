for _,force in pairs(game.forces) do
    local technology = force.technologies["recycling"]
    local recipe = force.recipes["copper-cable-recycling-muluna"]
    if technology and technology.researched and recipe then
        recipe.enabled = true
    end
end
