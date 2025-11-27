local rro = Muluna.rro
local Public = {}

-- Forked from Maraxsis
-- "build" and "build-ghost" and "super-forced-build" are custom keybind inputs

-- function update_cursor_stack(event) 

--     if not storage.cursor_stack then 
--         storage.cursor_stack = {} --Player-id -> cursor_stack data
--     end

--     if not storage.cursor_stack[event.player_index] then
--         storage.cursor_stack[event.player_index] = {}
--     end 
--     storage.cursor_stack[event.player_index].direction = event.


-- end
local mining_drill_prototypes = prototypes.get_entity_filtered{{filter="type",type="mining-drill"}}

function Public.construct_sand_extractor(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end

    local cursor_stack = player.cursor_stack
    local cursor_stack_valid = cursor_stack and cursor_stack.valid_for_read and cursor_stack.count > 0
    local force = player.force
    local quality
    local name
    if cursor_stack_valid then
        name = cursor_stack.name
        quality = cursor_stack.quality
    else
        local cursor_ghost = player.cursor_ghost
        if not cursor_ghost then return end
        name = cursor_ghost.name.name
        quality = cursor_ghost.quality
    end

    if not Muluna.constants.regolith_drills[name] then return end
    local drill_name = name .. "-ground-digger"

    local surface = player.surface
    if surface.name ~= "muluna" then return end
    local position = event.cursor_position
    local player_position = (player.character or player).position
    local distance = math.sqrt((position.x-player_position.x)^2+(position.y-player_position.y)^2)
    if surface.entity_prototype_collides(drill_name, position, false) then return end
    if surface.get_tile(position).hidden_tile then 
        player.create_local_flying_text{
            text = {"console.can-not-place-here-unnatural-tile"},
            --position = position,
            surface = surface,
            create_at_cursor = true,
            speed = 0.01,
        }
        
        return end --If tile is unnatural, like concrete, then don't place mine. Muluna addition.
    
    local is_ghost = (not cursor_stack_valid) or event.input_name == "build-ghost" or event.input_name == "super-forced-build"
    
    if player.character and (distance >= player.character.build_distance) and not is_ghost then
        -- If unreachable, then don't place
        return end
    
    --game.print(serpent.block(position))
    local direction = defines.direction.north

    local drill_prototype = mining_drill_prototypes[name]
    
    
    local range_offset = drill_prototype.get_mining_drill_radius(quality) 

    local neighboring_resources = surface.find_entities_filtered{ --Search for resources to see if a regular mining drill would be placed.
        area= {{position.x-range_offset,position.y-range_offset},{position.x+range_offset,position.y+range_offset}}, 
        type = {"resource"},
        
    }
    if #neighboring_resources ~= 0 then return end --If neighboring resources exist, then do not place
    




    --If mining drill not square, this code can't cleanly handle it, so while mod-data should ideally not contain this drill,
    --this check allows them to exist in mod-data without crashing.
    local offset_width = drill_prototype.tile_width
    local offset_height = drill_prototype.tile_height
    local margin = 0.5
    if offset_width ~= offset_height then return end 

    local colliding_entities = surface.find_entities_filtered{
            area= {{position.x-offset_width/2+margin,position.y-offset_height/2+margin},{position.x+offset_width/2-margin,position.y+offset_height/2-margin}},
            to_be_deconstructed = false,
        }
    if #colliding_entities ~= 0 then return end
    
    local neighboring_belts = rro.get_concatenation(
        surface.find_entities_filtered{
            area= {{position.x-offset_width+margin,position.y-offset_height+margin},{position.x+offset_width-margin,position.y+offset_height-margin}}, 
            type = {"transport-belt","underground-belt","splitter","container"},
            --ghost_type = {"transport-belt","underground-belt","splitter","container"},
        },
        surface.find_entities_filtered{
            area= {{position.x-offset_width+margin,position.y-offset_height+margin},{position.x+offset_width-margin,position.y+offset_height-margin}}, 
            --type = {"entity-ghost"},
            ghost_type = {"transport-belt","underground-belt","splitter","container"},
        }

    )
    --game.print(serpent.block(neighboring_belts))
    if neighboring_belts then --If adjacent belts exist, change direction of drill such that it feeds one of those belts. Muluna addition.
        for _,neighbor in pairs(neighboring_belts) do
            local delta_pos = {x = neighbor.position.x- position.x, y = neighbor.position.y- position.y}
            --game.print(serpent.block(neighbor))
            --game.print(serpent.block(delta_pos))
            if (delta_pos.x <=0.5 and delta_pos.x >= -0.5) then
                if delta_pos.y > 0 then
                    direction = defines.direction.south
                else
                    direction = defines.direction.north
                end
            elseif (delta_pos.y <=0.5 and delta_pos.y >= -0.5) then
                if delta_pos.x > 0 then
                    direction = defines.direction.east
                else
                    direction = defines.direction.west
                end
            end
        end
    end

    

    surface.create_entity {
        name = is_ghost and "entity-ghost" or drill_name,
        inner_name = is_ghost and drill_name or nil,
        position = position,
        force = player.force,
        player = player,
        quality = quality,
        direction = direction,
        raise_built = true,
    }
    if player.force.technologies["muluna-regolith-digging"].researched == false then --Because This script unexpectedly 
        Muluna.complete_research(player.force,"muluna-regolith-digging")
    end
    

    if not is_ghost then
        cursor_stack.count = cursor_stack.count - 1
        force.get_entity_build_count_statistics(surface).on_flow(name,1)
    end
end


Muluna.events.register_delayed_function("construct_sand_extractor", Public.construct_sand_extractor)

Muluna.events.on_event({"build", "build-ghost", "super-forced-build"}, function(event)
    Muluna.events.execute_later("construct_sand_extractor", 1, event)
end)
