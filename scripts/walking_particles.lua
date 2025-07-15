if settings.startup["muluna-graphics-enable-footstep-animations"].value == true then
    local m = 0.01
    local r = 0.01
    local direction_vectors = { --Velocity vector used to set velocity of kicked up particles.
        North = {0,m},	
        NorthNorthEast = {-m,m},	
        NorthEast = {-m,m},
        EastNorthEast = {-m,m},
        East = {-m,0},	
        EastSouthEast = {-m,-m},
        SouthEast = {-m,-m},
        SouthSouthEast = {-m,-m},
        South = {0,-m},	
        SouthSouthWest = {m,-m},
        SouthWest = {m,-m},
        WestSouthWest = {m,-m},
        West = {m,0},
        WestNorthWest = {m,m},
        NorthWest = {m,m},
        NorthNorthWest = {m,m},
    }




    local character_running_speed = 0.15
    local half_character_running_speed = 0.14


    local step_process_tick_rate = 6
    local function update_step_tick_rates(event)
        if game.surfaces.muluna then
            if not storage.walking_tick_rates then storage.walking_tick_rates = {} end
            for i,player in pairs(game.players) do
                if player.surface.name ~= "muluna" then break end
                local speed = player.character_running_speed
                local tick_rate = storage.walking_tick_rates[i]
                storage.walking_tick_rates[i] = step_process_tick_rate*math.ceil(30/(speed/0.075)/step_process_tick_rate)
            end
        end
    end

    Muluna.events.on_nth_tick(60, update_step_tick_rates)
    Muluna.events.on_event({defines.events.on_player_armor_inventory_changed}, update_step_tick_rates)

    Muluna.events.on_event({defines.events.on_player_changed_surface}, function(event)
        local id = event.player_index
        local player = game.players[event.player_index]
        if not storage.players_on_muluna then storage.players_on_muluna = {} end
        if player.surface.name == "muluna" then
            storage.players_on_muluna[event.player_index] = player
            update_step_tick_rates(event)
        else
            storage.players_on_muluna[event.player_index] = nil
        end


    end

    
    
    )
    Muluna.events.on_nth_tick(step_process_tick_rate, function(event)
        --local update_tick_rate = event.tick % 180 == true
        if game.surfaces.muluna then
            for i,player in pairs(storage.players_on_muluna) do
                local character = player.character
                local surface = player.surface
                if not storage.walking_tick_rates then update_step_tick_rates(event) end
                local tick_rate = storage.walking_tick_rates[i] or 30
                --if not tick_rate then update_step_tick_rates(event) end
                if surface.name ~= "muluna" then break end
                if event.tick % tick_rate == 0 then
                    
                    --game.print(surface.name)
                    
                    
                    local walking_state = player.walking_state
                    --game.print(player.character_running_speed)
                    if walking_state.walking == true and not player.physical_vehicle and not surface.get_tile(player.position).hidden_tile then
                        
                        local player_position = character.position
                        surface.create_particle{
                            name = "stone-particle-medium",
                            position = player_position,
                            movement = {0,0},
                            height = 0,
                            vertical_speed = 0,
                            frame_speed = 1
                        }
                        local direction = helpers.direction_to_string(walking_state.direction)
                        local movement = table.deepcopy(direction_vectors[direction]) --{0.01,0}
                        local speed = player.character_running_speed
                        movement[1] = (speed/0.075)*(movement[1] + r*(math.random()-0.5))
                        movement[2] = (speed/0.075)*(movement[2] + r*(math.random()-0.5))
                        surface.create_particle{
                            name = "stone-particle",
                            position = player_position,
                            movement = movement,
                            height = 0,
                            vertical_speed = 0.1,
                            frame_speed = 0.5
                        }
                    end
                end
            end
        end
        end
        )
end