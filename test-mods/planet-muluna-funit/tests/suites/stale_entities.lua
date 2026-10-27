-- Runtime regression tests for stale entity and player references in Muluna storage.
--
-- Issue #463: deleting a surface (for example the blueprint-sandbox reset)
-- invalidated the entities kept in storage.burner_roboports and
-- storage.telescopes. The burner roboport long update then read
-- roboport.energy from an invalid LuaEntity and crashed on on_nth_tick(480)
-- ("LuaEntity API call when LuaEntity was invalid", scripts/burner-roboports.lua).
-- The telescope combinator update had the same class of problem. The fixes
-- check entity validity and drop the stale storage entry.
--
-- Issues #458 / #461: storage.players_walking_on_muluna could keep a player
-- index after that player left Muluna while storage.players_on_muluna no
-- longer had the index. The every-tick walking handler then indexed a nil
-- player_info (or a stale LuaPlayer), which crashed the game.
--
-- LuaEntity.destroy({ raise_destroy = false }) is the documented way to remove
-- an entity without raising script_raised_destroy: LuaEntity::destroy only
-- raises that event when raise_destroy is true (Factorio 2.1 runtime docs).
-- The production destroy handlers listen to the on_destroyed event group, so a
-- silent destroy leaves the storage entry pointing at an invalid entity, which
-- is exactly the state a deleted surface produces. That is how the stale entity
-- cases below are built; no direct storage mutation is needed (and none is
-- possible, because muluna_funit.get_storage returns a copy through
-- remote.call).
local runner = require("__funit__.test_runner")
local helpers = require("__planet-muluna-funit__.tests.helpers")
local mock = require("__funit__.mock")

local TELESCOPE = "muluna-telescope"
local COMBINATOR_UPDATE_SETTING = "muluna-telescope-combinator-update-ticks"
local FOOTSTEP_SETTING = "muluna-graphics-enable-footstep-animations"
local STALE_PLAYER_INDEX = 9999
local WALKING_UPDATE_TICKS = 65
-- The burner roboport long update runs on an nth-tick of
-- 1200 * (0.8 - 0.6) / 0.5 = 480 ticks (scripts/burner-roboports.lua). Poll
-- with a generous timeout instead of hard-coding the period so a balance
-- change to those constants does not silently disable the test.
local LONG_UPDATE_TIMEOUT = 900
-- The telescope combinator update interval comes from a startup setting
-- (default 6). Wait one interval plus a margin: the nth-tick cleanup removes
-- the entry on the first interval, and a short window keeps a stale telescope
-- entry from surviving across a day boundary (update_all_telescopes would then
-- dereference it, see the note on the stale-telescope test).
local COMBINATOR_UPDATE_MARGIN = 30
local MULUNA_MOCK_INTERFACE = mock.PREFIX .. "planet-muluna"

local function get_constants()
  return prototypes.mod_data["muluna-constants"].data
end

local function get_roboport_config()
  local roboports = get_constants().vacuum_roboports
  runner.assert(type(roboports) == "table", "vacuum_roboports constants are missing")
  for _, machine in pairs(roboports) do
    runner.assert(machine.refueler, "vacuum roboport entry has no refueler")
    runner.assert(machine.roboport, "vacuum roboport entry has no roboport")
    return machine
  end
  error("vacuum_roboports constants are empty")
end

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

local function count_players()
  local count = 0
  for _ in pairs(game.players) do
    count = count + 1
  end
  return count
end

---Remove temporary surfaces and any entities left in the shared test areas.
---
---Temporary surfaces are named "funit-stale-*" and are deleted rather than
---cleared: deleting a surface invalidates the entities stored in Muluna
---storage without raising destroy events, which is the #463 scenario, and it
---also keeps the surface-name-keyed storage tables of a test from leaking into
---another test.
local function clean_areas()
  local stale_surfaces = {}
  for _, surface in pairs(game.surfaces) do
    if surface.name:find("^funit%-stale%-", 1) then
      table.insert(stale_surfaces, surface)
    end
  end
  for _, surface in pairs(stale_surfaces) do
    pcall(game.delete_surface, surface)
  end
  pcall(helpers.reset_test_areas)
end

local function create_test_surface(suffix)
  local name = "funit-stale-" .. suffix
  local surface = game.create_surface(name)
  runner.assert(surface ~= nil and surface.valid, "could not create test surface " .. name)
  helpers.generate_area(surface, {
    left_top = { -64, -64 },
    right_bottom = { 64, 64 },
  })
  return surface
