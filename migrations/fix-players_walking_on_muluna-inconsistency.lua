-- Registered so the FUnit re-add test can replay this migration with an empty
-- storage table, the way Factorio does when a mod is added back to a save.
local function migrate()
storage.players_walking_on_muluna = {}

end

Muluna.migrations = Muluna.migrations or {}
Muluna.migrations["fix-players_walking_on_muluna-inconsistency"] = migrate
if game then migrate() end
