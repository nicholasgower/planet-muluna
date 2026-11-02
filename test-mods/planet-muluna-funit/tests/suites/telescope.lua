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

-------------------------------------------------------------------------------
-- Combinator update: change detection
-------------------------------------------------------------------------------
-- The update tick used to rebuild and rewrite `section.filters` for every
-- telescope on every interval. Comparing the built signal list with a deep table
-- compare costs more than the write, so the update now compares a numeric
-- signature of the inputs (scripts/telescopes.lua). These tests pin both halves
-- of that contract: no write without a change, and a write with correct data
-- after a change.
local COMBINATOR_UPDATE_SETTING = "muluna-telescope-combinator-update-ticks"

local function combinator_update_interval()
  local setting = settings.startup[COMBINATOR_UPDATE_SETTING]
  runner.assert(setting ~= nil, COMBINATOR_UPDATE_SETTING .. " startup setting is missing")
  local value = tonumber(setting.value)
  runner.assert(
    type(value) == "number" and value >= 1,
    COMBINATOR_UPDATE_SETTING .. " is not a positive number: " .. tostring(setting.value)
  )
  return math.max(1, math.floor(value))
end

local function combinator_stats()
  return helpers.funit_call("get_telescope_combinator_stats")
end

---Find the space-location signal for a planet in a filter list.
local function planet_signal(filters, planet_name)
  for _, filter in ipairs(filters or {}) do
    local value = filter.value
    if value and value.type == "space-location" and value.name == planet_name then
      return filter
    end
  end
  return nil
end

local function cleanup_after_failure(context)
  pcall(cleanup_telescope, context)
end

runner.test("telescope: unchanged combinator signals are not rewritten", function()
  local context = build_powered_telescope()
  local unit_number = context.telescope.unit_number
  local data = helpers.funit_call("get_telescope_data", unit_number)
  local behavior = data["constant-combinator-control-behavior"]
  runner.assert(behavior ~= nil, "telescope has no cached combinator control behavior")
  behavior.enabled = true

  local interval = combinator_update_interval()

  -- Wait for the first update to write, then count writes over three intervals.
  runner.after_n_ticks_do(interval + 5, function()
    local ok, err = pcall(function()
      local first = combinator_stats()
      runner.assert(
        first.writes >= 1,
        "the first combinator update did not write the filters (writes=" .. tostring(first.writes) .. ")"
      )
      local writes = first.writes
      local rebuilds = first.rebuilds

      runner.after_n_ticks_do(interval * 3 + 5, function()
        local body_ok, body_err = pcall(function()
          local later = combinator_stats()
          runner.assert(
            later.updates > first.updates,
            "the combinator update did not run during the wait"
          )
          runner.assert(
            later.writes == writes,
            "unchanged telescope signals were rewritten " .. (later.writes - writes) .. " time(s)"
          )
          runner.assert(
            later.rebuilds == rebuilds,
            "unchanged telescope signals were rebuilt " .. (later.rebuilds - rebuilds) .. " time(s)"
          )

          -- The skipped updates must leave the previously written filters intact
          -- and equal to the producer's output.
          local section = behavior.get_section(1)
          runner.assert(section ~= nil, "combinator has no section after the skipped updates")
          local filters = section.filters
          local expected = helpers.funit_call("get_telescope_signals", unit_number)
          runner.assert(type(expected) == "table", "get_telescope_signals returned no table")
          runner.assert(
            #filters == #expected,
            "combinator holds " .. #filters .. " filters, the producer emits " .. #expected
          )
          for index = 1, #expected do
            runner.assert(
              filters[index].min == expected[index].min,
              "filter " .. index .. " min is " .. tostring(filters[index].min)
                .. ", expected " .. tostring(expected[index].min)
            )
          end
        end)

        local cleanup_ok, cleanup_err = pcall(cleanup_telescope, context)
        if not body_ok then
          error(body_err, 0)
        end
        runner.assert(cleanup_ok, "telescope cleanup failed: " .. tostring(cleanup_err))
      end)
    end)
    if not ok then
      cleanup_after_failure(context)
      error(err, 0)
    end
  end)
end)

