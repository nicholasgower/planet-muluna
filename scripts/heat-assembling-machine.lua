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
            snap_to_grid = true,
        }
        table.insert(storage.heat_assembling_machines,{["assembling-machine"]=entity,["reactor"] = reactor})
    end


end
)

Muluna.events.on_event({defines.events.on_player_mined_entity,defines.events.on_entity_died}, function(event)

    local entity = event.entity
    game.print(entity.name)
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
        --{entity.position[1]+0.5,entity.position[2]+0.5}
        local reactor = entity.surface.find_entity(heat_assembling_machine_data["reactor"],entity.position)
        game.print(reactor)
        --if reactor then
            reactor.die()
        --end
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