for _,force in pairs(game.forces) do 
    if force.technologies["space-platform-thruster"].researched == true then
        force.technologies["thruster-oxidizer"].researched = true
        force.technologies["thruster-fuel"].researched = true
        
    end
end