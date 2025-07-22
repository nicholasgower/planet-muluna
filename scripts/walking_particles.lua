if settings.startup["muluna-graphics-enable-footstep-animations"].value == true then
    local m = 0.01 local r = 0.01
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
    Muluna.events.on_nth_tick(step_process_tick_rate, function(event)
        --local update_tick_rate = event.tick % 180 == true
        
        
        if game.surfaces.muluna then --If Muluna exists
            for i,player_info in pairs(storage.players_on_muluna) do
                --profiler.reset()
                local player = player_info.player or player_info
                local character = player.character
                local surface = player.surface
                if not storage.walking_tick_rates then update_step_tick_rates(event) end
                local tick_rate = storage.walking_tick_rates[i] or 30
                --if not tick_rate then update_step_tick_rates(event) end
                if surface.name ~= "muluna" then break end
                if event.tick % tick_rate == 0 then
                    
                    --game.print(surface.name)
                    
                    
                    --game.print(player_armor.name)
                    --game.print(provides_flight)
                   
                    local walking_state = player.walking_state
                    --game.print(player.character_running_speed)
                    if walking_state.walking == false then return end --game.print(profiler) return end
                        local player_armor = get_armor(player)
                        local provides_flight = false
                        if player_armor.valid_for_read then 
                            provides_flight=prototypes.item[player_armor.name].provides_flight
                        end
                        if not player.physical_vehicle and not surface.get_tile(player.position).hidden_tile and not provides_flight then
                            
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
                            
                            local speed = player.character_running_speed /0.075
                            for i = 1,4,1 do
                                local movement = table.deepcopy(direction_vectors[direction]) --{0.01,0}
                                --local random = r*(math.random()-0.5)
                                movement[1] = (speed)*(movement[1] + r*(math.random()-0.5))
                                movement[2] = (speed)*(movement[2] + r*(math.random()-0.5))
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
                    
                --game.print(profiler)
                end
            end
        end
        end
        )
end