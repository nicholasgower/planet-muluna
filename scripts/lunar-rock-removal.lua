-- Handles deconstruction of Muluna's item-dropping lunar rocks.
--
-- Muluna's natural dirt and sand tiles have destroys_dropped_items = true.
-- Construction robots spill an entity's mining results on the ground before
-- collecting them, so deconstructing a lunar rock over natural terrain used to
-- destroy its stone. When a rock is marked for deconstruction, this module
-- cancels the order, queues the rock, and places crushed stone tile ghosts
-- under and around it. Once every required tile has been built, the rock is
-- marked for deconstruction again.

local ROCK_NAMES = {
  ["lunar-rock"] = true,
  ["lunar-huge-rock"] = true,
}

local ROCK_NAME_FILTER = {
  "lunar-rock",
  "lunar-huge-rock",
}

local REPLACEMENT_TILE = "muluna-gravel"
local TILE_GHOST_NAME = "tile-ghost"
local FLOOR_MARGIN = 1
local RECHECK_RADIUS = 6
local WAITING_MESSAGE = { "lunar-rock-removal.waiting-for-floor" }

local function ensure_storage()
  storage.rocks_queued_for_removal = storage.rocks_queued_for_removal or {}
  storage.tiles_queued_by_rock_remover = storage.tiles_queued_by_rock_remover or {}
  storage.rocks_queued_for_removal_next_index = storage.rocks_queued_for_removal_next_index or 1
end

local function tile_key(x, y)
  return tostring(x) .. ":" .. tostring(y)
end

local function player_from_index(player_index)
  if not player_index then
    return nil
  end
  local player = game.get_player(player_index)
  if player and player.valid then
    return player
  end
  return nil
end

local function is_eligible_rock(entity)
  if not entity or not entity.valid then
    return false
  end
  if entity.type ~= "simple-entity" or not ROCK_NAMES[entity.name] then
    return false
  end
  local surface = entity.surface
  if not surface or not surface.valid then
    return false
  end
  local planet = surface.planet
  return planet ~= nil and planet.name == "muluna"
end

local function get_floor_bounds(entity)
  local bounding_box = entity.bounding_box

  -- Rocks are placeable off-grid, so a fractional position can make the raw
  -- bounding box clip into an extra tile by a few hundredths of a tile. Use the
  -- rock's nominal whole-tile footprint instead; this keeps a huge rock at
  -- 3x3 floor tiles (5x5 with the margin) wherever the generator placed it.
  local tile_width = math.max(1, math.ceil(bounding_box.right_bottom.x - bounding_box.left_top.x))
  local tile_height = math.max(1, math.ceil(bounding_box.right_bottom.y - bounding_box.left_top.y))
  local center_x = (bounding_box.left_top.x + bounding_box.right_bottom.x) / 2
  local center_y = (bounding_box.left_top.y + bounding_box.right_bottom.y) / 2
  local footprint_left = math.floor(center_x - (tile_width - 1) / 2)
  local footprint_top = math.floor(center_y - (tile_height - 1) / 2)

  return footprint_left - FLOOR_MARGIN,
    footprint_left + tile_width - 1 + FLOOR_MARGIN,
    footprint_top - FLOOR_MARGIN,
    footprint_top + tile_height - 1 + FLOOR_MARGIN
end

local function analyse_floor(entity)
  local surface = entity.surface
  local left, right, top, bottom = get_floor_bounds(entity)
  local unsafe = {}
  local all_safe = true

  for x = left, right do
    for y = top, bottom do
      local tile = surface.get_tile(x, y)
      if not tile or tile.prototype.destroys_dropped_items then
        all_safe = false
        unsafe[#unsafe + 1] = {
          x = x,
          y = y,
          key = tile_key(x, y),
        }
      end
    end
  end

  return unsafe, all_safe
end

local function find_queue_index(entity)
  if not entity or not entity.valid then
    return nil
  end

  for index, entry in pairs(storage.rocks_queued_for_removal or {}) do
    local queued = entry.entity
    if queued and queued.valid then
      if queued == entity then
        return index
      end
      if
        entry.surface_index == entity.surface_index
        and entry.position
        and entry.position.x == entity.position.x
        and entry.position.y == entity.position.y
      then
        return index
      end
    end
  end

  return nil
end