end

local function find_build_position(surface, entity_name)
  -- LuaSurface::find_non_colliding_position(name, center, radius, precision, force_to_tile_center).
  local position = surface.find_non_colliding_position(entity_name, { x = 0, y = 0 }, 48, 1, true)
  runner.assert(
    position ~= nil,
    "could not find a free position for " .. entity_name .. " on " .. surface.name
  )
  return position
end

---Build a telescope through the production build handler on its own surface.
---
---The telescope build limit is one per surface and force, so each test gets a
---temporary surface. That also keeps the telescope-specific storage keys from
---affecting the Muluna surface used by the other suites.
local function build_telescope(suffix)
  local surface = create_test_surface(suffix)
  local position = find_build_position(surface, TELESCOPE)
  local telescope = helpers.entity_at(surface, TELESCOPE, position)
  runner.assert(
    telescope ~= nil and telescope.valid,
    "could not create " .. TELESCOPE .. " on " .. surface.name
  )

  local unit_number = telescope.unit_number
  local data = helpers.funit_call("get_telescope_data", unit_number)
  runner.assert(type(data) == "table", "building a telescope did not register storage.telescopes")
  runner.assert(
    data["assembling-machine"] == telescope,
    "storage.telescopes does not point at the built telescope"
  )
  local combinator = data["constant-combinator"]
  runner.assert(
    combinator ~= nil and combinator.valid,
    "telescope build did not create a valid constant-combinator"
  )
  runner.assert(
    data["constant-combinator-control-behavior"] ~= nil,
    "telescope build did not cache the combinator control behavior"
  )

  return {
    surface = surface,
    telescope = telescope,
    combinator = combinator,
    unit_number = unit_number,
  }
end

---Return the key sets of the walking-particle storage tables.
---
---remote.call returns copies, so these are snapshots; comparing the key sets
---before and after a tick is how the suite proves that a handler did not adopt
---a stale player index.
local function walking_keys()
  local storage = helpers.storage()
  local keys = { on_muluna = {}, walking = {}, rates = {}, control = {} }
  for key in pairs(storage.players_on_muluna or {}) do keys.on_muluna[key] = true end
  for key in pairs(storage.players_walking_on_muluna or {}) do keys.walking[key] = true end
  for key in pairs(storage.walking_tick_rates or {}) do keys.rates[key] = true end
  for key in pairs(storage.player_control_method or {}) do keys.control[key] = true end
  return keys
end

local function count_keys(tbl)
  local count = 0
  for _ in pairs(tbl) do
    count = count + 1
  end
  return count
end

