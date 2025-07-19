if settings.startup["enable-nav-beacon"].value == true then
    
    
    require("__core__/lualib/util.lua")
    local flib_bounding_box = require("__flib__/bounding-box")


   







    local radarEntity = table.deepcopy(data.raw.accumulator.accumulator)
    local radarItem = table.deepcopy(data.raw.item.radar)
    local radarRecipe = table.deepcopy(data.raw.recipe.radar)
    local radarTech = table.deepcopy(data.raw.technology.radar)

    ---@type ItemPrototype
    local navBeaconItem = util.merge({
        radarItem,
        {
            name = "muluna-satellite-radar",
            place_result = "muluna-satellite-radar",
            subgroup = "space-platform",
            order = "q[nav-beacon]",
            icon = "__muluna-graphics__/graphics/icons/nav-beacon-icon.png",
            localised_description = { "item-description.muluna-satellite-radar"},
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
            name = "muluna-satellite-radar",
            subgroup = "space-platform",
            order = "q[nav-beacon]",
            module_slots=0,
            distribution_effectivity = 0,
            distribution_effectivity_bonus_per_quality_level = 0,
            supply_area_distance = 0,
            selection_box = flib_bounding_box.resize(radarEntity.selection_box,3),
            collision_box = flib_bounding_box.resize(radarEntity.collision_box,3),
            minable = { mining_time = 2, result = "muluna-satellite-radar" },
            fast_replaceable_group = "muluna-satellite-radar",
            energy_per_sector = "1TJ",
            
            --max_distance_of_sector_revealed = 1,
            --max_distance_of_nearby_sector_revealed = 15,
            energy_per_nearby_scan = "1kJ",
            --localised_description = { "entity-description.muluna-satellite-radar"},
            localised_description = { "item-description.muluna-satellite-radar"},
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
            energy_usage = settings.startup["platform-power-consumption"].value .. "MW",
            icon = "__muluna-graphics__/graphics/icons/nav-beacon-icon.png",
            icon_size = 64,
            rotation_speed = 0.01,
            corpse = "medium-remnants",
            
            
            energy_source = {
                type = "electric",
                buffer_capacity = 3*settings.startup["platform-power-consumption"].value .. "MJ",
                output_flow_limit = "0MW",
                input_flow_limit = 3*settings.startup["platform-power-consumption"].value .. "MW",
            },
            custom_tooltip_fields = {
                {},
                {},
            }

        }
    })
    local navBeaconData = {
        type = "mod-data",
        name = "muluna-satellite-radar",
        data = {
            entities = {}, --List of satellite radar entities and associated stats
            energy_per_scan_expression = "base / (1 + 0.3 * quality_level)", --Formula evaluating energy usage per scan.
            scan_size_expression = "base * (1 + 0.3 * quality_level)", -- Formula evaluating tiles scanned per scan.
        }
    }
    navBeaconData.data.entities[navBeaconEntity.name] =
    {
        name = navBeaconEntity.name,
        energy_per_scan = settings.startup["platform-power-consumption"].value,
        scan_area = 100
    }

    navBeaconEntity.graphics_set = nil
    navBeaconEntity.circuit_connector = nil
    navBeaconEntity.next_upgrade = nil
    navBeaconEntity.chargable_graphics =
            {
                picture =
                
                    {
                        filename = "__muluna-graphics__/graphics/entities/nav-beacon/nav-beacon.png",
                        priority = "low",
                        width = 197,
                        height = 212,
                        apply_projection = false,
                        direction_count = 1,
                        line_length = 1,
                        shift = util.by_pixel(1.0, -4.0),
                        scale = 1.5*8/9
                    }
                
            }
    local navBeaconEntity_Platform = table.deepcopy(navBeaconEntity)
    navBeaconEntity_Platform.name = navBeaconEntity_Platform.name .. "-platform"
    navBeaconEntity_Platform.localised_name = { "entity-name.muluna-satellite-radar" }
    navBeaconEntity_Platform.energy_usage = settings.startup["platform-power-consumption"].value .. "MW"

    -- local navBeaconEntity_Planet = table.deepcopy(navBeaconEntity)
    -- navBeaconEntity_Planet.name = navBeaconEntity_Planet.name .. "-planet"
    -- --navBeaconEntity_Planet.localised_name = { "", { "entity-name.nav-beacon" }, " - ", { "entity-name.planet-mode" } }
    -- navBeaconEntity_Planet.energy_usage = settings.startup["platform-power-consumption"].value .. "MW"

    --nil it before merge to replace
    radarRecipe.ingredients = nil
    radarRecipe.results = nil

    ---@type RecipePrototype
    local navBeaconRecipe = util.merge({
        radarRecipe,
        {
            name = "muluna-satellite-radar",
            subgroup = "space-platform",
            order = "q[nav-beacon]",
            energy_required = 20,
            ingredients =
            {
                { type = "item", name = "processing-unit", amount = 50 },
                { type = "item", name = "radar",           amount = 25 },
                { type = "item", name = "beacon",          amount = 10 },
                { type = "item", name = "superconductor",          amount = 100 },
                { type = "item", name = "tungsten-plate",          amount = 100 },
                { type = "item", name = "aluminum-plate",          amount = 100 },
            },
            results = { { type = "item", name = "muluna-satellite-radar", amount = 1 } },
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
            name = "muluna-satellite-radar",
            localised_name = {"entity-name.muluna-satellite-radar"},
            localised_description = { "item-description.muluna-satellite-radar"},
            --localised_description={"entity-description.muluna-satellite-radar"},
            effects =
            {
                {
                    type = "unlock-recipe",
                    recipe = "muluna-satellite-radar"
                }
            },
            prerequisites = { "radar", "effect-transmission", "interstellar-science-pack","artillery"},
            unit =
            {
                count = 3000,
                ingredients = {
                    { "automation-science-pack", 1 },
                    { "logistic-science-pack",   1 },
                    { "chemical-science-pack",   1 },
                    { "military-science-pack",      1 },
                    { "utility-science-pack",      1 },
                    { "space-science-pack",      1 },
                    { "metallurgic-science-pack",      1 },
                    { "electromagnetic-science-pack",      1 },
                    { "interstellar-science-pack", 1 },
                },
                time = 30
            },
            icon = "__muluna-graphics__/graphics/icons/nav-beacon-icon.png",
            icon_size = 64,
        }
    })
    
    data:extend({
        -- navBeaconEntity_Planet,
        --navBeaconEntity_Platform,
        navBeaconEntity,
        navBeaconItem,
        navBeaconRecipe,
        navBeaconTech,
        navBeaconData,
    })
end