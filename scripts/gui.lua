local rro = Muluna.rro
local gui_lib = require("lib.guis")
local telescope_keys = rro.keys(Muluna.constants.telescopes)
local heat_assembling_machine_keys = rro.keys(Muluna.constants.heat_assembling_machines)
local telescope_combinator_keys = {}
local heat_element_keys = {}
for i,tab in pairs({telescope_keys,heat_assembling_machine_keys}) do
    local element_table
    local field
    if i == 1 then
        element_table = Muluna.constants.telescopes
        field = "constant-combinator"
    elseif i == 2 then
        element_table = Muluna.constants.heat_assembling_machines
        field = "reactor"
    end
    for j,key in pairs(element_table) do
        tab[j] = key[field]
    end
end
Muluna.events.on_event(defines.events.on_gui_opened, function(event)
    
    if not event.entity then return end
    game.print("gui opened")
    local entity = event.entity
    local entity_name = entity.name
    local other_entity_button
    local localised_title
    local localised_button
    game.print(entity_name)
    game.print(serpent.block(telescope_keys))
    game.print(serpent.block(telescope_combinator_keys))
    game.print(serpent.block(heat_assembling_machine_keys))
    game.print(serpent.block(heat_element_keys))
    if rro.contains(telescope_keys,entity_name) then
        local telescope_data = storage.telescopes
        other_entity_button = true
    elseif rro.contains(telescope_combinator_keys,entity_name) then
        local telescope_data = storage.telescopes
        other_entity_button = true
    elseif rro.contains(heat_assembling_machine_keys,entity_name) then
        local assembling_machine_data = storage.heat_assembling_machines
        other_entity_button = true
    elseif rro.contains(heat_element_keys,entity_name) then
        other_entity_button = true
        local assembling_machine_data = storage.heat_assembling_machines
    end

    if other_entity_button then
        local player = game.players[event.player_index]
        local frame = player.gui.relative.add{type="frame", name="muluna-entity-gui", caption=localised_title, direction = "vertical",
    
        anchor = {
				gui = defines.relative_gui_type.assembling_machine_gui,
				position = defines.relative_gui_position.right,
				ghost_mode = "both",
				--name = "",
			},
    
            }
        local title_bar = frame.add({
            type = "flow",
            direction = "horizontal",
            drag_target = frame,

        })
        -- title_bar.add({
        --     type = "label",
        --     caption = "test",
        --     style = "frame_title",
        --     ignored_by_interaction = true,
        -- })
        local drag_handle = title_bar.add({
            type = "empty-widget",
            ignored_by_interaction = true,
            style = "draggable_space_header"
        })
        drag_handle.style.horizontally_stretchable = true
		drag_handle.style.height = 24
		drag_handle.style.right_margin = 4
        local goto_button = frame.add({
            type = "button",
            name = "goto-button",
            label = localised_button,
        })

        local content_frame = frame.add({
			type = "frame",
			name = "content",
			style = "inside_shallow_frame_with_padding_and_vertical_spacing",
			direction = "vertical",
		})
        --player.gui..relative.greeting.caption = "Hello there!"
        --player.gui.top["greeting"].caption = "Actually, never mind, I don't like your face"
    end

end
)

Muluna.events.on_event(defines.events.on_gui_closed, function(event)

    local player = game.players[event.player_index]
    if player.gui.relative["muluna-entity-gui"] then
        player.gui.relative["muluna-entity-gui"].destroy()
    end
    


end)




