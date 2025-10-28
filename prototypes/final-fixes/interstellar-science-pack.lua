
local pack_conditions = data.raw["mod-data"]["muluna-interstellar-science-pack-conditions"].data
local gated_technology = pack_conditions.gated_technology
local scripted_triggers = helpers.compare_versions(helpers.game_version,"2.0.69") >= 0


for _,pack in pairs(pack_conditions.science_packs) do
    table.insert(data.raw["technology"][pack].effects ,
        {
                type = "nothing",
                icons = {
                    {icon= "__muluna-graphics__/graphics/icons/green-rectangle.png", icon_size = 64},
                    {icon = data.raw["tool"]["interstellar-science-pack"].icon, shift = {0,0}, scale = 0.375},
                    {
                        icon = "__core__/graphics/icons/technology/effect-constant/effect-constant-recipe-productivity.png",
                        icon_size = 64,
                        --scale = 0.375,
                        --shift = {4,-8},
                        --draw_background = true,
                    }
                    
                },
                effect_description = { "technology-effect.contributes-to-discovery", gated_technology,{"technology-name.".. gated_technology},tostring(pack_conditions.required_science_packs)},
        }

    )
end

local tech = data.raw["technology"][gated_technology]

if scripted_triggers then
    tech.research_trigger = {
            type = "scripted",
            trigger_description = {"research-trigger.muluna-nanofoamed-polymers",tostring(data.raw["mod-data"]["muluna-interstellar-science-pack-conditions"].data.required_science_packs)},
            icons = {
                {
                    icon = data.raw["tool"]["metallurgic-science-pack"].icon,
                    icon_size = data.raw["tool"]["metallurgic-science-pack"].icon_size,
                    scale = 0.35,
                    shift = {0,-8},
                },
                {
                    icon = data.raw["tool"]["agricultural-science-pack"].icon,
                    icon_size = data.raw["tool"]["agricultural-science-pack"].icon_size,
                    scale = 0.35,
                    shift = {8,8},
                },
                {
                    icon = data.raw["tool"]["electromagnetic-science-pack"].icon,
                    icon_size = data.raw["tool"]["electromagnetic-science-pack"].icon_size,
                    scale = 0.35,
                    shift = {-8,8},
                },
                
            },
            icon = data.raw["tool"]["metallurgic-science-pack"].icon,
            icon_size = data.raw["tool"]["metallurgic-science-pack"].icon_size,
        }
    tech.enabled = true
    tech.visible_when_disabled = false
    else
    tech.unit = {
            count = 1,
            time = 1,
            ingredients = {}
        }
    tech.enabled = false
    tech.visible_when_disabled = true
end





tech.localised_description =  {scripted_triggers and "technology-description.muluna-nanofoamed-polymers-2069" or "technology-description.muluna-nanofoamed-polymers",tostring(data.raw["mod-data"]["muluna-interstellar-science-pack-conditions"].data.required_science_packs)}

tech.localised_description = {"",tech.localised_description or {"technology-description."..tech.name}}
local i = 0
local packs_list = ""
for _,pack in pairs(pack_conditions.science_packs) do
    
    if i <= 18 then
        table.insert(tech.localised_description,"\n[technology="..pack.."]")
        i = i + 1
    end
    
end

if scripted_triggers then 
    tech.research_trigger.trigger_description = tech.localised_description
    tech.localised_description = {"item-description.muluna-microcellular-plastic"}
end