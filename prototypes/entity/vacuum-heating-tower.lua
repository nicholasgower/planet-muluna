local heating_boiler = table.deepcopy(data.raw["assembling-machine"]["muluna-advanced-boiler"])
local heating_tower = data.raw["reactor"]["heating-tower"]

heating_boiler.name = "muluna-vacuum-heating-tower"

heating_boiler = util.merge{heating_boiler,
    {
        type = "heat-assembling-machine",
        heat_buffer = heating_tower.heat_buffer,
        consumption = "40MW",
        heat_buffer =
        {
            max_temperature = 1000,
            specific_heat = "5MJ",
            max_transfer = "10GW",
            minimum_glow_temperature = 50,
            connections =
            {
                {
                position = {0, -1.5},
                direction = defines.direction.north
                },
                -- {
                -- position = {1.5, 0},
                -- direction = defines.direction.east
                -- },
                -- {
                -- position = {0, 1.5},
                -- direction = defines.direction.south
                -- },
                -- {
                -- position = {-1.5, 0},
                -- direction = defines.direction.west
                -- },
            },

            heat_picture = apply_heat_pipe_glow(
            util.sprite_load("__space-age__/graphics/entity/heating-tower/heating-tower-glow", {
                scale = 0.5,
                blend_mode = "additive"
            }))
        },

        connection_patches_connected =
            {
            sheet = util.sprite_load("__space-age__/graphics/entity/heating-tower/heating-tower-pipes", {
                scale = 0.5,
                variation_count = 4
            })
        },

        connection_patches_disconnected =
            {
            sheet = util.sprite_load("__space-age__/graphics/entity/heating-tower/heating-tower-pipes-disconnected", {
                scale = 0.5,
                variation_count = 4
            })
        },

        heat_connection_patches_connected =
            {
            sheet = apply_heat_pipe_glow(
                util.sprite_load("__space-age__/graphics/entity/heating-tower/heating-tower-pipes-heat", {
                scale = 0.5,
                variation_count = 4
            }))
        },

        heat_connection_patches_disconnected =
            {
            sheet = apply_heat_pipe_glow(
                util.sprite_load("__space-age__/graphics/entity/heating-tower/heating-tower-pipes-heat-disconnected", {
                scale = 0.5,
                variation_count = 4
            }))
        },
        fluid_boxes = {
            {
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_connections =
                {
                {flow_direction = "input-output", direction = defines.direction.west, position = {-1.0, 0}},
                {flow_direction = "input-output", direction = defines.direction.east, position = {1.0, 0}},
                },
                production_type = "input",
                --filter = "water"
            },
            {
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_connections =
                {
                {flow_direction = "input-output", direction = defines.direction.west, position = {-1.0, 1}},
                {flow_direction = "input-output", direction = defines.direction.east, position = {1.0, 1}}
                },
                production_type = "input",
                --filter = "water"
            },
            {
                volume = 200,
                --pipe_covers = pipecoverspictures(),
                pipe_connections =
                {
                    {flow_direction = "output", direction = defines.direction.north, position = {0, 0.0}},
                },
                production_type = "heat-output",
                --filter = "steam"
                },
            {
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_connections =
                {
                    {flow_direction = "input-output", direction = defines.direction.west, position = {-1.0, -1}},
                    {flow_direction = "input-output", direction = defines.direction.east, position = {1.0, -1}}
                },
                production_type = "output",
                --filter = "steam"
            },
    },
    }
}

-- heating_boiler.type = "heat-assembling-machine"
data:extend{heating_boiler}