runner.test("telescope: combinator signals are rewritten when the platform roster changes", function()
  local context = build_powered_telescope()
  local unit_number = context.telescope.unit_number
  local data = helpers.funit_call("get_telescope_data", unit_number)
  local behavior = data["constant-combinator-control-behavior"]
  runner.assert(behavior ~= nil, "telescope has no cached combinator control behavior")
  behavior.enabled = true

  local interval = combinator_update_interval()
  local planet = context.surface.planet
  local force = context.force
  local platform

  runner.after_n_ticks_do(interval + 5, function()
    local ok, err = pcall(function()
      local baseline = combinator_stats()

      -- Remove a platform left by an earlier failed run so the name stays unique.
      for _, existing in pairs(force.platforms) do
        if existing.name == "funit-telescope-platform" then
          pcall(function()
            existing.destroy()
          end)
        end
      end

      local before = #planet.get_space_platforms(force)

      platform = force.create_space_platform({
        name = "funit-telescope-platform",
        planet = "muluna",
        starter_pack = { name = "space-platform-starter-pack", quality = "normal" },
      })
      runner.assert(platform and platform.valid, "could not create a space platform at Muluna")
      platform.apply_starter_pack(true)
      runner.assert(platform.surface and platform.surface.valid, "new platform has no surface")

      local after = #planet.get_space_platforms(force)
      runner.assert(
        after == before + 1,
        "creating a platform did not change Muluna's platform roster (" .. before .. " -> " .. after .. ")"
      )

      runner.after_n_ticks_do(interval + 10, function()
        local body_ok, body_err = pcall(function()
          local later = combinator_stats()
          runner.assert(
            later.writes > baseline.writes,
            "the combinator filters were not rewritten after the roster changed"
          )

          local section = behavior.get_section(1)
          runner.assert(section ~= nil, "combinator has no section after the roster change")
          local signal = planet_signal(section.filters, "muluna")
          runner.assert(signal ~= nil, "combinator filters have no muluna space-location signal")
          local expected = #planet.get_space_platforms(force)
          runner.assert(
            signal.min == expected,
            "muluna platform-count signal is " .. tostring(signal.min) .. ", expected " .. tostring(expected)
          )
        end)

        if platform and platform.valid then
          pcall(function()
            platform.destroy()
          end)
        end
        local cleanup_ok, cleanup_err = pcall(cleanup_telescope, context)
        if not body_ok then
          error(body_err, 0)
        end
        runner.assert(cleanup_ok, "telescope cleanup failed: " .. tostring(cleanup_err))
      end)
    end)
    if not ok then
      if platform and platform.valid then
        pcall(function()
          platform.destroy()
        end)
      end
      cleanup_after_failure(context)
      error(err, 0)
    end
  end)
end)

runner.test("telescope: destroying the combinator removes the telescope pair", function()
  -- Regression guard for the reverse index: the combinator is a child entity and
  -- its destroy handler must find and remove its own telescope without scanning
  -- the whole storage table.
  with_telescope(function(context)
    local unit_number = context.telescope.unit_number
    local data = helpers.funit_call("get_telescope_data", unit_number)
    local combinator = data["constant-combinator"]
    runner.assert(combinator and combinator.valid, "telescope has no valid combinator")

    local combinator_unit = combinator.unit_number
    local children = helpers.storage().telescope_children
    runner.assert(type(children) == "table", "storage.telescope_children is missing")
    runner.assert(
      children[combinator_unit] == unit_number,
      "child index does not map the combinator to its telescope"
    )

    combinator.destroy({ raise_destroy = true })
    runner.assert(not context.telescope.valid, "destroying the combinator left the telescope alive")
    runner.assert(
      helpers.funit_call("get_telescope_data", unit_number) == nil,
      "storage.telescopes still holds the pair after the combinator was destroyed"
    )
    runner.assert(
      helpers.storage().telescope_children[combinator_unit] == nil,
      "the destroyed pair left a stale child index entry"
    )
  end)
end)

runner.test("telescope: child lookup falls back when the index is missing", function()
  with_telescope(function(context)
    local unit_number = context.telescope.unit_number
    local data = helpers.funit_call("get_telescope_data", unit_number)
    local combinator = data["constant-combinator"]
    local combinator_unit = combinator.unit_number

    helpers.funit_call("set_compound_child_index", "telescope_children", combinator_unit, nil)
    runner.assert(
      helpers.storage().telescope_children[combinator_unit] == nil,
      "could not remove the child index entry"
    )

    combinator.destroy({ raise_destroy = true })
    runner.assert(not context.telescope.valid, "the combinator did not remove its telescope through the fallback scan")
    runner.assert(
      helpers.funit_call("get_telescope_data", unit_number) == nil,
      "the storage entry survived the fallback cleanup"
    )
  end)
end)

runner.test("telescope: a child index entry with no telescope falls back to the scan", function()
  -- A save can carry an index entry whose telescope entry was already dropped
  -- (for example after the stale-entity cleanup). The lookup must not trust it.
  with_telescope(function(context)
    local unit_number = context.telescope.unit_number
    local data = helpers.funit_call("get_telescope_data", unit_number)
    local combinator = data["constant-combinator"]
    local combinator_unit = combinator.unit_number

    runner.assert(
      helpers.funit_call("set_compound_child_index", "telescope_children", combinator_unit, unit_number + 100000),
      "could not point the child index at a missing telescope"
    )
    runner.assert(
      helpers.storage().telescope_children[combinator_unit] ~= unit_number,
      "the child index still points at the real telescope"
    )

    combinator.destroy({ raise_destroy = true })
    runner.assert(not context.telescope.valid, "the combinator did not remove its telescope through the fallback scan")
    runner.assert(
      helpers.funit_call("get_telescope_data", unit_number) == nil,
      "the storage entry survived the fallback cleanup"
    )
  end)
end)