local function add_inverted_tile(surface_index, x, y, index)
  local by_surface = storage.tiles_queued_by_rock_remover[surface_index]
  if not by_surface then
    by_surface = {}
    storage.tiles_queued_by_rock_remover[surface_index] = by_surface
  end

  local by_x = by_surface[x]
  if not by_x then
    by_x = {}
    by_surface[x] = by_x
  end

  local by_y = by_x[y]
  if not by_y then
    by_y = {}
    by_x[y] = by_y
  end

  by_y[index] = true
end

local function remove_inverted_tile(surface_index, x, y, index)
  local by_surface = storage.tiles_queued_by_rock_remover[surface_index]
  if not by_surface then
    return
  end
  local by_x = by_surface[x]
  if not by_x then
    return
  end
  local by_y = by_x[y]
  if not by_y then
    return
  end

  by_y[index] = nil
  if next(by_y) == nil then
    by_x[y] = nil
  end
  if next(by_x) == nil then
    by_surface[x] = nil
  end
  if next(by_surface) == nil then
    storage.tiles_queued_by_rock_remover[surface_index] = nil
  end
end

local function ensure_tile_ghost(surface, x, y, force_name)
  local tile = surface.get_tile(x, y)
  if not tile or not tile.prototype.destroys_dropped_items then
    return
  end
  for _, ghost in pairs(tile.get_tile_ghosts(force_name)) do
    if ghost.valid and ghost.ghost_name == REPLACEMENT_TILE then
      return
    end
  end

  surface.create_entity({
    name = TILE_GHOST_NAME,
    inner_name = REPLACEMENT_TILE,
    position = { x + 0.5, y + 0.5 },
    force = force_name,
  })
end

local function cleanup_entry(index)
  local entry = storage.rocks_queued_for_removal[index]
  if not entry then
    return
  end

  for _, tile in pairs(entry.tiles or {}) do
    remove_inverted_tile(entry.surface_index, tile.x, tile.y, index)
  end
  storage.rocks_queued_for_removal[index] = nil
end

local function find_deconstruction_force(entity)
  if not entity or not entity.valid then
    return nil
  end

  for _, force in pairs(game.forces) do
    if entity.is_registered_for_deconstruction(force) then
      return force
    end
  end

  local last_user = entity.last_user
  if last_user and last_user.valid then
    return last_user.force
  end

  return entity.force
end

local function cancel_entity_deconstruction(entity, force_name, player)
  if not entity or not entity.valid then
    return
  end
  entity.cancel_deconstruction(force_name or entity.force.name, player)
end

local function cancel_all_deconstruction(entity)
  if not entity or not entity.valid then
    return
  end

  for _, force in pairs(game.forces) do
    if entity.valid and entity.is_registered_for_deconstruction(force) then
      cancel_entity_deconstruction(entity, force.name, nil)
    end
  end
end

local function cancel_marked_rock(entity)
  if not entity or not entity.valid then
    return
  end

  local last_user = entity.last_user
  if last_user and last_user.valid then
    cancel_entity_deconstruction(entity, last_user.force.name, last_user)
  end

  if entity.valid and entity.to_be_deconstructed() then
    cancel_all_deconstruction(entity)
  end
end

local function warn_waiting_for_floor(entity, player, force_name)
  if player and player.valid then
    player.create_local_flying_text({
      text = WAITING_MESSAGE,
      create_at_cursor = true,
    })
  elseif entity and entity.valid then
    local force = game.forces[force_name] or entity.force
    force.print(WAITING_MESSAGE)
  end
end

local function queue_rock(entity, force_name, player_index)
  local surface = entity.surface
  local unsafe, all_safe = analyse_floor(entity)
  if all_safe then
    return nil
  end

  local index = storage.rocks_queued_for_removal_next_index
  storage.rocks_queued_for_removal_next_index = index + 1

  local entry = {
    entity = entity,
    surface_index = surface.index,
    position = { x = entity.position.x, y = entity.position.y },
    force = force_name or entity.force.name,
    player_index = player_index,
    tiles = {},
    remaining = {},
  }
  storage.rocks_queued_for_removal[index] = entry

  local left, right, top, bottom = get_floor_bounds(entity)
  for x = left, right do
    for y = top, bottom do
      local key = tile_key(x, y)
      entry.tiles[key] = { x = x, y = y }
      add_inverted_tile(surface.index, x, y, index)
    end
  end

  for _, tile in ipairs(unsafe) do
    entry.remaining[tile.key] = { x = tile.x, y = tile.y }
    ensure_tile_ghost(surface, tile.x, tile.y, entry.force)
  end

  return index
end

local function reissue_deconstruction(entry)
  local entity = entry.entity
  if not entity or not entity.valid then
    return
  end

  local force = game.forces[entry.force] or entity.force
  local player = player_from_index(entry.player_index)
  entity.order_deconstruction(force, player)
