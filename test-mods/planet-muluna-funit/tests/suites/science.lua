-- Runtime tests for the interstellar science pack gate.
--
-- The gate is implemented in scripts/interstellar-science-pack.lua. FUnit runs
-- in a separate mod, so the normal "research finished" path is exercised by
-- invoking the event handler that planet-muluna registered for
-- on_research_finished through __funit__.mock (registered by control.lua).
local runner = require("__funit__.test_runner")
local helpers = require("__planet-muluna-funit__.tests.helpers")

local CONDITIONS_MOD_DATA = "muluna-interstellar-science-pack-conditions"
local MOCK_INTERFACE = "__funit_mock_event__planet-muluna"

local function get_conditions()
  local mod_data = prototypes.mod_data[CONDITIONS_MOD_DATA]
  runner.assert(mod_data ~= nil, "mod-data prototype " .. CONDITIONS_MOD_DATA .. " is missing")
  runner.assert(type(mod_data.data) == "table", CONDITIONS_MOD_DATA .. ".data is not a table")
  return mod_data.data
end

local function get_player_force()
  local force = game.forces["player"]
  runner.assert(force ~= nil, "player force is missing")
  return force
end

local function snapshot_technology(technology)
  return {
    researched = technology.researched,
    saved_progress = technology.saved_progress,
  }
end

local function restore_technology(technology, state)
  technology.researched = state.researched
  technology.saved_progress = state.saved_progress
end

