local rro = Muluna.rro

local heat_assembling_machines = Muluna.constants.telescopes

local function move_entity_to_bottom_layer(entity)

    entity.rotate{reverse=false}
    entity.rotate{reverse=true}
end

local function get_telescope_build_limit(force)
    return 1

end

Muluna.events.on_event({defines.events.on_built_entity,defines.events.on_robot_built_entity}, function(event)
    if not storage.telescopes then storage.telescopes = {} end
    local entity = event.entity
    
    local is_heat_assembling_machine = false
    local heat_assembling_machine_data = {}
    if heat_assembling_machines[entity.name] then
        is_heat_assembling_machine = true
        heat_assembling_machine_data = heat_assembling_machines[entity.name]
    end
    -- for _,machine in pairs(heat_assembling_machines) do
    --     if entity.name == machine["assembling-machine"] then
    --         is_heat_assembling_machine = true
    --         heat_assembling_machine_data = machine
    --         break
    --     end
    -- end
    local reactor = nil
    if is_heat_assembling_machine then
        local telescope_build_limit = get_telescope_build_limit(entity.force)
        local count = rro.count(storage.telescopes,function(entry) return entry["assembling-machine"].surface == entity.surface end)
        if count >= telescope_build_limit then --Forbid building if count exceeded.
            local position = entity.position
            local surface = entity.surface
            
            local player
            if event.player_index then
                player = game.players[event.player_index]
            else
                player = event.robot
            end
            local stack = {name=entity.prototype.mineable_properties.products[1].name, amount=1}

            --if event.consumed_items then
                --for i = 1,#event.consumed_items do --Return telescope to player inventory
                    --local item = event.consumed_items[i]
                    local inventory_define
                    if event.name == defines.events.on_built_entity then
                        inventory_define = defines.inventory.character_main
                        player.get_inventory(inventory_define).insert(stack)
                    else
                        local item = entity.surface.create_entity{
                            name = "item-on-ground",
                            position = entity.position,
                            stack = stack
                        }
                        if item then
                            item.order_deconstruction(entity.force)
                        end
                        
                            
                    end
                    
                    
                --end
            
            --end
            
            local text
            if telescope_build_limit == 1 then
                text = {"console.can-not-place-more-telescopes-1",tostring(telescope_build_limit)}
            else
                text = {"console.can-not-place-more-telescopes-X",tostring(telescope_build_limit)}
            end
            if event.name == defines.events.on_built_entity then
                player.create_local_flying_text{
                    text = text,
                    --position = position,
                    surface = surface,
                    create_at_cursor = true,
                    speed = 0.01,
                }
            else
                entity.force.print({"",text," ",entity.position})
            end
            entity.destroy{}
            return 
        end


        if entity.surface.platform then
            
        else
            entity.set_recipe("muluna-telescope-observation-" .. entity.surface.name,"normal")
        end
        
        entity.recipe_locked = true
        reactor = entity.surface.create_entity{
            name = heat_assembling_machine_data["constant-combinator"],
            position = entity.position,
            direction = entity.direction,
            quality = entity.quality,
            force = entity.force,
            source = entity,
            target= entity,
            cause = entity,
            --snap_to_grid = true,
        }
        local control_behavior = reactor.get_control_behavior()
        control_behavior.enabled = false
        move_entity_to_bottom_layer(entity) --Ensures that assembler entity, which has a smaller selection box, is always on top of the reactor entity, which unlike the assembler, can't be rotated.
        reactor.fluidbox.add_linked_connection(1,entity,1) 
        --rendering.draw_sprite{sprite = "item.heat-pipe", target = {entity=reactor,offset = {0,-1}},surface = reactor.surface,only_in_alt_mode = true}
        
        storage.telescopes[entity.unit_number] = {["assembling-machine"]=entity,["constant-combinator"] = reactor,["constant-combinator-control-behavior"] = control_behavior}
    end


end
)


Muluna.events.on_event({defines.events.on_player_mined_entity,defines.events.on_entity_died,defines.events.on_robot_mined_entity}, function(event)

    local entity = event.entity
    --game.print(entity.name)
    local is_heat_assembling_machine = false
    local heat_assembling_machine_data = {}
    for _,machine in pairs(heat_assembling_machines) do
        if entity.name == machine["assembling-machine"] then
            
            is_heat_assembling_machine = true
            heat_assembling_machine_data = machine
            break
        end
    end

    if is_heat_assembling_machine then
        local reactor = nil
        if storage.telescopes then
            if storage.telescopes[entity.unit_number] then
                reactor = storage.telescopes[entity.unit_number]["constant-combinator"]
                storage.telescopes[entity.unit_number] = nil
            end
            for i,registered_machine in pairs(storage.telescopes) do
                if registered_machine["assembling-machine"] == entity then
                    reactor = registered_machine["constant-combinator"]
                    storage.telescopes[i] = nil
                    break
                    
                end
                
            end
            
        end
        --{entity.position[1]+0.5,entity.position[2]+0.5}
        --game.print(reactor)
        if reactor then
            reactor.destroy()
        end
        -- entity.surface.create_entity{
        --     name = heat_assembling_machine_data["reactor"],
        --     position = entity.position,
        --     direction = entity.direction,
        --     quality = entity.quality,
        --     force = entity.force,
        --     source = entity,
        --     target= entity,
        --     cause = entity,
        --     snap_to_grid = true,
        -- }
    end

end)