end

local function refresh_queue_entry(index)
  local entry = storage.rocks_queued_for_removal[index]
  if not entry then
    return
  end

  local entity = entry.entity
  if not entity or not entity.valid then
    cleanup_entry(index)
    return
  end

  local surface = entity.surface
  if not surface or not surface.valid then
    cleanup_entry(index)
    return
  end

  local unsafe, all_safe = analyse_floor(entity)
  if all_safe then
    cleanup_entry(index)
    reissue_deconstruction(entry)
    return
  end

  entry.remaining = {}
  for _, tile in ipairs(unsafe) do
    entry.remaining[tile.key] = { x = tile.x, y = tile.y }
    ensure_tile_ghost(surface, tile.x, tile.y, entry.force)
  end
end

local function refresh_queue_entries_at(surface_index, position)
  local by_surface = storage.tiles_queued_by_rock_remover[surface_index]
  if not by_surface then
    return
  end
  local by_x = by_surface[position.x]
  if not by_x then
    return
  end
  local by_y = by_x[position.y]
  if not by_y then
    return
  end

  local indices = {}
  for index in pairs(by_y) do
    indices[#indices + 1] = index
  end
  for _, index in ipairs(indices) do
    refresh_queue_entry(index)
  end
end

local function cancel_marked_rocks_near(surface, position)
  local radius = RECHECK_RADIUS
  local rocks = surface.find_entities_filtered({
    area = {
      { position.x - radius, position.y - radius },
      { position.x + radius + 1, position.y + radius + 1 },
    },
    name = ROCK_NAME_FILTER,
    to_be_deconstructed = true,
  })

  for _, rock in pairs(rocks) do
    if is_eligible_rock(rock) then
      local _, all_safe = analyse_floor(rock)
      if not all_safe then
        cancel_marked_rock(rock)
      end
    end
  end
end

local function prune_invalid_entries()
  ensure_storage()
  for index, entry in pairs(storage.rocks_queued_for_removal) do
    if not entry.entity or not entry.entity.valid then
      cleanup_entry(index)
    end
  end
end

local function on_tiles_changed(event, check_marked_rocks, only_unsafe_tiles)
  ensure_storage()
  prune_invalid_entries()
  local surface = game.surfaces[event.surface_index]
  if not surface or not surface.valid then
    return
  end

  for _, tile in pairs(event.tiles or {}) do
    local position = tile.position
    refresh_queue_entries_at(surface.index, position)

    if check_marked_rocks then
      local current = surface.get_tile(position.x, position.y)
      if not only_unsafe_tiles or (current and current.prototype.destroys_dropped_items) then
        cancel_marked_rocks_near(surface, position)
      end
    end
  end
end

local function on_marked_for_deconstruction(event)
  ensure_storage()
  prune_invalid_entries()
  local entity = event.entity
  if not is_eligible_rock(entity) then
    return
  end

  local player = player_from_index(event.player_index)
  local deconstruction_force = player and player.force or find_deconstruction_force(entity)
  local force_name = deconstruction_force and deconstruction_force.name or entity.force.name
  local existing_index = find_queue_index(entity)

  if existing_index then
    cancel_entity_deconstruction(entity, force_name, player)
    if entity.valid and entity.to_be_deconstructed() then
      cancel_all_deconstruction(entity)
    end
    warn_waiting_for_floor(entity, player, force_name)
    if existing_index then
      refresh_queue_entry(existing_index)
    end
    return
  end

  local _, all_safe = analyse_floor(entity)
  if all_safe then
    return
  end

  cancel_entity_deconstruction(entity, force_name, player)
  if entity.valid and entity.to_be_deconstructed() then
    cancel_all_deconstruction(entity)
  end
  queue_rock(entity, force_name, event.player_index)
end

Muluna.events.on_event(Muluna.events.events.on_init(), function()
  ensure_storage()
end)

Muluna.events.on_event(defines.events.on_marked_for_deconstruction, on_marked_for_deconstruction)
Muluna.events.on_event(Muluna.events.events.on_built_tile(), function(event)
  on_tiles_changed(event, false)
end)
Muluna.events.on_event(defines.events.script_raised_set_tiles, function(event)
  on_tiles_changed(event, true, true)
end)
Muluna.events.on_event(Muluna.events.events.on_mined_tile(), function(event)
  on_tiles_changed(event, true)
end)
Muluna.events.on_nth_tick(60, prune_invalid_entries)
