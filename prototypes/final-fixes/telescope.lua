
for _,space_location in pairs(data.raw["planet"]) do
    local recipe = {
        type = "recipe",
        name = "muluna-telescope-observation-" .. space_location.name,
        category = "muluna-telescope",
        energy_required = 60,
        ingredients = {},
        results = {{type = "item", name = "muluna-astronomical-data",amount = 10 + math.floor(Muluna.telescopes.shortest_space_distance("nauvis",space_location.name)/1500)}},
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
        },
        auto_recycle = false,
        localised_name = {"recipe-name.muluna-telescope-observation-x",{"space-location-name."..space_location.name}},
        order = "aa-" .. space_location.order
    }
    if space_location.name == "muluna" then
        recipe.results[1].amount = 10
    end
    Muluna.rro.soft_insert(data.raw["technology"]["muluna-telescope"].effects,
        {
            type = "unlock-recipe",
            recipe = recipe.name,
        }
        )
    data:extend{recipe}
end


