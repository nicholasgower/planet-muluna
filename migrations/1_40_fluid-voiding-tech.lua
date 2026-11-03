-- Registered so the FUnit re-add test can replay this migration with an empty
-- storage table, the way Factorio does when a mod is added back to a save.
local function migrate()
for _,force in pairs(game.forces) do 
    if force.technologies["asteroid-collector"].researched == true then
        --Gas venting does not exist when Krastorio 2 is loaded.
        if force.technologies["muluna-gas-venting"] then
            force.technologies["muluna-gas-venting"].researched = true
        end
    end
end

end

Muluna.migrations = Muluna.migrations or {}
Muluna.migrations["1_40_fluid-voiding-tech"] = migrate
if game then migrate() end
