local rro = Muluna.rro
local MJ_per_fluid = 0.1
local roboport_power_MW=5
local fluid_per_craft = 10
data:extend{
    rro.merge(data.raw["fluid"]["water"],{
        type = "fluid",
        name = "muluna-roboport-energy",
        icon = "__base__/graphics/icons/signal/signal-battery-full.png",
        icon_size = 64,
        fuel_value = tostring(MJ_per_fluid) .. "MJ"
    }),
    {
        type = "recipe",
        categories = {"muluna-burner-roboport"},
        name = "burner-roboport-refuel-muluna",
        subgroup = data.raw["item"]["roboport"].subgroup,
        group = data.raw["item"]["roboport"].group,
        order = data.raw["item"]["roboport"].order .. "a",
        ingredients = {{type = "fluid",name = "thruster-oxidizer", amount = fluid_per_craft*2,fluidbox_index = 1,optional_fluidbox_indexes = {2}}},
        results = {{type = "fluid",name = "muluna-roboport-energy", amount = fluid_per_craft*1, fluidbox_multiplier = 100,ignored_by_productivity=fluid_per_craft*1}},
        icon = "__base__/graphics/icons/signal/signal-battery-full.png",
        icon_size = 64,
        energy_required = fluid_per_craft*MJ_per_fluid/roboport_power_MW,
        hide_from_player_crafting=true,
        hidden=true,

    },
    
}