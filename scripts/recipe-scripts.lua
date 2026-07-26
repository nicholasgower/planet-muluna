local diffused_plastic = prototypes.recipe["muluna-diffused-plastic"]
local diffused_plastic_item = prototypes.item["muluna-diffused-plastic"]

local spoil_time = diffused_plastic_item.get_spoil_ticks()

if settings.startup["muluna-performance-scripted-diffused-plastic"].value == true and diffused_plastic.on_crafted_event then
    script.on_event(diffused_plastic.on_crafted_event, function(event) 
        if not storage.entity_info[event.entity.unit_number] then 
            storage.entity_info[event.entity.unit_number] = {
                output_inventory = event.entity.get_output_inventory()
            }
        end
        local current_count = storage.entity_info[event.entity.unit_number].output_inventory.get_item_count("muluna-diffused-plastic")
        local spoil_level = event.shared_roll
    
    end)
end

