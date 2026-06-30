local roboport = table.deepcopy(data.raw["roboport"]["roboport"])

roboport.name = "muluna-burner-roboport"
roboport.is_vacuum_roboport = true

data:extend{roboport}
