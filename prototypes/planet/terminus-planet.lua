if settings.startup["muluna-enable-terminus-planet"].value == true then

    data:extend({
		{
			type = "surface-property",
			name = "is-terminus",
      hidden = true,
			default_value = 0,
      localised_name = {"surface-property-name.planet-str"},
			localised_unit_key = "surface-property-unit.planet-str",
			order = "z[is-terminus]za",
		},
	})

    local map_gen = {
    property_expression_names =
    { -- Warning: anything set here overrides any selections made in the map setup screen so the options do nothing.
      cliff_elevation = "cliff_elevation_muluna",
      cliffiness = "cliffiness_muluna",
      --elevation = "elevation_island"
      elevation = "elevation_muluna"
    },
    cliff_settings = 
    {
        name = "cliff-muluna",
        control = "muluna_cliff",
        cliff_smoothing = 0.1,
        cliff_elevation_0 = -0,
        cliff_elevation_interval = 1,
        richness = 1
      },
    autoplace_controls = 
    {
        --["stone"] = {},
        --["lunar_rocks"] = {},
        ["muluna_cliff"] = {},
        --["oxide-asteroid-chunk"] = {},
        --["metallic-asteroid-chunk"] = {},
        --["carbonic-asteroid-chunk"] = {},
        --["anorthite-chunk"] = {},
        --["helium"] = {},
        --["uranium-ore"] = {},
      },
    autoplace_settings = {
        ["tile"] =
      {
        settings =
        {
            ["terminus-dirt-1"] = {},
            ["terminus-dirt-2"] = {},
            ["terminus-dirt-3"] = {},
            ["terminus-dirt-4"] = {},
            ["terminus-dirt-5"] = {},
            ["terminus-dirt-6"] = {},
            ["terminus-dirt-7"] = {},
            ["terminus-dirt-8"] = {},
            ["terminus-dirt-9"] = {},
        }
      },
      ["decorative"] =
      {
        settings =
        {
          --["lunar-medium-rock"] = data.raw["optimized-decorative"]["lunar-medium-rock"] ~= nil and {} or nil,
          --["lunar-small-rock"] = data.raw["optimized-decorative"]["lunar-small-rock"] ~= nil and {} or nil,
          --["lunar-tiny-rock"] = data.raw["optimized-decorative"]["lunar-tiny-rock"] ~= nil and {} or nil,
          --["medium-sand-rock"] = {},
          --["small-sand-rock"] = {}
        }
      },
        ["entity"] =
      {
        settings =
        {
          --["stone"] = {},
          --["lunar-rock"] = data.raw["simple-entity"]["lunar-rock"] ~= nil and {} or nil,
          --["lunar-huge-rock"] = data.raw["simple-entity"]["lunar-huge-rock"] ~= nil and {} or nil,
          --["big-sand-rock"] = {},
          --["huge-rock"] = {},
          --["big-rock"] = {},
          --["oxide-asteroid-chunk"] = {},
          --["metallic-asteroid-chunk"] = {},
          --["carbonic-asteroid-chunk"] = {},
          --["anorthite-chunk"] = {},
          --["helium"] = {},
          --["uranium-ore"] = {},
        }
      }
    }


}

local solar_system_edge = data.raw["space-location"]["solar-system-edge"]

