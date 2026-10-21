-- Runtime tests for walking particles.
--
-- scripts/walking_particles.lua is player-driven. The headless FUnit scenario
-- has no players, so these tests cover the parts that are observable without
-- one: storage initialization, registration of the update tick, the
-- non-character mock event path, the particle prototypes, and the production
-- funit export for controller-input precedence.
local runner = require("__funit__.test_runner")
local helpers = require("__planet-muluna-funit__.tests.helpers")
local mock = require("__funit__.mock")

local FOOTSTEP_SETTING = "muluna-graphics-enable-footstep-animations"

local function count_entries(tbl)
  local count = 0
  for _ in pairs(tbl or {}) do
    count = count + 1
  end
  return count
end

local function state_snapshot()
  local storage = helpers.storage()
  return {
    players_on_muluna = count_entries(storage.players_on_muluna),
    players_walking_on_muluna = count_entries(storage.players_walking_on_muluna),
    player_control_method = count_entries(storage.player_control_method),
    walking_tick_rates = count_entries(storage.walking_tick_rates),
    cached_direction_to_string = count_entries(storage.cached_direction_to_string),
  }
end

local function assert_no_state(before, message)
  local after = state_snapshot()
  runner.assert(
    after.players_on_muluna == before.players_on_muluna,
    message
      .. ": storage.players_on_muluna changed from "
      .. before.players_on_muluna
      .. " to "
      .. after.players_on_muluna
  )
  runner.assert(
    after.players_walking_on_muluna == before.players_walking_on_muluna,
    message
      .. ": storage.players_walking_on_muluna changed from "
      .. before.players_walking_on_muluna
      .. " to "
      .. after.players_walking_on_muluna
  )
  runner.assert(
    after.player_control_method == before.player_control_method,
    message
      .. ": storage.player_control_method changed from "
      .. before.player_control_method
      .. " to "
      .. after.player_control_method
  )
  runner.assert(
    after.walking_tick_rates == before.walking_tick_rates,
    message
      .. ": storage.walking_tick_rates changed from "
      .. before.walking_tick_rates
      .. " to "
      .. after.walking_tick_rates
  )
  return after
end

runner.test("walking particle storage is initialized", function()
  local storage = helpers.storage()
  runner.assert(type(storage.players_on_muluna) == "table", "storage.players_on_muluna is not a table")
  runner.assert(
    type(storage.players_walking_on_muluna) == "table",
    "storage.players_walking_on_muluna is not a table"
  )
  runner.assert(
    type(storage.player_control_method) == "table",
    "storage.player_control_method is not a table"
  )
  runner.assert(type(storage.walking_tick_rates) == "table", "storage.walking_tick_rates is not a table")
  runner.assert(
    type(storage.cached_direction_to_string) == "table",
    "storage.cached_direction_to_string is not a table"
  )
end)

runner.test("walking particle startup setting is enabled for this suite", function()
  local setting = settings.startup[FOOTSTEP_SETTING]
  runner.assert(setting, FOOTSTEP_SETTING .. " startup setting is missing")
  runner.assert(
    setting.value == true,
    FOOTSTEP_SETTING
      .. " is false; scripts/walking_particles.lua did not load, so the walking tests are not meaningful"
  )
end)

runner.test("walking particle prototypes are available", function()
  local small = prototypes.particle["stone-particle"]
  local medium = prototypes.particle["stone-particle-medium"]
  runner.assert(small, "stone-particle prototype is missing")
  runner.assert(medium, "stone-particle-medium prototype is missing")
  runner.assert(
    small.type == "optimized-particle",
    "stone-particle has unexpected type " .. tostring(small.type)
  )
  runner.assert(
    medium.type == "optimized-particle",
    "stone-particle-medium has unexpected type " .. tostring(medium.type)
  )
end)

runner.test("walking update tick is safe with no tracked players", function()
  local before = state_snapshot()
  runner.assert(
    before.players_walking_on_muluna == 0,
    "walking state is not empty at test start: " .. before.players_walking_on_muluna
  )

  -- The nth-tick handler (every 60 ticks) walks storage.players_on_muluna and
  -- must do nothing when it is empty. If it errors the game would crash before
  -- the test resumes.
  runner.after_n_ticks_do(65, function()
    assert_no_state(before, "walking update tick without players")
  end)
end)

runner.test("non-character position event does not start walking particles", function()
  local before = state_snapshot()

  local ok, err = pcall(mock.mock_event, {
    name = defines.events.on_player_changed_position,
    player_index = 9999,
  })
  runner.assert(ok, "mocked on_player_changed_position errored: " .. tostring(err))
  assert_no_state(before, "non-character position event")
end)

runner.test("move event for an unknown player is ignored", function()
  local before = state_snapshot()

  local ok, err = pcall(mock.mock_event, {
    name = "move-up",
    player_index = 9999,
  })
  runner.assert(ok, "mocked move-up event errored: " .. tostring(err))
  assert_no_state(before, "movement event for an unknown player")
end)

runner.test("controller input precedence selects only the game controller", function()
  -- Regression target: scripts/walking_particles.lua must compare the stored
  -- input method with defines.input_method.game_controller, not negate it.
  -- The production funit export exposes the shared predicate because a player
  -- cannot be created in the headless scenario.
  local interface = remote.interfaces["muluna_funit"]
  runner.assert(
    interface and interface.get_walking_controller_branch,
    "muluna_funit.get_walking_controller_branch is not exported; controller-input precedence cannot be exercised"
  )

  runner.assert(
    remote.call("muluna_funit", "get_walking_controller_branch", defines.input_method.game_controller) == true,
    "game controller input did not select the game-controller branch"
  )
  runner.assert(
    remote.call("muluna_funit", "get_walking_controller_branch", defines.input_method.keyboard_and_mouse) == false,
    "keyboard/mouse input incorrectly selected the game-controller branch"
  )
  runner.assert(
    remote.call("muluna_funit", "get_walking_controller_branch", nil) == false,
    "a missing input method incorrectly selected the game-controller branch"
  )
end)
