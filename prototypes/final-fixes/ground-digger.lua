--Forked from Maraxsis

for i = 1, 50 do
    local mining_productivity = data.raw["technology"]["mining-productivity-" .. i]
    if not mining_productivity then break end

    table.insert(mining_productivity.effects, 
    {
        type = "change-recipe-productivity",
        recipe = "muluna-regolith-digging",
        change = 0.1,
        hidden = true
    }
    -- {
    --     type = "change-recipe-category-productivity",
    --     recipe = "ground-digging",
    --     change = 0.1,
    --     hidden = true
    -- }
)
end

for _,digger in pairs(Muluna.constants.regolith_drills) do
    if not data.raw["mining-drill"][digger.name] then error("Invalid ground digger: " .. digger.name) end
    local extractor = table.deepcopy(data.raw["mining-drill"][digger.name])
    extractor.type = "assembling-machine"
    extractor.crafting_categories = {"ground-digging"}
    extractor.placeable_by = {item = extractor.name, count = 1}
    extractor.localised_name = {"entity-name.x-ground-digger",extractor.localised_name or {"entity-name." .. extractor.name}}
    extractor.localised_description = {"recipe-description.muluna-regolith-digging"}
    --extractor.localised_description = extractor.localised_description or {"?", {"entity-description." .. extractor.name}, ""}
    extractor.hidden_in_factoriopedia = false
    extractor.fixed_recipe = "muluna-regolith-digging"
    extractor.fixed_quality = "normal"
    extractor.crafting_speed = extractor.mining_speed
    extractor.mining_speed = nil
    extractor.fast_replaceable_group = (extractor.fast_replaceable_group or extractor.name) .. "-ground-digger"
    extractor.next_upgrade = nil
    extractor.allowed_effects = {"productivity", "consumption", "speed", "pollution", "quality"}
    extractor.resource_drain_rate_percent = nil
    extractor.name = extractor.name .. "-ground-digger"
    data:extend {extractor}

    digger.width = digger.size -- To keep things simple, assume only square mining drills
    digger.height = digger.width
    digger.offset_width = digger.width/2 + 0.5
    digger.offset_height = digger.height/2 + 0.5
end