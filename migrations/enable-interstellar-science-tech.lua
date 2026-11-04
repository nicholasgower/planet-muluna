-- Registered so the FUnit re-add test can replay this migration with an empty
-- storage table, the way Factorio does when a mod is added back to a save.
local function migrate()
for _,force in pairs(game.forces) do
    if force.technologies["interstellar-science-pack"] and force.technologies["interstellar-science-pack"].enabled == false then
        force.technologies["interstellar-science-pack"].enabled = true
    end
end

end

Muluna.migrations = Muluna.migrations or {}
Muluna.migrations["enable-interstellar-science-tech"] = migrate
if game then migrate() end
