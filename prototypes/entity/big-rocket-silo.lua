local flib_bounding_box = Muluna.flib_bounding_box
local rocket_silo= data.raw["rocket-silo"]["rocket-silo"]
local rocket = data.raw["rocket-silo-rocket"]["rocket-silo-rocket"]
local cargo_pod = data.raw["cargo-pod"]["cargo-pod"]
local rocket_shadow = data.raw["rocket-silo-rocket-shadow"]["rocket-silo-rocket-shadow"]


local big_silo = table.deepcopy(rocket_silo)
local big_rocket = table.deepcopy(rocket)
local big_pod = table.deepcopy(cargo_pod)
local big_shadow = table.deepcopy(rocket_shadow)

big_silo.name = "muluna-big-rocket-silo"
big_rocket.name= "muluna-big-rocket-silo-rocket"
big_pod.name = "muluna-big-cargo-pod"
big_shadow.name = "muluna-big-rocket-silo-rocket-shadow"


big_silo.lift_weight = (rocket_silo.lift_weight or 1000000) * 5
big_silo.rocket_parts_required= rocket_silo.rocket_parts_required * 3
big_silo.crafting_speed = big_silo.crafting_speed * 3

big_silo.active_energy_usage = Muluna.multiply_energy(big_silo.active_energy_usage,5)
big_silo.lamp_energy_usage = Muluna.multiply_energy(big_silo.active_energy_usage,3)

big_rocket.tall = true
big_silo.selection_box=flib_bounding_box.resize(rocket_silo.selection_box,3) 
big_silo.collision_box=flib_bounding_box.resize(rocket_silo.collision_box,3) 

big_silo.fluidboxes=nil

local objects = {big_silo,big_rocket,big_pod,rocket_shadow}

--Scale up all of the graphics fields(There are many of them)
for _,scalar_field in pairs({"scale","rocket_render_layer_switch_distance","full_render_layer_switch_distance","rocket_above_wires_slice_offset_from_center","rocket_air_object_slice_offset_from_center","rocket_visible_distance_from_center"}) do
    Muluna.rro.deep_replace_field(objects,scalar_field,function(old_scale) return old_scale * 15/9 end)
end
for _,vector_field in pairs({"shift","rocket_rise_offset","rocket_initial_offset","rocket_launch_offset","door_back_open_offset","door_front_open_offset"}) do
    Muluna.rro.deep_replace_field(objects,vector_field,function(old_shift) return {(old_shift[1] or old_shift.x )*15/9,(old_shift[2] or old_shift.y)*15/9} end)
end
for _,box_field in pairs({"hole_clipping_box"}) do
    Muluna.rro.deep_replace_field(objects,box_field,function(old) return {left_top = {old[1][1]*15/9,old[1][2]*15/9}, right_bottom = {old[2][1]*15/9,old[2][2]*15/9}, orientation = old.orientation} end)
end


big_silo.rocket_entity=big_rocket.name
big_rocket.cargo_pod_entity=big_pod.name
big_rocket.shadow_slave_entity = rocket_shadow.name

data:extend{big_silo,big_rocket,big_pod}

