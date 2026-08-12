--forked from Maraxsis

Muluna:extend {{
    type = "recipe-category",
    name = "ground-digging"
}}

Muluna:extend {{
    type = "recipe",
    name = "muluna-regolith-digging",
    categories = {"ground-digging"},
    energy_required = 2,
    ingredients = {},
    results = {
        {type = "item", name = "muluna-lunar-regolith", amount = 1,shared_probability = {min = 0, max = 0.2}},
        {type = "item", name = "stone-crushed", amount = 1,shared_probability = {min = 0.2, max = 1},rigor_product = true}
    },
    rigor_invert = true,
    enabled = false,
    show_amount_in_title = false,
    allow_decomposition = false,
    allow_productivity = true,
    maximum_productivity = 9999999,
    main_product = "muluna-lunar-regolith",
    --rigor_no_results=true,
    auto_recycle = false,
    rigor_whitelist=mods["rigor-module"] and true
    --localised_name = {"item-name.sand"},
    --localised_description = {"item-description.sand"},
}}



Muluna:extend {{
    type = "custom-input",
    name = "build",
    key_sequence = "",
    linked_game_control = "build"
}}

Muluna:extend {{
    type = "custom-input",
    name = "rotate",
    key_sequence = "",
    linked_game_control = "rotate"
}}

Muluna:extend {{
    type = "custom-input",
    name = "reverse-rotate",
    key_sequence = "",
    linked_game_control = "rotate"
}}

Muluna:extend {{
    type = "custom-input",
    name = "build-ghost",
    key_sequence = "",
    linked_game_control = "build-ghost"
}}

Muluna:extend {{
    type = "custom-input",
    name = "super-forced-build",
    key_sequence = "",
    linked_game_control = "super-forced-build"
}}
