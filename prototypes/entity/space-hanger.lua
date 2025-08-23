local hanger = {
    type = "assembling-machine",
    name = "muluna-space-hanger",
    icon = "__planet-muluna__/graphics/icons/space-hanger.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = "muluna-space-hanger"},
    max_health = 600,
    corpse = "big-remnants",
    dying_explosion = "big-explosion",
    collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
    selection_box = {{-2.5, -2.5}, {2.5, 2.5}},
    crafting_categories = {"muluna-space-hanger"},
    crafting_speed = 1,
    ingredient_count = 6,
    energy_source = {
        type = "electric",
        usage_priority = "secondary-input",
        emissions_per_minute = 2
    },
    energy_usage = "2MW",
    module_specification = {
        module_slots = 4,
        allowed_effects = {"consumption", "speed", "productivity", "pollution"}
    },
    allowed_effects = {"consumption", "speed", "productivity", "pollution"},
    animation = {
        filename = "__planet-muluna__/graphics/entity/space-hanger/space-hanger.png",
        width = 320,
        height = 320,
        frame_count = 1,
        shift = {0, 0}
    },
    working_visualisations = {},
    vehicle_impact_sound = {filename = "__base__/sound/car-metal-impact.ogg", volume = 0.65},
    working_sound = {
        sound = {filename = "__base__/sound/assembling-machine-t3-1.ogg", volume = 0.8},
        idle_sound = {filename = "__base__/sound/idle1.ogg", volume = 0.6},
        apparent_volume = 1.5
    },
    resistances = {
        {type = "fire", percent = 70},
        {type = "impact", percent = 30}
    },
    fast_replaceable_group = "assembling-machine",
    -- Custom field for productivity bonus, not used by base game, but can be referenced in control scripts
    muluna_productivity_bonus = 0.5

}