local rro = Muluna.rro

--Forked from Maraxsis

local function is_square(entity) 
    if not entity.selection_box then return false end
    local width = Muluna.flib_bounding_box.width(entity.selection_box)
    local height = Muluna.flib_bounding_box.height(entity.selection_box)
    return math.ceil(width) == math.ceil(height)
end

local function contains_quality_name(entity) 

    for _,quality in pairs(data.raw["quality"]) do
        if string.find(entity,quality.name) then
            return true
        end
    end 

    for _,resource in pairs(data.raw["resource"]) do
        if string.find(entity,string.gsub(resource.name,"%-","%%-")) then
            return true
        end
    end 


    return false
end


for name,drill in pairs(data.raw["mining-drill"]) do
    if drill.energy_source.type == "electric" and drill.output_fluid_box == nil and is_square(drill) and not Muluna.constants.regolith_drills_blacklist[name] and not contains_quality_name(name) then
        Muluna.constants.regolith_drills[name] = {name = name}
    end

end



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
    local original_drill = data.raw["mining-drill"][digger.name]
    original_drill.custom_tooltip_fields = original_drill.custom_tooltip_fields or {}
    rro.soft_insert(original_drill.custom_tooltip_fields,{name = {"tooltip.digging-result-drill-on-X","[planet=muluna]"},value = "[item=muluna-lunar-regolith]"})
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
    local new_icon = {
                icon = data.raw["item"]["muluna-lunar-regolith"].icon,
                icon_size = data.raw["item"]["muluna-lunar-regolith"].icon_size,
                scale = 0.25,
                shift = {10,-10},
                draw_background = true,
        }
    if extractor.icons then
        rro.soft_insert(extractor.icons,new_icon)
    else
        extractor.icons = {
            {
                icon = extractor.icon or data.raw["mining-drill"]["electric-mining-drill"].icon,
                icon_size = extractor.icon_size or data.raw["mining-drill"]["electric-mining-drill"].icon_size,
            },
            new_icon
        }
    end
    extractor.icon = nil
    extractor.icon_size = nil
    data:extend {extractor}

    
end