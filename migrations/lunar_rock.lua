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
    -- Regenerating on every mod re-add both replaces existing rocks and
    -- duplicates them. This migration only belongs on a save that predates it.
    if not Muluna.should_run_migrations() then return end
    local map_gen_settings = game.planets.muluna.surface.map_gen_settings
    map_gen_settings.autoplace_controls["lunar_rocks"] = {}
    map_gen_settings.autoplace_settings.entity.settings["lunar-rock"] = {}
    game.planets.muluna.surface.map_gen_settings = map_gen_settings
    game.planets.muluna.surface.regenerate_entity("lunar-rock")
    --regenerate_resource("helium")
end

end

Muluna.migrations = Muluna.migrations or {}
Muluna.migrations["lunar_rock"] = migrate
if game then migrate() end
