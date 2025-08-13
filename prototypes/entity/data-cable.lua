local rro = Muluna.rro

local hit_effects = require("__base__.prototypes.entity.hit-effects")
local sounds = require("__base__.prototypes.entity.sounds")
local space_age_sounds = require ("__space-age__.prototypes.entity.sounds")

local data_cable = {
    type = "pipe",
    name = "muluna-data-cable",
    icon = "__Moshine__/graphics/icons/optical-fiber.png",
    flags = {"placeable-neutral", "player-creation"},
    minable = {mining_time = 0.1, result = "muluna-data-cable"},
    max_health = 10,
    corpse = "opticalfiber-remnants",
    dying_explosion = "pipe-explosion",
    icon_draw_specification = {scale = 0},
    resistances =
    {
      {
        type = "fire",
        percent = 30
      },
      {
        type = "impact",
        percent = 50
      }
    },
    fast_replaceable_group = "optical-cable",
    collision_box = {{-0.01, -0.01}, {0.01, 0.01}},
    selection_box = {{-0.4, -0.4}, {0.4, 0.4}},
    damaged_trigger_effect = hit_effects.entity(),
    fluid_box =
    {
      volume = 2,
      pipe_covers = opticalfibercoverspictures(), -- in case a real pipe is connected to a ghost --Only works if Moshine is installed
      --filter = "raw-data",
      pipe_connections =
      {
        { direction = defines.direction.north, position = {0, 0}, connection_category = "data" },
        { direction = defines.direction.east, position = {0, 0}, connection_category = "data" },
        { direction = defines.direction.south, position = {0, 0}, connection_category = "data" },
        { direction = defines.direction.west, position = {0, 0}, connection_category = "data" }
      },
      hide_connection_info = true,
      max_pipeline_extent = 50,
    },
    impact_category = "glass",
    pictures = opticalfiberpictures(), --Only works if Moshine is installed
    --working_sound = sounds.pipe,
    open_sound = sounds.metal_small_open,
    close_sound = sounds.metal_small_close,

    horizontal_window_bounding_box = {{-0.25, -0.28125}, {0.25, 0.15625}},
    vertical_window_bounding_box = {{-0.28125, -0.5}, {0.03125, 0.125}}
  }


rro.deep_replace(data_cable,"optical-cable","muluna-data-cable")



data:extend{data_cable}
