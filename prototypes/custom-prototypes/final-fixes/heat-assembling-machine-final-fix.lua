local flib_bounding_box = require("__flib__/bounding-box")

local function move_field(from,to,field)
    to[field] = from[field]
    from[field] = nil


end

local transferred_fields = {
    "heat_buffer",
    "heating_radius",
    "connection_patches_connected",
    "connection_patches_disconnected",
    "heat_connection_patches_connected",
    "heat_connection_patches_disconnected",
    "meltdown_action",
    "neighbour_bonus",
    "picture",
    "working-light-picture",
    --"consumption",
}

local copied_fields = {
    "collision_box",
    "selection_box",
}

if data.raw["heat-assembling-machine"] then
    for _,machine in pairs(data.raw["heat-assembling-machine"]) do

        local assembler = table.deepcopy(machine)
        assembler.name =  machine.name
        assembler.type = "assembling-machine"
        local reactor = {
            type = "reactor",
            name = "heat-assembling-machine-" .. machine.name .. "-reactor",
        }
    

        for _,field in pairs(transferred_fields) do
            move_field(assembler,reactor,field)

        end
        for _,field in pairs(copied_fields) do
            reactor[field] = assembler[field]

        end
        reactor.selection_box = flib_bounding_box.resize(assembler.selection_box,0.0)
        assembler.selection_box = flib_bounding_box.resize(assembler.selection_box,-0.2)
        assembler.quality_indicator_shift = {-0.2,0.2}
        reactor.energy_source = {
            type = "void",
            -- fluid_box = {
            --     volume = 10,
            --     pipe_connections = {}
            -- }
        }
        for _,fluid_box in pairs(assembler.fluid_boxes) do
            if fluid_box.production_type == "heat-output" then
                fluid_box.production_type = "output"
                reactor.energy_source = {
                    type = "fluid",
                    fluid_box = table.deepcopy(fluid_box),
                    scale_fluid_usage = true,
                    render_no_power_icon = false,
                    render_no_network_icon = false,
                }
                new_fluid_box =  reactor.energy_source.fluid_box
                new_fluid_box.production_type = "input"
                --new_fluid_box.linked_connection_id = 1
                new_fluid_box.pipe_connections[1].flow_direction = "input"
                new_fluid_box.pipe_connections[1].position[2] = reactor.energy_source.fluid_box.pipe_connections[1].position[2] - 1
                new_fluid_box.pipe_connections[1].direction = defines.direction.south
                
            end
        end
        reactor.localised_name = {"entity-name.heat-assembling-machine-x-reactor",{"entity-name."..assembler.name}}
        reactor.consumption = Muluna.multiply_energy(machine.energy_usage,machine.effectivity)
        
        data:extend{assembler,reactor}
        table.insert(Muluna.constants.heat_assembling_machines,
            {
                name = machine.name,
                ["assembling-machine"] = assembler.name,
                ["reactor"] = reactor.name
            }
        )
    end
end



data.raw["heat-assembling-machine"] = nil