-- Registered so the FUnit re-add test can replay this migration with an empty
-- storage table, the way Factorio does when a mod is added back to a save.
local function migrate()
local function regenerate_resource(resource) 
    local map_gen_settings = game.planets.muluna.surface.map_gen_settings
    --map_gen_settings.autoplace_controls[resource] = {}
    --map_gen_settings.autoplace_settings.entity.settings[resource] = {}
    --game.planets.muluna.surface.map_gen_settings = map_gen_settings
    game.planets.muluna.surface.regenerate_entity(resource)
end
if game.planets.muluna.surface then
    -- Converting cliffs again on a re-add can destroy map entities that the
    -- save already migrated.
    if not Muluna.should_run_migrations() then return end
    --regenerate_resource("cliff-muluna")
    --regenerate_resource("helium")
    local cliffs = game.planets.muluna.surface.find_entities_filtered{name="cliff"}
    if cliffs then
        for _,cliff in pairs(cliffs) do
            if cliff then
                local orientation = cliff.cliff_orientation
                local new_position = cliff.position
                cliff.destroy{}
                
                game.planets.muluna.surface.create_entity{name = "cliff-muluna", position = new_position, cliff_orientation = orientation}
                
                
            end
            
        end
    end
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
Muluna.migrations["new_cliffs"] = migrate
if game then migrate() end
