local Public = {}

function Public.update_interstellar_pack(force)
    --local force = event.research.force
    local technologies = force.technologies
    local interstellar_pack_name = "interstellar-science-pack"
    if technologies[interstellar_pack_name].researched == true then end

    local science_packs = prototypes.mod_data["muluna-interstellar-science-pack-conditions"].data.science_packs
    --local tech = event.research
    
    --if true or rro.contains(science_packs, tech.name) then
        local count = 0
        local max_count = settings.startup["muluna-interstellar-science-pack-packs-required"].value
        for _, pack in pairs(science_packs) do
            if technologies[pack].researched == true then
                count = count + 1
            end
            if count == max_count then break end
        end
        if count >= max_count then
            if technologies[interstellar_pack_name].researched == false then
                force.print({"technology-researched","[technology="..interstellar_pack_name.."]"}, {sound_path = "utility/research_completed"})
                technologies[interstellar_pack_name].researched = true
            end
            
            
        
        else 
            local progress = technologies[interstellar_pack_name].saved_progress
            if progress < count / max_count then
                force.print({"console.interstellar-science-pack-progress",tostring(count),tostring(max_count)})
            end
            technologies[interstellar_pack_name].saved_progress = count / max_count
        end
    --end


end




return Public