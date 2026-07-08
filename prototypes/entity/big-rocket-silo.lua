local flib_bounding_box = Muluna.flib_bounding_box
local rocket_silo= data.raw["rocket-silo"]["rocket-silo"]
local rocket = data.raw["rocket-silo-rocket"]["rocket-silo-rocket"]
local cargo_pod = data.raw["cargo-pod"]["cargo-pod"]
local rocket_shadow = data.raw["rocket-silo-rocket-shadow"]["rocket-silo-rocket-shadow"]
local rro = Muluna.rro

local big_silo = table.deepcopy(rocket_silo)
local big_rocket = table.deepcopy(rocket)
local big_pod = table.deepcopy(cargo_pod)
local big_shadow = table.deepcopy(rocket_shadow)

big_silo.name = "muluna-big-rocket-silo"
big_silo.minable.result= "muluna-big-rocket-silo"
big_rocket.name= "muluna-big-rocket-silo-rocket"
big_pod.name = "muluna-big-cargo-pod"
big_shadow.name = "muluna-big-rocket-silo-rocket-shadow"


big_silo.lift_weight = (rocket_silo.lift_weight or 1000000) * 5
big_silo.rocket_parts_required= rocket_silo.rocket_parts_required * 3
big_silo.crafting_speed = big_silo.crafting_speed * 3

big_silo.active_energy_usage = Muluna.multiply_energy(big_silo.active_energy_usage,5)
big_silo.lamp_energy_usage = Muluna.multiply_energy(big_silo.lamp_energy_usage,3)

big_rocket.tall = true
big_silo.selection_box=flib_bounding_box.resize(rocket_silo.selection_box,3) 
big_silo.collision_box=flib_bounding_box.resize(rocket_silo.collision_box,3) 

big_silo.fluidboxes=nil

local objects = {big_silo,big_rocket,big_pod,rocket_shadow}

Muluna.machine_scaling.scale_entity(objects,15/9)
-- Muluna.rro.deep_replace_field(objects,"flags",function(old_flags) 
--     local new_flags=table.deepcopy(old_flags)
--     rro.soft_insert(new_flags,"not-compressed")
--     return new_flags end)

big_silo.rocket_entity=big_rocket.name
big_rocket.cargo_pod_entity=big_pod.name
big_rocket.shadow_slave_entity = rocket_shadow.name

big_silo.module_slots = 8

data:extend{big_silo,big_rocket,big_pod}

