-- Runtime tests for Muluna telescopes.
--
-- A telescope is a 3x3 electric assembling machine. Building it raises
-- script_raised_built, which scripts/telescopes.lua handles by creating the
-- matching muluna-telescope-combinator and registering the pair in
-- storage.telescopes. The observation recipe only produces astronomical data,
-- so no input plumbing is needed for these tests; power is supplied by an
-- electric-energy-interface next to a substation.
local runner = require("__funit__.test_runner")
local helpers = require("__planet-muluna-funit__.tests.helpers")

local AREA = helpers.muluna_area()
local RECIPE_NAME = "muluna-telescope-observation-muluna"

local function cleanup_telescope(context)
  if not context then return end
  if context.surface and context.surface.valid then
    -- Pollution is chunk based and would otherwise leak into later tests.
    context.surface.clear_pollution()
    if context.telescope and context.telescope.valid then
      local data = helpers.funit_call("get_telescope_data", context.telescope.unit_number)
      if data and data.warning_icon and data.warning_icon.valid then
        data.warning_icon.destroy()
      end
    end
    helpers.clear_area(context.surface, AREA)
    context.surface.override_pollution_type = context.previous_pollution_override
  end
  if context.force and context.force.valid then
    local recipe = context.force.recipes[RECIPE_NAME]
    if recipe then
      recipe.enabled = context.recipe_was_enabled
    end
  end
end

local function build_powered_telescope()
  -- Clear both test areas before building so a leftover telescope cannot hit
  -- the one-telescope-per-surface build limit.
  helpers.reset_test_areas()

  local surface = helpers.get_muluna()
  local center = helpers.center(AREA)
  local force = game.forces["player"]

  local recipe = prototypes.recipe[RECIPE_NAME]
  runner.assert(recipe ~= nil, "observation recipe " .. RECIPE_NAME .. " is missing")
  local lua_recipe = force.recipes[RECIPE_NAME]
  runner.assert(lua_recipe ~= nil, "player force has no LuaRecipe for " .. RECIPE_NAME)
  local recipe_was_enabled = lua_recipe.enabled
  -- set_recipe is called while handling the build event; make sure the force
  -- can actually see the observation recipe.
  lua_recipe.enabled = true

  local substation = helpers.entity_at(surface, "substation", { x = center.x + 5, y = center.y })
  runner.assert(substation ~= nil, "could not create substation for telescope power")

  local energy_interface = helpers.entity_at(surface, "electric-energy-interface", { x = center.x + 7, y = center.y })
  runner.assert(energy_interface ~= nil, "could not create electric-energy-interface for telescope power")
  energy_interface.power_production = 50000000

  local telescope = helpers.entity_at(surface, "muluna-telescope", center)
  runner.assert(telescope ~= nil, "could not create muluna-telescope")

  local previous_pollution_override = surface.override_pollution_type
  surface.override_pollution_type = { pollutant = prototypes.airborne_pollutant["pollution"] }

  return {
    surface = surface,
    force = force,
    telescope = telescope,
    energy_interface = energy_interface,
    substation = substation,
    recipe_was_enabled = recipe_was_enabled,
    previous_pollution_override = previous_pollution_override,
  }
end

local function with_telescope(test_body)
  local context = build_powered_telescope()
  local ok, err = pcall(test_body, context)
  local cleanup_ok, cleanup_err = pcall(cleanup_telescope, context)
  if not ok then
    error(err, 0)
  end
  runner.assert(cleanup_ok, "telescope cleanup failed: " .. tostring(cleanup_err))
end

