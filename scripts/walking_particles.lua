
if settings.startup["muluna-graphics-enable-footstep-animations"].value == true then
    local vectors = Muluna.vectors
    local m = 0.01 local r = 0.005
    local direction_vectors = { --Velocity vector used to set velocity of kicked up particles.
        North = {0,m},	
        NorthNorthEast = {-m/math.sqrt(2),m/math.sqrt(2)},	
        NorthEast = {-m/math.sqrt(2),m/math.sqrt(2)},
        EastNorthEast = {-m/math.sqrt(2),m/math.sqrt(2)},
        East = {-m,0},	
        EastSouthEast = {-m/math.sqrt(2),-m/math.sqrt(2)},
        SouthEast = {-m/math.sqrt(2),-m/math.sqrt(2)},
        SouthSouthEast = {-m/math.sqrt(2),-m/math.sqrt(2)},
        South = {0,-m},	
        SouthSouthWest = {m/math.sqrt(2),-m/math.sqrt(2)},
        SouthWest = {m/math.sqrt(2),-m/math.sqrt(2)},
        WestSouthWest = {m/math.sqrt(2),-m/math.sqrt(2)},
        West = {m,0},
        WestNorthWest = {m/math.sqrt(2),m/math.sqrt(2)},
        NorthWest = {m/math.sqrt(2),m/math.sqrt(2)},
        NorthNorthWest = {m/math.sqrt(2),m/math.sqrt(2)},
    }

local function cached_direction_to_string(x)
    local s = storage.cached_direction_to_string[x]
    if s == nil then
        s = helpers.direction_to_string(x)
        storage.cached_direction_to_string[x] = s
    end
    return s
end

    
local step_process_tick_rate = 1
local function update_player_step_tick_rate(i,player_table)
        --if not (player.connected and player.surface.name == "muluna") then goto continue end
        --player.print(player.name)
        local player = player_table.player
        local speed
        if storage.player_control_method[i] == defines.input_method.game_controller then
            speed = player_table.delta_position and math.sqrt( player_table.delta_position.x^2 + player_table.delta_position.y^2) or player.character_running_speed
        else
            speed = player.character_running_speed or 0
        end
        
        local tick_rate = storage.walking_tick_rates[i]
        storage.walking_tick_rates[i] = step_process_tick_rate*math.ceil(30/(speed/0.075)/step_process_tick_rate)
        --player.print(storage.walking_tick_rates[i])
        --player.print(speed)
        ::continue::

    end
 


    
    local function update_step_tick_rates(event)
            for i,player_table in pairs(storage.players_on_muluna) do
                update_player_step_tick_rate(i,player_table)
            end
        --end
    end
    

    Muluna.events.on_nth_tick(60, update_step_tick_rates)
    Muluna.events.on_event({defines.events.on_player_armor_inventory_changed}, update_step_tick_rates)

    Muluna.events.on_event(Muluna.events.events.on_init(),function()
        storage.players_on_muluna = {}
    end
    )
    Muluna.events.on_event({defines.events.on_player_changed_surface}, function(event)
        local id = event.player_index
        local player = game.players[event.player_index]
        if not storage.players_on_muluna then storage.players_on_muluna = {} end
        if player.surface.name == "muluna" then
            storage.players_on_muluna[event.player_index] = {player = player}
            update_step_tick_rates(event)
        else
            storage.players_on_muluna[event.player_index] = nil
            storage.players_walking_on_muluna[event.player_index] = nil
        end


    end

    
    
    )


    -- local profiler_exp = helpers.create_profiler()
    --     game.print(helpers.evaluate_expression("L^12+36*L+500",{L = 64}))
    --     game.print({"",profiler_exp,"expression"})
    --     profiler_exp.reset()
    --     local L = 64
    --     game.print(L^12+36*L+500)
    --     game.print({"",profiler_exp,"Lua"})
    --     profiler_exp.reset()
    --     game.print(saved_value)
    --     game.print({"",profiler_exp,"saved"})
    -- profiler_exp.reset()
local experimental = helpers.compare_versions(helpers.game_version,"2.0.64") >= 0
local armor_list = prototypes.get_item_filtered({{filter = "type", type = "armor"}})

    local function get_armor(player)

        local armor_inventory = nil
        if player.controller_type == defines.controllers.editor then
            armor_inventory = player.get_inventory(defines.inventory.editor_armor)
        else
            armor_inventory = player.get_inventory(defines.inventory.character_armor)
        end
        --if not armor_inventory or armor_inventory.is_empty() then return end
        return (armor_inventory or {{valid_for_read = false}})[1] 
    end
    --local profiler = helpers.create_profiler()
