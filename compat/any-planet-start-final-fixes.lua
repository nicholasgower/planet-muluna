local rro = Muluna.rro
local function delete_tech(deleted_tech,new_tech)
    for _,effect in pairs(data.raw["technology"][deleted_tech].effects) do
        if effect.type == "unlock-recipe" then
            if new_tech then
                rro.soft_insert(data.raw["technology"][new_tech].effects, 
                {
                    type = "unlock-recipe",
                    recipe = data.raw["recipe"][effect.recipe].name,
                }
            )
            else
                data.raw["recipe"][effect.recipe].enabled = true
            end
        end
    end
    data.raw["technology"][deleted_tech] = nil
    
    for _,technology in pairs(data.raw["technology"]) do
        rro.remove(technology.prerequisites,deleted_tech)
    end
end


delete_tech("electric-mining-drill","metallic-asteroid-crushing")
delete_tech("advanced-material-processing-2","muluna-advanced-boiler")
delete_tech("advanced-material-processing","muluna-advanced-boiler")
delete_tech("steel-processing","metallic-asteroid-crushing")
delete_tech("advanced-circuit","electronics")
delete_tech("oil-processing","oil-gathering")
delete_tech("fluid-handling","oxide-asteroid-crushing")
delete_tech("thruster-fuel","space-platform-thruster")
delete_tech("thruster-oxidizer","space-platform-thruster")
delete_tech("landfill","muluna-greenhouses")
delete_tech("muluna-silicon-processing","solar-energy")
delete_tech("electric-energy-distribution-1","oxide-asteroid-crushing")
delete_tech("sulfur-processing","wood-gas-processing")
delete_tech("engine","steam-power") 