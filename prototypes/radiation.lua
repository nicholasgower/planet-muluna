local rro=Muluna.rro

local radiation={
    type="airborne-pollutant",
    name="radiation",
    chart_color={0,150,0},
    icon=data.raw["airborne-pollutant"]["pollution"].icon,
    affects_evolution=false,
    affects_water_tint=false,
}

for _,drill in pairs(data.raw["mining-drill"]) do
    if drill.emissions_per_second then
        drill.emissions_per_second["radiation"]=drill.mining_speed*0.1
    else
        drill.emissions_per_second={["radiation"]=drill.mining_speed*0.1}
    end
    
end

data:extend{radiation}