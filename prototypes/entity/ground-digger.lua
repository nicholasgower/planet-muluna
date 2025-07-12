--forked from Maraxsis

data:extend {{
    type = "recipe-category",
    name = "ground-digging"
}}

data:extend {{
    type = "recipe",
    name = "muluna-regolith-digging",
    category = "ground-digging",
    energy_required = 10,
    ingredients = {},
    results = {
        {type = "item", name = "muluna-lunar-regolith", amount = 1,probability = 0.25},
        {type = "item", name = "stone-crushed", amount = 1}
    },
    enabled = false,
    show_amount_in_title = false,
    allow_decomposition = false,
    allow_productivity = true,
    maximum_productivity = 9999999,
    main_product = "muluna-lunar-regolith",
    auto_recycle = false,
    --localised_name = {"item-name.sand"},
    --localised_description = {"item-description.sand"},
}}



data:extend {{
    type = "custom-input",
    name = "build",
    key_sequence = "",
    linked_game_control = "build"
}}

data:extend {{
    type = "custom-input",
    name = "rotate",
    key_sequence = "",
    linked_game_control = "rotate"
}}

data:extend {{
    type = "custom-input",
    name = "reverse-rotate",
    key_sequence = "",
    linked_game_control = "rotate"
}}

data:extend {{
    type = "custom-input",
    name = "build-ghost",
    key_sequence = "",
    linked_game_control = "build-ghost"
}}

data:extend {{
    type = "custom-input",
    name = "super-forced-build",
    key_sequence = "",
    linked_game_control = "super-forced-build"
}}
