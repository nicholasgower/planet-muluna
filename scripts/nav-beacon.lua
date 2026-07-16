local debug_mode = false
local DT = "[NavBeacon] "
local radar_data 
local rro = Muluna.rro
if settings.startup["enable-nav-beacon"].value == true then
    radar_data = prototypes.mod_data["muluna-satellite-radar"].data
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
    if rro.deep_equals(storage.nav_beacons,{}) then
        storage.has_nav_beacons = false
    else
        storage.has_nav_beacons = true
    end
    --storage.has_nav_beacons = #storage.nav_beacons > 0
    --print("has_nav_beacon " .. storage.has_nav_beacons)

    
end

local function update_space_platform_beacon(platformBeacon,platform)
    if platformBeacon.valid == true then
            storage.nav_surfaces[platformBeacon.unit_number] = platform.space_location --this can be nil, which is acceptable
        else
            storage.beaconed_platforms[platform.index] = nil
        end


end

local function update_space_platform(platform)
    --only track platforms with a nav beacon
    local platformBeacon = storage.beaconed_platforms[platform.index]
    if platformBeacon ~= nil then
        update_space_platform_beacon(platformBeacon,platform)
        
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
        for _,force in pairs(game.forces) do
            
            for _,platform in pairs(force.platforms) do 
                update_space_platform(platform)
            end
        end
end

