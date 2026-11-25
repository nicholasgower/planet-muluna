-- Registered so the FUnit re-add test can replay this migration with an empty
-- storage table, the way Factorio does when a mod is added back to a save.
local function migrate()
-- This migration grants technologies that did not exist before Muluna was
-- added. Adding the mod back to a save is not the same as adding it for the
-- first time: the save already has the tech tree, so do not grant anything.
if not Muluna.should_run_migrations() then return end
for _,force in pairs(game.forces) do 
    if force.technologies["planet-discovery-muluna"].researched == false then
        if force.technologies["space-science-pack"].researched == true then
            --force.technologies["crusher"].researched = true
            force.technologies["metallic-asteroid-crushing"].researched = true
            force.technologies["carbonic-asteroid-crushing"].researched = true
            force.technologies["oxide-asteroid-crushing"].researched = true
            force.technologies["planet-discovery-muluna"].researched = true
            if script.active_mods["cupric-asteroids"] then
                force.technologies["cupric-asteroid-crushing"].researched = true
            end

        end

        if force.technologies["space-platform-thruster"].researched == true then
            force.technologies["asteroid-collector"].researched = true
            --force.technologies["muluna-anorthite-processing"].researched = true
            if settings.startup["muluna-easy-vanilla-rocket-part-costs"].value == false then 
                force.technologies["rocket-part-productivity"].researched = true
                force.technologies["rocket-part-productivity-2"].researched = true
                force.technologies["rocket-part-productivity-3"].researched = true
                force.technologies["rocket-part-productivity-4"].researched = true
            end
            
        end
        if settings.startup["muluna-easy-vanilla-rocket-part-costs"].value == false then
            if force.technologies["electromagnetic-science-pack"].researched == true then
                force.technologies["rocket-part-productivity-fulgora"].researched = true
                force.technologies["rocket-part-productivity-fulgora-2"].researched = true
            end

            if force.technologies["agricultural-science-pack"].researched == true then
                force.technologies["rocket-part-productivity-gleba"].researched = true
                force.technologies["rocket-part-productivity-gleba-2"].researched = true
            end

            if force.technologies["metallurgic-science-pack"].researched == true then
                force.technologies["rocket-part-productivity-vulcanus"].researched = true
                force.technologies["rocket-part-productivity-vulcanus-2"].researched = true
            end
        end
        if force.technologies["planet-discovery-aquilo"].researched == true then
            --force.technologies["interstellar-science-pack"].researched = true
            force.technologies["advanced-space-science-pack"].researched = true
            force.technologies["thruster-fuel-productivity"].researched = true
            force.technologies["thruster-fuel-productivity"].level = 6
        end

        
    end
end

end

Muluna.migrations = Muluna.migrations or {}
Muluna.migrations["existing_save"] = migrate
if game then migrate() end
