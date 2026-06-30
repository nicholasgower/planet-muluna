local data_util = require("__flib__.data-util")
local rro = Muluna.rro
Muluna.constants.vacuum_roboports = {}
local vacuum_roboports = Muluna.constants.vacuum_roboports 

local function parse_energy_string(s) --ChatGPT
		-- Match: number part, optional prefix, and unit
		-- %d+ matches digits, %.? allows decimal point,
		-- ([%a]?) captures single optional letter (prefix),
		-- ([%a]+) captures remaining letters (unit).
		local number, prefix, unit = string.match(s, "^(%d+%.?%d*)([%a]?)([%a])$")

		if not number then
			error("Invalid format: " .. s)
		end

		return number, prefix, unit
	end

local function localise_energy(energy)
		local symbols = {
			k = "si-prefix-symbol-kilo",
			M = "si-prefix-symbol-mega",
			G = "si-prefix-symbol-giga",
			T = "si-prefix-symbol-tera",
			P = "si-prefix-symbol-peta",
			E = "si-prefix-symbol-exa",
			Z = "si-prefix-symbol-zetta",
			Y = "si-prefix-symbol-yotta",
			R = "si-prefix-symbol-ronna",
			Q = "si-prefix-symbol-quetta",
			W = "si-unit-symbol-watt",
			J = "si-unit-symbol-joule",
			N = "si-unit-symbol-newton",
		}

		if type(energy) == "string" then
			--local j_index = string.find(energy,"J")
			--local prefix_index = j_index - 1
			local number, prefix, unit = parse_energy_string(energy)
			return { "", tostring(number), " ", { symbols[prefix] or "" }, { symbols[unit] } }
		else
			return "?"
		end
	end

data:extend{
    {
        type="recipe-category",
        name="muluna-vacuum-roboport",
    }
}    
for _,roboport in pairs(data.raw["roboport"]) do
    if roboport.is_vacuum_roboport then
        vacuum_roboports[roboport.name] = {}
        local roboport_data = vacuum_roboports[roboport.name]
        if roboport.energy_source.type == "electric" then
            roboport_data.fuel_input_limit = data_util.get_energy_value(roboport.energy_source.input_flow_limit)
            
            if not roboport.custom_tooltip_fields then roboport.custom_tooltip_fields = {} end
            rro.soft_insert(roboport.custom_tooltip_fields,
        
                {
                    name = {"tooltip.muluna-burner-roboport-internal-buffer-refuel-limit"},
                    value = localise_energy(roboport.energy_source.input_flow_limit),
                    quality_header = "quality-tooltip.increases",
                    --quality_values = {}
                })

            

            local refueler = {
                type = "assembling-machine",
                name = roboport.name,
                quality_affects_energy_usage = true,
                selection_box = Muluna.flib_bounding_box.resize(roboport.selection_box,-0.4),
                collision_box = data.raw["assembling-machine"]["electromagnetic-plant"].collision_box,
                crafting_categories = {"muluna-vacuum-roboport"},
                use_mirroring=true,
                allowed_effects = {},
                fluid_boxes = {
                    
                    {
                        production_type = "input",
                        pipe_picture = require("__space-age__.prototypes.entity.electromagnetic-plant-pictures").pipe_pictures,
                        pipe_picture_frozen = require("__space-age__.prototypes.entity.electromagnetic-plant-pictures").pipe_pictures_frozen,
                        pipe_covers = pipecoverspictures(),
                        volume = 100,
                        secondary_draw_orders = { north = -1 },
                        pipe_connections = {{ flow_direction="input-output", direction = defines.direction.south, position = {0.5, 1.5} }}
                    },
                    {
                        production_type = "input",
                        pipe_picture = require("__space-age__.prototypes.entity.electromagnetic-plant-pictures").pipe_pictures,
                        pipe_picture_frozen = require("__space-age__.prototypes.entity.electromagnetic-plant-pictures").pipe_pictures_frozen,
                        pipe_covers = pipecoverspictures(),
                        volume = 100,
                        secondary_draw_orders = { north = -1 },
                        pipe_connections = {{ flow_direction="input-output", direction = defines.direction.north, position = {-0.5, -1.5} }}
                    },
                    {
                        production_type = "output",
                        pipe_picture = require("__space-age__.prototypes.entity.electromagnetic-plant-pictures").pipe_pictures,
                        pipe_picture_frozen = require("__space-age__.prototypes.entity.electromagnetic-plant-pictures").pipe_pictures_frozen,
                        pipe_covers = pipecoverspictures(),
                        volume = 100,
                        secondary_draw_orders = { north = -1 },
                        pipe_connections = {{ connection_type = "linked", linked_connection_id = 1, flow_direction="output", direction = defines.direction.north, position = {0, 0} }}
                    }
                },
                crafting_speed = 1,
                energy_source = {
                    type = "fluid",
                    fuel_categories = {"thruster-fuel"},
                    scale_fluid_usage = true,
                    burns_fluid = true,
                    fluid_box = {
                        production_type = "input",
                        pipe_picture = require("__space-age__.prototypes.entity.electromagnetic-plant-pictures").pipe_pictures,
                        pipe_picture_frozen = require("__space-age__.prototypes.entity.electromagnetic-plant-pictures").pipe_pictures_frozen,
                        pipe_covers = pipecoverspictures(),
                        volume = 1000,
                        secondary_draw_orders = { north = -1 },
                        filter = "thruster-fuel",

                        pipe_connections = {
                            { flow_direction="input-output", direction = defines.direction.west, position = {-1.5, 0.5} },
                            { flow_direction="input-output", direction = defines.direction.east, position = {1.5, -0.5} }
                        }
                    },
                    
                },
                energy_usage = roboport.energy_source.input_flow_limit,
                max_health = 10000,
                quality_indicator_shift = {-0.4,0.4}
            }
            
            roboport.name = roboport.name .. "-roboport"
            roboport.is_vacuum_roboport = false
            data:extend{roboport,refueler}
            data.raw["roboport"][refueler.name] = nil
            roboport_data["refueler"] = refueler.name
            roboport_data["roboport"] = roboport.name
            roboport.energy_source.input_flow_limit = "0W"
        
        end
        
    end
end
