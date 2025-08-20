for _,force in pairs(game.forces) do
    if force.technologies["fluid-handling"] and force.technologies["fluid-handling"].researched == true then
        force.technologies["fluid-barreling"].researched = true
    end
end