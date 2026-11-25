-- Registered so the FUnit re-add test can replay this migration with an empty
-- storage table, the way Factorio does when a mod is added back to a save.
local function migrate()
for _,burner_roboport_data in pairs(storage.burner_roboports or {}) do
    local roboport = burner_roboport_data.roboport
    roboport.update_connections()
end

end

Muluna.migrations = Muluna.migrations or {}
Muluna.migrations["fix-burner-roboport-connections"] = migrate
if game then migrate() end
