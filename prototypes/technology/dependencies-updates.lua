local rro=require("lib.remove-replace-object")


for _,tech in pairs(data.raw["technology"]) do
    if tech.prerequisites then
        rro.replace(tech.prerequisites,"space-platform-thruster","space-science-pack")
    end
    
end

data.raw["recipe"]["crusher"].subgroup = "smelting-machine"
data.raw["item"]["crusher"].subgroup = "smelting-machine"
data.raw["assembling-machine"]["crusher"].subgroup = "smelting-machine"
data.raw["item"]["crusher"].order = "ca[crusher]"


--replace_object(data.raw["technology"]["space-science-pack"].prerequisites,"space-platform-thruster","space-platform")
rro.replace(data.raw["technology"]["space-science-pack"].prerequisites,"space-platform","muluna-alice-propellant")
table.insert(data.raw["technology"]["space-science-pack"].prerequisites,"wood-gas-processing")
--table.insert(data.raw["technology"]["space-science-pack"].prerequisites,"muluna-oxide-asteroid-processing")
-- table.insert(data.raw["technology"]["space-platform-thruster"].effects,{
--     type="unlock-space-location",
--     space_location="muluna"
-- })
rro.remove(data.raw["technology"]["space-platform-thruster"].effects,{
    type="unlock-recipe",
    recipe="ice-melting"
})


data.raw["technology"]["space-platform-thruster"].unit=nil


-- if false or mods["aai-signal-transmission"] then
--     rro.replace(data.raw["technology"]["space-platform-thruster"].prerequisites,"space-science-pack","aai-signal-transmission")
--     data.raw["technology"]["space-platform-thruster"].research_trigger = {
--         type="build-entity",
--         entity="aai-signal-receiver"
--     }
--     rro.replace(data.raw["technology"]["aai-signal-transmission"].prerequisites,"space-science-pack","space-platform")
--     rro.remove(data.raw["technology"]["aai-signal-transmission"].unit.ingredients,{"space-science-pack",1})
-- else
    table.insert(data.raw["technology"]["space-platform-thruster"].prerequisites,"space-platform")
   
    data.raw["technology"]["space-platform-thruster"].research_trigger = data.raw["technology"]["space-platform"].research_trigger
    table.insert(data.raw["technology"]["space-platform-thruster"].prerequisites,"space-platform")
-- end

--rro.remove(data.raw["technology"]["space-platform-thruster"].unit.ingredients,{"space-science-pack",1})








--Removing asteroid collector,crusher, and asteroid crushing from space platform tech
local space_platform=data.raw["technology"]["space-platform"]
-- rro.remove(space_platform.effects,{type="unlock-recipe",recipe="asteroid-collector"})
-- rro.remove(space_platform.effects,{type="unlock-recipe",recipe="crusher"})
-- rro.remove(space_platform.effects,{type="unlock-recipe",recipe="metallic-asteroid-crushing"})
-- rro.remove(space_platform.effects,{type="unlock-recipe",recipe="carbonic-asteroid-crushing"})
-- rro.remove(space_platform.effects,{type="unlock-recipe",recipe="oxide-asteroid-crushing"})

-- if mods["aai-signal-transmission"] then
--     space_platform.effects = table.deepcopy(data.raw["technology"]["aai-signal-transmission"].effects)
--     rro.remove(space_platform.effects,{type="unlock-recipe",recipe="aai-signal-receiver"})
--     rro.remove(data.raw["technology"]["aai-signal-transmission"].effects,{type="unlock-recipe",recipe="aai-signal-sender"})
--     data.raw["technology"]["aai-signal-transmission"].unit=nil
--     data.raw["technology"]["aai-signal-transmission"].research_trigger = {
--         --type="send-item-to-orbit",
--         type="build-entity",
--         --item="aai-signal-sender"
--         entity="aai-signal-sender"
--     }
-- else
    space_platform.effects = {}
-- end

data.raw["technology"]["space-science-pack"].research_trigger = {
    type="build-entity",
    entity="muluna-steam-crusher"
}

data.raw["technology"]["space-science-pack"].localised_description={"technology-description.space-science-pack"}
data.raw["recipe"]["space-science-pack"].energy_required=settings.startup["space-science-pack-energy"].value --7 by default


--Moves rocket silo science packs down to prereqs, makes rocket silo into a trigger technology.
local techs_change={"logistic-robotics","rocket-fuel","processing-unit","advanced-material-processing-2","low-density-structure"}
for _,technology in pairs(techs_change) do
    if data.raw["technology"][technology] then
        data.raw["technology"][technology].unit.count = data.raw.technology[technology].unit.count + 200
    end
    
