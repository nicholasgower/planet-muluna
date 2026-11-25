-- Registered so the FUnit re-add test can replay this migration with an empty
-- storage table, the way Factorio does when a mod is added back to a save.
local function migrate()
if game.planets.muluna and game.planets.muluna.surface then
    local surface = game.planets.muluna.surface
    surface.wind_speed = 0
    surface.wind_orientation = 0
    surface.wind_orientation_change = 0
end

end

Muluna.migrations = Muluna.migrations or {}
Muluna.migrations["disable_wind"] = migrate
if game then migrate() end
