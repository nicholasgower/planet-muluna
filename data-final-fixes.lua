local rro = Muluna.rro

local function delete_tech(deleted_tech,new_tech)
    for _,effect in pairs(data.raw["technology"][deleted_tech].effects) do
        if effect.type == "unlock-recipe" then
            if new_tech then
                rro.soft_insert(data.raw["technology"][new_tech].effects, 
                {
                    type = "unlock-recipe",
                    recipe = data.raw["recipe"][effect.recipe].name,
                }
            )
            else
                data.raw["recipe"][effect.recipe].enabled = true
            end
        end
    end
    data.raw["technology"][deleted_tech] = nil
    
    for _,technology in pairs(data.raw["technology"]) do
        if rro.contains(technology.prerequisites,deleted_tech) then
            rro.remove(technology.prerequisites,deleted_tech)
            if new_tech and (not technology.prerequisites or #technology.prerequisites == 0)  then
                rro.soft_insert(technology.prerequisites,new_tech)
            end
        end
    end
end


if mods["bztitanium"] or mods["bzcarbon"] or mods["bztin"] or mods["bzlead"] or mods["bzzirconium"] or mods["bzsilicon"] then
    require("prototypes.recipe.vanilla-alternate-recipes")
end

require("prototypes.technology.interstellar-technologies")
require("prototypes.final-fixes.ground-digger")
require("prototypes.final-fixes.recipe-productivity-technology")
require("prototypes.overrides.telescope-data")
require("prototypes.final-fixes.telescope-prototype")

--Overrides any mods which add their own techs to space platform thruster as a prereq.
--Moves prereq to asteroid collector, which is roughly equivalent to space platform thruster's place in the vanilla tech tree.
local new_prereqs={}


if settings.startup["muluna-easy-vanilla-rocket-part-costs"].value == false then
    for _,silo in pairs(data.raw["rocket-silo"]) do
        silo.crafting_speed = silo.crafting_speed/2
        if silo.module_slots then 
            silo.module_slots = silo.module_slots * 2
        end
    end
end


for _,technology in pairs(data.raw["technology"]["space-platform-thruster"].prerequisites) do
    
    if technology ~= "afterburner" and technology ~= "aai-signal-transmission" and technology ~= "space-platform" then
        --rro.remove(data.raw["technology"]["space-platform-thruster"].prerequisistes,technology)
        rro.soft_insert(data.raw["technology"]["asteroid-collector"].prerequisites,technology)
    else
        rro.soft_insert(new_prereqs,technology)
    end

end
data.raw["technology"]["space-platform-thruster"].prerequisites = new_prereqs



if settings.startup["muluna-easy-vanilla-rocket-part-costs"].value == false then
    --Doubles the change associated with infinite rocket part productivity technology.
    --Also adds support in case Hardcore is installed.
    if data.raw["technology"]["rocket-part-productivity-aquilo"] then
        for _,effect in pairs(data.raw["technology"]["rocket-part-productivity-aquilo"].effects) do 
            effect.change = effect.change * 2
        end
        --game.print("Error: Technology \"rocket-part-productivity-aquilo\" deleted by another mod. Please report this error to MeteorSwarm.")
    end

    for i = 1,10,1 do 
        if data.raw["technology"]["rocket-part-productivity-aquilo-"..tostring(i)] then
            for _,effect in pairs(data.raw["technology"]["rocket-part-productivity-aquilo-"..tostring(i)].effects) do 
                effect.change = effect.change * 2
            end
            --game.print("Error: Technology \"rocket-part-productivity-aquilo\" deleted by another mod. Please report this error to MeteorSwarm.")
        end
    end
end

if data.raw["technology"]["fluid-handling"] then
    local barreling_tech = rro.merge(data.raw["technology"]["fluid-handling"],{
        type = "technology",
        name = "fluid-barreling",
        prerequisites = {"fluid-handling"},
        effects = {},
        icons = {
            {
                icon = data.raw["technology"]["fluid-handling"].icon or "__base__/graphics/technology/fluid-handling.png",
                icon_size = data.raw["technology"]["fluid-handling"].icon_size or 256,
            },  
            {
                icon = data.raw["item"]["barrel"].icon,
                icon_size=data.raw["item"]["barrel"].icon_size,
                --scale=0.3,
                shift = {45,45},
                scale=0.75,
            },
            
        },
        unit = "_nil",
        research_trigger = {
            type = "craft-item",
            item = "barrel",
        }
    })

    -- for i,effect in pairs(data.raw["technology"]["fluid-handling"].effects) do
    --     if effect.type == "unlock-recipe" and string.find(effect.recipe,"%-barrel") then
    --         table.insert(barreling_tech.effects,effect)
    --         data.raw["technology"]["fluid-handling"].effects[i] = nil
    --     end
    -- end

    
        for i = #data.raw["technology"]["fluid-handling"].effects, 1, -1 do -- Iterate backward to avoid index shifting
        local effect = data.raw["technology"]["fluid-handling"].effects[i]
            if effect.type == "unlock-recipe" and string.find(effect.recipe,"%-barrel") then
                table.insert(barreling_tech.effects,effect)
                table.remove(data.raw["technology"]["fluid-handling"].effects, i)
            end
        end
rro.soft_insert(data.raw["technology"]["thruster-oxidizer"].prerequisites,barreling_tech.name)
data:extend{barreling_tech}

end





if data.raw["technology"]["planet-discovery-nauvis"] then
    rro.replace(data.raw["technology"]["planet-discovery-nauvis"].prerequisites,"space-platform-thruster","asteroid-collector")
end

data.raw["lab"]["cryolab"].inputs = data.raw["lab"]["biolab"].inputs

-- if mods["metal-and-stars"] then
--     data.raw["technology"]["space-chest-muluna"] = nil
-- end


local function get_boiler_quality_description(quality) 
    local quality_name = quality.localised_name or {"quality-name." .. quality.name}

    local quality_level = quality.level
    --if quality_level >= 5 and not mods["infinite-quality-tiers"] then quality_level = quality_level - 1 end

    local efficiency = 150*(1+0.3*quality_level)
    

    return {"recipe-description.global-advanced-boiler-quality-description", quality.name, tostring(efficiency)}
end

local electricity_description = {""} --Based on Maraxsis code for custom quality labels
local boiler_description = {""}
        local i = 0
        for _, quality in pairs(data.raw.quality) do
            if quality.hidden or i >= 8 then goto continue end
            local quality_name = quality.localised_name or {"quality-name." .. quality.name}

            local quality_level = quality.level
            --if quality_level >= 5 and not mods["infinite-quality-tiers"] then quality_level = quality_level - 1 end

            local multiplier = 1/(1+0.3*quality_level)
            local drain = string.format("%.2f",settings.startup["platform-power-consumption"].value * multiplier)
            local tiles = tostring(100 *(1+0.3*quality_level))
            table.insert(electricity_description, {"recipe-description.global-nav-beacon-quality-description", quality.name, drain, tiles})
            table.insert(electricity_description, "\n")
            
            table.insert(boiler_description, get_boiler_quality_description(quality))
            table.insert(boiler_description, "\n")


            i = i + 1
            ::continue::
        end
        electricity_description[#electricity_description] = nil
        boiler_description[#boiler_description] = nil
        --electricity_description = maraxsis.shorten_localised_string(electricity_description)

if data.raw["assembling-machine"]["muluna-advanced-boiler"] then
    
    if not data.raw["assembling-machine"]["muluna-advanced-boiler"].quality_affects_energy_usage then
        data.raw["assembling-machine"]["muluna-advanced-boiler"].factoriopedia_description = {"",{"entity-description.muluna-advanced-boiler"},"\n",boiler_description}
    else
        
        --data.raw["assembling-machine"]["muluna-advanced-boiler"].localised_description = {"",{"entity-description.muluna-advanced-boiler"},"\n",{"recipe-description.global-advanced-boiler-efficiency-description","150"}}
    end
end

if helpers.compare_versions(helpers.game_version,"2.0.59") == -1 then
  if data.raw["accumulator"]["muluna-satellite-radar"] then
    data.raw["accumulator"]["muluna-satellite-radar"].factoriopedia_description = {"",{"entity-description.muluna-satellite-radar"},"\n",electricity_description}
    end
    if data.raw["item"]["muluna-satellite-radar"] then
        data.raw["item"]["muluna-satellite-radar"].factoriopedia_description = {"",{"item-description.muluna-satellite-radar"},"\n",electricity_description}
    end
end


-- navBeaconItem.localised_description = {"",{"item-description.nav-beacon"},"\n",electricity_description}
data.raw["recipe"]["copper-cable"].localised_name={"recipe-name.copper-cable"}

require("compat.aai-industry")
--require("prototypes.technology.interstellar-science-pack-final-fix")
require("prototypes.final-fixes.nav-beacon-final-fix")
require("prototypes.final-fixes.data-cells")
require("prototypes.final-fixes.interstellar-science-pack")
--require("prototypes.entity.vanilla-entity-shadows")
if data.raw["technology"]["tree-seeding"] and not data.raw.planet.lignumis then --Removed vanilla/wood-gasification recipes from tree seeding, then deletes the tech if no other mods add recipes to the tech.
--Technologies that have this tech as a prerequisite are moved to having agricultural science pack as the prerequisite.
    --rro.remove(data.raw["technology"]["tree-seeding"].effects, {type = "unlock-recipe", recipe = "wood-processing"})
    rro.remove(data.raw["technology"]["tree-seeding"].effects, {type = "unlock-recipe", recipe = "wood-seed-greenhouse"})
    -- if #data.raw["technology"]["tree-seeding"].effects == 0 then
    --     delete_tech("tree-seeding","agricultural-science-pack")
    -- end
    
end
local flib_prototypes = require("__flib__.prototypes")
-- Train gravity conditions: All train-related entities with min gravity <=1 will be further lowered to 0.1
for _,entity in pairs(flib_prototypes.all("entity")) do
    --print(entity.name)
    if 
        rro.contains({
            "car","locomotive","cargo-wagon",
            "fluid-wagon","train-stop","artillery-wagon",
            "rail-signal","rail-chain-signal","curved-rail-b",
            "curved-rail-a","half-diagonal-rail","straight-rail",
            "rail-ramp","elevated-straight-rail","elevated-half-diagonal-rail",
            "elevated-curved-rail-a","elevated-curved-rail-b",
            "rail-support","car","spider-vehicle","cargo-landing-pad"
            },
        
            entity.type)
        and
            
        (entity.surface_conditions and rro.contains(entity.surface_conditions,{property="gravity",min=rro.predicates.compare("<=",1)}))
        
    then
        --print("Burner energy source in " .. entity.name)
        PlanetsLib.relax_surface_conditions(entity, {
            property = "gravity",
	        min = 0.1,
        })
        
    end
end

--Recycling recipe fixes

local cable_recycling = table.deepcopy(data.raw["recipe"]["copper-cable-recycling"])
local cable_recycling_muluna = table.deepcopy(cable_recycling)
cable_recycling_muluna.name = cable_recycling.name .. "-muluna"
cable_recycling_muluna.results[1].name = "aluminum-plate"
cable_recycling_muluna.surface_conditions = {
    {
        property = "is-muluna",
        min = 1,
        max = 1,
    },
    -- {
    --     property = "oxygen",
    --     min = 0,
    --     max = 0,
    -- }
}

cable_recycling.surface_conditions = {
    {
        property = "is-muluna",
        min = 0,
        max = 0,
    },

}

for _,entity in pairs(Muluna.flib_prototypes.all("entity")) do
    --print(entity.name)
    if 
        entity.energy_source and 
        ((
            entity.energy_source.type == "burner" and
            rro.contains(entity.energy_source.fuel_categories,"chemical") and
            not rro.contains({"car","locomotive"},entity.type) and
            not rro.contains(Muluna.constants.oxygen_restriction_blacklist,entity.name) and
            not (entity.type == "assembling-machine" and (rro.contains(entity.crafting_categories,"double-boiler") or rro.contains(entity.crafting_categories,"muluna-vacuum-heating-tower"))) 
        )
            or
        (
            entity.energy_source.type == "fluid" and 
            entity.energy_source.burns_fluid == true
        ))
    then
        --print("Burner energy source in " .. entity.name)
        PlanetsLib.restrict_surface_conditions(entity, {
            property = "oxygen",
	        min = 1,
        })
        
    end
end

if settings.startup["override-space-connection"].value == true then
  
    for _,connection in pairs(data.raw["space-connection"]) do
        local from = data.raw["planet"][connection.from] or data.raw["space-location"][connection.from]
        local to = data.raw["planet"][connection.to] or data.raw["space-location"][connection.to]

        if connection.name ~= "nauvis-muluna" then
            if connection.from == "nauvis" and to.subgroup ~= "satellites" then connection.from = "muluna" end
            if connection.to == "nauvis" and from.subgroup ~= "satellites" then connection.to = "muluna" end
            --rro.replace(connection.to,"nauvis","muluna")
        end
        
    end
  

end


data:extend{cable_recycling_muluna,cable_recycling}

if data.raw["container"]["bottomless-chest"] then --If version >= 2.0.57
    for _,quality in pairs(data.raw["quality"]) do
        quality.crafting_machine_energy_usage_multiplier = quality.default_multiplier or (1+ 0.3*quality.level)
    end
end


require("prototypes.custom-prototypes.final-fixes.heat-assembling-machine-final-fix")

for _,location in pairs(Muluna.flib_prototypes.all("space-location")) do
    print(location.name .. ": " .. tostring(Muluna.telescopes.shortest_space_distance("nauvis",location.name)))
end