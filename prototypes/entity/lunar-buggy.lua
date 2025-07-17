local rro = Muluna.rro
local buggy = table.deepcopy(data.raw["car"]["car"])
local buggy_scale = 1.25
local gun_scale = 1/2

buggy.name = "muluna-rocket-buggy"
buggy.max_health = 750
buggy.minable.result = "muluna-rocket-buggy"
buggy.weight = buggy.weight * buggy_scale^2
buggy.consumption = "500kW"
buggy.braking_power = "750kW"
buggy.rotation_speed = buggy.rotation_speed * 0.9

buggy.equipment_grid = data.raw["car"]["tank"].equipment_grid
buggy.allow_remote_driving = true
buggy.resistances =
    {
      {
        type = "fire",
        percent = 60
      },
      {
        type = "impact",
        percent = 40,
        decrease = 75
      },
      {
        type = "acid",
        percent = 30,
        decrease = 10
      }
    }
buggy.friction = 2.5e-3
buggy.turret_animation = table.deepcopy(data.raw["ammo-turret"]["rocket-turret"].attacking_animation)

for i,layer in ipairs(buggy.turret_animation.layers) do
    if rro.contains(layer.flags,"mask") then
        --layer.apply_runtime_tint = false
        rro.remove(buggy.turret_animation.layers,layer)
        break
    end
    layer.scale = layer.scale * gun_scale
    layer.shift = util.by_pixel( 0, -32)
end

for i,layer in ipairs(buggy.animation.layers) do
    layer.scale = (layer.scale or 1) * buggy_scale
end
--buggy.minimap_representation.scale = (buggy.minimap_representation.scale or 1) * buggy_scale
for i,layer in ipairs(buggy.animation.layers) do
    layer.scale = (layer.scale or 1) * buggy_scale
end



local buggy_gun = table.deepcopy(data.raw["gun"]["spidertron-rocket-launcher-1"])

buggy_gun.name = "muluna-rocket-buggy-rocket-launcher"


table.insert(buggy.guns, buggy_gun.name)
data:extend{buggy,buggy_gun}