local function gated_technology_names(conditions)
  local names = { conditions.gated_technology }
  for _, pack in ipairs(conditions.science_packs) do
    names[#names + 1] = pack
  end
  return names
end

local function snapshot_technologies(force, names)
  local states = {}
  for _, name in ipairs(names) do
    local technology = force.technologies[name]
    if technology then
      states[name] = snapshot_technology(technology)
    end
  end
  return states
end

local function restore_technologies(force, states)
  for name, state in pairs(states) do
    local technology = force.technologies[name]
    if technology then
      restore_technology(technology, state)
    end
  end
end

-- Restore the gated technology last: restoring a science pack can, in theory,
-- trigger on_research_finished and change the gate again.
local function restore_all_technologies(force, conditions, states)
  local gated_name = conditions.gated_technology
  local gated_state = states[gated_name]
  local other_states = {}
  for name, state in pairs(states) do
    if name ~= gated_name then
      other_states[name] = state
    end
  end
  restore_technologies(force, other_states)
  local gated = force.technologies[gated_name]
  if gated and gated_state then
    restore_technology(gated, gated_state)
  end
end

-- Put the gate and every listed science pack back into a known, unresearched
-- state. Missing technologies are skipped; a separate test reports them.
local function reset_gate(force, conditions)
  local gated = force.technologies[conditions.gated_technology]
  if gated then
    gated.researched = false
    gated.saved_progress = 0
  end
  for _, pack in ipairs(conditions.science_packs) do
    local technology = force.technologies[pack]
    if technology then
      technology.researched = false
      technology.saved_progress = 0
    end
  end
end

-- Snapshot, reset, run the test body, then always restore. This keeps the
-- suite repeatable even when an assertion fails halfway through a test.
local function with_technology_restore(force, conditions, test_body)
  local states = snapshot_technologies(force, gated_technology_names(conditions))
  local ok, err = pcall(function()
    reset_gate(force, conditions)
    test_body()
  end)
  local restore_ok, restore_err = pcall(restore_all_technologies, force, conditions, states)
  if not ok then
    error(err, 0)
  end
  runner.assert(restore_ok, "failed to restore technology state: " .. tostring(restore_err))
end

-- Invoke planet-muluna's registered on_research_finished handler. The event
-- itself cannot be raised with script.raise_event (only a small whitelist can
-- be), but __funit__.mock exposes script.get_event_handler for exactly this.
local function invoke_research_finished(force, technology)
  runner.assert(
    technology ~= nil and technology.force == force,
    "cannot invoke on_research_finished without a technology belonging to the player force"
  )
  local interface = remote.interfaces[MOCK_INTERFACE]
  runner.assert(
    interface ~= nil and interface.call_event_handler ~= nil,
    "funit mock interface " .. MOCK_INTERFACE .. " is unavailable; cannot invoke on_research_finished"
  )
  local ok, err = pcall(remote.call, MOCK_INTERFACE, "call_event_handler", {
    name = defines.events.on_research_finished,
    tick = game.tick,
    research = technology,
  })
  runner.assert(ok, "on_research_finished handler raised an error: " .. tostring(err))
end

runner.test("interstellar science: conditions reference real technologies", function()
  local conditions = get_conditions()
  local force = get_player_force()

  runner.assert(
    type(conditions.gated_technology) == "string" and conditions.gated_technology ~= "",
    "gated_technology is not a non-empty string"
  )
  runner.assert(
    prototypes.technology[conditions.gated_technology] ~= nil,
    "gated technology prototype " .. tostring(conditions.gated_technology) .. " does not exist"
  )
  runner.assert(
    force.technologies[conditions.gated_technology] ~= nil,
    "gated technology " .. tostring(conditions.gated_technology) .. " does not exist on the player force"
  )

  runner.assert(type(conditions.science_packs) == "table", "science_packs is not a table")
  runner.assert(#conditions.science_packs > 0, "science_packs is empty")
  runner.assert(type(conditions.required_science_packs) == "number", "required_science_packs is not a number")
  runner.assert(
    conditions.required_science_packs >= 1 and conditions.required_science_packs <= #conditions.science_packs,
    string.format(
      "required_science_packs (%s) must be between 1 and the number of listed packs (%d)",
      tostring(conditions.required_science_packs),
      #conditions.science_packs
    )
  )

  for index, pack in ipairs(conditions.science_packs) do
    runner.assert(
      prototypes.technology[pack] ~= nil,
      "science pack entry " .. index .. " (" .. tostring(pack) .. ") has no technology prototype"
    )
    runner.assert(
      force.technologies[pack] ~= nil,
      "science pack entry " .. index .. " (" .. tostring(pack) .. ") has no technology on the player force"
    )
  end
end)

runner.test("interstellar science: gate starts unresearched", function()
  local conditions = get_conditions()
  local force = get_player_force()
  local gated = force.technologies[conditions.gated_technology]

  runner.assert(gated ~= nil, "gated technology " .. tostring(conditions.gated_technology) .. " is missing")
  runner.assert(
    gated.researched == false,
    "gated technology " .. conditions.gated_technology .. " should start unresearched"
  )
  runner.assert(
    gated.saved_progress >= 0 and gated.saved_progress < 1,
    "gated technology saved_progress should be in [0, 1), got " .. tostring(gated.saved_progress)
  )
end)

runner.test("interstellar science: cheat mode researches the gated technology", function()
  local conditions = get_conditions()
  local force = get_player_force()

  with_technology_restore(force, conditions, function()
    local gated = force.technologies[conditions.gated_technology]
    runner.assert(gated.researched == false, "test setup failed: gate is still researched")

    local ok, err = pcall(helpers.funit_call, "set_cheat_mode", "player")
    runner.assert(ok, "set_cheat_mode raised an error: " .. tostring(err))
    runner.assert(
      gated.researched == true,
      "set_cheat_mode did not research " .. conditions.gated_technology
    )
  end)
end)

runner.test("interstellar science: handler tracks partial progress", function()
  local conditions = get_conditions()
  local force = get_player_force()

  with_technology_restore(force, conditions, function()
    local required = conditions.required_science_packs
    runner.assert(required >= 1, "required_science_packs must be at least 1")
    local researched = math.max(required - 1, 0)

    for index = 1, researched do
      local technology = force.technologies[conditions.science_packs[index]]
      runner.assert(
        technology ~= nil,
        "science pack technology " .. tostring(conditions.science_packs[index]) .. " is missing"
      )
      technology.researched = true
    end

    invoke_research_finished(force, force.technologies[conditions.gated_technology])

    local gated = force.technologies[conditions.gated_technology]
    runner.assert(
      gated.researched == false,
      string.format(
        "gate should stay locked with %d of %d required science packs",
        researched,
        required
      )
    )

    local expected = researched / required
    runner.assert(
      math.abs(gated.saved_progress - expected) < 1e-6,
      string.format(
        "saved_progress should be %.6f (%d/%d), got %.6f",
        expected,
        researched,
        required,
        gated.saved_progress
      )
    )
  end)
end)

runner.test("interstellar science: handler researches the gate at the required pack count", function()
  local conditions = get_conditions()
  local force = get_player_force()

  with_technology_restore(force, conditions, function()
    local required = conditions.required_science_packs
    runner.assert(required >= 1, "required_science_packs must be at least 1")

    for index = 1, required do
      local technology = force.technologies[conditions.science_packs[index]]
      runner.assert(
        technology ~= nil,
        "science pack technology " .. tostring(conditions.science_packs[index]) .. " is missing"
      )
      technology.researched = true
    end

    invoke_research_finished(force, force.technologies[conditions.gated_technology])

    local gated = force.technologies[conditions.gated_technology]
    runner.assert(
      gated.researched == true,
      string.format(
        "gate was not researched after %d of %d listed science pack technologies",
        required,
        #conditions.science_packs
      )
    )
  end)
end)
