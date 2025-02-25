local debug_mode = false
local DT = "[NavBeacon] "

require("__core__/lualib/util.lua")

local function init_storage_nav_beacons() 
    -- storage = {
    --     ---@type table<int, LuaEntity>
    --     nav_beacons = {}, -- beacon [unit_number] = LuaEntity (nav-beacon)
    --     ---@type table<int, LuaSpacePlatform>
    --     beacon_platforms = {}, -- beacon [unit_number] = LuaSpacePlatform
    --     ---@type table<int, LuaEntity>
    --     platform_beacons = {}, -- platform [index] = LuaEntity (nav-beacon)
    --     ---@type table<int, LuaSpaceLocationPrototype>
    --     nav_surfaces = {}, -- beacon [unit_number] = LuaSpaceLocationPrototype
    --     ---@type table<int, LuaEntity>
    --     beacon_electric_interfaces = {}, -- beacon [unit_number] = LuaEntity (nav-beacon-electric-interface)
    -- }
    if storage.nav_beacons == nil then
        storage.nav_beacons = {}
    end
    if storage.beaconed_platforms == nil then
        storage.beaconed_platforms = {}
    end
    if storage.platform_beacons == nil then
        storage.platform_beacons = {}
    end
    if storage.nav_surfaces == nil then
        storage.nav_surfaces = {}
    end
    if storage.beacon_electric_interfaces == nil then
        storage.beacon_electric_interfaces = {}
    end
end

script.on_init(function()

    init_storage_nav_beacons()


end)

script.on_configuration_changed(function()
    if debug_mode then
        log(DT .. "initialized storage")
        log(serpent.block(storage))
    end

    init_storage_nav_beacons()
end)

---@param entity LuaEntity
local function built_nav_beacon(entity)
    if debug_mode then
        game.print(DT .. "built nav beacon @ " .. entity.gps_tag)
    end

    local surface = entity.surface
    local platform = surface.platform
    local position = entity.position
    local force = entity.force
    local quality = entity.quality
    

    if platform == nil then
        entity.destroy({
            raise_destroy = false
        })
        surface.create_entity({
            name = "nav-beacon-planet",
            position = position,
            force = force,
            raise_built = false,
            fast_replace = true,
            quality = quality
        })
    else
        if storage.beaconed_platforms[platform.index] ~= nil then
            game.print({"", DT, {"nav-beacon.single-per-platform"}, " @ ",entity.gps_tag})
            entity.mine({
                inventory = platform.hub.get_inventory(defines.inventory.hub_main),
                force = true,
                raise_destroyed = false,
                ignore_minable = true
            })
            return
        end
        entity.destroy({
            raise_destroy = false
        })
        local nav = surface.create_entity({
            name = "nav-beacon-platform",
            position = position,
            force = force,
            raise_built = false,
            fast_replace = true,
            quality = quality
        })
        storage.beaconed_platforms[platform.index] = nav
        storage.nav_surfaces[nav.unit_number] = platform.space_location
        storage.nav_beacons[nav.unit_number] = nav
    end
end

---@param entity LuaEntity
local function destroyed_nav_beacon(entity)
    if debug_mode then
        game.print(DT .. "destroyed nav beacon @ " .. entity.gps_tag)
    end

    local platform = entity.surface.platform
    if platform == nil then return end --if not destroyed on a space platform, then we don't care about it

    storage.beaconed_platforms[platform.index] = nil
    storage.nav_surfaces[entity.unit_number] = nil
    storage.nav_beacons[entity.unit_number] = nil
end

---@param e on_space_platform_changed_state
script.on_event(defines.events.on_space_platform_changed_state, function(e)
    --only track platforms with a nav beacon
    local platformBeacon = storage.beaconed_platforms[e.platform.index]
    if platformBeacon ~= nil then
        storage.nav_surfaces[platformBeacon.unit_number] = e.platform.space_location --this can be nil, which is acceptable
    end
end)

local filter_built = {
    {filter = "name", name = "nav-beacon"},
    {filter = "name", name = "nav-beacon-platform"},
    {filter = "name", name = "nav-beacon-planet"},
}



------------------------------------------------------------------------------------------------------------------------
----- HANDLE TRAVERSING THE MAP -----
-----
------------------------------------------------------------------------------------------------------------------------

