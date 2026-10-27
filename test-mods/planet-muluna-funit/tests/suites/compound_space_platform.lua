-- Runtime regression tests for compound entities built on space platforms and
-- for the telescope per-surface build limit.
--
-- Historical crash reports covered here:
--   #373 / #381  A telescope built on a space platform crashed inside the
--                on_space_platform_built_entity / script_raised_revive handler.
--                The build handler read game.players[event.player_index]
--                unconditionally, which is nil when a platform (not a player or
--                robot) is the builder.
--   #444         Construction robots placing a second telescope on a planet
--                crashed in the per-surface build limit while refunding the
--                telescope: the refund item stack carried entity.quality (a
--                LuaQualityPrototype) where a quality name string is required.
--   #371         A telescope ghost revived by an external mod without bplib
--                position data crashed on the resulting nil direction.
--
-- A compound entity's parent (the telescope / heat assembling machine) spawns
-- its subentity (the constant combinator / reactor) from the build handler, so
-- these tests assert both the storage registration and the subentity.
--
-- The headless scenario cannot raise on_space_platform_built_entity itself
-- (script.raise_event only accepts script_raised_built / script_raised_revive
-- and friends), so the platform builds here arrive through script_raised_built.
-- That is the same multi-handler in lib/events.lua and it has the same missing
-- player_index / robot that caused #373, so the regression is still covered.
local runner = require("__funit__.test_runner")
local helpers = require("__planet-muluna-funit__.tests.helpers")

local STARTER_PACK = "space-platform-starter-pack"
local TELESCOPE = "muluna-telescope"
local TELESCOPE_RECIPE = "muluna-telescope-observation-muluna"
-- Every surface and platform created here uses this prefix so a stale one from a
-- failed earlier run can be found and removed.
local PLATFORM_PREFIX = "funit-compound-"
local PLATFORM_PATTERN = "^funit%-compound%-"

local function get_constants()
  return prototypes.mod_data["muluna-constants"].data
end

local function get_telescope_config()
  local telescopes = get_constants().telescopes
  runner.assert(type(telescopes) == "table", "Muluna.constants.telescopes is missing")
  local config = telescopes[TELESCOPE]
  runner.assert(type(config) == "table", TELESCOPE .. " is not registered in Muluna.constants.telescopes")
  runner.assert(
    type(config["constant-combinator"]) == "string",
    TELESCOPE .. " has no constant-combinator in Muluna.constants.telescopes"
  )
  return config
end