runner.test("telescope: building registers storage, combinator, and recipe", function()
  with_telescope(function(context)
    local telescope = context.telescope
    runner.assert(telescope.valid, "telescope entity became invalid after building")

    local data = helpers.funit_call("get_telescope_data", telescope.unit_number)
    runner.assert(type(data) == "table", "storage.telescopes has no entry for telescope unit number")
    runner.assert(data["assembling-machine"] == telescope, "registered assembling-machine does not match the built telescope")

    local combinator = data["constant-combinator"]
    runner.assert(combinator ~= nil and combinator.valid, "telescope has no valid constant-combinator")
    runner.assert(
      combinator.name == "muluna-telescope-combinator",
      "expected muluna-telescope-combinator, got " .. tostring(combinator.name)
    )
    runner.assert(
      combinator.unit_number ~= telescope.unit_number,
      "combinator and telescope unexpectedly share a unit number"
    )

    local control_behavior = data["constant-combinator-control-behavior"]
    runner.assert(control_behavior ~= nil, "telescope has no cached combinator control behavior")
    runner.assert(control_behavior.enabled == false, "telescope combinator should start disabled")
    runner.assert(data.output_asteroid_signals == false, "output_asteroid_signals should default to false on a surface")

    local storage = helpers.storage()
    runner.assert(storage.telescopes[telescope.unit_number] ~= nil, "storage.telescopes is missing the telescope")
    runner.assert(
      storage.telescopes_on_surface[telescope.surface.name]
        and storage.telescopes_on_surface[telescope.surface.name][telescope.unit_number] == true,
      "storage.telescopes_on_surface is missing the telescope"
    )

    local current_recipe = telescope.get_recipe()
    runner.assert(current_recipe ~= nil, "telescope has no recipe assigned")
    runner.assert(
      current_recipe.name == RECIPE_NAME,
      "telescope recipe should be " .. RECIPE_NAME .. ", got " .. tostring(current_recipe.name)
    )
    runner.assert(telescope.recipe_locked == true, "surface telescope recipe should be locked")

    -- The only fluid box is the astronomical-data output; no input pipe is
    -- needed to exercise the state machine.
    local fluidboxes = telescope.prototype.fluidbox_prototypes
    runner.assert(fluidboxes ~= nil and #fluidboxes == 1, "telescope should have exactly one fluid box")
    runner.assert(
      fluidboxes[1].filter ~= nil and fluidboxes[1].filter.name == "muluna-astronomical-data",
      "telescope fluid box is not filtered to muluna-astronomical-data"
    )
  end)
end)

runner.test("telescope: powered telescope is connected to an electric network", function()
  local context = build_powered_telescope()

  -- Electric network membership is recalculated on the next tick.
  runner.after_n_ticks_do(1, function()
    local ok, err = pcall(function()
      local telescope = context.telescope
      runner.assert(telescope.valid, "telescope entity became invalid while waiting for power")
      runner.assert(
        context.energy_interface.valid and context.energy_interface.power_production > 0,
        "test power source is missing or produces no power"
      )
      runner.assert(
        telescope.is_connected_to_electric_network(),
        "telescope is not connected to an electric network with a power producer"
      )
    end)
    local cleanup_ok, cleanup_err = pcall(cleanup_telescope, context)
    if not ok then
      error(err, 0)
    end
    runner.assert(cleanup_ok, "telescope cleanup failed: " .. tostring(cleanup_err))
  end)
end)

runner.test("telescope: update_telescope follows pollution state", function()
  with_telescope(function(context)
    local telescope = context.telescope
    local surface = context.surface
    local position = telescope.position

    -- Low pollution on Muluna: no sun or clouds, so the telescope is enabled.
    surface.clear_pollution()
    local ok, err = pcall(helpers.funit_call, "update_telescope", telescope.unit_number)
    runner.assert(ok, "update_telescope raised an error at low pollution: " .. tostring(err))
    runner.assert(
      telescope.disabled_by_script == false,
      "telescope should be enabled at zero pollution"
    )
    runner.assert(telescope.custom_status == nil, "telescope should have no custom status at zero pollution")

    local max_pollution = helpers.funit_call("get_telescope_max_pollution", 0)
    surface.set_pollution(position, max_pollution + 100)
    runner.assert(
      surface.get_pollution(position) >= max_pollution,
      "failed to raise chunk pollution to the telescope maximum"
    )

    ok, err = pcall(helpers.funit_call, "update_telescope", telescope.unit_number)
    runner.assert(ok, "update_telescope raised an error at high pollution: " .. tostring(err))

    local data = helpers.funit_call("get_telescope_data", telescope.unit_number)
    runner.assert(telescope.disabled_by_script == true, "telescope should be disabled above max pollution")
    runner.assert(type(telescope.custom_status) == "table", "telescope should expose a pollution custom status")
    runner.assert(
      telescope.custom_status.label and telescope.custom_status.label[1] == "custom-status.muluna-telescopes-stars-covered-by-pollution",
      "telescope custom status is not the pollution status"
    )
    runner.assert(data.warning_icon ~= nil and data.warning_icon.valid, "telescope should show an obscured warning icon")

    -- Clearing pollution must restore the enabled state and remove the icon.
    surface.clear_pollution()
    ok, err = pcall(helpers.funit_call, "update_telescope", telescope.unit_number)
    runner.assert(ok, "update_telescope raised an error after clearing pollution: " .. tostring(err))
    runner.assert(telescope.disabled_by_script == false, "telescope should be re-enabled when pollution is cleared")
    runner.assert(telescope.custom_status == nil, "telescope custom status should clear with pollution")
    -- Remote calls copy tables, so re-read the stored entry instead of using
    -- the snapshot taken before the update.
    local cleared_data = helpers.funit_call("get_telescope_data", telescope.unit_number)
    runner.assert(cleared_data.warning_icon == nil, "warning icon should be destroyed when pollution clears")
  end)
end)

runner.test("telescope: get_telescope_signals returns sane planet signals", function()
  with_telescope(function(context)
    local signals = helpers.funit_call("get_telescope_signals", context.telescope.unit_number)
    runner.assert(type(signals) == "table", "get_telescope_signals did not return a table")
    runner.assert(#signals > 0, "get_telescope_signals returned no signals")

    local found_planet_signal = false
    for index, signal in ipairs(signals) do
      runner.assert(type(signal) == "table", "signal " .. index .. " is not a table")
      runner.assert(type(signal.value) == "table", "signal " .. index .. " has no value table")
      runner.assert(type(signal.value.type) == "string", "signal " .. index .. " has no string value.type")
      runner.assert(type(signal.value.name) == "string", "signal " .. index .. " has no string value.name")
      runner.assert(type(signal.min) == "number", "signal " .. index .. " has no numeric min")

      if signal.value.type == "space-location" and signal.value.name == "muluna" then
        found_planet_signal = true
        local expected = #context.telescope.surface.planet.get_space_platforms(game.forces["player"])
        runner.assert(
          signal.min == expected,
          "Muluna platform-count signal should be " .. expected .. ", got " .. tostring(signal.min)
        )
      end
    end

    runner.assert(found_planet_signal, "signals do not include a space-location signal for Muluna")
  end)
end)

runner.test("telescope: get_state_integer maps no_schedule", function()
  local value = helpers.funit_call("get_state_integer", defines.space_platform_state.no_schedule)
  runner.assert(
    value ~= nil,
    "get_state_integer(no_schedule) returned nil; state_integer_table has no no_schedule entry"
  )
end)

runner.test("telescope: get_state_integer covers every platform state", function()
  local missing = {}
  for name, state in pairs(defines.space_platform_state) do
    local value = helpers.funit_call("get_state_integer", state)
    if value == nil then
      table.insert(missing, name)
    else
      runner.assert(type(value) == "number", "get_state_integer(" .. name .. ") is not a number")
    end
  end
  runner.assert(
    #missing == 0,
    "get_state_integer returns nil for: " .. table.concat(missing, ", ")
  )
end)

runner.test("telescope: get_state_integer follows the documented state order", function()
  -- The order used by the commented-out implementation in scripts/telescopes.lua
  -- and by defines.space_platform_state itself.
  local expected = {
    { "waiting_for_starter_pack", 1 },
    { "starter_pack_requested", 2 },
    { "starter_pack_on_the_way", 3 },
    { "on_the_path", 4 },
    { "waiting_for_departure", 5 },
    { "no_schedule", 6 },
    { "no_path", 7 },
    { "waiting_at_station", 8 },
    { "paused", 9 },
  }

  for _, entry in ipairs(expected) do
    local name = entry[1]
    local actual = helpers.funit_call("get_state_integer", defines.space_platform_state[name])
    runner.assert(
      actual == entry[2],
      string.format("get_state_integer(%s) should be %d, got %s", name, entry[2], tostring(actual))
    )
  end
end)

runner.test("telescope: get_state_integer gives distinct states distinct integers", function()
  local seen = {}
  for name, state in pairs(defines.space_platform_state) do
    local value = helpers.funit_call("get_state_integer", state)
    if value ~= nil then
      runner.assert(
        seen[value] == nil,
        "space platform states " .. tostring(seen[value]) .. " and " .. name .. " both map to " .. tostring(value)
      )
      seen[value] = name
    end
  end
end)

runner.test("telescope: pollution probability spans zero to one", function()
  local min_pollution = helpers.funit_call("get_telescope_min_pollution", 0)
  local max_pollution = helpers.funit_call("get_telescope_max_pollution", 0)

  runner.assert(type(min_pollution) == "number", "get_telescope_min_pollution did not return a number")
  runner.assert(type(max_pollution) == "number", "get_telescope_max_pollution did not return a number")
  runner.assert(max_pollution > min_pollution, "telescope max pollution must be greater than min pollution")

  local at_min = helpers.funit_call("get_telescope_probability", min_pollution, 0)
  local at_max = helpers.funit_call("get_telescope_probability", max_pollution, 0)

  runner.assert(math.abs(at_min - 0) < 1e-9, "probability at min pollution should be 0, got " .. tostring(at_min))
  runner.assert(math.abs(at_max - 1) < 1e-9, "probability at max pollution should be 1, got " .. tostring(at_max))
end)
