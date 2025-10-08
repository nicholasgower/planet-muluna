local function regenerate_resource(resource) 
    local map_gen_settings = game.planets.muluna.surface.map_gen_settings
    map_gen_settings.autoplace_controls[resource] = {}
    map_gen_settings.autoplace_settings.entity.settings[resource] = {}
    game.planets.muluna.surface.map_gen_settings = map_gen_settings
    game.planets.muluna.surface.regenerate_entity(resource)
end
if game.planets.muluna.surface then
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