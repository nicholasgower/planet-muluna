--Extends Assembling machine
local telescope = Muluna.rro.merge(data.raw["assembling-machine"]["assembling-machine-3"],{
    type = "assembling-machine", --Extends Assembling machine
    name = "muluna-telescope",
    muluna_is_telescope = true,
    next_upgrade = "_nil",
    module_slots = 2,
    crafting_speed = 1,
    crafting_categories = {"muluna-telescope"},
    selection_box = Muluna.flib_bounding_box.from_dimensions({0,0},3,3),
    collision_box = Muluna.flib_bounding_box.from_dimensions({0,0},3-0.5,3-0.5),
    energy_usage = "2MW",
    --energy_source = table.deepcopy(data.raw["assembling-machine-3"].energy_source),
    effect_receiver = "",
    --per_surface_limit = 1, --Custom field: Number of telescopes per surface
    --circuit_connector = table.deepcopy(data.raw["assembling-machine-3"].circuit_connector),
    minable = {
        mining_time = 1,
        result = "muluna-telescope",
        amount = 1,
    },
    icon = "__space-exploration-graphics__/graphics/icons/telescope.png",
    icon_size = 64,
    graphics_set = {
      animation =
      {
        layers =
        {
          {
            filename = "__space-exploration-graphics-4__/graphics/entity/telescope/telescope.png",
            priority = "high",
            width = 2080/8,
            height = 2128/8,
            frame_count = 64,
            line_length = 8,
            shift = util.by_pixel(6, -19),
            animation_speed = 0.3,
            scale = 0.5,
          },
          {
            draw_as_shadow = true,
            filename = "__space-exploration-graphics-4__/graphics/entity/telescope/telescope-shadow.png",
            priority = "high",
            width = 2608/8,
            height = 1552/8,
            frame_count = 64,
            line_length = 8,
            shift = util.by_pixel(32, 7),
            animation_speed = 0.3,
            scale = 0.5,
          },
        },
      },
    },
    --icon = data.raw["item"]["muluna-telescope"].icon,
})

table.remove(telescope.fluid_boxes,1)
telescope.fluid_boxes[1].pipe_connections[1].connection_category = "data"
telescope.fluid_boxes[1].filter = "muluna-astronomical-data"
telescope.fluid_boxes[1].pipe_covers = nil
telescope.fluid_boxes[1].pipe_covers_frozen = nil
telescope.fluid_boxes[1].pipe_picture = nil
telescope.fluid_boxes[1].pipe_picture_frozen = nil

data:extend{telescope}

-- Muluna.rro.copy_fields(telescope,data.raw["assembling-machine"]["assembling-machine-3"],

--     {
--         "selection_box",
--         "collision_box",
--         "energy_source",
--         "effect_receiver",
--         "circuit_connector",
--         "graphics_set",
--     }
-- )

--Extends Assembling machine
-- local space_telescope = {
--     type = "muluna-space-telescope", 
--     name = "muluna-space-telescope",
--     crafting_speed = 1,
--     distance_speed_factor = 1, --Custom field: How much distance from Muluna adds to productivity
--     circuit_connector = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"].circuit_connector),
-- }

Muluna.rro.soft_insert(Muluna.constants.telescope_entities, --Entities with limited number of placements
    {name = "muluna-telescope",
    count = 1,    

})



-- rro.soft_insert(Muluna.constants.telescope_entities , {
--   name = "muluna-telescope",
--   combinator = 
-- })



data:extend{
  {
    type = "recipe-category",
    name = "muluna-telescope"
  },

}