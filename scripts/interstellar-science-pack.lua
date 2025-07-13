local Public = {}

function Public.update_interstellar_pack(force,display_notification)
    if display_notification == nil then display_notification = true end
    --local force = event.research.force
    local technologies = force.technologies
    local data = prototypes.mod_data["muluna-interstellar-science-pack-conditions"].data
    local interstellar_pack_name = data.gated_technology
    if technologies[interstellar_pack_name].researched == true then end

    local science_packs = data.science_packs
    --local tech = event.research
    
    if technologies[interstellar_pack_name].researched == false then
        local count = 0
        local max_count = settings.startup["muluna-interstellar-science-pack-packs-required"].value
        for _, pack in pairs(science_packs) do
            if technologies[pack].researched == true then
                count = count + 1
            end
            if count == max_count then break end
        end
        if count >= max_count then
            if display_notification then
                force.print({"technology-researched","[technology="..interstellar_pack_name.."]"}, {sound_path = "utility/research_completed"})
            end
            
            technologies[interstellar_pack_name].researched = true
            
            
            
        
        else 
            local progress = technologies[interstellar_pack_name].saved_progress
            if display_notification and progress < count / max_count then
                force.print({"console.interstellar-science-pack-progress",tostring(count),tostring(max_count),"[technology=".. interstellar_pack_name .. "]"})
            end
            technologies[interstellar_pack_name].saved_progress = count / max_count
        end
    end


end




return Public