local function generate_particles(speed,movement,player_position,surface)
    for i = 1,math.floor(3*math.sqrt(speed)),1 do
        local new_movement = {}
        --local random = r*(math.random()-0.5)
        new_movement[1] = (speed)*(movement[1] + r*((math.random()-0.5)+(math.random()-0.5)+(math.random()-0.5)))
        new_movement[2] = (speed)*(movement[2] + r*((math.random()-0.5)+(math.random()-0.5)+(math.random()-0.5)))
        surface.create_particle{
            name = "stone-particle",
            position = player_position,
            movement = new_movement,
            height = 0,
            vertical_speed = (speed < 0.14 and 0.02905*speed/0.15) or (0.075*(math.sqrt((speed >= 5 and 5) or (speed)))),
            frame_speed = 0.1
        }
    end

end

    Muluna.events.on_event(Muluna.events.events.on_player_moved(), function(event)
        if not storage.players_on_muluna[event.player_index] then return end
        local player = game.players[event.player_index]
        if player.controller_type == defines.controllers.character and player.physical_surface.name == "muluna" then
            storage.players_walking_on_muluna[event.player_index] = player
            update_player_step_tick_rate(event.player_index,storage.players_on_muluna[event.player_index])
        end
    end)
    Muluna.events.on_event(defines.events.on_player_changed_position, function(event)
        if not storage.player_control_method[event.player_index] == defines.input_method.game_controller then return end
            if not storage.players_on_muluna[event.player_index] then return end
            local player = game.players[event.player_index]
            if player.controller_type == defines.controllers.character and player.physical_surface.name == "muluna" then
                storage.players_walking_on_muluna[event.player_index] = player
                update_player_step_tick_rate(event.player_index,storage.players_on_muluna[event.player_index])
            end
    end)
    Muluna.events.on_event({defines.events.on_player_joined_game,defines.events.on_player_input_method_changed},function(event)
        storage.player_control_method[event.player_index] = game.players[event.player_index].input_method
    end)


    Muluna.events.on_event(defines.events.on_tick, function(event)
            for i,player in pairs(storage.players_walking_on_muluna) do
                --profiler.reset()
                local player_info = storage.players_on_muluna[i]
                if storage.player_control_method[i] == defines.input_method.game_controller then
                    if not player_info.cached_position then player_info.cached_position = player.physical_position end
                    player_info.delta_position = {x = player.physical_position.x-player_info.cached_position.x,y = player.physical_position.y - player_info.cached_position.y}
                    player_info.cached_position = player.character.position
                end

                if not storage.walking_tick_rates then update_step_tick_rates(event) end
                local tick_rate = storage.walking_tick_rates[i] 
                if not tick_rate then update_step_tick_rates(event) tick_rate = storage.walking_tick_rates[i] end
                --if surface.name ~= "muluna" then goto continue end
                if event.tick % tick_rate ~= 0 then goto continue end
                local player = player_info.player or player_info
                local character = player.character
                local surface = player.surface
                    --game.print(surface.name)
                    
                    
                    --game.print(player_armor.name)
                    --game.print(provides_flight)
                   
                    local walking_state = player.walking_state
                    --game.print(player.character_running_speed)
                    if walking_state.walking == false then 
                        storage.players_on_muluna[i].previous_movement = {0,0} 
                        storage.players_walking_on_muluna[i] = nil
                        goto continue 

                    end 
                        local character_is_flying = not character or character.is_flying 
                        if character_is_flying then goto continue end
                        
                        local player_tile = surface.get_tile(player.position)
                        if player.physical_vehicle or (player_tile.valid and player_tile.hidden_tile) then goto continue end
                            
                            local player_position

                            if character then
                                player_position = character.position
                            else 
                                player_position = player.position
                            end
                            surface.create_particle{
                                name = "stone-particle-medium",
                                position = player_position,
                                movement = {0,0},
                                height = 0,
                                vertical_speed = 0,
                                frame_speed = 1
                            }
                            local direction = cached_direction_to_string(walking_state.direction)
                            
                            local speed = player.character_running_speed /0.075
                            if speed == 1/0 then speed = 1 end --To fix issue where character running speed is infinity for some reason.
                            
                            
                            local movement = table.deepcopy(direction_vectors[direction]) --{0.01,0}
                            local prev_movement = storage.players_on_muluna[i].previous_movement or {0,0}
                            movement = vectors.vector_average_unsafe(movement,prev_movement)
                            --game.print(serpent.block(movement))
                            storage.players_on_muluna[i].previous_movement = table.deepcopy(movement)
                            generate_particles(speed,movement,player_position,surface)
                            
                        --end
                    
                --game.print(profiler)
                
                ::continue::
            end
        
        end
        )
end