Muluna.events.on_event({defines.events.on_player_rotated_entity}, function(event)

    for _,telescope in pairs(storage.telescopes) do
        if event.entity == telescope["constant-combinator"] then
            move_entity_to_bottom_layer(telescope["assembling-machine"])
        end


    end
end)

local function get_state_integer(state)
    if state == defines.space_platform_state.waiting_for_starter_pack then
        return 1
    elseif state == defines.space_platform_state.starter_pack_requested then
        return 2
    elseif state == defines.space_platform_state.starter_pack_on_the_way then
        return 3
    elseif state == defines.space_platform_state.on_the_path then
        return 4
    elseif state == defines.space_platform_state.waiting_for_departure then
        return 5
    elseif state == defines.space_platform_state.no_schedule then
        return 6
    elseif state == defines.space_platform_state.no_path then
        return 7
    elseif state == defines.space_platform_state.waiting_at_station then
        return 8
    elseif state == defines.space_platform_state.paused then
        return 9
    else
        return nil -- or some default value if needed
    end
end

local function bool_to_int(state)
    if state == true then
        return 2
    else
        return 1
    end


end

local platform_list_signals = {}

for _,signal in pairs(prototypes.virtual_signal) do
    table.insert(platform_list_signals,signal.name)
end

local function get_telescope_combinator_signals(surface,force) --Intended to be memoized with cache resetting every on_nth_tick event
    local signals = {}
    local i = 1
    if surface.planet then
        local planet = surface.planet
        --return {} --Table of logistic filters/signals
        -- Produce list of space platforms (Normal quality channel provides platform id) (Uses list of virtual signals with strength equal to id)
        -- Uncommon quality: State of space platform (https://lua-api.factorio.com/latest/defines.html#defines.space_platform_state)
        -- Rare quality: Can leave_current_location (1 or 2) (https://lua-api.factorio.com/latest/classes/LuaSpacePlatform.html#can_leave_current_location)
        for j,space_platform in ipairs(planet.get_space_platforms(force)) do
            local signal = platform_list_signals[j]
            if signal then
                signals[i]={value = {type = "virtual",name = signal,quality = "normal"},min= space_platform.index}
                i = i+1
                signals[i]={value = {type = "virtual",name = signal,quality = "uncommon"},min= get_state_integer(space_platform.state)}
                i = i+1
                signals[i]={value = {type = "virtual",name = signal,quality = "rare"},min= bool_to_int(space_platform.can_leave_current_location())}
                i = i+1

            end
        end
        -- Other signals indicating planet and total number of platforms
        local number_of_platforms = 1
        signals[i]={value = {type = "space-location",name = planet.name,quality = "normal"},min= number_of_platforms, }
        i = i+1
    elseif surface.platform then
        local platform = surface.platform
        if platform.space_connection then
            local total_length = platform.space_connection.length
            local distance = math.floor(platform.distance * total_length)
            signals[i]={value = {type = "virtual",name = "signal-X",quality = "normal"},min= distance, }
            i = i+1
            signals[i]={value = {type = "virtual",name = "signal-L",quality = "normal"},min= total_length, }
            i = i+1
            
        end
        signals[i]={value = {type = "virtual",name = "signal-I",quality = "normal"},min = platform.index} --Platform index, matched by terrestrial telescopes.
        i = i+1
        -- Also display number of asteroids on screen by type
        local asteroids = surface.find_entities_filtered{type = {"asteroid"}}
        local asteroid_counts = {}
        for _,asteroid in pairs(asteroids) do --Make list of every name and quality of 
            if asteroid_counts[asteroid.name] == nil then asteroid_counts[asteroid.name] = {} end
            if asteroid_counts[asteroid.name][asteroid.quality.name] == nil then
                asteroid_counts[asteroid.name][asteroid.quality.name] = 1
            else
                asteroid_counts[asteroid.name][asteroid.quality.name] = asteroid_counts[asteroid.name][asteroid.quality.name] + 1
            end
        end
        for asteroid,asteroid_info in pairs(asteroid_counts) do
            for quality,amount in pairs(asteroid_info) do
                signals[i]={value = {type = "entity",name = asteroid, quality = quality},min = amount}
                i = i+1
            end
        end
    end
    return signals
end



Muluna.events.on_nth_tick(settings.startup["muluna-telescope-combinator-update-ticks"].value, function() --Update telescope combinators
    for _,telescope in pairs(storage.telescopes) do
            local combinator = telescope["constant-combinator"]
            if combinator.valid and telescope["constant-combinator-control-behavior"] then
                local combinator_behavior = telescope["constant-combinator-control-behavior"]
                if combinator_behavior.enabled == true then
                    local signals = get_telescope_combinator_signals(combinator.surface,combinator.force)
                    combinator_behavior.remove_section(1)
                    local section = combinator_behavior.add_section()
                    for i,signal in ipairs(signals) do
                        section.set_slot(i,signal)
                    end
                end
            end
    end



end)