---Assert the invariant the 2.6.52 fix relies on (#458 / #461).
---
---scripts/walking_particles.lua indexes storage.players_on_muluna with every
---key of storage.players_walking_on_muluna, so a walking key without a matching
---on_muluna entry is the crash shape: the handler dereferences a nil
---player_info (or a stale LuaPlayer) and the game stops.
local function assert_walking_invariant(keys, message)
  for key in pairs(keys.walking) do
    runner.assert(
      keys.on_muluna[key] == true,
      message
        .. ": storage.players_walking_on_muluna["
        .. tostring(key)
        .. "] has no matching storage.players_on_muluna entry, which is the #458 crash shape"
    )
  end
end

local function assert_same_keys(before, after, message)
  for _, category in pairs({ "on_muluna", "walking", "rates", "control" }) do
    runner.assert(
      count_keys(before[category]) == count_keys(after[category]),
      message
        .. ": storage key count for "
        .. category
        .. " changed from "
        .. count_keys(before[category])
        .. " to "
        .. count_keys(after[category])
    )
    for key in pairs(before[category]) do
      runner.assert(
        after[category][key] == true,
        message .. ": storage key " .. tostring(key) .. " disappeared from " .. category
      )
    end
    for key in pairs(after[category]) do
      runner.assert(
        before[category][key] == true,
        message .. ": storage key " .. tostring(key) .. " appeared in " .. category
      )
    end
  end
end

-- #463: the hidden roboport disappeared, but the storage entry (and the
-- refueler) did not. The long update must drop the entry instead of reading
-- roboport.energy from the invalid LuaEntity.
runner.test("stale burner roboport is cleaned up without crashing", function()
  clean_areas()

  local surface = helpers.get_muluna()
  local machine = get_roboport_config()
  local center = helpers.center(helpers.muluna_area())

  local refueler = helpers.entity_at(surface, machine.refueler, center)
  runner.assert(
    refueler ~= nil and refueler.valid,
    "could not create " .. machine.refueler .. " at (" .. center.x .. ", " .. center.y .. ")"
  )
  local unit_number = refueler.unit_number

  local data = helpers.funit_call("get_burner_roboport_data", unit_number)
  runner.assert(data ~= nil, "burner roboport was not registered in storage")
  local roboport = data.roboport
  runner.assert(roboport ~= nil and roboport.valid, "burner roboport has no valid hidden roboport")
  runner.assert(roboport.name == machine.roboport, "hidden roboport has the wrong prototype name")

  -- Simulate a surface deletion: the hidden roboport disappears without
  -- raising a destroy event, so the production destroy handler cannot clean up.
  roboport.destroy({ raise_destroy = false })
  runner.assert(not roboport.valid, "hidden roboport is still valid after a silent destroy")

  local stale = helpers.funit_call("get_burner_roboport_data", unit_number)
  runner.assert(
    stale ~= nil,
    "the silent destroy already removed the storage entry, so the stale path was not exercised"
  )
  -- remote.call returns a copy of the storage table, and an invalid LuaEntity is
  -- dropped while copying. The entry itself surviving is the observable part of
  -- the stale state; the long update below proves the invalid reference is
  -- handled without crashing.
  runner.assert(
    stale.refueler == nil or stale.refueler.valid,
    "the refueler should survive destroying only the hidden roboport"
  )

  -- The short update path is also reachable from crafting and must tolerate the
  -- stale pair; it does not clean up, so the entry is expected to survive it.
  local ok, err = pcall(helpers.funit_call, "short_update_roboport", unit_number)
  runner.assert(ok, "short_update_roboport errored on a stale burner roboport: " .. tostring(err))

  helpers.wait_until(runner, function()
    return helpers.funit_call("get_burner_roboport_data", unit_number) == nil
  end, {
    timeout = LONG_UPDATE_TIMEOUT,
    interval = 30,
    message = "the burner roboport long update did not drop the entry whose hidden roboport was invalid (#463)",
    on_success = function()
      runner.assert(
        refueler.valid,
        "the long update destroyed the refueler instead of only dropping the stale storage entry"
      )
      runner.assert(
        helpers.funit_call("get_burner_roboport_data", unit_number) == nil,
        "storage.burner_roboports still holds the stale entry after the long update"
      )
      clean_areas()
    end,
    on_failure = clean_areas,
  })
end)

-- #463 (telescope half): the assembling machine disappeared while its storage
-- entry and combinator survived. The combinator update must not crash and must
-- drop the entry that points at an invalid assembling machine.
--
-- NOTE: as of this suite, scripts/telescopes.lua only drops a telescope entry
-- when its *combinator* is invalid (the nth-tick `else` branch); it never looks
-- at the assembling machine. If that is still true, this test fails, and the
-- leftover entry is a real crash risk: update_all_telescopes
-- (scripts/telescopes.lua:98) calls Muluna.update_telescope_daytime on it at the
-- next day boundary, which reads telescope.surface from the invalid LuaEntity.
-- The fix is to check both entities in the nth-tick cleanup and to clear the
-- matching storage.telescopes_on_surface key at the same time.
runner.test("stale telescope is cleaned up without crashing", function()
  clean_areas()

  local context = build_telescope("telescope-entity")
  local telescope = context.telescope
  local unit_number = context.unit_number
  local interval = combinator_update_interval()

  telescope.destroy({ raise_destroy = false })
  runner.assert(not telescope.valid, "telescope is still valid after a silent destroy")

  local stale = helpers.funit_call("get_telescope_data", unit_number)
  runner.assert(
    stale ~= nil,
    "the silent destroy already removed the storage entry, so the stale path was not exercised"
  )
  -- remote.call copies storage, and an invalid LuaEntity is dropped from the
  -- copy. Either shape (nil or invalid) proves the entry outlived its telescope.
  runner.assert(
    stale["assembling-machine"] == nil or not stale["assembling-machine"].valid,
    "storage.telescopes does not point at the destroyed telescope"
  )
  runner.assert(
    stale["constant-combinator"] ~= nil and stale["constant-combinator"].valid,
    "the combinator should survive destroying only the telescope; the test needs the combinator-invalid case otherwise"
  )

  helpers.wait_until(runner, function()
    return helpers.funit_call("get_telescope_data", unit_number) == nil
  end, {
    timeout = interval + COMBINATOR_UPDATE_MARGIN,
    interval = interval,
    message = "the telescope combinator update did not drop the entry whose assembling machine was destroyed (#463)",
    on_success = function()
      runner.assert(
        helpers.funit_call("get_telescope_data", unit_number) == nil,
        "storage.telescopes still holds the stale telescope entry"
      )
      clean_areas()
    end,
    on_failure = clean_areas,
  })
end)

