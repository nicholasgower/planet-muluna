local surface_property_lib = require("__PlanetsLib__.lib.surface-property-lib")
local categories = {"car"}

local nuclear_fuel_category = data.raw["item"]["nuclear-fuel"].fuel_category
local new_nuclear_fuel_category = "muluna-nuclear-chemical-fuel"
data.raw["item"]["nuclear-fuel"].fuel_category=new_nuclear_fuel_category

for _,category in pairs(categories) do
    for _,vehicle in pairs(data.raw[category]) do
        if (not vehicle.PlanetsLib_do_not_generate_variants) and 
        vehicle.surface_conditions and surface_property_lib.fits_surface_conditions(vehicle,"muluna") and 
        vehicle.energy_source.type == "burner" and 
        vehicle.energy_source.fuel_categories and Muluna.rro.contains(vehicle.energy_source.fuel_categories,"chemical") then
            local new_energy_source = table.deepcopy(vehicle.energy_source)
            new_energy_source.fuel_categories = {"muluna-oxygenated-fuel",new_nuclear_fuel_category}
            new_energy_source.burnt_inventory_size = new_energy_source.burnt_inventory_size or 2
            vehicle.fast_replaceable_group = not vehicle.fast_replaceable_group and vehicle.name
            local new_vehicle = PlanetsLib.create_planet_entity_variant("muluna",vehicle,
                {
                    
                    energy_source = new_energy_source,
                    placeable_by = data.raw.item[vehicle.name] and {{item = vehicle.name, count =1}}
                },
                "muluna-runtime-vehicle-replacement"
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

