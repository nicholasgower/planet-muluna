local science_packs = {}
local possible_science_packs = 
{
    "metallurgic-science-pack",
    "agricultural-science-pack",
    "electromagnetic-science-pack",
    "electrochemical-science-pack",
    "cerysian-science-pack",
    "janus-time-science-pack",
    --"slp-sunpack",
    "nanite-science-pack",
    --"insulation-science-pack",
    "battlefield-science-pack",
    --"igrys-mineral-science-pack",
    --"biorecycling-science-pack"
    --"craptonite-processing",
}

local special_cases = {
    ["slp-sunpack"] = "slp-sun-science-pack",
    ["igrys-mineral-science"] = "igrys-mineral-science",
    ["biorecycling-science-pack"] = "craptonite-processing"
}



for _,pack in pairs(possible_science_packs) do 
    if data.raw["tool"][pack] then
        table.insert(science_packs,pack)
    elseif data.raw["tool"][special_cases[pack]] then
        table.insert(science_packs,special_cases[pack])
    end
end

data:extend{
    {
        type = "mod-data",
        name = "muluna-interstellar-science-pack-conditions",
        data_type = "table",
        data = {
            science_packs = science_packs,
        }
    }


}