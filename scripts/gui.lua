local rro = Muluna.rro
local gui_lib = require("lib.guis")
local telescopes = rro.keys(Muluna.constants.telescopes)
local heat_assembling_machine_keys = rro.keys(Muluna.constants.heat_assembling_machines)
local telescope_combinator_keys = {}
local heat_element_keys = {}

for i,tab in pairs({telescope_keys,heat_assembling_machine_keys}) do
    local element_table
    local table_write
    local field
    if i == 1 then
        element_table = Muluna.constants.telescopes
        field = "constant-combinator"
        table_write = telescope_combinator_keys
    elseif i == 2 then
        element_table = Muluna.constants.heat_assembling_machines
        field = "reactor"
        table_write = telescope_combinator_keys
    end
    for j,key in pairs(element_table) do
        table_write[j] = key[field]
        
    end
end
Muluna.events.on_event(defines.events.on_gui_opened, function(event)
    
    if not (event.entity and rro.contains({"assembling-machine","constant-combinator","reactor","accumulator"},event.entity.type)) then return end
    --game.print("gui opened")
    local player = game.players[event.player_index]
    local selected = (player or {}).opened --The currently selected entity
    local entity = event.entity
    local entity_name = entity.name
    local other_entity_button
    local satradar_gui
    local localised_title
    local localised_button
    local gui_type 
    local other_entity
    local button_name
    local enabled
    if not storage.player_focus then storage.player_focus = {} end
    --game.print(entity_name)
    --game.print(serpent.block(Muluna.constants.telescopes))
    --game.print(serpent.block(Muluna.constants.heat_assembling_machines))
    if entity_name == "muluna-satellite-radar" then
        satradar_gui = true
        gui_type = defines.relative_gui_type.accumulator_gui
        localised_button = {"muluna-gui.satellite-radar-enable-button"}
        if not storage.nav_beacons_other then storage.nav_beacons_other = {} end
        if not storage.nav_beacons_other[entity.unit_number] then storage.nav_beacons_other[entity.unit_number] = {gui = {enabled = true}} end
        enabled = storage.nav_beacons_other[entity.unit_number].gui.enabled
        button_name = "satellite-radar"
    elseif rro.contains(Muluna.constants.telescopes,function(other) return entity_name == other["assembling-machine"] end ) then
        local telescope_data = storage.telescopes
        other_entity_button = true
        gui_type = defines.relative_gui_type.assembling_machine_gui
        localised_button = {"muluna-gui.telescope-goto-button"}
        other_entity = storage.telescopes
        button_name = "telescope-unit"
    elseif rro.contains(Muluna.constants.telescopes,function(other) return entity_name == other["constant-combinator"] end ) then
        local telescope_data = storage.telescopes
        other_entity_button = true
        gui_type = defines.relative_gui_type.constant_combinator_gui
        localised_button = {"muluna-gui.telescope-combinator-goto-button"}
        button_name = "telescope-combinator"
    elseif rro.contains(Muluna.constants.heat_assembling_machines,function(other) return entity_name == other["assembling-machine"] end ) then
        local assembling_machine_data = storage.heat_assembling_machines
        other_entity_button = true
        gui_type = defines.relative_gui_type.assembling_machine_gui
        localised_button = {"muluna-gui.heat-assembling-machine-goto-button"}
        button_name = "heat-assembling-machine-unit"
    elseif rro.contains(Muluna.constants.heat_assembling_machines,function(other) return entity_name == other["reactor"] end ) then
        other_entity_button = true
        local assembling_machine_data = storage.heat_assembling_machines
        gui_type = defines.relative_gui_type.reactor_gui
        localised_button = {"muluna-gui.heat-assembling-machine-reactor-goto-button"}
        button_name = "heat-assembling-machine-reactor"
    end

    if other_entity_button or satradar_gui then
        local player = game.players[event.player_index]
        local frame = player.gui.relative.add{type="frame", name="muluna-entity-gui", caption=localised_title, direction = "vertical",
    
        anchor = {
				gui = gui_type,
				position = satradar_gui and defines.relative_gui_position.bottom or defines.relative_gui_position.right,
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
            ignored_by_interaction = false,
            style = (not satradar_gui ) and "draggable_space_header" or nil
        })
        drag_handle.style.horizontally_stretchable = true
		drag_handle.style.height = (not satradar_gui ) and 24 or 0
		drag_handle.style.right_margin = 4
        if other_entity_button then
            local goto_button = frame.add({
                type = "button",
                name = "muluna-goto-button-" .. button_name,
                caption = localised_button,
            })
        elseif satradar_gui then
            local enable_switch = frame.add({
                type = "checkbox",
                name = "muluna-satellite-radar-enable-checkbox",
                caption = localised_button,
                state = enabled,
            })
            local goto_planet_button = frame.add({
                type = "button",
                name = "muluna-goto-button-" .. button_name,
                caption = {"muluna-gui.satellite-radar-look-at",{"space-location-name." .. storage.nav_surfaces[selected.unit_number].name},storage.nav_surfaces[selected.unit_number].name},
                
            })
        end
        -- local content_frame = frame.add({
		-- 	type = "frame",
		-- 	name = "content",
		-- 	style = "inside_shallow_frame_with_padding_and_vertical_spacing",
		-- 	direction = "vertical",
		-- })
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

Muluna.events.on_event(defines.events.on_gui_click, function(event)
    local element = event.element
    --game.print(serpent.block(element))
    if false then

    elseif string.find(element.name, "muluna%-goto%-button") then 

        local player = game.players[event.player_index]

        local selected = player.opened --The currently selected entity
        local to_entity --Entity to change focus to
        local to_planet --Planet to switch view to
        --game.print(element.name)
        if string.find(element.name,"telescope%-unit") then
            --game.print(element.name)
            to_entity = storage.telescopes[selected.unit_number]["constant-combinator"]
        elseif string.find(element.name,"telescope%-combinator")  then
            --game.print(element.name)
            local to_entity_table = rro.find_contains(storage.telescopes, function(entry) return entry["constant-combinator"].unit_number == selected.unit_number end)
            to_entity = to_entity_table["assembling-machine"]
        elseif string.find(element.name,"heat%-assembling%-machine%-unit")  then
            to_entity = storage.heat_assembling_machines[selected.unit_number]["reactor"]
            --game.print(element.name)
        elseif string.find(element.name,"heat%-assembling%-machine%-reactor")  then
            local to_entity_table = rro.find_contains(storage.heat_assembling_machines, function(entry) return entry["reactor"].unit_number == selected.unit_number end)
            to_entity = to_entity_table["assembling-machine"]
            --game.print(element.name)
        elseif string.find(element.name,"satellite%-radar")  then
            to_planet = storage.nav_surfaces[selected.unit_number]
        end
        if to_entity then
            player.opened = to_entity
        elseif to_planet then
            player.set_controller{type = defines.controllers.remote,surface = to_planet.name}
        end


    
    



    end






end)

Muluna.events.on_event(defines.events.on_gui_checked_state_changed, function(event)
    local checkbox = event.element

    if not checkbox.name == "muluna-satellite-radar-enable-checkbox" then return end
    local player = game.players[event.player_index]
    local radar = player.opened --The currently selected entity (Satellite Radar)
    storage.nav_beacons_other[radar.unit_number].gui.enabled = checkbox.state




end)



