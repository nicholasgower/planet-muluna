local rro = Muluna.rro

local heat_assembling_machines = Muluna.constants.vacuum_roboports

local status_burner_roboport_refueling = {
    diode = defines.entity_status_diode.yellow,
    label = {"custom-status.muluna-burner-roboport-refueling"}

}

local status_burner_roboport_full = {
    diode = defines.entity_status_diode.green,
    label = {"custom-status.muluna-burner-roboport-full"}
    
}

local status_burner_roboport_empty = {
    diode = defines.entity_status_diode.red,
    label = {"custom-status.muluna-burner-roboport-empty"}
    
}
   
local function move_entity_to_bottom_layer(entity)

    entity.rotate{reverse=false}
    entity.rotate{reverse=true}
end
local heat_assembler_filters = {}
for entity_name,machine in pairs(heat_assembling_machines or {}) do
    table.insert(heat_assembler_filters,{filter = "name", name =  machine["roboport"]})
    table.insert(heat_assembler_filters,{filter = "ghost_name", name =  machine["roboport"]})
    table.insert(heat_assembler_filters,{filter = "name", name = machine["refueler"]})
    table.insert(heat_assembler_filters,{filter = "ghost_name", name = machine["refueler"]})
end
Muluna.events.on_event(Muluna.events.events.on_built(), function(event)
    
    local entity = event.entity

    local is_heat_assembling_machine = false
    local heat_assembling_machine_data = {}
    for _,machine in pairs(heat_assembling_machines) do
        if entity.valid and entity.name == machine["refueler"] then
            is_heat_assembling_machine = true
            heat_assembling_machine_data = machine
            break
        end
    end
    local roboport = nil
    if is_heat_assembling_machine then
        if not storage.active_burner_roboports then storage.active_burner_roboports = {} end
        storage.active_burner_roboports[entity.unit_number] = entity
        roboport = entity.surface.create_entity{
            name = heat_assembling_machine_data["roboport"],
            position = entity.position,
            direction = entity.direction,
            quality = entity.quality,
            force = entity.force,
            source = entity,
            target= entity,
            cause = entity,
            --snap_to_grid = true,
        }
        entity.set_recipe("burner-roboport-refuel-muluna","normal")
        --reactor.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(entity.get_wire_connector(defines.wire_connector_id.circuit_red,true))
        --reactor.get_wire_connector(defines.wire_connector_id.circuit_green,true).connect_to(entity.get_wire_connector(defines.wire_connector_id.circuit_green,true))
        move_entity_to_bottom_layer(entity) --Ensures that assembler entity, which has a smaller selection box, is always on top of the reactor entity, which unlike the assembler, can't be rotated.
        entity.add_fluid_box_linked_connection(1,entity,1) 
        entity.recipe_locked = true
        entity.custom_status= status_burner_roboport_empty
        roboport.custom_status = entity.custom_status
        --rendering.draw_sprite{sprite = "item.heat-pipe", target = {entity=reactor,offset = {0,-1}},surface = reactor.surface,only_in_alt_mode = true}
        if not storage.burner_roboports then storage.burner_roboports = {} end
        storage.burner_roboports[entity.unit_number] = {["roboport"]=roboport,["refueler"] = entity}
    end


end,
heat_assembler_filters
)


Muluna.events.on_event(Muluna.events.events.on_destroyed(), function(event)

    local entity = event.entity
    --game.print(entity.name)
    local is_heat_assembling_machine = false
    local heat_assembling_machine_data = {}
    for _,machine in pairs(heat_assembling_machines) do
        if entity.name == machine["refueler"] then
            
            is_heat_assembling_machine = true
            heat_assembling_machine_data = machine
            break
        end
    end

    if is_heat_assembling_machine then
        local reactor = nil
        if storage.burner_roboports then
            if storage.burner_roboports[entity.unit_number] then
                reactor = storage.burner_roboports[entity.unit_number]["roboport"]
                storage.burner_roboports[entity.unit_number] = nil
            end
            for i,registered_machine in pairs(storage.burner_roboports) do
                if registered_machine["roboport"] == entity then
                    reactor = registered_machine["roboport"]
                    storage.burner_roboports[i] = nil
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
        --     name = heat_assembling_machine_data["refueler"],
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
    storage.active_burner_roboports[entity.unit_number] = nil

end,
heat_assembler_filters)

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


