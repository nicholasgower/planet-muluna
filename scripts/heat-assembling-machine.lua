local rro = Muluna.rro

local heat_assembling_machines = Muluna.constants.heat_assembling_machines

local function move_entity_to_bottom_layer(entity)

    entity.rotate{reverse=false}
    entity.rotate{reverse=true}
end

Muluna.events.on_event(Muluna.events.events.on_built(), function(event)
    
    local entity = event.entity

    local is_heat_assembling_machine = false
    local heat_assembling_machine_data = {}
    for _,machine in pairs(heat_assembling_machines) do
        if entity.valid and entity.name == machine["assembling-machine"] then
            is_heat_assembling_machine = true
            heat_assembling_machine_data = machine
            break
        end
    end
    local reactor = nil
    if is_heat_assembling_machine then
        reactor = entity.surface.create_entity{
            name = heat_assembling_machine_data["reactor"],
            position = entity.position,
            direction = entity.direction,
            quality = entity.quality,
            force = entity.force,
            source = entity,
            target= entity,
            cause = entity,
            --snap_to_grid = true,
        }
        move_entity_to_bottom_layer(entity) --Ensures that assembler entity, which has a smaller selection box, is always on top of the reactor entity, which unlike the assembler, can't be rotated.
        reactor.fluidbox.add_linked_connection(1,entity,1) 
        --rendering.draw_sprite{sprite = "item.heat-pipe", target = {entity=reactor,offset = {0,-1}},surface = reactor.surface,only_in_alt_mode = true}
        if not storage.heat_assembling_machines then storage.heat_assembling_machines = {} end
        storage.heat_assembling_machines[entity.unit_number] = {["assembling-machine"]=entity,["reactor"] = reactor}
    end


end
)


Muluna.events.on_event(Muluna.events.events.on_destroyed(), function(event)

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
        if storage.heat_assembling_machines then
            if storage.heat_assembling_machines[entity.unit_number] then
                reactor = storage.heat_assembling_machines[entity.unit_number]["reactor"]
                storage.heat_assembling_machines[entity.unit_number] = nil
            end
            for i,registered_machine in pairs(storage.heat_assembling_machines) do
                if registered_machine["assembling-machine"] == entity then
                    reactor = registered_machine["reactor"]
                    storage.heat_assembling_machines[i] = nil
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

local function register_for_deconstruction_events(entity_name,entity_storage) --Assumes that upgrades are done to upgrade quality, not entity type

    Muluna.events.on_event({defines.events.on_marked_for_deconstruction,defines.events.on_cancelled_deconstruction}, function(event)
        local entity = event.entity
        game.print(entity)
        local player = game.players[event.player_index]
        local force = game.players[event.player_index].force
        if entity.name == entity_name then
            if entity_storage then
                game.print(entity_storage)
                local entity_group = entity_storage[entity.unit_number]
                for _,sub_entity in pairs(entity_group) do
                    game.print(sub_entity)
                    if sub_entity ~= entity then
                        if event.name == defines.events.on_marked_for_deconstruction then
                            sub_entity.order_deconstruction(force,player,1)
                        elseif event.name == defines.events.on_cancelled_deconstruction then
                            sub_entity.cancel_deconstruction(force,player)
                        end

                    end
                end
            end
        end
    end)

end
-- for _,entity in pairs(heat_assembling_machines) do
--     register_for_deconstruction_events(entity["assembling-machine"],storage.heat_assembling_machines)
-- end


-- Muluna.events.on_event(defines.events.on_player_toggled_alt_mode, function()
--     if storage.heat_assembling_machines then
--         for _,player in pairs(game.players) do
--             for _,machine in pairs(storage.heat_assembling_machines) do
                

--             end
--         end
--     end
    



-- end)