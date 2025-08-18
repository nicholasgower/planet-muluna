local should_notify = false
local rro = Muluna.rro
for _,force in pairs(game.forces) do
    if game.surfaces["muluna"] then
        should_notify = true
    end
    if force.technologies["low-density-space-platform-foundation"].researched == true then
        force.technologies["interstellar-science-pack"].researched = true
    end
    if force.technologies["asteroid-collector"].researched == true then
        force.technologies["crusher"].researched = true
    end
end
if should_notify then
    game.print({"console.muluna-2-message"})
end


--To my disappointment, conditional migrations for the space science pack assemblers on Muluna will not work.
-- for _,machine in pairs(game.surfaces.muluna.find_entities_filtered{type = {"assembling-machine"}}) do
--     local recipe = machine.get_recipe() 
--     if recipe and recipe.name == "space-science-pack" then
--         game.print("Assembler found")
--         machine.set_recipe("space-science-pack-muluna",recipe.quality)
--     end
-- end

local function correct_surface_space_science_packs(surface,desired_recipe) 
    if surface then
        --As alternative, we can scan for assembling machines without recipes, and check neighboring inserters to guess if it should have its recipe set to space science packs.
        for _,machine in pairs(surface.find_entities_filtered{type = {"assembling-machine"}}) do
            local recipe = machine.get_recipe() 
            
            if not recipe then
                local control = machine.get_control_behavior()
                local position = machine.position
                local offset_width = 5
                local offset_height = 5
                --game.print("Assembler found")
                local neighboring_inserters = surface.find_entities_filtered{area={{position.x-offset_width,position.y-offset_height},{position.x+offset_width,position.y+offset_height}}, type = {"inserter"}}

                for _,inserter in pairs(neighboring_inserters) do
                    if inserter.pickup_target == machine then
                        local stack = inserter.held_stack
                        if stack.valid_for_read and stack.name == "space-science-pack" then
                            if not control or control.circuit_set_recipe == false then
                                machine.set_recipe(desired_recipe,stack.quality)
                            end
                            
                        end
                    end
                    
                    
                end
                
                
                
                
            end
        end
        --Second pass, check for neighbors
        for _,machine in pairs(surface.find_entities_filtered{type = {"assembling-machine"}}) do
            local recipe = machine.get_recipe() 
            
            if not recipe then
                local control = machine.get_control_behavior()
                local position = machine.position
                local offset_width = 8
                local offset_height = 8
                --game.print("Assembler found")
                local neighboring_assemblers = surface.find_entities_filtered{area={{position.x-offset_width,position.y-offset_height},{position.x+offset_width,position.y+offset_height}}, type = {"assembling-machine"}}

                for _,neighbor in pairs(neighboring_assemblers) do
                    --if neighbor.pickup_target == machine then
                        local recipe,quality = neighbor.get_recipe()
                        if recipe and recipe.name == desired_recipe then
                            if not control or control.circuit_set_recipe == false then
                                machine.set_recipe(desired_recipe,quality or "normal")
                            end
                            
                        end
                    --end
                    
                    
                end
                
                
                
                
            end
        end
        -- This guessing algorithm won't find every space science pack factory, but it should catch the majority of cases.
    end
end

correct_surface_space_science_packs(game.surfaces.muluna,"space-science-pack-muluna")

-- for _,force in pairs(game.forces) do
--     for _,platform in pairs(force.platforms) do
--         correct_surface_space_science_packs(platform.surface,"space-science-pack")
--     end
-- end