Muluna.events.on_event(Muluna.events.events.on_init(), function(event)

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
        -- entity.destroy({
        --     raise_destroy = false
        -- })
        -- surface.create_entity({
        --     name = "nav-beacon-planet",
        --     position = position,
        --     force = force,
        --     raise_built = false,
        --     fast_replace = true,
        --     quality = quality
        -- })
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
        storage.has_nav_beacons = true
    end
    --if #storage.nav_beacons > 0 then
        
    --end
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
    if #storage.nav_beacons == 0 then
        storage.has_nav_beacons = false
    end
end




---@param e on_space_platform_changed_state
Muluna.events.on_event(defines.events.on_space_platform_changed_state, function(e)
    update_space_platform(e.platform)
end)

local filter_built = {
    {filter = "name", name = "muluna-satellite-radar"},
    --{filter = "name", name = "nav-beacon-platform"},
    --{filter = "name", name = "nav-beacon-planet"},
}


local function display_nav_beacon_alert(player,alert_locale)
    if not player.gui.top["muluna-satellite-radar-alert-button"] then
        local top = player.gui.top.add{
            type = "sprite-button",
            name = "muluna-satellite-radar-alert-button",
            sprite = "item/muluna-satellite-radar", -- swap for your own sprite, e.g. "item/iron-plate"
            tooltip = alert_locale, -- falls back fine if you haven't localized it yet
            style = "frame_action_button" -- gives it the same look as vanilla top-bar buttons
        }
        top.style.height = 60
        top.style.width = 60
    end
    
        

end

-- Hides the button for a single player (destroys the GUI element)
local function hide_nav_beacon_alert(player)
  local button = player.gui.top["muluna-satellite-radar-alert-button"]
    if button then button.destroy() end
end

------------------------------------------------------------------------------------------------------------------------
----- HANDLE TRAVERSING THE MAP -----
-----
------------------------------------------------------------------------------------------------------------------------

--local profiler_1 = helpers.create_profiler()
if settings.startup["enable-nav-beacon"].value == true then
---@param event on_tick
    Muluna.events.on_nth_tick(settings.startup["nav-beacon-update-ticks"].value, function(event)
        --profiler_1.reset()
        --if event.tick % settings.startup["nav-beacon-update-ticks"].value ~= 0 then return end
        --game.print("test")
            if not storage.has_nav_beacons == true then return end
                for _,player in pairs(game.players) do
                    if player.controller_type == defines.controllers.remote then
                        local display_beacon_alert = player.mod_settings["nav-beacon-display-alert"].value
                        --chart_zoomed_in doesn't seem to work
                        --if player.render_mode == defines.render_mode.chart or player.render_mode == defines.render_mode.chart_zoomed_in then
                        local navSat = nil
                        local enough_light = false
                        --game.print(serpent.block(storage.nav_surfaces))
                        for beacon_id,nav_surface in pairs(storage.nav_surfaces) do
                            if storage.nav_beacons[beacon_id] and not nav_surface.valid then --If a surface is removed via mod uninstallation, update the space platform.
                                --storage.nav_surfaces[beacon_id] = nil
                                local beacon = storage.nav_beacons[beacon_id] 
                                if beacon then update_space_platform_beacon(beacon,beacon.surface.platform) end
                                goto on_to_the_next
                            
                            end
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
                                    if not storage.nav_beacons_other then 
                                        storage.nav_beacons_other = {}
                                    end
                                    if not storage.nav_beacons_other[beacon_id] then 
                                        storage.nav_beacons_other[beacon_id] = {}
                                    end
                                    
                                    if not storage.nav_beacons_other[beacon_id].gui then storage.nav_beacons_other[beacon_id].gui = {enabled = true} end
                                    
                                    --game.print(beacon)
                                    if beacon ~= nil then if beacon.force == player.force then
                                            navSat = beacon
                                            if display_beacon_alert then
                                                local enabled = storage.nav_beacons_other[navSat.unit_number].gui.enabled
                                                local alert_locale = {enabled and "alert.nav-beacon-available" or "alert.nav-beacon-available-disabled",{"space-location-name."..player.surface.name}}
                                                display_nav_beacon_alert(player,alert_locale)
                                                player.add_custom_alert(beacon,
                                                    {type = "item", name = "muluna-satellite-radar"},
                                                    alert_locale,
                                                    false
                                                )
                                            end
                                            
                                            break
                                    else
                                        hide_nav_beacon_alert(player)
                                        player.remove_alert{entity = beacon}
                                    end end
                                
                                else 
                                    hide_nav_beacon_alert(player)
                                    player.remove_alert{entity = beacon}
                                end
                            ::on_to_the_next::
                        end
                        --game.print(serpent.block(navSat))
                        if navSat ~= nil and (storage.nav_beacons_other[navSat.unit_number].gui.enabled == true) then
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
            
          --game.print(profiler_1)
    end)
end

------------------------------------------------------------------------------------------------------------------------
----- BUILT RADAR -----
----- need to register all build events because of the custom energy interface
------------------------------------------------------------------------------------------------------------------------
---@param event on_space_platform_built_entity
Muluna.events.on_event(defines.events.on_space_platform_built_entity, function(event)
    local entity = event.entity or event.created_entity
    if not entity or not entity.valid then return end
    if entity.name ~= "muluna-satellite-radar" then return end
    built_nav_beacon(entity)
end, filter_built)

---@param event script_raised_built
Muluna.events.on_event(defines.events.script_raised_built, function(event)
    local entity = event.entity or event.created_entity
    if not entity or not entity.valid then return end
    if entity.name ~= "muluna-satellite-radar" then return end
    built_nav_beacon(entity)
end, filter_built)

-- ---@param event on_built_entity
-- Muluna.events.on_event(defines.events.on_built_entity, function(event)
--     local entity = event.entity or event.created_entity
--     if not entity or not entity.valid then return end

--     built_nav_beacon(entity)
-- end, filter_built)

---@param event on_robot_built_entity
Muluna.events.on_event(defines.events.on_robot_built_entity, function(event)
    local entity = event.entity or event.created_entity
    if not entity or not entity.valid then return end
    if entity.name ~= "muluna-satellite-radar" then return end
    built_nav_beacon(entity)
end, filter_built)

------------------------------------------------------------------------------------------------------------------------
----- DESTROYED RADAR -----
----- only register destroy events from the space platform since that's the only place we care about having these
----- script raised is included, as well as on_entity_died in case one is e.g. killed by meteor
------------------------------------------------------------------------------------------------------------------------

---@param event on_space_platform_mined_entity
Muluna.events.on_event(defines.events.on_space_platform_mined_entity, function(event)
    local entity = event.entity or event.created_entity
    if not entity or not entity.valid then return end
    if entity.name ~= "muluna-satellite-radar" then return end
    destroyed_nav_beacon(entity)
end, filter_built)

---@param event on_entity_died
Muluna.events.on_event(defines.events.on_entity_died, function(event)
    local entity = event.entity or event.created_entity
    if not entity or not entity.valid then return end
    if entity.name ~= "muluna-satellite-radar" then return end
    destroyed_nav_beacon(entity)
end, filter_built)

---@param event script_raised_destroy
Muluna.events.on_event(defines.events.script_raised_destroy, function(event)
    local entity = event.entity or event.created_entity
    if not entity or not entity.valid then return end
    if entity.name ~= "muluna-satellite-radar" then return end
    destroyed_nav_beacon(entity)
end, filter_built)

---@param event on_player_mined_entity
Muluna.events.on_event(defines.events.on_player_mined_entity, function(event)
    local entity = event.entity or event.created_entity
    if not entity or not entity.valid then return end
    if entity.name ~= "muluna-satellite-radar" then return end
    destroyed_nav_beacon(entity)
end, filter_built)

---@param event on_robot_mined_entity
Muluna.events.on_event(defines.events.on_robot_mined_entity, function(event)
    local entity = event.entity or event.created_entity
    if not entity or not entity.valid then return end
    if entity.name ~= "muluna-satellite-radar" then return end
    destroyed_nav_beacon(entity)
end, filter_built)

Muluna.events.on_event(defines.events.on_gui_click,function(event)
    local player = game.players[event.player_index]
        
    local element = event.element
    if element.name ~= "muluna-satellite-radar-alert-button" then return end
        

    local selected
    for beacon_unit_number,nav_surface in pairs(storage.nav_surfaces) do
        local surface = game.planets[space_location.object_name]
        game.print(surface)
        if nav_surface.name == player.surface.name then
            selected = storage.nav_beacons[beacon_unit_number]
            break
        end
    end
    print(selected)
    local to_platform = selected.surface
    player.set_controller{type = defines.controllers.remote,surface = to_platform}


end)