local debug_mode = false
local DT = "[NavBeacon] "
if settings.startup["enable-nav-beacon"].value == true then
    local radar_data = prototypes.mod_data["muluna-satellite-radar"].data
end

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

local function reset_storage_nav_beacons() 
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
    
        storage.nav_beacons = {}
    
    
        storage.beaconed_platforms = {}
    
    
        storage.platform_beacons = {}
   
    
        storage.nav_surfaces = {}
    
    
        storage.beacon_electric_interfaces = {}

        --Search space platforms for nav beacons already placed
        --Register those beacons using existing functions.
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
            name = "muluna-satellite-radar",
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
        if platformBeacon.valid == true then
            storage.nav_surfaces[platformBeacon.unit_number] = e.platform.space_location --this can be nil, which is acceptable
        else
            storage.beaconed_platforms[e.platform.index] = nil
        end
        
    end
end)

local filter_built = {
    {filter = "name", name = "muluna-satellite-radar"},
    {filter = "name", name = "nav-beacon-platform"},
    {filter = "name", name = "nav-beacon-planet"},
}



------------------------------------------------------------------------------------------------------------------------
----- HANDLE TRAVERSING THE MAP -----
-----
------------------------------------------------------------------------------------------------------------------------

if settings.startup["enable-nav-beacon"].value == true then
---@param event on_tick
    script.on_nth_tick(settings.startup["nav-beacon-update-ticks"].value, function(event)
        
        --if event.tick % settings.startup["nav-beacon-update-ticks"].value ~= 0 then return end
        
            for _,player in pairs(game.players) do
                if player.controller_type == defines.controllers.remote then
                    local display_beacon_alert = player.mod_settings["nav-beacon-display-alert"].value
                    --chart_zoomed_in doesn't seem to work
                    --if player.render_mode == defines.render_mode.chart or player.render_mode == defines.render_mode.chart_zoomed_in then
                    local navSat = nil
                    local enough_light = false
                    --game.print(serpent.block(storage.nav_surfaces))
                    for beacon_id,nav_surface in pairs(storage.nav_surfaces) do
                            if nav_surface.name == player.surface.name then
                                local beacon = storage.nav_beacons[beacon_id] 

                                if beacon.valid == false then 
                                    game.print("[Muluna] ERROR: Satellite Radar data storage invalid, deleting storage to prevent crash. You might need to place your radars again.") 
                                    log("ERROR: Navigation beacon storage invalidated to prevent crash.")
                                    log("planet-muluna storage contents:")
                                    log(serpent.block(storage))
                                    log("End planet-muluna storage")
                                    reset_storage_nav_beacons() break 

                                    end
                                --game.print(beacon)
                                if beacon ~= nil then if beacon.force == player.force then
                                        navSat = beacon
                                        if display_beacon_alert then
                                            player.add_custom_alert(beacon,
                                                {type = "item", name = "muluna-satellite-radar"},
                                                {"alert.nav-beacon-available",{"space-location-name."..player.surface.name}},
                                                false
                                            )
                                        end
                                        
                                        break
                                else
                                    player.remove_alert{entity = beacon}
                                end end
                            
                            else 
                                player.remove_alert{entity = beacon}
                            end
                    end

                    if navSat ~= nil then
                        --local multiplier = 1/(1+0.3*navSat.quality.level)
                        local energy_cost = util.parse_energy(tostring(helpers.evaluate_expression(radar_data.energy_per_scan_expression,{base = radar_data.entities[navSat.name].energy_per_scan, quality_level = navSat.quality.level})) .. "MJ")
                        if navSat.energy >= energy_cost then
                            local pos = player.position
                            --if player.force.is_chunk_visible(player.surface,{pos.x/32,pos.y/32}) == false then
                                --local multiplier = (1-0.1667*navSat.quality.level)
                                
                                navSat.energy = navSat.energy - energy_cost
                                --game.print(navSat.quality.level)
                                --local offset = 100 * (1+0.3*navSat.quality.level)
                                local offset = helpers.evaluate_expression(radar_data.scan_size_expression,{base = radar_data.entities[navSat.name].energy_per_scan, quality_level = navSat.quality.level})
                                local chartBounds = {
                                    left_top = { pos.x - offset/2, pos.y - offset/2},
                                    right_bottom = { pos.x + offset/2, pos.y + offset/2}
                                }
                                player.force.chart(player.surface, chartBounds)
                            --end
                        end
                            
                    
                    end
                    --end
                else
                    player.remove_alert{type = defines.alert_type.custom, icon = {type = "item", name = "muluna-satellite-radar"},message = {"alert.nav-beacon-available",{"space-location-name."..player.surface.name}}}
                end
            end
        
    end)
end

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
