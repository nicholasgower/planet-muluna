local roboport = table.deepcopy(data.raw["roboport"]["roboport"])

roboport.name = "muluna-burner-roboport"
roboport.energy_usage = "0W"
roboport.is_vacuum_roboport = true
roboport.recharging_animation.filename = "__muluna-graphics__/graphics/entity/burner-roboport/burner-roboport-recharging.png"
roboport.base.layers[1].filename = "__muluna-graphics__/graphics/entity/burner-roboport/burner-roboport-base.png"
roboport.base_patch.filename = "__muluna-graphics__/graphics/entity/burner-roboport/burner-roboport-base-patch.png"
data:extend{roboport}
