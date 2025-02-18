require("__core__/lualib/util.lua")
local flib_bounding_box = require("__flib__/bounding-box")

local radarEntity = table.deepcopy(data.raw.radar.radar)
local radarItem = table.deepcopy(data.raw.item.radar)
local radarRecipe = table.deepcopy(data.raw.recipe.radar)
local radarTech = table.deepcopy(data.raw.technology.radar)

---@type ItemPrototype
local navBeaconItem = util.merge({
    radarItem,
    {
        name = "nav-beacon",
        place_result = "nav-beacon",
        icon = "__planet-muluna__/graphics/icons/nav-beacon-icon.png",
        localised_description = { "item-description.nav-beacon", tostring(settings.startup["planet-power-consumption"].value), tostring(settings.startup["platform-power-consumption"].value) },
        icon_size = 64,
        stack_size = 10,
    }
})
navBeaconItem.order = navBeaconItem.order .. "-z"


radarEntity.pictures = nil
---@type RadarPrototype
local navBeaconEntity = util.merge({
    radarEntity,
    {
        name = "nav-beacon",
        selection_box = flib_bounding_box.resize(radarEntity.selection_box,3),
        collision_box = flib_bounding_box.resize(radarEntity.collision_box,3),
        minable = { mining_time = 2, result = "nav-beacon" },
        fast_replaceable_group = "nav-beacon",
        energy_per_sector = "1TJ",
        max_distance_of_sector_revealed = 1,
        max_distance_of_nearby_sector_revealed = 15,
        energy_per_nearby_scan = "1kJ",
        localised_description = { "entity-description.nav-beacon", tostring(settings.startup["planet-power-consumption"].value), tostring(settings.startup["platform-power-consumption"].value) },
        energy_source =
        {
            type = "electric",
            usage_priority = "secondary-input"
        },
        surface_conditions = {
            {
                property = "gravity",
                min = 0,
                max = 0,
            }
        },
        energy_usage = settings.startup["planet-power-consumption"].value .. "MW",
        icon = "__planet-muluna__/graphics/icons/nav-beacon-icon.png",
        icon_size = 64,
        rotation_speed = 0.01,
        corpse = "medium-remnants",
        pictures =
        {
            layers =
            {
                {
                    filename = "__planet-muluna__/graphics/entities/nav-beacon/nav-beacon.png",
                    priority = "low",
                    width = 197,
                    height = 212,
                    apply_projection = false,
                    direction_count = 1,
                    line_length = 1,
                    shift = util.by_pixel(1.0, -4.0),
                    scale = 1.5
                }
            }
        },

    }
})
navBeaconEntity.circuit_connector = nil
local navBeaconEntity_Platform = table.deepcopy(navBeaconEntity)
navBeaconEntity_Platform.name = navBeaconEntity_Platform.name .. "-platform"
navBeaconEntity_Platform.localised_name = { "", { "entity-name.nav-beacon" }, " - ", { "entity-name.platform-mode" } }
navBeaconEntity_Platform.energy_usage = settings.startup["platform-power-consumption"].value .. "MW"
local navBeaconEntity_Planet = table.deepcopy(navBeaconEntity)
navBeaconEntity_Planet.name = navBeaconEntity_Planet.name .. "-planet"
navBeaconEntity_Planet.localised_name = { "", { "entity-name.nav-beacon" }, " - ", { "entity-name.planet-mode" } }
navBeaconEntity_Planet.energy_usage = settings.startup["planet-power-consumption"].value .. "MW"

--nil it before merge to replace
radarRecipe.ingredients = nil
radarRecipe.results = nil

---@type RecipePrototype
local navBeaconRecipe = util.merge({
    radarRecipe,
    {
        name = "nav-beacon",
        ingredients =
        {
            { type = "item", name = "processing-unit", amount = 50 },
            { type = "item", name = "radar",           amount = 25 },
            { type = "item", name = "beacon",          amount = 10 },
            { type = "item", name = "superconductor",          amount = 100 },
            { type = "item", name = "aluminum-plate",          amount = 100 },
        },
        results = { { type = "item", name = "nav-beacon", amount = 1 } },
    }
})

--nil it before merge to replace
radarTech.effects = nil
radarTech.prerequisites = nil
radarTech.unit = nil
---@type RecipePrototype
local navBeaconTech = util.merge({
    radarTech,
    {
        name = "nav-beacon",
        effects =
        {
            {
                type = "unlock-recipe",
                recipe = "nav-beacon"
            }
        },
        prerequisites = { "radar", "effect-transmission", "interstellar-science-pack" },
        unit =
        {
            count = 2000,
            ingredients = {
                { "automation-science-pack", 1 },
                { "logistic-science-pack",   1 },
                { "chemical-science-pack",   1 },
                { "military-science-pack",      1 },
                { "utility-science-pack",      1 },
                { "space-science-pack",      1 },
                { "electromagnetic-science-pack",      1 },
                { "interstellar-science-pack", 1 },
            },
            time = 10
        },
        icon = "__planet-muluna__/graphics/icons/nav-beacon-icon.png",
        icon_size = 64,
        localised_description = { "technology-description.nav-beacon", tostring(settings.startup["planet-power-consumption"].value), tostring(settings.startup["platform-power-consumption"].value) }
    }
})


data:extend({
    navBeaconEntity_Planet,
    navBeaconEntity_Platform,
    navBeaconEntity,
    navBeaconItem,
    navBeaconRecipe,
    navBeaconTech
})
