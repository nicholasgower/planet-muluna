local rro = Muluna.rro

local turbine =data.raw["generator"]["steam-turbine"]
local fusion_generator = data.raw["fusion-generator"]["fusion-generator"]

local recycling_turbine=util.merge{table.deepcopy(fusion_generator),

    {
        name = "muluna-cycling-steam-turbine",
        max_fluid_usage = 1.5,
        collision_box = {{-1.4, -3.4}, {1.4, 3.4}},
        selection_box = {{-1.5, -3.5}, {1.5, 3.5}},
        icon = "__muluna-graphics__/graphics/icons/advanced-steam-turbine.png",
        icon_size = 64,
    }

}

recycling_turbine.input_fluid_box = util.merge{table.deepcopy(recycling_turbine.input_fluid_box),
    {
        filter = "steam",
        minimum_temperature=165,
        maximum_temperature=1000,
        volume = 200,
        
    }
    

}

recycling_turbine.input_fluid_box.pipe_connections =
{
  { flow_direction="input-output",  direction = defines.direction.south, position = {0,  3}, connection_category = {"default"} },
  --{ flow_direction="input",  direction = defines.direction.south, position = { 1,  2}, connection_category = {"fusion-plasma"} },
  { flow_direction="input-output", direction = defines.direction.north, position = { 0, -3}, connection_category = {"default"} },
  --{ flow_direction="output", direction = defines.direction.west,  position = {-1,  0}, connection_category = {"fusion-plasma"} },
  --{ flow_direction="output", direction = defines.direction.east,  position = { 1,  0}, connection_category = {"fusion-plasma"} },
  --{ flow_direction="output", direction = defines.direction.west,  position = {-1, -1}, connection_category = {"fusion-plasma"} },
  --{ flow_direction="output", direction = defines.direction.east,  position = { 1, -1}, connection_category = {"fusion-plasma"} },
}
recycling_turbine.surface_conditions = nil
recycling_turbine.output_fluid_box = util.merge{table.deepcopy(recycling_turbine.output_fluid_box),
    {
        filter = "cooled-steam",
        temperature = 100,
        volume = 200,
        
    }
}
if mods["maraxsis"] then
    recycling_turbine.maraxsis_buildability_rules = {water = false, dome = true, coral = false, trench = true, trench_entrance = false, trench_lava = false}
end

recycling_turbine.output_fluid_box.pipe_connections =
{
  { flow_direction="input-output", direction = defines.direction.west,  position = {-1,  0}, connection_category = {"default"} },
  { flow_direction="input-output", direction = defines.direction.east,  position = { 1,  0}, connection_category = {"default"} },
  { flow_direction="input-output", direction = defines.direction.west,  position = {-1,  1}, connection_category = {"default"} },
  { flow_direction="input-output", direction = defines.direction.east,  position = { 1,  1}, connection_category = {"default"} },
  --{ flow_direction="output", direction = defines.direction.north, position = {-1, -2} },
  --{ flow_direction="output", direction = defines.direction.north, position = {1, -2} },
}

recycling_turbine.energy_source.output_flow_limit = "9MW"

recycling_turbine.graphics_set = require ("__planet-muluna__.prototypes.entity.fusion-system-pictures").generator_graphics_set


recycling_turbine.max_health = 500

-- recycling_turbine.input_fluid_box.filter = "steam"
-- recycling_turbine.output_fluid_box.filter = "water"
recycling_turbine.minable.result = "muluna-cycling-steam-turbine"

local cooled_steam = util.merge{table.deepcopy(data.raw["fluid"]["steam"]),
    {
        name = "cooled-steam",
        default_temperature = 100,
        icons = {
            {
                icon = data.raw["fluid"]["steam"].icon,
                tint = {0.6,0.6,1},
            }
        }
    }


}

recycling_turbine.factoriopedia_description = nil



data:extend{recycling_turbine,cooled_steam}

