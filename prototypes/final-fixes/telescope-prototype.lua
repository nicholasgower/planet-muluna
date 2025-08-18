local flib_bounding_box = Muluna.flib_bounding_box
Muluna.constants.telescopes = {}
for _,entity in pairs(data.raw["assembling-machine"]) do
    if entity.muluna_is_telescope == true then
        --local telescope = table.deepcopy(entity)
        --telescope.type = "assembling-machine"
        local telescope_combinator = Muluna.rro.merge(data.raw["constant-combinator"]["constant-combinator"] ,
            {
                name = entity.name .. "-combinator",
                collision_box = entity.collision_box,
                map_generator_bounding_box = "_nil",
                minable = "_nil",
                sprites = "_nil",
                activity_led_sprites = "_nil",
                max_health = 10000,

            }
        )
        telescope_combinator.selection_box = flib_bounding_box.resize(entity.selection_box,0.0)
        telescope_combinator.selection_priority=49 --Default is 50
        entity.selection_box = flib_bounding_box.resize(entity.selection_box,-0.2)
        Muluna.constants.telescopes[entity.name] = {
            ["assembling-machine"] = entity.name,
            ["constant-combinator"] = telescope_combinator.name,
        }
        entity.muluna_is_telescope = false
        data:extend{telescope_combinator}
    end
end