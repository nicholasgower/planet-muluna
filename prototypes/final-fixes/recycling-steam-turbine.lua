-- The condenser turbine was cloned from the fusion generator, but a
-- FusionGeneratorPrototype has no maximum_temperature. The game therefore uses
-- the input fluid's maximum temperature (4000 °C on K2SO) instead of the actual
-- steam temperature when it reports available power. A regular Generator uses
-- maximum_temperature and reports available power for the fluid that is actually
-- in the machine.
--
-- The fusion-generator is converted here, after data-updates, so compatibility
-- patches that target the fusion-generator (including K2SO's buff) still apply
-- before the conversion.
-- https://github.com/nicholasgower/planet-muluna/issues/533

local fusion = data.raw["fusion-generator"] and data.raw["fusion-generator"]["muluna-cycling-steam-turbine"]
local generators = data.raw["generator"]
if not fusion or not generators then
    return
end

local converted = table.deepcopy(fusion)
converted.type = "generator"

-- Generator-only fields that replace the fusion-generator fields.
converted.fluid_box = table.deepcopy(fusion.input_fluid_box)
converted.fluid_box.maximum_temperature = nil
converted.fluid_box.minimum_temperature = nil
converted.fluid_usage_per_tick = fusion.max_fluid_usage
converted.maximum_temperature = math.max(
    500,
    (data.raw["fluid"]["steam"] and data.raw["fluid"]["steam"].max_temperature) or 500
)

-- The fusion generator uses output_flow_limit as its hard power cap; a regular
-- generator uses max_power_output for the same purpose.
converted.energy_source = table.deepcopy(fusion.energy_source)
converted.max_power_output = converted.energy_source.output_flow_limit
converted.energy_source.output_flow_limit = nil

-- Replace the fusion-generator graphics set with regular generator pictures.
local function pictures_for(direction)
    local direction_set = fusion.graphics_set and fusion.graphics_set[direction .. "_graphics_set"]
    if direction_set and direction_set.animation then
        return {animation = direction_set.animation}
    end
end

converted.pictures = {
    north = pictures_for("north"),
    east = pictures_for("east"),
    south = pictures_for("south"),
    west = pictures_for("west"),
}
local fallback_pictures = generators["steam-turbine"] and generators["steam-turbine"].pictures
for direction, pictures in pairs(converted.pictures) do
    if not pictures and fallback_pictures then
        converted.pictures[direction] = fallback_pictures[direction]
    end
end

converted.graphics_set = nil
converted.max_fluid_usage = nil
converted.input_fluid_box = nil

data.raw["fusion-generator"][converted.name] = nil
generators[converted.name] = converted
