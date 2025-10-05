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
    "compression-science-pack",
    "omnia-omnite-processing",
    --"igrys-mineral-science-pack",
    --"biorecycling-science-pack"
    --"craptonite-processing",
    "igrys-mineral-science",
    "rubia-progression-stage1B",
    "quantum-science-pack",
    "ring-science-pack",
    "anomaly-science-pack",
    --"thermodynamic-science-pack",
    --"aerospace-science-pack",
    "tiberium-mechanical-research",
    "moshine-tech-ai-trainer",
    "pelagos-science-pack",
    "carnal-science-pack",
    "foliax-welcome",
    "arboric-science-pack",
}

-- Other mods can use the field "muluna_adds_progress_to_exploration_science_pack" to make a technology contribute progress to the exploration science pack.
for _,tech in pairs(data.raw["technology"]) do
    if tech.muluna_adds_progress_to_exploration_science_pack == true then
        table.insert(possible_science_packs,tech.name)
    elseif tech.muluna_adds_progress_to_exploration_science_pack == false then
        Muluna.rro.remove(possible_science_packs,tech.name)
    end
end

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
        
    --elseif data.raw["technology"][special_cases[pack]] then
    --    table.insert(science_packs,special_cases[pack])
    end
end

local required_science_packs

if settings.startup["muluna-interstellar-science-pack-dynamic-packs-required"].value == false then
    required_science_packs = settings.startup["muluna-interstellar-science-pack-packs-required"].value
else
    local percentage = settings.startup["muluna-interstellar-science-pack-dynamic-packs-required-percentage-required"].value / 100
    required_science_packs = math.ceil(#science_packs*percentage)
end


data:extend{
    {
        type = "mod-data",
        name = "muluna-interstellar-science-pack-conditions",
        data_type = "table",
        data = {
            science_packs = science_packs,
            gated_technology = gated_technology,
            required_science_packs = required_science_packs
        }
    }


}