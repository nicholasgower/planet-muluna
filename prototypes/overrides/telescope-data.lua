local rro = Muluna.rro

-- Telescope data collection recipes
for _,space_location in pairs(data.raw["planet"]) do
    print(rro.safe_find(data.raw["mod-data"],{"maraxsis-constants","TRENCH_SURFACE_NAME"}))
    if       string.find(space_location.name,"factory%-floor") == nil and --Blacklist Factorissimo surfaces
             space_location.name~="factory-travel-surface" and
             not space_location.name ~= rro.safe_find(data.raw["mod-data"],{"maraxsis-constants","TRENCH_SURFACE_NAME"})

             
             
        then
        local distance_factor = ((Muluna.telescopes.shortest_space_distance("nauvis",space_location.name)))
        if distance_factor then
            local recipe = {
                type = "recipe",
                name = "muluna-telescope-observation-" .. space_location.name,
                category = "muluna-telescope",
                energy_required = 6,
                ingredients = {},
                results = {{type = "fluid", name = "muluna-astronomical-data",amount = 100 + math.floor(distance_factor)/150}},
                icons = Muluna.icons.dual_icon("muluna-astronomical-data",space_location.name),
                surface_conditions = {
                    {
                        property = "pressure",
                        min = space_location.surface_properties["pressure"] or data.raw["surface-property"]["pressure"].default_value,
                        max = space_location.surface_properties["pressure"] or data.raw["surface-property"]["pressure"].default_value,
                    },
                    {
                        property = "gravity",
                        min = space_location.surface_properties["gravity"] or data.raw["surface-property"]["gravity"].default_value,
                        max = space_location.surface_properties["gravity"] or data.raw["surface-property"]["gravity"].default_value,
                    },
                    {
                        property = "temperature",
                        min = space_location.surface_properties["temperature"] or data.raw["surface-property"]["temperature"].default_value,
                        max = space_location.surface_properties["temperature"] or data.raw["surface-property"]["temperature"].default_value,
                    },
                    {
                        property = "magnetic-field",
                        min = space_location.surface_properties["magnetic-field"] or data.raw["surface-property"]["magnetic-field"].default_value,
                        max = space_location.surface_properties["magnetic-field"] or data.raw["surface-property"]["magnetic-field"].default_value,
                    },
                },
                auto_recycle = false,
                localised_name = {"recipe-name.muluna-telescope-observation-x",{"space-location-name."..space_location.name}},
                order = "aa-" .. (space_location.order or "")
            }
            if space_location.name == "muluna" then
                recipe.results[1].amount = 100
            end
            Muluna.rro.soft_insert(data.raw["technology"]["muluna-telescope"].effects,
                {
                    type = "unlock-recipe",
                    recipe = recipe.name,
                }
                )
            data:extend{recipe}
        end
    end
end