end

data.raw.technology["rocket-silo"].unit=nil
data.raw.technology["rocket-silo"].research_trigger={
    type="craft-item",
    item="logistic-robot",
    count=100,
}
if not (settings.startup["rocs-hardcore-push-back-logistic-system"] and settings.startup["rocs-hardcore-push-back-logistic-system"].value == true) then
    -- table.insert(data.raw.technology["logistic-robotics"].effects,{
    --     type="unlock-recipe",
    --     recipe="requester-chest",
    -- })

    -- rro.remove(data.raw.technology["logistic-system"].effects,{
    --     type="unlock-recipe",
    --     recipe="requester-chest",
    -- })

    --data.raw["technology"]["logistic-system"].unit.count=300

    rro.remove(data.raw["technology"]["logistic-system"].prerequisites , "space-science-pack")
    rro.soft_insert(data.raw["technology"]["logistic-system"].prerequisites , "space-platform")
    rro.remove(data.raw["technology"]["logistic-system"].unit.ingredients, {"space-science-pack", 1})
end



table.insert(data.raw["technology"]["rocket-part-productivity"].prerequisites,"production-science-pack")

--table.insert(data.raw["technology"]["advanced-asteroid-processing"].prerequisites,"muluna-advanced-stone-processing")
--table.insert(data.raw["technology"]["asteroid-reprocessing"].prerequisites,"muluna-advanced-stone-processing")

table.insert(data.raw["technology"]["wood-gas-processing"].prerequisites,"muluna-greenhouses")
rro.replace(data.raw["recipe"]["wood-gasification"].ingredients, {type = "item", name = "wood", amount = 10}, {type = "item", name = "cellulose", amount = 15})
--rro.replace(data.raw["recipe"]["advanced-wood-gasification"].ingredients, {type = "item", name = "wood", amount = 20}, {type = "item", name = "cellulose", amount = 20})
data.raw["recipe"]["wood-gasification"].allow_productivity = true
data.raw["recipe"]["advanced-wood-gasification"].allow_productivity = true
data.raw["technology"]["wood-gas-processing"].unit = nil
data.raw["technology"]["wood-gas-processing"].research_trigger = {
    type="mine-entity",
    entity="lunar-rock"
}
data.raw["technology"]["advanced-wood-gas-processing"].unit = {
    count = 500,
    time = 60,
    ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"production-science-pack", 1},
        {"utility-science-pack", 1},
        {"space-science-pack", 1},
        --{"interstellar-science-pack",1},
    }
}
data.raw["technology"]["wood-gas-processing-to-crude-oil"].unit = {
    count = 500,
    time = 60,
    ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"production-science-pack", 1},
        --{"utility-science-pack", 1},
        {"space-science-pack", 1},
        --{"interstellar-science-pack",1},
    }
}

table.insert(data.raw["technology"]["wood-gas-processing"].effects, {
    type = "unlock-recipe",
    recipe="plastic-from-wood"
})
table.insert(data.raw["technology"]["wood-gas-processing"].effects, {
    type = "unlock-recipe",
    recipe="woodchips"
})
table.insert(data.raw["technology"]["wood-gas-processing"].effects, {
    type = "unlock-recipe",
    recipe="cellulose"
})
-- table.insert(data.raw["technology"]["wood-gas-processing"].effects, {
--     type = "unlock-recipe",
--     recipe="cellulose"
-- })

--table.insert(data.raw["technology"]["advanced-wood-gas-processing"].prerequisites,"interstellar-science-pack")
--table.insert(data.raw["technology"]["wood-gas-processing-to-crude-oil"].prerequisites,"interstellar-science-pack")

-- data.raw["recipe"]["wood-greenhouse"].energy_required=10*60
-- data.raw["recipe"]["wood-seed-greenhouse"].energy_required=10*60
-- data.raw["recipe"]["wood-greenhouse"].surface_conditions={{property = "oxygen",min=1}}
-- data.raw["recipe"]["jellynut-seed-greenhouse"].energy_required=5*60
-- data.raw["recipe"]["yumako-seed-greenhouse"].energy_required=5*60
rro.remove(data.raw["technology"]["wood-gas-processing"].effects,{type = "unlock-recipe", recipe = "greenhouse"})
rro.remove(data.raw["technology"]["agriculture"].effects,{type = "unlock-recipe", recipe = "greenhouse"})
-- data.raw["recipe"]["greenhouse"] = nil
-- data.raw["item"]["I-greenhouse"] = nil
-- if data.raw["assembling-machine"]["E-greenhouse"] then
--     data.raw["assembling-machine"]["E-greenhouse"].minable = {mining_time = 0.5}
--     data.raw["assembling-machine"]["E-greenhouse"].localised_name = {"entity-name.n-deprecated",{"entity-name.E-greenhouse"}}
-- end