-- #458 / #461: a stale player index in the walking-particle tables.
--
-- The headless FUnit scenario has no players, and muluna_funit.get_storage goes
-- through remote.call, which copies tables, so the suite cannot write a stale
-- entry into Muluna storage; scripts/funit.lua has no walking-particle write
-- seam either. The test therefore verifies everything that is observable
-- without one: the storage invariant the fix relies on, that the handlers which
-- read the tables ignore an unknown player index, and that a full walking
-- update period leaves the tables untouched. If get_storage ever becomes a live
-- reference (or a write seam is added), the probe below exercises the real
-- every-tick handler with the #458 crash shape and restores it immediately.
runner.test("stale player walking state is ignored", function()
  clean_areas()

  local footstep_setting = settings.startup[FOOTSTEP_SETTING]
  runner.assert(
    footstep_setting ~= nil and footstep_setting.value == true,
    FOOTSTEP_SETTING
      .. " is disabled; scripts/walking_particles.lua did not load, so the walking tests are not meaningful"
  )
  runner.assert(
    count_players() == 0,
    "the headless scenario unexpectedly has a player; the stale-index test assumes none"
  )

  local before = walking_keys()
  runner.assert(
    type(helpers.storage().players_on_muluna) == "table",
    "storage.players_on_muluna is not a table"
  )
  runner.assert(
    type(helpers.storage().players_walking_on_muluna) == "table",
    "storage.players_walking_on_muluna is not a table"
  )
  runner.assert(
    count_keys(before.walking) == 0,
    "storage.players_walking_on_muluna is not empty at test start: " .. count_keys(before.walking)
  )
  assert_walking_invariant(before, "before the walking update tick")

  -- Probe whether storage is writable from the suite. It should not be: the
  -- accessor returns a copy. Never leave a stale entry behind, because the
  -- production every-tick handler has no nil guard and would crash the game
  -- before FUnit could report a failure.
  local probe = helpers.storage()
  probe.players_walking_on_muluna[STALE_PLAYER_INDEX] = true
  local injected = helpers.storage().players_walking_on_muluna[STALE_PLAYER_INDEX] ~= nil
  if injected then
    -- Storage is live after all. Invoke the production every-tick handler
    -- synchronously through the FUnit mock bridge so a crash is a test failure
    -- instead of a game crash, then remove the injected entry before any tick.
    local interface = remote.interfaces[MULUNA_MOCK_INTERFACE]
    runner.assert(
      interface ~= nil and interface.call_event_handler,
      MULUNA_MOCK_INTERFACE .. " is not registered; the walking handler cannot be exercised"
    )
    local ok, err = pcall(function()
      remote.call(MULUNA_MOCK_INTERFACE, "call_event_handler", {
        name = defines.events.on_tick,
        tick = game.tick,
      })
    end)
    probe.players_walking_on_muluna[STALE_PLAYER_INDEX] = nil
    runner.assert(
      helpers.storage().players_walking_on_muluna[STALE_PLAYER_INDEX] == nil,
      "could not restore the walking storage after the stale-index probe"
    )
    runner.assert(
      ok,
      "the every-tick walking handler crashed on a stale player index (#458/#461): " .. tostring(err)
    )
  else
    runner.log(
      "stale_entities: muluna_funit.get_storage returns a copy, so the #458/#461 "
        .. "stale-entry crash cannot be injected from the suite; asserting the storage invariant instead"
    )
  end

  -- Whatever the probe found, the walking storage must be back to its original
  -- key set before the real tick path runs.
  assert_same_keys(before, walking_keys(), "after the storage injection probe")

  -- The handlers that read the walking tables must ignore an unknown player
  -- index instead of creating state for it.
  local ok, err = pcall(mock.mock_event, { name = "move-up", player_index = STALE_PLAYER_INDEX })
  runner.assert(ok, "mocked move-up for an unknown player errored: " .. tostring(err))
  ok, err = pcall(mock.mock_event, {
    name = defines.events.on_player_changed_position,
    player_index = STALE_PLAYER_INDEX,
  })
  runner.assert(ok, "mocked on_player_changed_position for an unknown player errored: " .. tostring(err))

  -- Wait for the walking nth-tick (60 ticks) plus a margin. If any handler
  -- errors the game stops before this callback runs, so reaching it proves the
  -- real tick path did not crash.
  runner.after_n_ticks_do(WALKING_UPDATE_TICKS, function()
    local after = walking_keys()
    assert_walking_invariant(after, "after the walking update tick")
    runner.assert(
      after.walking[STALE_PLAYER_INDEX] == nil,
      "storage.players_walking_on_muluna adopted the unknown player index"
    )
    runner.assert(
      after.on_muluna[STALE_PLAYER_INDEX] == nil,
      "storage.players_on_muluna adopted the unknown player index"
    )
    runner.assert(
      after.rates[STALE_PLAYER_INDEX] == nil,
      "storage.walking_tick_rates adopted the unknown player index"
    )
    -- The snapshot was never mutated (storage is a copy), so an unchanged key
    -- set is the observable equivalent of restoring the exact prior tables.
    assert_same_keys(before, after, "walking storage changed while ignoring an unknown player index")
    clean_areas()
  end)
end)

