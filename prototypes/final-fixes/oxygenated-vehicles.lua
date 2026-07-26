local surface_property_lib = require("__PlanetsLib__.lib.surface-property-lib")
for _,vehicle in pairs(data.raw.car) do
    if (not vehicle.PlanetsLib_do_not_generate_variants) and surface_property_lib.fits_surface_conditions(vehicle,"muluna") and vehicle.energy_source.type == "burner" then
        local new_energy_source = table.deepcopy(vehicle.energy_source)
        new_energy_source.fuel_categories = {"muluna-oxygenated-fuel"}
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
