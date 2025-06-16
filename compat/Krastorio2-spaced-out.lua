if mods["Krastorio2-spaced-out"] then
    


    local rro = require("lib.remove-replace-object")

    rro.replace_field(data.raw["technology"]["kr-singularity-lab"].effects,"recipe","biolab","cryolab")
    rro.soft_insert(data.raw["technology"]["kr-singularity-lab"].prerequisites,"cryolab")







end