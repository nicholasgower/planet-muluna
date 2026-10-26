for _,force in pairs(game.forces) do 
    if force.technologies["asteroid-collector"].researched == true then
        --Gas venting does not exist when Krastorio 2 is loaded.
        if force.technologies["muluna-gas-venting"] then
            force.technologies["muluna-gas-venting"].researched = true
        end
    end
end