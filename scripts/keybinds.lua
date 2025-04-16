--game.forces.player.players[1].set_controller{type=defines.controllers.character,position = {1,1}}

script.on_event("muluna-walk-on-platform", function(event)
    local player = game.players[event.player_index]
    local prototype = event.selected_prototype
    game.print("Keyboard shortcut pressed on tick: " ..tostring(event.tick) .. " by " .. player.name)
    game.print(player.physical_position)
    game.print(player.hub)
    --game.print("Keyboard shortcut pressed on tick: " ..tostring(event.tick))
    --if player.physical_position == {0,0}
    if player.hub then
        local hub = player.hub.get_control_behavior()
        local platform = hub.surface.platform 
        platform.paused = true
        -- if hub.surface.platform == player.surface then
        --     platform = player.surface.platform
        -- end
        player.leave_space_platform()
        player.set_controller{type = defines.controllers.character,character = player.character}
        player.teleport(0,4)
    end
  end)