-- 5000 MJ / 2000 MW

local cutoff_energy_high = 0.8 --If energy % is greater/equal than this, stop updating
local cutoff_energy_low = 0.6 --If energy % is lower than this, start updating

local discharge_time_max = 1200 -- Shortest possible time to fully discharge a normal roboport (in ticks)
local dischange_time_threshold = discharge_time_max * (cutoff_energy_high-cutoff_energy_low)
local long_update_tolerance = 0.5 --Higher tolerance is less performant, but less likely to create UX complaints
local long_update_period = dischange_time_threshold / long_update_tolerance --During long update, roboport's energy value is checked to see if they need more energy.


local short_update_period = 60 --Arbitrary choice that should be less than the time to half-fill the energy fluid buffer

local burner_roboports = {}

for _,burner_roboport_table in pairs(Muluna.constants.vacuum_roboports) do
    local roboport= burner_roboport_table.roboport
    table.insert(burner_roboports,roboport)
end

local roboport_max_energy = {}
local roboport_cutoff_energy_low = {}
local roboport_cutoff_energy_high = {}

for _,roboport_name in pairs(burner_roboports) do
    local roboport = prototypes.entity[roboport_name]
    if roboport.electric_energy_source_prototype and roboport.electric_energy_source_prototype.buffer_capacity then
        roboport_max_energy[roboport.name] = roboport.electric_energy_source_prototype.buffer_capacity
        roboport_cutoff_energy_low[roboport.name]=roboport.electric_energy_source_prototype.buffer_capacity*cutoff_energy_low
        roboport_cutoff_energy_high[roboport.name]=roboport.electric_energy_source_prototype.buffer_capacity*cutoff_energy_high
    end
end

local function calc_energy_percent(roboport) 
    
    local energy = roboport.energy
    local max_energy = roboport_max_energy[roboport.name] --roboport.prototype.electric_energy_source_prototype.buffer_capacity
    return energy/max_energy
end

Muluna.events.on_nth_tick(long_update_period, function()

    for key,entity_table in pairs(storage.burner_roboports) do
        local roboport = entity_table["roboport"]
        local refueler = entity_table["refueler"]
        --local energy_percent = calc_energy_percent(roboport)

        if roboport.energy <= roboport_cutoff_energy_low[roboport.name] and refueler.custom_status ~= status_burner_roboport_refueling then
            --storage.active_burner_roboports[key] = refueler
            refueler.disabled_by_script = false --Turns on refueler
            if refueler.get_fluid_count() > 0 then
                refueler.custom_status = status_burner_roboport_refueling
            else
                refueler.custom_status = status_burner_roboport_empty
            end
            roboport.custom_status = refueler.custom_status 
        end
    end


end)

local fluid_per_craft = Muluna.constants.burner_roboport_fluid_per_craft
local fluid_removed_amount = fluid_per_craft
local energy_value = 0.1 * 1000000
local delta_energy = (fluid_removed_amount or 0) * energy_value

--Pre 2.1.12, this function was used in a loop on every refueler with low energy in a table to periodically convert proxy fluid into energy. Now, it's done on crafting of a recipe that consumes fuel.
local function short_update_roboport(refueler)
    --local roboport = entity_table["roboport"]
        local key = refueler.unit_number
        
        local roboport = storage.burner_roboports[key]["roboport"]
        
        roboport.energy = (roboport.energy or 0) + delta_energy
        if roboport.energy >= roboport_cutoff_energy_high[roboport.name] then
            --storage.active_burner_roboports[key] = nil --Deactivates roboport
            refueler.disabled_by_script = true --Turns off refueler
            refueler.custom_status = status_burner_roboport_full
            roboport.custom_status = refueler.custom_status
            -- Add status
        end

end

script.on_event(prototypes.recipe["burner-roboport-refuel-muluna"].on_crafted_event, function(event)
    short_update_roboport(event.entity)
  
end)


-- Muluna.events.on_nth_tick(short_update_period, function() 

--     for key,refueler in pairs(storage.active_burner_roboports) do
--         short_update_roboport(refueler)
--     end


-- end)