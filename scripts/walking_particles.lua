local m = 0.01
local r = 0.01
local direction_vectors = {
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
local half_character_running_speed = 0.07875
script.on_nth_tick(30, function(event)

    for _,player in pairs(game.players) do
        local character = player.character
        local surface = player.surface

        if surface.name ~= "muluna" then end
        
        local walking_state = player.walking_state
        --game.print(player.character_running_speed)
        if walking_state.walking == true and player.character_running_speed <= half_character_running_speed and not player.physical_vehicle then
            
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
            movement[1] = movement[1] + r*(math.random()-0.5)
            movement[2] = movement[2] + r*(math.random()-0.5)
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
    )