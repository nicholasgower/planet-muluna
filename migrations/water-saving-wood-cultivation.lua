-- Registered so the FUnit re-add test can replay this migration with an empty
-- storage table, the way Factorio does when a mod is added back to a save.
local function migrate()
for _,force in pairs(game.forces) do
    if force.technologies["muluna-wood-cultivation"] and force.technologies["muluna-wood-cultivation"].researched == true then
        force.technologies["muluna-water-saving-wood-cultivation"].researched = true
    end
end

end

Muluna.migrations = Muluna.migrations or {}
Muluna.migrations["water-saving-wood-cultivation"] = migrate
if game then migrate() end
