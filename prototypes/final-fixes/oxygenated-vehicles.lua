local surface_property_lib = require("__PlanetsLib__.lib.surface-property-lib")
local categories = {"car","spider-vehicle","locomotive"}

local nuclear_fuel_category = data.raw["item"]["nuclear-fuel"].fuel_category
local new_nuclear_fuel_category = "muluna-nuclear-chemical-fuel"

local changed_items = {
    "nuclear-fuel",
    "rocket-fuel",
}

for _,item in pairs(changed_items) do
    data.raw["item"][item].fuel_category=new_nuclear_fuel_category
end



for _,category in pairs(categories) do
    local setting = "muluna-runtime-vehicle-replacement"
    if category == "locomotive" then
        setting = "muluna-runtime-locomotive-replacement"
    end
    for _,vehicle in pairs(data.raw[category]) do
        if (not vehicle.PlanetsLib_do_not_generate_variants) and 
        (not vehicle.surface_conditions or surface_property_lib.fits_surface_conditions(vehicle,"muluna")) and 
        vehicle.energy_source.type == "burner" and 
        vehicle.energy_source.fuel_categories and Muluna.rro.contains_any(vehicle.energy_source.fuel_categories,{"chemical","kr-vehicle-fuel"}) then
            local new_energy_source = table.deepcopy(vehicle.energy_source)
            new_energy_source.fuel_categories = {"muluna-oxygenated-fuel",new_nuclear_fuel_category}
            new_energy_source.burnt_inventory_size = new_energy_source.burnt_inventory_size or 2
            vehicle.fast_replaceable_group = vehicle.fast_replaceable_group or vehicle.name
            local new_placeable_by = data.raw.item[vehicle.name] and {{item = vehicle.name, count =1}} or nil
            local item_name = data.raw["item-with-entity-data"][vehicle.name] and vehicle.name or nil
            --error(vehicle.name .. " " .. item_name)
            local new_vehicle = PlanetsLib.create_planet_entity_variant("muluna",vehicle,
                {
                    
                    energy_source = new_energy_source,
                    placeable_by = new_placeable_by
                },
                setting,
                item_name
            )
            
        end
        
        

    end
end


for _,entity in pairs(Muluna.flib_prototypes.all("entity")) do
    local energy_source = entity.energy_source 
    if energy_source and energy_source.type == "burner" then
        if Muluna.rro.contains(energy_source.fuel_categories,nuclear_fuel_category) then
            table.insert(energy_source.fuel_categories,new_nuclear_fuel_category)
        end
    end
end

