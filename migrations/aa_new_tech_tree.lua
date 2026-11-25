-- Registered so the FUnit re-add test can replay this migration with an empty
-- storage table, the way Factorio does when a mod is added back to a save.
local function migrate()
for _,force in pairs(game.forces) do 
    if force.technologies["planet-discovery-muluna"].researched == true then
        if force.technologies["wood-gas-processing"].researched == true then
            force.technologies["muluna-greenhouses"].researched = true
            force.technologies["muluna-wood-cultivation"].researched = true
            --force.technologies["muluna-anorthite-processing"].researched = true
        end

        if force.technologies["muluna-anorthite-processing"].researched == true then
            force.technologies["muluna-alumina-processing"].researched = true
            force.technologies["muluna-aluminum-processing"].researched = true
            force.technologies["muluna-alice-propellant"].researched = true
        end

        if force.technologies["oxide-asteroid-crushing"].researched == true then
            force.technologies["muluna-oxygen"].researched = true
            
        end

        if force.technologies["carbonic-asteroid-crushing"].researched == true then
            force.technologies["muluna-advanced-boiler"].researched = true
            
        end

        
    end
end

end

Muluna.migrations = Muluna.migrations or {}
Muluna.migrations["aa_new_tech_tree"] = migrate
if game then migrate() end
