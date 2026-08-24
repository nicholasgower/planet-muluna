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
                minable = entity.minable,
                sprites = "_nil",
                activity_led_sprites = "_nil",
                max_health = 10000,
                
            }
        )
        PlanetsLib.constants.pipette_result[telescope_combinator.name] = entity.name
        telescope_combinator.selection_box = flib_bounding_box.resize(entity.selection_box,0.0)
        telescope_combinator.selection_priority=49 --Default is 50
        telescope_combinator.factoriopedia_description={"entity-factoriopedia-description.muluna-telescope-combinator"}
        if not mods["quality"] then
            telescope_combinator.factoriopedia_description={"entity-factoriopedia-description.muluna-telescope-combinator-no-quality"}
            telescope_combinator.localised_description={"entity-description.muluna-telescope-combinator-no-quality"}
        end

        entity.selection_box = flib_bounding_box.resize(entity.selection_box,-0.4)
        entity.quality_indicator_shift = {-0.4,0.4}
        Muluna.constants.telescopes[entity.name] = {
            ["assembling-machine"] = entity.name,
            ["constant-combinator"] = telescope_combinator.name,
        }
        data.raw["mod-data"]["bplib"].data.extract_entity_names[entity.name] = true
        entity.muluna_is_telescope = false
        Muluna:extend{telescope_combinator}
    end
end

data:extend {{
    type = "sprite",
    name = "muluna-telescope-obscured-warning",
    filename = "__muluna-graphics__/graphics/icons/alerts/stars-obscured-icon.png",
    width = 64,
    height = 64,
    scale = 0.5,
    shift = {0, 0},
    flags = {"no-crop", "no-scale", "icon"},
}}