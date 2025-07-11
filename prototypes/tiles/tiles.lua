
local concrete = table.deepcopy(data.raw["tile"]["concrete"])
local refined_concrete = table.deepcopy(data.raw["tile"]["refined-concrete"])

local muluna_dirt_base=table.deepcopy(data.raw["tile"]["dry-dirt"])
muluna_dirt_base.walking_speed_modifier = 0.5
muluna_dirt_base.vehicle_friction_modifier = concrete.vehicle_friction_modifier
muluna_dirt_base.walking_sound = "__space-age__/sound/walking/soft-sand-1.ogg"
muluna_dirt_base.absorptions_per_second={
    radiation = 0.01/60
  }
local color={
    {55,55,55},
    {50,50,50},
    {45,45,45},
    {60,60,60},
    {70,70,70},
    {80,80,80},
}

for i = 1,6,1 do
    local muluna_dirt=table.deepcopy(muluna_dirt_base)
    muluna_dirt.name="muluna-dirt-"..tostring(i)
    muluna_dirt.autoplace = {probability_expression = 'expression_in_range_base(0.45, -10, 0.55, 0.35) + 0.25*noise_layer_noise('..tostring(i)..')'}
    muluna_dirt.localised_name={"tile-name.muluna-dirt",tostring(i)}
    
    muluna_dirt.variants = tile_variations_template(
    "__alien-biomes-graphics__/graphics/terrain/mineral-grey-dirt-"..tostring(i)..".png", "__base__/graphics/terrain/masks/transition-3.png",
    {
   
      max_size = 4,
      [1] = { weights = {0.085, 0.085, 0.085, 0.085, 0.087, 0.085, 0.065, 0.085, 0.045, 0.045, 0.045, 0.045, 0.005, 0.025, 0.045, 0.045 } },
      [2] = { probability = 1, weights = {0.070, 0.070, 0.025, 0.070, 0.070, 0.070, 0.007, 0.025, 0.070, 0.050, 0.015, 0.026, 0.030, 0.005, 0.070, 0.027 }, },
      [4] = { probability = 1.00, weights = {0.070, 0.070, 0.070, 0.070, 0.070, 0.070, 0.015, 0.070, 0.070, 0.070, 0.015, 0.050, 0.070, 0.070, 0.065, 0.070 }, },
      --[8] = { probability = 1.00, weights = {0.090, 0.125, 0.125, 0.125, 0.125, 0.125, 0.125, 0.025, 0.125, 0.005, 0.010, 0.100, 0.100, 0.010, 0.020, 0.020} }
    }
    )
  
  muluna_dirt.layer=19+i
  muluna_dirt.map_color=color[i]
  --muluna_dirt.effect = "space"
  data:extend{muluna_dirt}
end


local muluna_sand_base=table.deepcopy(data.raw["tile"]["dry-dirt"])

local color_sand={
    {85,85,85},
    {90,90,90},
    {87,87,87},
}

for i = 1,3,1 do
    local muluna_dirt=table.deepcopy(muluna_sand_base)
    muluna_dirt.name="muluna-dirt-"..tostring(i+6)
    muluna_dirt.autoplace = {probability_expression = 'expression_in_range_base(0.45, -10, 0.55, 0.35) + 0.25*noise_layer_noise('..tostring(i+6)..')'}
    muluna_dirt.localised_name={"tile-name.muluna-dirt",tostring(i+6)}
    muluna_dirt.walking_speed_modifier = 0.5
    muluna_dirt.vehicle_friction_modifier = refined_concrete.vehicle_friction_modifier
    muluna_dirt.walking_sound = "__space-age__/sound/walking/soft-sand-1.ogg"
    muluna_dirt.variants = tile_variations_template(
    "__alien-biomes-graphics__/graphics/terrain/mineral-grey-sand-"..tostring(i)..".png", "__base__/graphics/terrain/masks/transition-3.png",
    {
   
      max_size = 4,
      [1] = { weights = {0.085, 0.085, 0.085, 0.085, 0.087, 0.085, 0.065, 0.085, 0.045, 0.045, 0.045, 0.045, 0.005, 0.025, 0.045, 0.045 } },
      [2] = { probability = 1, weights = {0.070, 0.070, 0.025, 0.070, 0.070, 0.070, 0.007, 0.025, 0.070, 0.050, 0.015, 0.026, 0.030, 0.005, 0.070, 0.027 }, },
      [4] = { probability = 1.00, weights = {0.070, 0.070, 0.070, 0.070, 0.070, 0.070, 0.015, 0.070, 0.070, 0.070, 0.015, 0.050, 0.070, 0.070, 0.065, 0.070 }, },
      --[8] = { probability = 1.00, weights = {0.090, 0.125, 0.125, 0.125, 0.125, 0.125, 0.125, 0.025, 0.125, 0.005, 0.010, 0.100, 0.100, 0.010, 0.020, 0.020} }
    }
    
    
   
    
  )
  --muluna_dirt.effect = "space"
  muluna_dirt.absorptions_per_second={
    radiation = 0.01/60
  }
  muluna_dirt.layer=25+i
  muluna_dirt.map_color=color_sand[i]
  data:extend{muluna_dirt}
end








