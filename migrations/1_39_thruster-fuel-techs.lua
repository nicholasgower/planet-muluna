-- Registered so the FUnit re-add test can replay this migration with an empty
-- storage table, the way Factorio does when a mod is added back to a save.
local function migrate()
for _,force in pairs(game.forces) do 
    if force.technologies["space-platform-thruster"].researched == true then
        force.technologies["thruster-oxidizer"].researched = true
        force.technologies["thruster-fuel"].researched = true
        
    end
end

end

Muluna.migrations = Muluna.migrations or {}
Muluna.migrations["1_39_thruster-fuel-techs"] = migrate
if game then migrate() end
