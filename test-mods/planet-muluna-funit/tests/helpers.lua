-- Shared helpers for the Muluna FUnit runtime suites.
local helpers = {}

local TEST_AREA_MULUNA = {
  left_top = { -12000, -12000 },
  right_bottom = { -11800, -11800 },
}

local TEST_AREA_NAUVIS = {
  left_top = { -12000, -12000 },
  right_bottom = { -11800, -11800 },
}

function helpers.get_muluna()
  local muluna = game.planets["muluna"]
  assert(muluna, "Muluna planet prototype is missing")
  if not muluna.surface then
    muluna.create_surface()
  end
  return muluna.surface
end

function helpers.get_nauvis()
  return game.planets["nauvis"].surface
end

function helpers.generate_area(surface, area)
  local center = {
    x = (area.left_top[1] + area.right_bottom[1]) / 2,
    y = (area.left_top[2] + area.right_bottom[2]) / 2,
  }
  surface.request_to_generate_chunks(center, 4)
  surface.force_generate_chunk_requests()
end

function helpers.clear_area(surface, area)
  if not surface or not surface.valid then return end
  local entities = surface.find_entities_filtered({ area = area })
  for _, entity in pairs(entities) do
    if entity.valid then
      entity.destroy({ raise_destroy = true })
    end
  end
end

function helpers.reset_test_areas()
  local muluna = helpers.get_muluna()
  helpers.generate_area(muluna, TEST_AREA_MULUNA)
  helpers.clear_area(muluna, TEST_AREA_MULUNA)
  local nauvis = helpers.get_nauvis()
  if nauvis then
    helpers.generate_area(nauvis, TEST_AREA_NAUVIS)
    helpers.clear_area(nauvis, TEST_AREA_NAUVIS)
  end
end

function helpers.muluna_area()
  return TEST_AREA_MULUNA
end

function helpers.nauvis_area()
  return TEST_AREA_NAUVIS
end

function helpers.center(area)
  return {
    x = (area.left_top[1] + area.right_bottom[1]) / 2,
    y = (area.left_top[2] + area.right_bottom[2]) / 2,
  }
end

function helpers.entity_at(surface, name, position, extra)
  local entity_data = {
    name = name,
    position = position,
    force = "player",
    raise_built = true,
  }
  for key, value in pairs(extra or {}) do
    entity_data[key] = value
  end
  return surface.create_entity(entity_data)
end

function helpers.find_entities(surface, name, area)
  return surface.find_entities_filtered({
    name = name,
    area = area or TEST_AREA_MULUNA,
  })
end

function helpers.destroy_named(surface, name, area)
  for _, entity in pairs(helpers.find_entities(surface, name, area)) do
    if entity.valid then
      entity.destroy({ raise_destroy = true })
    end
  end
end

function helpers.storage()
  return remote.call("muluna", "get_storage")
end

function helpers.funit_call(name, ...)
  return remote.call("muluna_funit", name, ...)
end

---Replace tiles and optionally raise the documented script tile-change event.
---
---`set_tiles` has five positional arguments and raises `script_raised_set_tiles`
---inconsistently in the headless test harness. This helper keeps the argument
---order in one place and raises the event after the tiles have been applied so
---listeners observe the final world state.
---@param surface LuaSurface
---@param tiles Tile[]
---@param options table|nil
function helpers.set_tiles(surface, tiles, options)
  options = options or {}
  local correct_tiles = options.correct_tiles ~= false
  local remove_colliding_entities = options.remove_colliding_entities
  if remove_colliding_entities == nil then
    remove_colliding_entities = false
  end
  local remove_colliding_decoratives = options.remove_colliding_decoratives ~= false

  surface.set_tiles(
    tiles,
    correct_tiles,
    remove_colliding_entities,
    remove_colliding_decoratives,
    false
  )

  if options.raise_event then
    script.raise_event(defines.events.script_raised_set_tiles, {
      surface_index = surface.index,
      tiles = tiles,
    })
  end
end

---Poll a predicate on a tick interval until it succeeds or the timeout expires.
---
---The predicate may call `runner.assert` for an irreversible failure. Optional
---`on_success` and `on_failure` callbacks run exactly once and are useful for
---cleaning up entities in asynchronous tests.
---@param runner table FUnit test runner
---@param predicate fun(): boolean
---@param options table|nil
function helpers.wait_until(runner, predicate, options)
  options = options or {}
  local timeout = math.max(1, options.timeout or 600)
  local interval = math.max(1, options.interval or 30)
  local message = options.message or "condition was not met"
  local deadline = game.tick + timeout

  local function check()
    local ok, err = pcall(function()
      if predicate() then
        if options.on_success then
          options.on_success()
        end
        return
      end

      if game.tick >= deadline then
        runner.assert(false, message .. " (timeout: " .. tostring(timeout) .. " ticks)")
      end

      runner.after_n_ticks_do(interval, check)
    end)

    if not ok then
      if options.on_failure then
        pcall(options.on_failure)
      end
      error(err, 0)
    end
  end

  runner.after_n_ticks_do(1, check)
end

return helpers
