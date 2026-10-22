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

return helpers
