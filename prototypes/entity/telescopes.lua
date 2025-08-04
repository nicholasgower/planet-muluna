--Extends Assembling machine
local telescope = {
    type = "muluna-telescope", --Extends Assembling machine
    name = "muluna-telescope",
    crafting_speed = 1,
    recipe_categories = {"muluna-telescope-observation"},
    selection_box = Muluna.flib_bounding_box.from_dimensions({0,0},3,3),
    collision_box = Muluna.flib_bounding_box.from_dimensions({0,0},3-0.5,3-0.5),
    energy_usage = "2MW",
    energy_source = table.deepcopy(data.raw["assembling-machine-3"].circuit_connector),
    per_surface_limit = 1, --Custom field: Number of telescopes per surface
    circuit_connector = table.deepcopy(data.raw["assembling-machine-3"].circuit_connector),
}

--Extends Assembling machine
local space_telescope = {
    type = "muluna-space-telescope", 
    name = "muluna-space-telescope",
    crafting_speed = 1,
    distance_speed_factor = 1, --Custom field: How much distance from Muluna adds to productivity
    circuit_connector = table.deepcopy(data.raw["assembling-machine-3"].circuit_connector),
}

data:extend{telescope}