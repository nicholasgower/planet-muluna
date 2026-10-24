-- Runtime tests for lunar rock deconstruction over Muluna terrain.
--
-- Muluna's natural dirt and sand tiles destroy dropped items. Construction
-- robots spill a mined entity's results onto the ground before collecting
-- them, so deconstructing a lunar rock over natural terrain used to lose the
-- stone it should have dropped. The control-stage rock removal queue cancels
-- the order until a crushed stone floor has been built underneath the rock.
local runner = require("__funit__.test_runner")
local helpers = require("__planet-muluna-funit__.tests.helpers")

local ROCK = "lunar-rock"
local DIRT = "muluna-dirt-1"
local FLOOR = "muluna-gravel"

-- The queue covers the rock's nominal tile footprint with no outer margin.
local ROCK_AREA_HALF_SIZE = 30

local function floor_positions_for_rock(rock)
  local bounding_box = rock.bounding_box
  local tile_width = math.max(1, math.ceil(bounding_box.right_bottom.x - bounding_box.left_top.x))
  local tile_height = math.max(1, math.ceil(bounding_box.right_bottom.y - bounding_box.left_top.y))
  local center_x = (bounding_box.left_top.x + bounding_box.right_bottom.x) / 2
  local center_y = (bounding_box.left_top.y + bounding_box.right_bottom.y) / 2
  local left = math.floor(center_x - (tile_width - 1) / 2)
  local top = math.floor(center_y - (tile_height - 1) / 2)

  local positions = {}
  for x = left, left + tile_width - 1 do
    for y = top, top + tile_height - 1 do
      positions[#positions + 1] = { x = x, y = y }
    end
  end
  return positions
end

local function test_area(center)
  return {
    { center.x - ROCK_AREA_HALF_SIZE, center.y - ROCK_AREA_HALF_SIZE },
    { center.x + ROCK_AREA_HALF_SIZE, center.y + ROCK_AREA_HALF_SIZE },
  }
end

local function set_floor(surface, positions, tile_name, raise_event)
  local tiles = {}
  for _, position in ipairs(positions) do
    tiles[#tiles + 1] = {
      name = tile_name,
      position = { position.x, position.y },
    }
  end
  helpers.set_tiles(surface, tiles, {
    raise_event = raise_event,
    -- This intentionally builds tiles underneath the lunar rock without
    -- deconstructing the rock first.
    remove_colliding_entities = false,
  })
end

local function fill_area(surface, area, tile_name)
  local left_top = area[1]
  local right_bottom = area[2]
  local tiles = {}
  for x = math.floor(left_top[1]), math.ceil(right_bottom[1]) - 1 do
    for y = math.floor(left_top[2]), math.ceil(right_bottom[2]) - 1 do
      tiles[#tiles + 1] = {
        name = tile_name,
        position = { x, y },
      }
    end
  end
  helpers.set_tiles(surface, tiles, { remove_colliding_entities = false })
end

local function tile_ghosts(surface, position, force)
  return surface.get_tile(position.x, position.y).get_tile_ghosts(force or "player")
end

local function has_floor_ghost(surface, position)
  for _, ghost in pairs(tile_ghosts(surface, position)) do
    if ghost.valid and ghost.ghost_name == FLOOR then
      return true
    end
  end
  return false
end

local function queue_entries(storage)
  return storage.rocks_queued_for_removal or {}
end

local function count_entries(tbl)
  local count = 0
  for _ in pairs(tbl or {}) do
    count = count + 1
  end
  return count
end

local function find_queue_entry(storage, surface, rock)
  for index, entry in pairs(queue_entries(storage)) do
    if
      entry.surface_index == surface.index
      and entry.position
      and entry.position.x == rock.position.x
      and entry.position.y == rock.position.y
    then
      return index, entry
    end
  end
  return nil
end

local function cleanup_area(surface, center)
  local area = test_area(center)
  pcall(helpers.funit_call, "clear_rock_removal_state", surface.index)
  pcall(helpers.clear_area, surface, area)
  pcall(fill_area, surface, area, FLOOR)
end

local function with_rock_area(fn)
  pcall(helpers.reset_test_areas)
  local surface = helpers.get_muluna()
  local center = helpers.center(helpers.muluna_area())
  local area = test_area(center)
  pcall(helpers.clear_area, surface, area)
  fill_area(surface, area, FLOOR)

  local ok, err = pcall(fn, surface, center)

  cleanup_area(surface, center)
  if not ok then
    error(err, 0)
  end
end

local function queue_test_rock(surface, center, rock_name)
  rock_name = rock_name or ROCK
  local rock = helpers.entity_at(surface, rock_name, center)
  runner.assert(rock and rock.valid, "could not create " .. rock_name)
  local positions = floor_positions_for_rock(rock)
  set_floor(surface, positions, DIRT)
  runner.assert(rock.order_deconstruction("player"), "could not mark " .. rock_name .. " for deconstruction")
  runner.assert(not rock.to_be_deconstructed(), "rock deconstruction was not cancelled")
  return rock, positions
end

runner.test("lunar rock: unsafe floor queues removal and ghosts the floor", function()
  with_rock_area(function(surface, center)
    local rock, positions = queue_test_rock(surface, center)

    local storage = helpers.funit_call("get_storage")
    local index, entry = find_queue_entry(storage, surface, rock)
    runner.assert(entry, "rock was not added to storage.rocks_queued_for_removal")
    runner.assert(entry.force == "player", "queued rock did not store the marking force")
    runner.assert(entry.player_index == nil, "script-marked rock unexpectedly stored a player index")
    runner.assert(
      table_size(entry.tiles) == #positions,
      "queued rock tracks " .. tostring(table_size(entry.tiles)) .. " floor tiles, expected " .. tostring(#positions)
    )
    runner.assert(
      table_size(entry.remaining) == #positions,
      "queued rock has " .. tostring(table_size(entry.remaining)) .. " unbuilt tiles, expected " .. tostring(#positions)
    )

    for _, position in ipairs(positions) do
      runner.assert(
        has_floor_ghost(surface, position),
        "missing " .. FLOOR .. " ghost at (" .. tostring(position.x) .. ", " .. tostring(position.y) .. ")"
      )
      local inverted = storage.tiles_queued_by_rock_remover[surface.index]
        and storage.tiles_queued_by_rock_remover[surface.index][position.x]
        and storage.tiles_queued_by_rock_remover[surface.index][position.x][position.y]
      runner.assert(
        inverted and inverted[index],
        "inverted tile map does not point at the queued rock for ("
          .. tostring(position.x) .. ", " .. tostring(position.y) .. ")"
      )
    end

    local outside = {
      x = positions[1].x - 1,
      y = center.y,
    }
    runner.assert(
      not has_floor_ghost(surface, outside),
      "tile ghost was created outside the expanded rock footprint"
    )
  end)
end)

runner.test("lunar rock: undo removes queued floor ghosts", function()
  with_rock_area(function(surface, center)
    local rock = helpers.entity_at(surface, ROCK, center)
    runner.assert(rock and rock.valid, "could not create " .. ROCK)
    local positions = floor_positions_for_rock(rock)
    set_floor(surface, positions, DIRT)

    local unrelated_position = positions[1]
    local unrelated_ghost = surface.create_entity({
      name = "tile-ghost",
      inner_name = "stone-path",
      position = { unrelated_position.x + 0.5, unrelated_position.y + 0.5 },
      force = "player",
    })
    runner.assert(unrelated_ghost and unrelated_ghost.valid, "could not create the unrelated tile ghost")

    runner.assert(rock.order_deconstruction("player"), "could not mark " .. ROCK .. " for deconstruction")
    runner.assert(not rock.to_be_deconstructed(), "rock deconstruction was not cancelled")

    local before = helpers.funit_call("get_storage")
    local _, entry = find_queue_entry(before, surface, rock)
    runner.assert(entry, "rock was not queued before undo")
    for _, position in ipairs(positions) do
      runner.assert(
        has_floor_ghost(surface, position),
        "missing " .. FLOOR .. " ghost before undo at ("
          .. tostring(position.x) .. ", " .. tostring(position.y) .. ")"
      )
    end

    local removed = helpers.funit_call("apply_rock_removal_undo", {
      {
        type = "removed-entity",
        target = {
          name = ROCK,
          position = { x = rock.position.x, y = rock.position.y },
        },
      },
    })
    runner.assert(removed == 1, "undo removed " .. tostring(removed) .. " queued rocks, expected 1")

    local after = helpers.funit_call("get_storage")
    runner.assert(
      count_entries(after.rocks_queued_for_removal) == 0,
      "undo left an entry in the removal queue"
    )
    runner.assert(
      not after.tiles_queued_by_rock_remover[surface.index],
      "undo left entries in the inverted tile map"
    )

    for _, position in ipairs(positions) do
      runner.assert(
        not has_floor_ghost(surface, position),
        "undo left a " .. FLOOR .. " ghost at ("
          .. tostring(position.x) .. ", " .. tostring(position.y) .. ")"
      )
    end

    local remaining_ghost_names = {}
    for _, ghost in pairs(tile_ghosts(surface, unrelated_position)) do
      if ghost.valid then
        remaining_ghost_names[ghost.ghost_name] = true
      end
    end
    runner.assert(
      remaining_ghost_names["stone-path"],
      "undo removed the unrelated stone-path ghost"
    )
  end)
end)

runner.test("lunar rock: only robot-built gravel is queued for cleanup", function()
  with_rock_area(function(surface, center)
    local rock, positions = queue_test_rock(surface, center)
    local robot_positions = {}
    local player_positions = {}
    for index, position in ipairs(positions) do
      if index % 2 == 0 then
        robot_positions[#robot_positions + 1] = position
      else
        player_positions[#player_positions + 1] = position
      end
    end

    local function event_tiles(source)
      local tiles = {}
      for _, position in ipairs(source) do
        tiles[#tiles + 1] = {
          position = { x = position.x, y = position.y },
        }
      end
      return tiles
    end

    helpers.funit_call(
      "record_rock_floor_build",
      surface.index,
      event_tiles(robot_positions),
      FLOOR,
      "robot"
    )
    helpers.funit_call(
      "record_rock_floor_build",
      surface.index,
      event_tiles(player_positions),
      FLOOR,
      "player"
    )

    set_floor(surface, positions, FLOOR, true)
    runner.assert(rock.to_be_deconstructed(), "rock was not re-marked after its floor was completed")

    local storage = helpers.funit_call("get_storage")
    runner.assert(
      count_entries(storage.rocks_pending_gravel_cleanup) == 1,
      "floor completion did not create a pending gravel cleanup entry"
    )
    local pending_index = next(storage.rocks_pending_gravel_cleanup)
    local pending = storage.rocks_pending_gravel_cleanup[pending_index]
    runner.assert(
      table_size(pending.tiles) == #robot_positions,
      "pending cleanup tracks " .. tostring(table_size(pending.tiles))
        .. " tiles, expected " .. tostring(#robot_positions)
    )

    local expected = {}
    for _, position in ipairs(robot_positions) do
      expected[position.x .. ":" .. position.y] = true
    end
    for _, position in ipairs(pending.tiles) do
      runner.assert(
        expected[position.x .. ":" .. position.y],
        "pending cleanup included player-built tile at ("
          .. tostring(position.x) .. ", " .. tostring(position.y) .. ")"
      )
    end

    helpers.funit_call("apply_rock_removal_undo", {
      {
        type = "removed-entity",
        target = {
          name = ROCK,
          position = { x = rock.position.x, y = rock.position.y },
        },
      },
    })

    local unreferenced = helpers.funit_call("get_storage")
    runner.assert(
      count_entries(unreferenced.rocks_pending_gravel_cleanup) == 0,
      "undo left the pending robot-built gravel cleanup entry behind"
    )
    for _, position in ipairs(robot_positions) do
      runner.assert(
        surface.get_tile(position.x, position.y).to_be_deconstructed("player"),
        "undo did not mark the robot-built gravel for removal at ("
          .. tostring(position.x) .. ", " .. tostring(position.y) .. ")"
      )
    end
    for _, position in ipairs(player_positions) do
      runner.assert(
        not surface.get_tile(position.x, position.y).to_be_deconstructed("player"),
        "undo marked player-built gravel for removal at ("
          .. tostring(position.x) .. ", " .. tostring(position.y) .. ")"
      )
    end
  end)
end)

runner.test("lunar rock: huge rock uses its full footprint", function()
  with_rock_area(function(surface, center)
    local rock, positions = queue_test_rock(surface, center, "lunar-huge-rock")
    runner.assert(#positions == 9, "huge rock floor covers " .. tostring(#positions) .. " tiles, expected 9")

    local expected = {
      { x = center.x - 1, y = center.y - 1 },
      { x = center.x - 1, y = center.y + 1 },
      { x = center.x + 1, y = center.y - 1 },
      { x = center.x + 1, y = center.y + 1 },
    }
    local actual = {}
    for _, position in ipairs(positions) do
      actual[position.x .. ":" .. position.y] = true
    end
    for _, position in ipairs(expected) do
      runner.assert(
        actual[position.x .. ":" .. position.y],
        "huge rock floor is missing corner (" .. tostring(position.x) .. ", " .. tostring(position.y) .. ")"
      )
    end

    for _, position in ipairs(positions) do
      runner.assert(
        has_floor_ghost(surface, position),
        "huge rock is missing a floor ghost at (" .. tostring(position.x) .. ", " .. tostring(position.y) .. ")"
      )
    end
    runner.assert(not rock.to_be_deconstructed(), "huge rock deconstruction was not cancelled")
  end)
end)

runner.test("lunar rock: off-grid huge rock does not gain an edge tile", function()
  with_rock_area(function(surface, center)
    local position = { x = center.x + 0.4375, y = center.y + 0.1875 }
    local rock = helpers.entity_at(surface, "lunar-huge-rock", position)
    runner.assert(rock and rock.valid, "could not create off-grid lunar-huge-rock")

    local positions = floor_positions_for_rock(rock)
    runner.assert(
      #positions == 9,
      "off-grid huge rock floor covers " .. tostring(#positions) .. " tiles, expected 9"
    )

    local min_x, max_x = math.huge, -math.huge
    local min_y, max_y = math.huge, -math.huge
    for _, tile in ipairs(positions) do
      min_x = math.min(min_x, tile.x)
      max_x = math.max(max_x, tile.x)
      min_y = math.min(min_y, tile.y)
      max_y = math.max(max_y, tile.y)
    end
    runner.assert(min_x == center.x - 1, "off-grid huge rock floor starts at x=" .. tostring(min_x))
    runner.assert(max_x == center.x + 1, "off-grid huge rock floor ends at x=" .. tostring(max_x))
    runner.assert(min_y == center.y - 1, "off-grid huge rock floor starts at y=" .. tostring(min_y))
    runner.assert(max_y == center.y + 1, "off-grid huge rock floor ends at y=" .. tostring(max_y))

    set_floor(surface, positions, DIRT)
    runner.assert(
      rock.order_deconstruction("player"),
      "could not mark off-grid lunar-huge-rock for deconstruction"
    )
    runner.assert(not rock.to_be_deconstructed(), "off-grid huge rock deconstruction was not cancelled")

    local storage = helpers.funit_call("get_storage")
    local _, entry = find_queue_entry(storage, surface, rock)
    runner.assert(entry, "off-grid huge rock was not queued")
    runner.assert(
      table_size(entry.tiles) == 9,
      "off-grid huge rock queue tracks " .. tostring(table_size(entry.tiles)) .. " tiles, expected 9"
    )
  end)
end)

runner.test("lunar rock: unrelated tile ghost does not satisfy the floor", function()
  with_rock_area(function(surface, center)
    local rock = helpers.entity_at(surface, ROCK, center)
    runner.assert(rock and rock.valid, "could not create " .. ROCK)
    local positions = floor_positions_for_rock(rock)
    set_floor(surface, positions, DIRT)

    local blocked = positions[1]
    local ghost = surface.create_entity({
      name = "tile-ghost",
      inner_name = "stone-path",
      position = { blocked.x + 0.5, blocked.y + 0.5 },
      force = "player",
    })
    runner.assert(ghost and ghost.valid, "could not create the unrelated tile ghost")

    runner.assert(rock.order_deconstruction("player"), "could not mark " .. ROCK .. " for deconstruction")
    runner.assert(not rock.to_be_deconstructed(), "rock deconstruction was not cancelled")

    local ghost_names = {}
    for _, queued_ghost in pairs(tile_ghosts(surface, blocked)) do
      if queued_ghost.valid then
        ghost_names[queued_ghost.ghost_name] = true
      end
    end
    runner.assert(
      ghost_names[FLOOR],
      "an unrelated tile ghost prevented the " .. FLOOR .. " ghost from being placed"
    )
  end)
end)

runner.test("lunar rock: safe floor leaves deconstruction alone", function()
  with_rock_area(function(surface, center)
    local rock = helpers.entity_at(surface, ROCK, center)
    runner.assert(rock and rock.valid, "could not create " .. ROCK)
    local positions = floor_positions_for_rock(rock)
    set_floor(surface, positions, FLOOR)

    runner.assert(rock.order_deconstruction("player"), "could not mark " .. ROCK .. " for deconstruction")
    runner.assert(rock.to_be_deconstructed(), "rock on a safe floor was unexpectedly cancelled")

    local storage = helpers.funit_call("get_storage")
    runner.assert(
      count_entries(storage.rocks_queued_for_removal) == 0,
      "rock on a safe floor was added to the removal queue"
    )
    for _, position in ipairs(positions) do
      runner.assert(
        not has_floor_ghost(surface, position),
        "safe floor unexpectedly received a " .. FLOOR .. " ghost"
      )
    end
  end)
end)

runner.test("lunar rock: premature re-mark is stopped without duplicating the queue", function()
  with_rock_area(function(surface, center)
    local rock, positions = queue_test_rock(surface, center)
    local before = helpers.funit_call("get_storage")
    local _, before_entry = find_queue_entry(before, surface, rock)
    local before_remaining = table_size(before_entry.remaining)

    runner.assert(
      rock.order_deconstruction("player"),
      "could not re-mark a queued " .. ROCK .. " for deconstruction"
    )
    runner.assert(not rock.to_be_deconstructed(), "premature re-mark was not cancelled")

    local after = helpers.funit_call("get_storage")
    runner.assert(
      count_entries(after.rocks_queued_for_removal) == 1,
      "premature re-mark duplicated the removal queue entry"
    )
    local _, after_entry = find_queue_entry(after, surface, rock)
    runner.assert(after_entry, "premature re-mark removed the removal queue entry")
    runner.assert(
      table_size(after_entry.remaining) == before_remaining,
      "premature re-mark changed the outstanding floor tiles"
    )

    for _, position in ipairs(positions) do
      runner.assert(
        #tile_ghosts(surface, position) == 1,
        "premature re-mark duplicated the tile ghost at ("
          .. tostring(position.x) .. ", " .. tostring(position.y) .. ")"
      )
    end
  end)
end)

runner.test("lunar rock: completing the floor re-marks the rock", function()
  with_rock_area(function(surface, center)
    local rock, positions = queue_test_rock(surface, center)
    local half = math.floor(#positions / 2)
    local first = {}
    local second = {}
    for i, position in ipairs(positions) do
      if i <= half then
        first[#first + 1] = position
      else
        second[#second + 1] = position
      end
    end

    set_floor(surface, first, FLOOR, true)
    runner.assert(
      surface.get_tile(first[1].x, first[1].y).name == FLOOR,
      "test floor tile was not built at ("
        .. tostring(first[1].x) .. ", " .. tostring(first[1].y) .. ")"
    )
    runner.assert(not rock.to_be_deconstructed(), "rock was re-marked before its whole floor was built")
    local partially_built = helpers.funit_call("get_storage")
    local _, partial_entry = find_queue_entry(partially_built, surface, rock)
    runner.assert(partial_entry, "queue entry disappeared before the floor was complete")
    runner.assert(
      table_size(partial_entry.remaining) == #second,
      "queue entry tracks " .. tostring(table_size(partial_entry.remaining))
        .. " unbuilt tiles, expected " .. tostring(#second)
    )

    set_floor(surface, second, FLOOR, true)
    runner.assert(rock.to_be_deconstructed(), "rock was not re-marked after its floor was completed")

    local completed = helpers.funit_call("get_storage")
    runner.assert(
      count_entries(completed.rocks_queued_for_removal) == 0,
      "completed rock floor left an entry in the removal queue"
    )
    runner.assert(
      count_entries(completed.tiles_queued_by_rock_remover[surface.index]) == 0,
      "completed rock floor left entries in the inverted tile map"
    )
  end)
end)

runner.test("lunar rock: losing floor cancels a marked rock without laying ghosts", function()
  with_rock_area(function(surface, center)
    local rock = helpers.entity_at(surface, ROCK, center)
    runner.assert(rock and rock.valid, "could not create " .. ROCK)
    local positions = floor_positions_for_rock(rock)
    set_floor(surface, positions, FLOOR)
    runner.assert(rock.order_deconstruction("player"), "could not mark " .. ROCK .. " for deconstruction")
    runner.assert(rock.to_be_deconstructed(), "rock on a safe floor was unexpectedly cancelled")

    local removed = positions[1]
    set_floor(surface, { removed }, DIRT, true)

    runner.assert(
      not rock.to_be_deconstructed(),
      "rock stayed marked for deconstruction after losing its safe floor"
    )
    local storage = helpers.funit_call("get_storage")
    runner.assert(
      count_entries(storage.rocks_queued_for_removal) == 0,
      "losing floor unexpectedly queued the marked rock for removal"
    )
    for _, position in ipairs(positions) do
      runner.assert(
        not has_floor_ghost(surface, position),
        "losing floor unexpectedly created a replacement tile ghost"
      )
    end
  end)
end)

runner.test("lunar rock: non-Muluna surfaces are ignored", function()
  pcall(helpers.reset_test_areas)
  local surface = helpers.get_nauvis()
  local center = helpers.center(helpers.nauvis_area())
  local area = test_area(center)
  pcall(helpers.clear_area, surface, area)

  local ok, err = pcall(function()
    local rock = helpers.entity_at(surface, ROCK, center)
    runner.assert(rock and rock.valid, "could not create " .. ROCK .. " on Nauvis")
    runner.assert(rock.order_deconstruction("player"), "could not mark Nauvis " .. ROCK .. " for deconstruction")
    runner.assert(rock.to_be_deconstructed(), "Nauvis rock deconstruction was unexpectedly cancelled")

    local storage = helpers.funit_call("get_storage")
    runner.assert(
      count_entries(storage.rocks_queued_for_removal) == 0,
      "Nauvis rock was added to the Muluna removal queue"
    )
  end)

  pcall(helpers.clear_area, surface, area)
  if not ok then
    error(err, 0)
  end
end)

runner.test("lunar rock: destroying a queued rock clears its queue entry", function()
  pcall(helpers.reset_test_areas)
  local surface = helpers.get_muluna()
  local center = helpers.center(helpers.muluna_area())
  local area = test_area(center)
  pcall(helpers.clear_area, surface, area)
  fill_area(surface, area, FLOOR)

  local rock = queue_test_rock(surface, center)
  local before = helpers.funit_call("get_storage")
  local _, entry = find_queue_entry(before, surface, rock)
  runner.assert(entry, "rock was not queued before the destroy test")
  local tracked_position = next(entry.tiles)
  runner.assert(tracked_position, "queued rock has no tracked floor tiles")

  rock.destroy({ raise_destroy = true })

  helpers.wait_until(runner, function()
    local after = helpers.funit_call("get_storage")
    local x, y = string.match(tracked_position, "^(-?%d+):(-?%d+)$")
    runner.assert(x and y, "tracked floor key was not in x:y format")
    return count_entries(after.rocks_queued_for_removal) == 0
      and not after.tiles_queued_by_rock_remover[surface.index]
  end, {
    timeout = 120,
    interval = 10,
    message = "destroyed queued rock was not pruned from the removal queue",
    on_success = function()
      cleanup_area(surface, center)
    end,
    on_failure = function()
      cleanup_area(surface, center)
    end,
  })
end)

runner.test("lunar rock: construction robots deliver stone and sulfur (issue #495)", function()
  pcall(helpers.reset_test_areas)
  local surface = helpers.get_muluna()
  local center = helpers.center(helpers.muluna_area())
  local area = test_area(center)
  pcall(helpers.clear_area, surface, area)
  fill_area(surface, area, FLOOR)

  local old_speed = game.speed
  game.speed = 10
  local rock
  local storage_chest
  local cleanup_done = false

  local function cleanup()
    if cleanup_done then
      return
    end
    cleanup_done = true
    game.speed = old_speed
    cleanup_area(surface, center)
  end

  local setup_ok, setup_err = pcall(function()
    rock = helpers.entity_at(surface, ROCK, center)
    runner.assert(rock and rock.valid, "could not create " .. ROCK)
    local positions = floor_positions_for_rock(rock)
    set_floor(surface, positions, DIRT)

    if not surface.has_global_electric_network then
      surface.create_global_electric_network()
    end

    local energy_interface = helpers.entity_at(
      surface,
      "electric-energy-interface",
      { x = center.x + 12, y = center.y }
    )
    runner.assert(energy_interface and energy_interface.valid, "could not create test power source")
    energy_interface.power_production = 100000000

    local roboport = helpers.entity_at(surface, "roboport", { x = center.x + 15, y = center.y })
    runner.assert(roboport and roboport.valid, "could not create test roboport")
    local provider = helpers.entity_at(
      surface,
      "passive-provider-chest",
      { x = center.x + 18, y = center.y }
    )
    runner.assert(provider and provider.valid, "could not create test provider chest")
    storage_chest = helpers.entity_at(surface, "storage-chest", { x = center.x + 20, y = center.y })
    runner.assert(storage_chest and storage_chest.valid, "could not create test storage chest")

    provider.insert({ name = "stone-crushed", count = 200 })
    local robot_inventory = roboport.get_inventory(defines.inventory.roboport_robot)
    runner.assert(robot_inventory, "test roboport has no robot inventory")
    runner.assert(
      robot_inventory.insert({ name = "construction-robot", count = 20 }) == 20,
      "could not insert construction robots into the test roboport"
    )

    runner.assert(rock.order_deconstruction("player"), "could not mark " .. ROCK .. " for deconstruction")
    runner.assert(not rock.to_be_deconstructed(), "rock deconstruction was not cancelled")
  end)

  if not setup_ok then
    cleanup()
    error(setup_err, 0)
  end

  helpers.wait_until(runner, function()
    if rock.valid then
      return false
    end

    local inventory = storage_chest and storage_chest.valid
      and storage_chest.get_inventory(defines.inventory.chest)
    if not inventory then
      return false
    end
    if inventory.get_item_count("stone") < 20 or inventory.get_item_count("sulfur") < 2 then
      return false
    end

    local center_tile = surface.get_tile(center.x, center.y).name
    if center_tile == FLOOR then
      return false
    end

    runner.assert(
      center_tile == DIRT,
      "robot-built gravel was not removed back to the original floor; tile is " .. tostring(center_tile)
    )
    return true
  end, {
    timeout = 9000,
    interval = 30,
    message = "construction robots did not deliver the rock drops and remove the robot-built gravel (issue #495)",
    on_success = cleanup,
    on_failure = cleanup,
  })
end)
