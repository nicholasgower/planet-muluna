local rro = require("lib.remove-replace-object")

local Public = {}

local function random_place(surface,item_name,item_count)
    --if item_count == nil then item_count = 1 end
    local x = math.random(-128,128)+math.random(-128,128)
    local y = math.random(-128,128)+math.random(-128,128)
    local entity = {name = "fulgoran-cargo-pod-container", position = {x,y}, force = "player"}
    if surface.can_place_entity(entity) == false then
        entity.position[1] = entity.position[1] + math.random(-8,8)
        entity.position[2] = entity.position[2] + math.random(-8,8) 
    end
    local chest = surface.create_entity(entity)
    chest.get_output_inventory().insert({name = item_name,count = item_count or 1})
end

local function random_place_entity(surface,entity_name)

    local x = math.random(-128,128)+math.random(-128,128)
    local y = math.random(-128,128)+math.random(-128,128)
    local entity = {name = entity_name, position = {x,y}, force = "player"}
    if surface.can_place_entity(entity) == false then
        entity.position[1] = entity.position[1] + math.random(-8,8)
        entity.position[2] = entity.position[2] + math.random(-8,8)
    end
    surface.create_entity(entity)
    --chest.get_output_inventory().insert({name = entity,count = 1})
end

local function place_muluna_cargo_pods() 

    -- game.print("Muluna created")
    local muluna = game.planets["muluna"].surface
        
    for i = 1,math.random(3,5) do
        random_place(muluna,"crusher",math.random(3,5))
    end
    for i = 1,math.random(3,5) do
        random_place(muluna,"plastic-bar",math.random(20,40))
    end
    for i = 1,math.random(2,4) do
        random_place(muluna,"electric-furnace",math.random(1,3))
    end
    for i = 1,math.random(2,4) do
        random_place(muluna,"electric-mining-drill",math.random(1,3))
    end
    for i = 1,math.random(2,4) do
        random_place(muluna,"pipe",math.random(10,20))
    end
    for i = 1,math.random(2,4) do
        random_place(muluna,"pipe-to-ground",math.random(2,5))
    end
    for i = 1,math.random(2,4) do
        random_place(muluna,"chemical-plant",math.random(1,3))
    end
    for i = 1,math.random(3,10) do
        random_place(muluna,"solar-panel",math.random(1,3))
    end
    for i = 1,math.random(3,10) do
        random_place(muluna,"medium-electric-pole",math.random(1,3))
    end
    for i = 1,1 do
        random_place(muluna,"tungsten-plate",math.random(2,5)+math.random(2,5))
    end
    for i = 1,2 do
        random_place(muluna,"holmium-plate",math.random(2,5)+math.random(2,5))
    end
    for i = 1,2 do
        random_place(muluna,"superconductor",math.random(2,5)+math.random(2,5))
    end
    for i = 1,1 do
        random_place(muluna,"carbon-fiber",math.random(2,5)+math.random(2,5))
    end
    for i = 1,math.random(3,7) do
        random_place(muluna,"spoilage",math.random(20,50)+math.random(20,50))
    end
    local mods = script.active_mods
    local mod_list = { --A bunch of items from various mods to make it seem like many years ago, an ancient Fulgoran ship dropped a bunch of cargo in this area.
        moshine = "moshine-tech-magnet",
        maraxsis = "maraxsis-wyrm-specimen",
        corrundum = "platinum-plate",
        secretas = "gold-plate",
        tenebris = "quartz-crystal",
        ["tenebris-prime"] = "quartz-crystal",
        --janus = "janus-shiftite-alpha",
        castra = "nickel-plate",
        ["dea-dia-system"] = "fossil",
        terrapalus = "palusium-plate"
    }
    for mod,item in pairs(mod_list) do
        if mods[mod] and math.random(1,10)>3 then
            for i = 1,1 do
                random_place(muluna,item,math.random(2,5)+math.random(2,5))
            end
        end
    end
    if mods["moshine"] then
        
    end
    for i = 1,10 do
        random_place_entity(muluna,"lunar-rock")
    end


    for i = 1,4 do
        random_place(muluna,"tree-seed",math.random(2,6)+math.random(3,7))
    end
    for i = 1,1 do
        random_place(muluna,"wood",math.random(5,12)+math.random(5,13))
    end
    local random_chance_table = {
        {"foundry",2,1},
        {"electromagnetic-plant",4,1},
        {"big-mining-drill",6,math.random(1,3)+math.random(1,3)},
        {"cryogenic-plant",7,1},

    }
    if mods["maraxsis"] then
        table.insert(random_chance_table,{"maraxsis-hydro-plant",8,1})
    end
    for i = 1,2 do 
        local dice_roll = math.random(1,200)
        for _,item in pairs(random_chance_table) do
            if dice_roll<= item[2] then
                random_place(muluna,item[1],item[3])
                break
            end
        end
    end
    -- for i = 1,10 do
        --     random_place(muluna,"accumulator")
        -- end

        -- local chests = muluna.find_entities_filtered{name = "cargo-pod-container"}

        -- --if spaceship[1] then spaceship = spaceship[1] else spaceship = nil end

        -- for _,chest in pairs(chests) do
        --     chest.get_output_inventory().insert({name = "wood",count = 25})
        -- end


end

function Public.on_new_surface(muluna_index)
-- 3 crushers
-- 10 solar panels
-- 10 medium poles
-- 10 accumulators
-- game.print(muluna_index)
-- if game.planets["muluna"].surface then
--     game.print(game.planets["muluna"].surface.index)
-- end

    if game.planets["muluna"].surface and game.planets["muluna"].surface.index == muluna_index then
        if settings.startup["muluna-hardcore-remove-starting-cargo-pods"].value == true then 
            if settings.startup["aps-planet"] and settings.startup["aps-planet"].value == "muluna" then
                game.print({"console.muluna-incompatible-aps-setting"})
            end
        end
        if settings.startup["muluna-hardcore-remove-starting-cargo-pods"].value == false then
            place_muluna_cargo_pods()  
        end
        
        
        
    end




end

return Public