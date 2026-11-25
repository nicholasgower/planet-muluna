-- Registered so the FUnit re-add test can replay this migration with an empty
-- storage table, the way Factorio does when a mod is added back to a save.
local function migrate()
if not storage.telescopes_on_surface then storage.telescopes_on_surface = {} end
for i,telescope in pairs(storage.telescopes) do
    local entity = telescope["assembling-machine"]
    if entity.valid then 
        if not storage.telescopes_on_surface[entity.surface.name] then storage.telescopes_on_surface[entity.surface.name] = {} end
        storage.telescopes_on_surface[entity.surface.name][entity.unit_number] = true
        Muluna.update_telescope_daytime(telescope)
    else
        storage.telescopes[i] = nil
    end
    
end

end

Muluna.migrations = Muluna.migrations or {}
Muluna.migrations["add_telescopes_to_storage_telescopes_on_surface"] = migrate
if game then migrate() end
