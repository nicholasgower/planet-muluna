local rro = Muluna.rro

local heat_assembling_machines = Muluna.constants.heat_assembling_machines


Muluna.events.on_event(defines.events.on_built_entity, function(event)
    
    local entity = event.entity

    local is_heat_assembling_machine = false
    local heat_assembling_machine_data = {}
    for _,machine in pairs(heat_assembling_machines) do
        if entity.name == machine["assembling-machine"] then
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
        rendering.draw_sprite{sprite = "item.heat-pipe", target = {entity=reactor,offset = {0,-1}},surface = reactor.surface,only_in_alt_mode = true}
        if not storage.heat_assembling_machines then storage.heat_assembling_machines = {} end
        table.insert(storage.heat_assembling_machines,{["assembling-machine"]=entity,["reactor"] = reactor})
    end


end
)

Muluna.events.on_event({defines.events.on_player_mined_entity,defines.events.on_entity_died}, function(event)

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

-- Muluna.events.on_event(defines.events.on_player_toggled_alt_mode, function()
--     if storage.heat_assembling_machines then
--         for _,player in pairs(game.players) do
--             for _,machine in pairs(storage.heat_assembling_machines) do
                

--             end
--         end
--     end
    



-- end)