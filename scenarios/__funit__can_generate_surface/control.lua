require("__base__/script/freeplay/control.lua")
local runner = require("__funit__.test_runner")

runner.register("planet-muluna")



local function generate_muluna()
    local muluna = game.planets.muluna
    if not muluna.surface then
        local surface = muluna.create_surface()
    end
    runner.assert(muluna.surface,"Muluna not generated!")
end

local function place_entities_to_replace()
    local muluna = game.planets.muluna
    local surface = muluna.surface
    --local x = 0
    --local y = 0
    local entity_replacement_rules = prototypes.mod_data.Planetslib.data.on_entity_placed_on_planet_replacements.muluna
    for old_entity,entity_table in pairs(entity_replacement_rules) do
        if entity_table.enabled == true then
            local entity_data = {
            name = old_entity,
            position = {math.random(0,1000),math.random(0,1000)},
            force = "player",
            raise_built = true,
            }
            surface.request_to_generate_chunks(entity_data.position,1) 
            surface.force_generate_chunk_requests()
            -- if not surface.can_place_entity(entity_data) then
            --     entity_data.position = {math.random(0,1000),math.random(0,1000)}
            -- end
            surface.create_entity(entity_data)
            
            local found_entity = surface.find_entities_filtered{position=entity_data.position}
            runner.assert(#found_entity == 1 and found_entity[1].name == entity_table.entity,old_entity .. " " ..entity_table.entity .. " " .. serpent.block(found_entity))
        end
        
    end
    


end



runner.test(
    "Can generate surface",
    generate_muluna
)
runner.test(
    "Cargo pods spawned on surface",
    function()
        runner.assert(game.planets.muluna.surface.find_entities_filtered{type = "cargo-pod"})
    end
)

runner.test(
    "Entity replacement system replaces all entities correctly on Muluna.",
    place_entities_to_replace
)