local rro = Muluna.rro
for _,tech in pairs(data.raw["technology"]) do
    if tech.prerequisites then
        rro.replace(tech.prerequisites,"space-platform-thruster","space-science-pack")
    end
    
end

data.raw["recipe"]["crusher"].subgroup = "smelting-machine"
data.raw["item"]["crusher"].subgroup = "smelting-machine"
data.raw["assembling-machine"]["crusher"].subgroup = "smelting-machine"
data.raw["item"]["crusher"].order = "ca[crusher]"
