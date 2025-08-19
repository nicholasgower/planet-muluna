---Krastorio2-spaced-out compatibility
if mods["Krastorio2-spaced-out"] then
    


    local rro = Muluna.rro

    rro.replace_field(data.raw["technology"]["kr-singularity-lab"].effects,"recipe","biolab","cryolab")
    rro.soft_insert(data.raw["technology"]["kr-singularity-lab"].prerequisites,"cryolab")

    
    table.insert(data.raw["recipe"]["muluna-regolith-digging"].results,{type = "item", name = "kr-rare-metal-ore",amount = 1,probability = 0.025})





end