local terminus= 
{
    type = "planet",
    name = "terminus",
    
    draw_orbit = true,
    solar_power_in_space = solar_system_edge.solar_power_in_space,
    auto_save_on_first_trip = true,
    gravity_pull = 5,
    order = solar_system_edge.order .. "a",
    
    icons = {
      {
        icon = "__muluna-graphics__/graphics/icons/pluto.png",
        icon_size = 64,
        
      }
    },
    icon = "__muluna-graphics__/graphics/icons/pluto.png",
    icon_size = 64,
    
    --orientation = nauvis.orientation-0.02,
    --distance = nauvis.distance*1.0,
    
    
    label_orientation = 0.05,
    starmap_icon = "__muluna-graphics__/graphics/moon-icon.png",
    starmap_icon_size = 1482,
    subgroup = "satellites",
    magnitude = 3/5,
    --pollutant_type = "radiation",
    persistent_ambient_sounds=data.raw["space-platform-hub"]["space-platform-hub"].persistent_ambient_sounds,
    --localised_description={"planetslib-templates.moon-description",{"space-location-description.muluna"},"[planet="..parent_planet.."]"},
    --localised_description={"space-location-description.terminus"}.
    surface_properties = {
        ["solar-power"] = 0,
        ["pressure"] = 50,
        ["magnetic-field"] = 0.01,
        ["day-night-cycle"] = 30*60*60,
        ["is-terminus"] = 1,
    },
    map_gen_settings = map_gen,
    parked_platforms_orientation=0.00,
    orbit = { --Added in preparation for PlanetsLib to display orbits, hopefully in a less invasive way than MTLib.
      --polar = {2,0.005*tau},
      orientation = 0.16, --When planetsLib orbit is added, orientation and distance are set relative to parent body.
      distance = 4,
      parent = {
        type = "space-location",
        name = "solar-system-edge",
        },
      
        -- sprite = {
        --   type = "sprite",
        --   filename = "__muluna-graphics__/graphics/orbits/orbit-muluna.png",
        --   size = 412,
        --   scale = 0.25*o_parent_planet.magnitude/(nauvis.magnitude),
        -- }
    },
    surface_render_parameters = {
      shadow_opacity = 0.9,
      space_dust_foreground = data.raw["space-platform-hub"]["space-platform-hub"].surface_render_parameters.space_dust_foreground
      -- clouds = util.merge{nauvis.surface_render_parameters.clouds,
      --                     opacity_at_day = 0.9,
      --                     opacity_at_night = 0.9,
      --                     density_at_day = 0.9,
      --                     density_at_night = 0.9,

      --                     },
      -- clouds = {
      --   shape_noise_texture =
      --   {
      --     filename = "__muluna-graphics__/graphics/clouds-noise-new.png",
      --     size = 2048
      --   },
      --   detail_noise_texture =
      --   {
      --     filename = "__muluna-graphics__/graphics/clouds-detail-noise-3.png",
      --     size = 2048
      --   },
      --   opacity = 0.9,
      --   opacity_at_night = 0.9,
      --   density = 0.9,
      --   density_at_night = 0.9,
      --   warp_sample_1 = { scale = 0.8 / 16 },
      --   warp_sample_2 = { scale = 0.8 / 16 },
      --   warped_shape_sample = { scale = 1 },
      --   additional_density_sample = { scale = 1, wind_speed_factor = 1.77 },
      --   detail_sample_1 = { scale = 1, wind_speed_factor = 0.2 / 1.709 },
      --   detail_sample_2 = { scale = 1, wind_speed_factor = 0.2 / 1.709 },
  
      --   scale = 1,
      --   movement_speed_multiplier = 0.1,
      --   shape_warp_strength = 0.06,
      --   shape_warp_weight = 0.4,
      --   detail_sample_morph_duration = 0,
      -- }
    },
    platform_procession_set =
    {
      arrival = {"planet-to-platform-b"},
      departure = {"platform-to-planet-a"}
    },
    planet_procession_set =
    {
      arrival = {"platform-to-planet-b"},
      departure = {"planet-to-platform-a"}
    },
    procession_graphic_catalogue = planet_catalogue_vulcanus,

    --Player effects, based on Varaxia's work on Celestial weather
    ticks_between_player_effects = 1,
    --player_effects = require("player_effects").player_effects

    
}

if settings.startup["PlanetsLib-enable-temperature"].value == true then
  terminus.surface_properties["temperature"] = 225
end

if settings.startup["PlanetsLib-enable-oxygen"].value == true then
  terminus.surface_properties["oxygen"] = 0
end

if settings.startup["PlanetsLib-enable-carbon-dioxide"].value == true then
  terminus.surface_properties["carbon-dioxide"] = 0
end


local bot_power = 10

terminus.surface_properties["gravity"] = terminus.surface_properties["pressure"]/100*bot_power

local terminus_connection = {
  type = "space-connection",
  name = "solar-system-edge-terminus",
  from = "solar-system-edge",
  to = "terminus",
  subgroup = data.raw["space-connection"]["nauvis-vulcanus"].subgroup,
  length = 10000,
  --asteroid_spawn_definitions = asteroid_spawn_definitions_connection
}
PlanetsLib:extend({terminus})

data:extend{terminus_connection}

end