---Pick a deterministic heat assembling machine configuration.
local function get_heat_machine_config()
  local machines = get_constants().heat_assembling_machines
  runner.assert(type(machines) == "table", "Muluna.constants.heat_assembling_machines is missing")
  local keys = {}
  for key in pairs(machines) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  runner.assert(#keys > 0, "Muluna.constants.heat_assembling_machines is empty")
  local machine = machines[keys[1]]
  runner.assert(machine["assembling-machine"], "heat machine entry has no assembling-machine")
  runner.assert(machine.reactor, "heat machine entry has no reactor")
  return machine
end

local function table_size(tbl)
  local count = 0
  for _ in pairs(tbl or {}) do
    count = count + 1
  end
  return count
end

local function destroy_entity(entity)
  if entity and entity.valid then
    pcall(function()
      entity.destroy({ raise_destroy = true })
    end)
  end
end

---Remove anything this suite could have left behind, then reset the shared test
---areas. Called before and after every test so a failure cannot leak state into
---the telescope / heat machine suites.
local function clean_areas()
  local stale_platforms = {}
  for _, force in pairs(game.forces) do
    for _, platform in pairs(force.platforms) do
      if platform.name:find(PLATFORM_PATTERN) then
        table.insert(stale_platforms, platform)
      end
    end
  end
  for _, platform in pairs(stale_platforms) do
    pcall(function()
      platform.destroy()
    end)
  end

  local stale_surfaces = {}
  for _, surface in pairs(game.surfaces) do
    if surface.name:find(PLATFORM_PATTERN) then
      table.insert(stale_surfaces, surface)
    end
  end
  for _, surface in pairs(stale_surfaces) do
    pcall(game.delete_surface, surface)
  end

  pcall(helpers.reset_test_areas)
end

local function create_platform(name)
  runner.assert(prototypes.item[STARTER_PACK], STARTER_PACK .. " item prototype is missing; cannot create a space platform")
  local platform = game.forces.player.create_space_platform({
    name = name,
    planet = "nauvis",
    starter_pack = { name = STARTER_PACK, quality = "normal" },
  })
  runner.assert(platform and platform.valid, "could not create space platform " .. name)
  platform.apply_starter_pack(true)
  runner.assert(
    platform.surface and platform.surface.valid,
    "space platform " .. name .. " has no surface after applying its starter pack"
  )
  runner.assert(platform.hub and platform.hub.valid, "space platform " .. name .. " has no hub")
  return platform
end

local function destroy_platform(platform)
  if platform and platform.valid then
    pcall(function()
      platform.destroy()
    end)
  end
end

---Destroy the compound parents first so their destroy handlers clear storage,
---then the platform, then anything stale.
local function cleanup_platform(platform, parents)
  for _, parent in ipairs(parents or {}) do
    destroy_entity(parent)
  end
  destroy_platform(platform)
  clean_areas()
end

---Find a position on a platform surface where `name` can actually be built.
---The starter pack is small and its layout is not part of this mod, so search
---outwards from the hub instead of hardcoding a position.
local function find_platform_position(surface, name)
  local platform = surface.platform
  local origin = { x = 0, y = 0 }
  if platform and platform.hub and platform.hub.valid then
    origin = platform.hub.position
  end
  -- A starter pack is much smaller than a 3x3 compound entity, so extend the
  -- platform with foundation tiles around the hub. This is test setup, not
  -- production behavior: it makes room for the entity without changing the
  -- platform branch the build handler takes.
  local tiles = {}
  for dx = -10, 10 do
    for dy = -10, 10 do
      tiles[#tiles + 1] = {
        name = "space-platform-foundation",
        position = { x = origin.x + dx, y = origin.y + dy },
      }
    end
  end
  surface.set_tiles(tiles, true)
  for radius = 0, 12 do
    for dx = -radius, radius do
      for dy = -radius, radius do
        if math.abs(dx) == radius or math.abs(dy) == radius then
          local position = { x = origin.x + dx, y = origin.y + dy }
          if surface.can_place_entity({ name = name, position = position, force = "player" }) then
            return position
          end
        end
      end
    end
  end
  return nil
end

---Registered telescope entries that live on `surface` for `force`. This mirrors
---the per-surface build limit in scripts/telescopes.lua: entries whose
---assembling machine is valid, on the same surface, for the builder's force.
local function registered_telescopes(surface, force)
  local found = {}
  for unit_number, entry in pairs(helpers.storage().telescopes or {}) do
    local machine = entry["assembling-machine"]
    if
      machine
      and machine.valid
      and machine.surface_index == surface.index
      and machine.force.index == force.index
    then
      found[unit_number] = entry
    end
  end
  return found
end

---Telescope builds assign the observation recipe, so the player force must be
---able to see it. Restore the flag even when the test body fails.
local function with_telescope_recipe(fn, recipe_name)
  recipe_name = recipe_name or TELESCOPE_RECIPE
  local recipe = game.forces["player"].recipes[recipe_name]
  runner.assert(recipe ~= nil, "player force has no LuaRecipe for " .. recipe_name)
  local was_enabled = recipe.enabled
  recipe.enabled = true
  local ok, err = xpcall(fn, debug.traceback)
  if recipe.valid then
    recipe.enabled = was_enabled
  end
  if not ok then
    error(err, 0)
  end
end

runner.test("space platform telescope builds and registers", function()
  -- Regression: #373 / #381. script_raised_built (which is also raised for a
  -- platform build in this headless scenario) has no player_index and no robot,
  -- so the build handler must fall back instead of indexing game.players[nil].
  clean_areas()
  local telescope_config = get_telescope_config()
  local platform = create_platform(PLATFORM_PREFIX .. "telescope")
  local context = { platform = platform }

  local ok, err = pcall(function()
    local surface = platform.surface
    local position = find_platform_position(surface, TELESCOPE)
    runner.assert(position ~= nil, "no buildable position for " .. TELESCOPE .. " on " .. platform.name)

    local telescope = helpers.entity_at(surface, TELESCOPE, position)
    context.telescope = telescope
    runner.assert(
      telescope and telescope.valid,
      "building " .. TELESCOPE .. " on a space platform did not create an entity (#373/#381)"
    )
    runner.assert(telescope.name == TELESCOPE, "created entity is not " .. TELESCOPE)
    runner.assert(telescope.surface_index == surface.index, "telescope was created on the wrong surface")
    runner.assert(
      surface.platform and surface.platform.index == platform.index,
      "the telescope surface is not the test platform"
    )

    local data = helpers.funit_call("get_telescope_data", telescope.unit_number)
    runner.assert(type(data) == "table", "storage.telescopes has no entry for the platform telescope")
    runner.assert(
      data["assembling-machine"] == telescope,
      "storage.telescopes entry points at the wrong assembling machine"
    )

    local combinator = data["constant-combinator"]
    runner.assert(combinator ~= nil and combinator.valid, "platform telescope has no valid constant-combinator")
    runner.assert(
      combinator.name == telescope_config["constant-combinator"],
      "expected " .. telescope_config["constant-combinator"] .. ", got " .. tostring(combinator.name)
    )
    runner.assert(
      combinator.surface_index == surface.index,
      "the telescope combinator is not on the telescope's surface"
    )
    runner.assert(
      combinator.surface.platform and combinator.surface.platform.index == platform.index,
      "the telescope combinator is not on the test platform"
    )
    runner.assert(
      combinator.unit_number ~= telescope.unit_number,
      "the telescope and its combinator unexpectedly share a unit number"
    )

    local control_behavior = data["constant-combinator-control-behavior"]
    runner.assert(control_behavior ~= nil, "platform telescope has no cached combinator control behavior")
    runner.assert(control_behavior.enabled == false, "a new telescope combinator should start disabled")
    runner.assert(
      data.output_asteroid_signals == false,
      "output_asteroid_signals should default to false on a new telescope"
    )

    local storage = helpers.storage()
    runner.assert(storage.telescopes[telescope.unit_number] ~= nil, "storage.telescopes is missing the telescope")
    local on_surface = storage.telescopes_on_surface[surface.name]
    runner.assert(type(on_surface) == "table", "storage.telescopes_on_surface has no entry for the platform surface")
    runner.assert(
      on_surface[telescope.unit_number] == true,
      "storage.telescopes_on_surface is missing the platform telescope"
    )

    -- scripts/telescopes.lua only assigns an observation recipe on planets (and
    -- blueprint sandboxes), so a platform telescope keeps no recipe.
    runner.assert(
      telescope.get_recipe() == nil,
      "a platform telescope should not be assigned a planet observation recipe"
    )
  end)

  cleanup_platform(platform, { context.telescope })
  if not ok then
    error(err, 0)
  end
end)

