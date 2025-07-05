local rro = require("lib.remove-replace-object")

local dual_icon = require("lib.dual-item-icon").dual_icon
--local  = require("lib.remove-replace-object")
local i_lunar_pack = table.deepcopy(data.raw["tool"]["space-science-pack"])

local r_lunar_pack = table.deepcopy(data.raw["recipe"]["space-science-pack"])

local t_lunar_pack = table.deepcopy(data.raw["technology"]["space-science-pack"])

local all = {i_lunar_pack,r_lunar_pack,t_lunar_pack}


for _,entity in pairs(all) do
    entity.name = "interstellar-science-pack"
    entity.localised_name = {"item-name.interstellar-science-pack"}
    entity.localised_description = nil
end



i_lunar_pack.name = "interstellar-science-pack"
i_lunar_pack.default_import_location = "muluna"
i_lunar_pack.icon = "__muluna-graphics__/graphics/icons/space-science-pack.png"
i_lunar_pack.localised_description = {"item-description.science-pack"}

if i_lunar_pack.pictures then --Compatibility with glowing science packs
    i_lunar_pack.pictures.layers[1].filename="__muluna-graphics__/graphics/icons/space-science-pack.png"
    i_lunar_pack.pictures.layers[1].size=64
    i_lunar_pack.pictures.layers[1].scale = 0.5
end

r_lunar_pack.icon = "__muluna-graphics__/graphics/icons/space-science-pack.png"

--data.raw["recipe"]["space-science-pack"].icon = "__muluna-graphics__/graphics/icons/space-science-pack.png" --Why was this here?
t_lunar_pack.icon = "__muluna-graphics__/graphics/technology/space-science-pack.png"
t_lunar_pack.localised_description = {"technology-description.interstellar-science-pack",tostring(settings.startup["muluna-interstellar-science-pack-packs-required"].value)}
t_lunar_pack.prerequisites = { --These prerequisites are overridden by interstellar-science-pack-final-fix.
    --"electromagnetic-science-pack",
    --"agricultural-science-pack",
    --"metallurgic-science-pack",
    "kovarex-enrichment-process",
    "muluna-anorthite-processing",
    "asteroid-collector"

}
i_lunar_pack.order = "j[interstellar-science-pack]"
if data.raw["tool"]["hydraulic-science-pack"] then
    data.raw["tool"]["hydraulic-science-pack"].order = data.raw["tool"]["hydraulic-science-pack"].order .. "a"
end



r_lunar_pack.main_product = "interstellar-science-pack"
r_lunar_pack.category = "crafting-with-fluid"


if settings.startup["muluna-new-interstellar-pack-recipe"].value == true then
    r_lunar_pack.category = "double-boiler"
    r_lunar_pack.ingredients = {
        {type = "fluid", name = "helium", amount = 100},
        --{type = "item", name = "rocket-fuel", amount = 1},
        {type = "item", name = "space-platform-foundation", amount = 2},
        {type = "item", name = "uranium-fuel-cell", amount = 1}
    }
    r_lunar_pack.results = {{type = "item", name = "interstellar-science-pack", amount = 3}}
    r_lunar_pack.energy_required = 63
    local oxygen = 60*r_lunar_pack.energy_required
    table.insert(r_lunar_pack.ingredients,{type = "fluid", name = "oxygen", amount = oxygen})
    table.insert(r_lunar_pack.results,{type = "fluid", name = "carbon-dioxide", amount = oxygen, temperature = 500,ignored_by_productivity = oxygen})
else
    r_lunar_pack.ingredients = {
        {type = "fluid", name = "helium", amount = 400},
        {type = "item", name = "rocket-fuel", amount = 8},
        {type = "item", name = "aluminum-plate", amount = 40},
        {type = "item", name = "uranium-235", amount = 1}
    }
    r_lunar_pack.results = {{type = "item", name = "interstellar-science-pack", amount = 12}}
    r_lunar_pack.energy_required = 28
end

t_lunar_pack.research_trigger = nil
-- t_lunar_pack.research_trigger = {
--     --type = "craft-item",
--     --item = "iron-plate",
-- }
t_lunar_pack.unit = {
    count = 1,
    ingredients = {},
    time = 1,
}

-- t_lunar_pack.unit = {}

-- t_lunar_pack.unit.ingredients = {
--     {"automation-science-pack", 1},
--     {"logistic-science-pack", 1},
--     {"chemical-science-pack", 1},
--     {"production-science-pack", 1},
--     {"utility-science-pack", 1},
--     {"space-science-pack", 1},
--     {"metallurgic-science-pack", 1},
--     {"agricultural-science-pack", 1},
--     {"electromagnetic-science-pack", 1},
--     --{"cryogenic-science-pack", 1},
--     --{"interstellar-science-pack",1}
-- }

-- t_lunar_pack.unit.count = 1000
-- t_lunar_pack.unit.time= 60

t_lunar_pack.effects = {
    {type = "unlock-recipe", recipe = "interstellar-science-pack"},
    {type = "unlock-recipe", recipe = "muluna-microcellular-plastic-diffusion"},
    {type = "unlock-recipe", recipe = "muluna-microcellular-plastic-curing"},
}

-- local r_lunar_pack_4 = table.deepcopy(r_lunar_pack)
--r_lunar_pack_4.name = "interstellar-science-pack-helium-4"
r_lunar_pack.main_product = "interstellar-science-pack"
 data:extend(all)

-- r_lunar_pack_4.ingredients = {
--     {type = "fluid", name = "helium-4", amount = 100},
--     {type = "item", name = "rocket-fuel", amount = 2},
--     {type = "item", name = "aluminum-plate", amount = 2},
--     {type = "item", name = "uranium-235", amount = 2}
-- }

-- r_lunar_pack_4.localised_name = nil




--data:extend{r_lunar_pack_4}

