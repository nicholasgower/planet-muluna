-- Registered so the FUnit re-add test can replay this migration with an empty
-- storage table, the way Factorio does when a mod is added back to a save.
local function migrate()
local function regenerate_resource(resource) 
    local map_gen_settings = game.planets.muluna.surface.map_gen_settings
    map_gen_settings.autoplace_controls[resource] = {}
    map_gen_settings.autoplace_settings.entity.settings[resource] = {}
    game.planets.muluna.surface.map_gen_settings = map_gen_settings
    game.planets.muluna.surface.regenerate_entity(resource)
end
if game.planets.muluna.surface then
    -- Regenerating an already-migrated resource duplicates it on every re-add.
    if not Muluna.should_run_migrations() then return end
    regenerate_resource("anorthite-chunk")
    --regenerate_resource("helium")
end


--     --map_gen_settings.autoplace_settings.entity.settings["anorthite-chunk"] == nil
--     --if map_gen_settings.autoplace_settings.entity.settings["anorthite-chunk"] == nil then
--       map_gen_settings.autoplace_controls["anorthite-chunk"] = {}
--       map_gen_settings.autoplace_settings.entity.settings["anorthite-chunk"] = {}
--       game.planets.muluna.surface.map_gen_settings = map_gen_settings
--       game.planets.muluna.surface.regenerate_entity("anorthite-chunk")
--     --end
-- local map_gen_settings = game.planets.muluna.surface.map_gen_settings
--     --if map_gen_settings.autoplace_settings.entity.settings["helium"] == nil then
--         map_gen_settings.autoplace_controls["helium"] = {}
--         map_gen_settings.autoplace_settings.entity.settings["helium"] = {}
--         game.planets.muluna.surface.map_gen_settings = map_gen_settings
--         game.planets.muluna.surface.regenerate_entity("helium")
--       --end

end

Muluna.migrations = Muluna.migrations or {}
Muluna.migrations["new_resources"] = migrate
if game then migrate() end
