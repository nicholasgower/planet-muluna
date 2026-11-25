-- Registered so the FUnit re-add test can replay this migration with an empty
-- storage table, the way Factorio does when a mod is added back to a save.
local function migrate()
local function remove_resource(resource) 
    local map_gen_settings = game.planets.muluna.surface.map_gen_settings
    map_gen_settings.autoplace_controls[resource] = nil
    map_gen_settings.autoplace_settings.entity.settings[resource] = nil
    game.planets.muluna.surface.map_gen_settings = map_gen_settings
    game.planets.muluna.surface.regenerate_entity(resource)
end
if game.planets.muluna.surface then
    -- Regenerating on every re-add duplicates or removes resources again.
    if not Muluna.should_run_migrations() then return end
    remove_resource("uranium-ore")
    remove_resource("stone")
    --regenerate_resource("helium")
end




-- for surface in pairs(game.surfaces) do
--     if surface.name == "muluna" then
        
--     end
-- end

end

Muluna.migrations = Muluna.migrations or {}
Muluna.migrations["muluna-2-resources_"] = migrate
if game then migrate() end