-- #463 (telescope half): the combinator disappeared while the telescope
-- survived. The combinator update must drop the entry instead of crashing or
-- leaving an entry whose combinator is invalid.
runner.test("stale telescope combinator is cleaned up without crashing", function()
  clean_areas()

  local context = build_telescope("telescope-combinator")
  local telescope = context.telescope
  local combinator = context.combinator
  local unit_number = context.unit_number
  local interval = combinator_update_interval()

  combinator.destroy({ raise_destroy = false })
  runner.assert(not combinator.valid, "combinator is still valid after a silent destroy")
  runner.assert(telescope.valid, "destroying the combinator invalidated the telescope")

  local stale = helpers.funit_call("get_telescope_data", unit_number)
  runner.assert(
    stale ~= nil,
    "the silent destroy already removed the storage entry, so the stale path was not exercised"
  )
  runner.assert(
    stale["constant-combinator"] == nil or not stale["constant-combinator"].valid,
    "storage.telescopes does not point at the destroyed combinator"
  )

  helpers.wait_until(runner, function()
    return helpers.funit_call("get_telescope_data", unit_number) == nil
  end, {
    timeout = interval + COMBINATOR_UPDATE_MARGIN,
    interval = interval,
    message = "the telescope combinator update did not drop the entry whose combinator was destroyed (#463)",
    on_success = function()
      runner.assert(
        helpers.funit_call("get_telescope_data", unit_number) == nil,
        "storage.telescopes still holds the stale combinator entry"
      )
      -- The telescope itself is still valid and is left for clean_areas to
      -- delete with its surface; storage.telescopes is already consistent.
      runner.assert(
        telescope.valid,
        "the telescope should remain valid when only its combinator disappears"
      )
      clean_areas()
    end,
    on_failure = clean_areas,
  })
end)

-- #463: destroying the surviving combinator after the assembling machine has
-- already disappeared must clean up the pair without reading unit_number or
-- surface from the invalid assembling machine.
runner.test("destroying a stale telescope pair does not crash", function()
  clean_areas()
  local context = build_telescope("telescope-stale-pair")
  local telescope = context.telescope
  local combinator = context.combinator
  local unit_number = context.unit_number

  telescope.destroy({ raise_destroy = false })
  runner.assert(not telescope.valid, "telescope is still valid after a silent destroy")
  runner.assert(combinator.valid, "destroying the telescope invalidated the combinator")

  local ok, err = pcall(function()
    combinator.destroy({ raise_destroy = true })
  end)
  runner.assert(ok, "destroying a stale telescope pair crashed (#463): " .. tostring(err))
  runner.assert(
    helpers.funit_call("get_telescope_data", unit_number) == nil,
    "storage.telescopes still holds the pair after the stale combinator was destroyed"
  )
  clean_areas()
end)
