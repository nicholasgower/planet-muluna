---Krastorio2-spaced-out compatibility
if mods["Krastorio2-spaced-out"] then
    


    local rro = Muluna.rro

    rro.replace_field(data.raw["technology"]["kr-singularity-lab"].effects,"recipe","biolab","cryolab")
    rro.soft_insert(data.raw["technology"]["kr-singularity-lab"].prerequisites,"cryolab")

    
    table.insert(data.raw["recipe"]["muluna-regolith-digging"].results,{type = "item", name = "kr-rare-metal-ore",amount = 1,probability = 0.025})


    data.raw["technology"]["muluna-silicon-processing"].localised_name = {"technology-name.muluna-silicon-processing-alt"}

    local advanced_anorthite = data.raw["recipe"]["advanced-anorthite-crushing"]
    local silicon = data.raw["item"]["kr-silicon"]
    if silicon then
        advanced_anorthite.icons[3].icon = silicon.icon
        advanced_anorthite.icons[4].icon = silicon.icon
        advanced_anorthite.icons[3].icon_size = silicon.icon_size
        advanced_anorthite.icons[4].icon_size = silicon.icon_size
    end
    
end