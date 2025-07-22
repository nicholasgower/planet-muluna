local function extend_lunar_rock(copied_entity,results)
  local lunar_rock
  if data.raw["simple-entity"][copied_entity] then
    lunar_rock = table.deepcopy(data.raw["simple-entity"][copied_entity])
  else
    lunar_rock = table.deepcopy(data.raw["optimized-decorative"][copied_entity])
  end
  local tint = {1,1,0.5}
  for i,sprite in ipairs(lunar_rock.pictures) do
      sprite.filename = string.gsub(sprite.filename,"__base__/graphics/decorative","__muluna-graphics__/graphics/entities")
      --sprite.filename = "__muluna-graphics__/graphics/entities/"..copied_entity.."/"..copied_entity.."-" .. string.format("%02d",i+shift) .. ".png"
      --sprite.tint = tint
  end

  lunar_rock.icons = {{icon = lunar_rock.icon, icon_size = lunar_rock.icon_size, tint = tint}}
  if copied_entity == "big-rock" then
    lunar_rock.name = "lunar-rock"
  else
    lunar_rock.name = "lunar-" .. lunar_rock.name
  end
  
  if lunar_rock.minable then
    lunar_rock.minable.results = results
  end
  

  lunar_rock.map_color = {174, 174, 174}




  lunar_rock.autoplace =
  {
    control = "lunar_rocks",
    order = "a[doodad]-a[rock]-b[big]",
    probability_expression = "multiplier * control * (region_box + lunar_rock_density - penalty)",
    local_expressions =
    {
      multiplier = 0.17,
      penalty = 1.6,
      region_box = "range_select_base(moisture, 0.35, 1, 0.2, -10, 0)",
      control = "control:lunar_rocks:size"
    }
  }
  data:extend{lunar_rock}
end

extend_lunar_rock("big-rock",
  {
        {type = "item", name = "sulfur", amount = 2},
        {type = "item", name = "stone", amount = 20},
  }

)

extend_lunar_rock("huge-rock",
  {
        {type = "item", name = "sulfur", amount = 5},
        {type = "item", name = "stone", amount = 40},
  }

)

extend_lunar_rock("medium-rock", nil)
extend_lunar_rock("small-rock", nil)
extend_lunar_rock("tiny-rock", nil)


data:extend{
    {
        type = "noise-expression",
        name = "lunar_rock_noise",
        expression = "multioctave_noise{x = x,\z
                                        y = y,\z
                                        seed0 = map_seed,\z
                                        seed1 = 1371,\z
                                        octaves = 4,\z
                                        persistence = 0.9,\z
                                        input_scale = 0.15 * var('control:lunar_rocks:frequency'),\z
                                        output_scale = 1} + 0.25 + 0.75 * (slider_rescale(control:lunar_rocks:size, 1.5) - 1)"
      },
      {
        type = "noise-expression",
        name = "lunar_rock_density",
        expression = "lunar_rock_noise - max(0, 1.1 - distance / 32)"
      }


}

local ancient_container = table.deepcopy(data.raw["temporary-container"]["cargo-pod-container"])

ancient_container.picture.layers[1].filename = "__muluna-graphics__/graphics/entities/cargo-pod/pod-landing.png"
ancient_container.name = "fulgoran-cargo-pod-container"
ancient_container.alert_after_time = 0
data:extend{ancient_container}



local simulations = require("__base__.prototypes.factoriopedia-simulations")
local lunar_cliff = table.deepcopy(data.raw["cliff"]["cliff"])
lunar_cliff.name = "cliff-muluna"

local lunar_cliff = scaled_cliff(
    {
      mod_name = "__muluna-graphics__",
      name = "cliff-muluna",
      map_color = {r=90, g=90, b=110},
      suffix = nil,
      scale = 1.0,
      has_lower_layer = true,
      factoriopedia_simulation = simulations.factoriopedia_cliff
    }
  )
data:extend{lunar_cliff}