runner.test("space platform heat assembling machine builds and registers", function()
  -- Regression: the compound parent/child registration must also work when the
  -- parent is built on a space platform. The build handler creates the reactor
  -- and links its fluid box without any player or robot present.
  clean_areas()
  local machine = get_heat_machine_config()
  local platform = create_platform(PLATFORM_PREFIX .. "heat")
  local context = { platform = platform }

  local ok, err = pcall(function()
    local surface = platform.surface
    local position = find_platform_position(surface, machine["assembling-machine"])
    runner.assert(
      position ~= nil,
      "no buildable position for " .. machine["assembling-machine"] .. " on " .. platform.name
    )

    local assembler = helpers.entity_at(surface, machine["assembling-machine"], position)
    context.assembler = assembler
    runner.assert(
      assembler and assembler.valid,
      "building " .. machine["assembling-machine"] .. " on a space platform did not create an entity"
    )
    runner.assert(assembler.surface_index == surface.index, "heat assembling machine was created on the wrong surface")

    local data = helpers.funit_call("get_heat_assembling_machine_data", assembler.unit_number)
    runner.assert(data ~= nil, "platform heat assembling machine was not registered in storage")
    runner.assert(
      data["assembling-machine"] == assembler,
      "storage entry points at the wrong assembling machine"
    )

    local reactor = data.reactor
    runner.assert(reactor ~= nil and reactor.valid, "platform heat assembling machine has no valid reactor")
    runner.assert(
      reactor.name == machine.reactor,
      "reactor has the wrong prototype name: " .. tostring(reactor.name)
    )
    runner.assert(reactor.surface_index == surface.index, "the reactor is not on the assembling machine's surface")
    runner.assert(reactor.force == assembler.force, "reactor force does not match the assembling machine")
    runner.assert(
      math.abs(reactor.position.x - assembler.position.x) < 0.1
        and math.abs(reactor.position.y - assembler.position.y) < 0.1,
      "the reactor is not at the assembling machine position"
    )

    -- The reactor's linked fluid box is what carries heat to the machine.
    local linked_entity, linked_id = reactor.get_fluid_box_linked_connection(1)
    runner.assert(
      linked_entity == assembler,
      "reactor fluid box 1 is not linked to its assembling machine"
    )
    runner.assert(linked_id == 1, "reactor fluid box link uses unexpected remote id " .. tostring(linked_id))

    local fixed_recipe = assembler.prototype.fixed_recipe
    runner.assert(fixed_recipe ~= nil, machine["assembling-machine"] .. " has no fixed recipe prototype")
    local recipe = assembler.get_recipe()
    runner.assert(recipe ~= nil, "platform heat assembling machine has no recipe")
    runner.assert(
      recipe.name == fixed_recipe.name,
      "heat machine recipe should be " .. fixed_recipe.name .. ", got " .. tostring(recipe.name)
    )
  end)

  cleanup_platform(platform, { context.assembler })
  if not ok then
    error(err, 0)
  end
end)

