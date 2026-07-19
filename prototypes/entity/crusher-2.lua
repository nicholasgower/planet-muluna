data:extend{
    {
        type = "recipe-category",
        name = "muluna-crusher-2"
    }
}
local flib_data_util=require("__flib__.data-util")


local crusher_2=table.deepcopy(data.raw["assembling-machine"]["crusher"])

crusher_2.name="crusher-2"
crusher_2.module_slots=crusher_2.module_slots + 2
crusher_2.minable.result="crusher-2"
crusher_2.graphics_set = require("__muluna-graphics__.graphics.entities.crusher.crusher-2-pictures")
crusher_2.crafting_speed=crusher_2.crafting_speed*1.5
crusher_2.max_health=crusher_2.max_health+50
local energy, suffix=flib_data_util.get_energy_value(crusher_2.energy_usage)
crusher_2.energy_usage=tostring(energy*2) .. suffix
crusher_2.energy_source.emissions_per_minute["pollution"] = crusher_2.energy_source.emissions_per_minute["pollution"]*0.75
table.insert(crusher_2.crafting_categories,"muluna-crusher-2")
--crusher_2.energy_usage=crusher_2.crafting_speed*2
crusher_2.localised_name={"",{"item-name.crusher"}," 2"}
crusher_2.icon="__muluna-graphics__/graphics/icons/crusher-2.png"

if mods["rigor-module"] then

    data.raw["mod-data"]["rigor_module_mod_data"].data["entity_to_base_rigor"][crusher_2.name]=50
end

data:extend{crusher_2}

data.raw["assembling-machine"]["crusher"].next_upgrade = crusher_2.name