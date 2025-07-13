local science_packs = {}
local possible_science_packs = --Science pack technologies
{
    "metallurgic-science-pack",
    "agricultural-science-pack",
    "electromagnetic-science-pack",
    "electrochemical-science-pack",
    "cerysian-science-pack",
    "janus-time-science-pack",
    "slp-sunpack",
    "nanite-science-pack",
    --"insulation-science-pack",
    "battlefield-science-pack",
    --"igrys-mineral-science-pack",
    --"biorecycling-science-pack"
    --"craptonite-processing",
    "igrys-mineral-science",
    "rubia-progression-stage1B",
    "quantum-science-pack",
    "ring-science-pack",
    "anomaly-science-pack",
    "thermodynamic-science-pack",
    "aerospace-science-pack",
}

-- local special_cases = {
--     ["slp-sunpack"] = "slp-sun-science-pack",
--     ["igrys-mineral-science"] = "igrys-mineral-science",
--     ["biorecycling-science-pack"] = "craptonite-processing"
-- }

local gated_technology = "muluna-nanofoamed-polymers"

for _,pack in pairs(possible_science_packs) do 
    if data.raw["technology"][pack] then
        table.insert(science_packs,pack)
        --add_interstellar_pack_tooltip(data.raw["technology"][pack])
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
			effect_description = { "technology-effect.contributes-to-discovery", gated_technology,{"technology-name.".. gated_technology},tostring(settings.startup["muluna-interstellar-science-pack-packs-required"].value)},
	}

)
    --elseif data.raw["technology"][special_cases[pack]] then
    --    table.insert(science_packs,special_cases[pack])
    end
end

data:extend{
    {
        type = "mod-data",
        name = "muluna-interstellar-science-pack-conditions",
        data_type = "table",
        data = {
            science_packs = science_packs,
            gated_technology = gated_technology
        }
    }


}