---@param event on_tick
script.on_event(defines.events.on_tick, function(event)
    if event.tick % 20 ~= 0 then return end

    for _,player in pairs(game.players) do
        if player.controller_type == defines.controllers.remote then
            --chart_zoomed_in doesn't seem to work
            --if player.render_mode == defines.render_mode.chart or player.render_mode == defines.render_mode.chart_zoomed_in then
            local navSat = nil
            local enough_light = false
            for beacon_id,nav_surface in pairs(storage.nav_surfaces) do
                    if nav_surface.name == player.surface.name then
                        local beacon = storage.nav_beacons[beacon_id]
                        if  beacon ~= nil
                            and beacon.force == player.force
                            and beacon.energy >= (util.parse_energy(settings.startup["platform-power-consumption"].value .. "MW") * 0.9)
                        then
                                navSat = beacon
                                player.add_custom_alert(beacon,
                                {type = "item", name = "nav-beacon"},
                                {"alert.nav-beacon-available",{"space-location-name."..player.surface.name}},
                                false
                                )
                                break
                        else
                            player.remove_alert{entity = beacon}
                        end
                    else 
                        player.remove_alert{entity = beacon}
                    end
            end

            if navSat ~= nil then
                local pos = player.position
                --game.print(navSat.quality.level)
                local offset = 100 + navSat.quality.level * 25
                local chartBounds = {
                    left_top = { pos.x - offset, pos.y - offset},
                    right_bottom = { pos.x + offset, pos.y + offset}
                }
                player.force.chart(player.surface, chartBounds)
            
            end
            --end
        else
            player.remove_alert{entity = beacon}
        end
    end
end)

------------------------------------------------------------------------------------------------------------------------
----- BUILT RADAR -----
----- need to register all build events because of the custom energy interface
------------------------------------------------------------------------------------------------------------------------
---@param event on_space_platform_built_entity
script.on_event(defines.events.on_space_platform_built_entity, function(event)
    local entity = event.entity or event.created_entity
    if not entity or not entity.valid then return end

    built_nav_beacon(entity)
end, filter_built)

---@param event script_raised_built
script.on_event(defines.events.script_raised_built, function(event)
    local entity = event.entity or event.created_entity
    if not entity or not entity.valid then return end

    built_nav_beacon(entity)
end, filter_built)

-- ---@param event on_built_entity
-- script.on_event(defines.events.on_built_entity, function(event)
--     local entity = event.entity or event.created_entity
--     if not entity or not entity.valid then return end

--     built_nav_beacon(entity)
-- end, filter_built)

---@param event on_robot_built_entity
script.on_event(defines.events.on_robot_built_entity, function(event)
    local entity = event.entity or event.created_entity
    if not entity or not entity.valid then return end

    built_nav_beacon(entity)
end, filter_built)

------------------------------------------------------------------------------------------------------------------------
----- DESTROYED RADAR -----
----- only register destroy events from the space platform since that's the only place we care about having these
----- script raised is included, as well as on_entity_died in case one is e.g. killed by meteor
------------------------------------------------------------------------------------------------------------------------

---@param event on_space_platform_mined_entity
script.on_event(defines.events.on_space_platform_mined_entity, function(event)
    local entity = event.entity or event.created_entity
    if not entity or not entity.valid then return end

    destroyed_nav_beacon(entity)
end, filter_built)

---@param event on_entity_died
script.on_event(defines.events.on_entity_died, function(event)
    local entity = event.entity or event.created_entity
    if not entity or not entity.valid then return end

    destroyed_nav_beacon(entity)
end, filter_built)

---@param event script_raised_destroy
script.on_event(defines.events.script_raised_destroy, function(event)
    local entity = event.entity or event.created_entity
    if not entity or not entity.valid then return end

    destroyed_nav_beacon(entity)
end, filter_built)

---@param event on_player_mined_entity
script.on_event(defines.events.on_player_mined_entity, function(event)
    local entity = event.entity or event.created_entity
    if not entity or not entity.valid then return end

    destroyed_nav_beacon(entity)
end, filter_built)

---@param event on_robot_mined_entity
script.on_event(defines.events.on_robot_mined_entity, function(event)
    local entity = event.entity or event.created_entity
    if not entity or not entity.valid then return end

    destroyed_nav_beacon(entity)
end, filter_built)
