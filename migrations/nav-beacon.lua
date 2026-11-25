-- Registered so the FUnit re-add test can replay this migration with an empty
-- storage table, the way Factorio does when a mod is added back to a save.
local function migrate()
storage.nav_beacons = {}

end

Muluna.migrations = Muluna.migrations or {}
Muluna.migrations["nav-beacon"] = migrate
if game then migrate() end
