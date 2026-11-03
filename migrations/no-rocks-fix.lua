-- Registered so the FUnit re-add test can replay this migration with an empty
-- storage table, the way Factorio does when a mod is added back to a save.
local function migrate()
for _,force in pairs(game.forces) do
    if force.technologies["muluna-greenhouses"].researched == true then
        force.technologies["wood-gas-processing"].researched = true
    end
end

end

Muluna.migrations = Muluna.migrations or {}
Muluna.migrations["no-rocks-fix"] = migrate
if game then migrate() end