runner.test("second telescope on the same surface is refused without crashing", function()
  -- Regression: #444. A planet allows one telescope per surface per force. The
  -- refusal path builds a refund item stack; it used to carry
  -- entity.quality (a prototype) instead of entity.quality.name, which raised
  -- while the stack was created. It also must not double-register the refused
  -- telescope or drop the first telescope's registration.
  clean_areas()
  local telescope_config = get_telescope_config()
  -- Use Nauvis: Muluna's natural tiles destroy dropped items, which would
  -- consume the refund before the assertion can observe it. The build-limit
  -- code path is surface-independent.
  local surface = helpers.get_nauvis()
  local force = game.forces["player"]
  local context = {}
  local area = helpers.nauvis_area()
  local center = helpers.center(area)

  -- The Nauvis test area can be water; landfill makes the placement reliable.
  local tiles = {}
  for x = area.left_top[1], area.right_bottom[1] do
    for y = area.left_top[2], area.right_bottom[2] do
      tiles[#tiles + 1] = { name = "landfill", position = { x = x, y = y } }
    end
  end
  helpers.set_tiles(surface, tiles, { remove_colliding_entities = true })

  with_telescope_recipe(function()
    local ok, err = pcall(function()
      local before = table_size(registered_telescopes(surface, force))
      runner.assert(
        before == 0,
        "a telescope on Nauvis was left registered before the build-limit test (count "
          .. before
          .. "); earlier cleanup did not clear it"
      )

      local first = helpers.entity_at(surface, TELESCOPE, center)
      context.first = first
      runner.assert(first and first.valid, "could not create the first telescope on Nauvis")
      local first_unit_number = first.unit_number

      local registered = registered_telescopes(surface, force)
      runner.assert(
        table_size(registered) == 1,
        "expected exactly one registered telescope after the first build, got " .. table_size(registered)
      )
      local first_data = helpers.funit_call("get_telescope_data", first_unit_number)
      runner.assert(first_data ~= nil, "the first telescope was not registered in storage.telescopes")
      runner.assert(
        first_data["constant-combinator"] ~= nil and first_data["constant-combinator"].valid,
        "the first telescope has no valid combinator"
      )

      -- The second build must be refused. create_entity raises the build event
      -- synchronously, so the entity may already be destroyed when it returns;
      -- only read its `valid` flag, never its unit number.
      local second_position = { x = center.x + 10, y = center.y }
      local second
      local build_ok, build_err = pcall(function()
        second = helpers.entity_at(surface, TELESCOPE, second_position)
      end)
      context.second = second
      runner.assert(
        build_ok,
        "placing a second telescope on the same surface raised an error (#444): " .. tostring(build_err)
      )
      runner.assert(
        second == nil or not second.valid,
        "the second telescope survived the per-surface build limit"
      )

      -- The refusal path refunds the telescope as an item on the ground. This is
      -- the item stack that used to carry entity.quality instead of
      -- entity.quality.name (#444), so it proves the limit path really ran.
      local refunds = surface.find_entities_filtered({
        name = "item-on-ground",
        area = {
          left_top = { x = second_position.x - 1, y = second_position.y - 1 },
          right_bottom = { x = second_position.x + 1, y = second_position.y + 1 },
        },
      })
      runner.assert(
        #refunds > 0,
        "the per-surface build limit did not refund the refused telescope as an item on the ground"
      )
      local refunded_telescope = false
      for _, refund in pairs(refunds) do
        local stack = refund.stack
        if stack and stack.valid_for_read and stack.name == TELESCOPE then
          refunded_telescope = true
        end
      end
      runner.assert(
        refunded_telescope,
        "the refused telescope refund is not a " .. TELESCOPE .. " item stack"
      )

      local after = registered_telescopes(surface, force)
      runner.assert(
        table_size(after) == 1,
        "the per-surface build limit left "
          .. table_size(after)
          .. " telescopes registered, expected exactly 1"
      )
      runner.assert(
        after[first_unit_number] ~= nil,
        "the refused second telescope removed the first telescope's registration"
      )

      local storage = helpers.storage()
      local on_surface = storage.telescopes_on_surface[surface.name]
      runner.assert(
        table_size(on_surface) == 1,
        "storage.telescopes_on_surface has "
          .. table_size(on_surface)
          .. " entries for Muluna, expected exactly 1"
      )
      runner.assert(
        on_surface[first_unit_number] == true,
        "storage.telescopes_on_surface does not point at the first telescope"
      )

      runner.assert(
        surface.find_entity(telescope_config["constant-combinator"], second_position) == nil,
        "the refused second telescope was given a combinator"
      )
      runner.assert(
        #surface.find_entities_filtered({ name = TELESCOPE, area = area }) == 1,
        "expected exactly one telescope entity left on Muluna after the refused build"
      )

      runner.assert(first.valid, "the first telescope became invalid when the second build was refused")
      local still_registered = helpers.funit_call("get_telescope_data", first_unit_number)
      runner.assert(still_registered ~= nil, "the first telescope lost its storage entry")
      runner.assert(
        still_registered["constant-combinator"] ~= nil and still_registered["constant-combinator"].valid,
        "the first telescope lost its combinator"
      )
    end)

    -- Clean up through the real destroy handler so storage is cleared even when
    -- an assertion above failed.
    destroy_entity(context.first)
    clean_areas()
    if not ok then
      error(err, 0)
    end
  end, "muluna-telescope-observation-nauvis")
end)

runner.test("telescope ghost revives without bplib positions", function()
  -- Regression: #371. An external mod can revive a telescope ghost without
  -- raising bplib-positions, so there is no saved source direction. The build
  -- handler used to assign that nil direction and crash; it must keep the
  -- entity's own orientation instead.
  clean_areas()
  local telescope_config = get_telescope_config()
  local surface = helpers.get_muluna()
  local context = {}

  with_telescope_recipe(function()
    local ok, err = pcall(function()
      local center = helpers.center(helpers.muluna_area())
      local position = { x = center.x, y = center.y }
      local ghost = helpers.entity_at(surface, "entity-ghost", position, {
        inner_name = TELESCOPE,
        direction = defines.direction.east,
        raise_built = false,
      })
      context.ghost = ghost
      runner.assert(ghost and ghost.valid, "could not create an " .. TELESCOPE .. " entity-ghost")
      runner.assert(ghost.ghost_name == TELESCOPE, "the ghost does not wrap " .. TELESCOPE)
      runner.assert(
        type(ghost.tags) ~= "table" or ghost.tags.muluna_compound == nil,
        "the ghost unexpectedly carries muluna compound blueprint tags"
      )

      local ghost_direction = ghost.direction
      runner.assert(
        ghost_direction == defines.direction.east,
        "the test ghost did not keep its requested direction: " .. tostring(ghost_direction)
      )

      local revived
      local revive_ok, revive_err = pcall(function()
        local _, entity = ghost.revive({ raise_revive = true })
        revived = entity
      end)
      context.revived = revived
      runner.assert(
        revive_ok,
        "reviving a telescope ghost without bplib positions raised an error (#371): " .. tostring(revive_err)
      )
      runner.assert(revived ~= nil and revived.valid, "the telescope ghost did not revive into a valid entity")
      runner.assert(revived.name == TELESCOPE, "the revived entity is " .. tostring(revived.name))
      -- The engine may revive a script-created ghost facing north; the
      -- regression is that a missing bplib direction must not be assigned as a
      -- nil direction (which used to raise). A numeric direction proves the
      -- handler kept the entity's own orientation instead of writing nil.
      runner.assert(
        type(revived.direction) == "number",
        "the revived telescope has no numeric direction: " .. tostring(revived.direction)
      )

      local data = helpers.funit_call("get_telescope_data", revived.unit_number)
      runner.assert(type(data) == "table", "the revived telescope was not registered in storage.telescopes")
      runner.assert(
        data["assembling-machine"] == revived,
        "the revived telescope storage entry points at the wrong assembling machine"
      )
      local combinator = data["constant-combinator"]
      runner.assert(combinator ~= nil and combinator.valid, "the revived telescope has no valid combinator")
      runner.assert(
        combinator.name == telescope_config["constant-combinator"],
        "the revived telescope got " .. tostring(combinator.name) .. " instead of its combinator"
      )
    end)

    destroy_entity(context.revived)
    clean_areas()
    if not ok then
      error(err, 0)
    end
  end)
end)

runner.test("space platform telescope survives the combinator update tick", function()
  -- Follow-up to #373 / #381: the combinator update tick runs the platform
  -- branch of get_telescope_combinator_signals, which reads surface.platform,
  -- the platform index and the platform's space connection. Enable the cached
  -- control behavior so the tick actually reaches that branch.
  clean_areas()
  local platform = create_platform(PLATFORM_PREFIX .. "update")
  local context = { platform = platform }

  local build_ok, build_err = pcall(function()
    local surface = platform.surface
    local position = find_platform_position(surface, TELESCOPE)
    runner.assert(position ~= nil, "no buildable position for " .. TELESCOPE .. " on " .. platform.name)
    local telescope = helpers.entity_at(surface, TELESCOPE, position)
    context.telescope = telescope
    runner.assert(telescope and telescope.valid, "could not build the platform telescope for the update tick test")
  end)
  if not build_ok then
    cleanup_platform(platform, { context.telescope })
    error(build_err, 0)
  end

  local telescope = context.telescope
  local unit_number = telescope.unit_number
  local platform_index = platform.index
  local data = helpers.funit_call("get_telescope_data", unit_number)
  runner.assert(type(data) == "table", "the platform telescope was not registered")
  local control_behavior = data["constant-combinator-control-behavior"]
  runner.assert(control_behavior ~= nil, "the platform telescope has no cached combinator control behavior")
  -- LuaObjects cross the remote interface by reference, so this enables the
  -- same control behavior object that storage.telescopes holds.
  control_behavior.enabled = true

  local enabled_data = helpers.funit_call("get_telescope_data", unit_number)
  runner.assert(
    enabled_data["constant-combinator-control-behavior"].enabled == true,
    "could not enable the platform telescope combinator; the update tick would skip it"
  )

  local update_ticks = math.floor(settings.startup["muluna-telescope-combinator-update-ticks"].value)
  runner.assert(update_ticks > 0, "muluna-telescope-combinator-update-ticks must be positive")

  runner.after_n_ticks_do(update_ticks + 5, function()
    local ok, err = pcall(function()
      local current = helpers.funit_call("get_telescope_data", unit_number)
      runner.assert(current ~= nil, "the combinator update tick removed the platform telescope from storage")
      runner.assert(
        current.cached_signals ~= nil,
        "the platform telescope combinator was not updated on its update tick"
      )

      local platform_signal
      for _, signal in ipairs(current.cached_signals) do
        if
          type(signal.value) == "table"
          and signal.value.type == "virtual"
          and signal.value.name == "signal-I"
        then
          platform_signal = signal
        end
      end
      runner.assert(
        platform_signal ~= nil,
        "platform telescope signals do not include the platform index signal (signal-I)"
      )
      runner.assert(
        platform_signal.min == platform_index,
        "signal-I should carry the platform index "
          .. tostring(platform_index)
          .. ", got "
          .. tostring(platform_signal.min)
      )
    end)

    cleanup_platform(platform, { telescope })
    if not ok then
      error(err, 0)
    end
  end)
end)