table.insert(data.raw["technology"]["heating-tower"].effects,
    
        {
            type = "unlock-recipe",
            recipe = "advanced-water-boiling-high-temperature",
        }
    
)
-- local seed_recipes = {"jellynut","yumako"}

-- for _,seed in pairs(seed_recipes) do
--     data.raw["recipe"][seed.."-seed-greenhouse"].surface_conditions = {{property = "oxygen",min=1}}--,{property = "pressure", min = 2000, max = 2000}}
-- end


--data.raw["item"]["E-greenhouse"]=nil
-- data.raw["recipe"]["greenhouse"].enabled = false

-- table.insert(data.raw["technology"]["tree-seeding"].effects, {
--     type = "unlock-recipe",
--     recipe="greenhouse"
-- })
local muluna_imports = {"carbon","ice"}

for _,item in pairs(muluna_imports) do
    data.raw["item"][item].default_import_location = "muluna"
end


data.raw["tool"]["space-science-pack"].default_import_location = "muluna"

data.raw["item"]["copper-cable"].localised_name = {"item-name.copper-cable"}


rro.soft_insert(data.raw["technology"]["coal-liquefaction"].effects, {type = "unlock-recipe", recipe = "coal-synthesis"})

if settings.startup["muluna-hardcore-restrict-crusher"].value == true then
    data.raw["recipe"]["crusher"].surface_conditions = {{property = "oxygen", max = 0, min = 0},{property = "gravity", max = 0.1, min = 0.1}}
    table.insert(data.raw["recipe"]["crusher"].ingredients, {type = "item", name = "aluminum-plate", amount = 10})
    data.raw["item"]["crusher"].default_import_location = "muluna"
end


if settings.startup["muluna-hardcore-restrict-asteroid-collector"].value == true then
    data.raw["recipe"]["asteroid-collector"].surface_conditions = {{property = "oxygen", max = 0, min = 0},{property = "gravity", max = 0.1, min = 0.1}}
    table.insert(data.raw["recipe"]["asteroid-collector"].ingredients, {type = "item", name = "aluminum-plate", amount = 10})
    data.raw["item"]["asteroid-collector"].default_import_location = "muluna"
end

local one_gravity_condition =
{
  {
    property = "gravity",
    min = 0.1
  }
}


data.raw["spider-vehicle"]["spidertron"].surface_conditions = one_gravity_condition
data.raw["legacy-curved-rail"]["legacy-curved-rail"].surface_conditions = one_gravity_condition
data.raw["legacy-straight-rail"]["legacy-straight-rail"].surface_conditions = one_gravity_condition
data.raw["locomotive"]["locomotive"].surface_conditions = one_gravity_condition
data.raw["cargo-wagon"]["cargo-wagon"].surface_conditions = one_gravity_condition
data.raw["fluid-wagon"]["fluid-wagon"].surface_conditions = one_gravity_condition
data.raw["artillery-wagon"]["artillery-wagon"].surface_conditions = one_gravity_condition
data.raw["train-stop"]["train-stop"].surface_conditions = one_gravity_condition
data.raw["rail-signal"]["rail-signal"].surface_conditions = one_gravity_condition
data.raw["rail-chain-signal"]["rail-chain-signal"].surface_conditions = one_gravity_condition
data.raw["curved-rail-b"]["curved-rail-b"].surface_conditions = one_gravity_condition
data.raw["curved-rail-a"]["curved-rail-a"].surface_conditions = one_gravity_condition
data.raw["half-diagonal-rail"]["half-diagonal-rail"].surface_conditions = one_gravity_condition
data.raw["straight-rail"]["straight-rail"].surface_conditions = one_gravity_condition

data.raw["rail-ramp"]["rail-ramp"].surface_conditions = one_gravity_condition
data.raw["elevated-straight-rail"]["elevated-straight-rail"].surface_conditions = one_gravity_condition
data.raw["elevated-half-diagonal-rail"]["elevated-half-diagonal-rail"].surface_conditions = one_gravity_condition
data.raw["elevated-curved-rail-a"]["elevated-curved-rail-a"].surface_conditions = one_gravity_condition
data.raw["elevated-curved-rail-b"]["elevated-curved-rail-b"].surface_conditions = one_gravity_condition
data.raw["rail-support"]["rail-support"].surface_conditions = one_gravity_condition
