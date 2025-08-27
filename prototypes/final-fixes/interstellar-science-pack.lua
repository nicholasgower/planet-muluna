
local pack_conditions = data.raw["mod-data"]["muluna-interstellar-science-pack-conditions"].data
local gated_technology = pack_conditions.gated_technology



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
tech.localised_description =  {"technology-description.muluna-nanofoamed-polymers",tostring(data.raw["mod-data"]["muluna-interstellar-science-pack-conditions"].data.required_science_packs)}
for _,pack in pairs(pack_conditions.science_packs) do
    tech.localised_description = {"",tech.localised_description or {"technology-description."..tech.name},"\n[technology="..pack.."]"}
    
end