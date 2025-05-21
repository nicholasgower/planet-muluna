for _,force in pairs(game.forces) do 
    if force.technologies["asteroid-collector"].researched == true then
        force.technologies["muluna-gas-venting"].researched = true
        
    end
end