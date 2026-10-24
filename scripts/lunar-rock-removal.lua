-- Handles deconstruction of Muluna's item-dropping lunar rocks.
--
-- Muluna's natural dirt and sand tiles have destroys_dropped_items = true.
-- Construction robots spill an entity's mining results on the ground before
-- collecting them, so deconstructing a lunar rock over natural terrain used to
-- destroy its stone. When a rock is marked for deconstruction, this module
-- cancels the order, queues the rock, and places crushed stone tile ghosts
-- under and around it. Once every required tile has been built, the rock is
-- marked for deconstruction again. Undoing the original deconstruction order
-- removes the queue entry and any tile ghosts this module created. After the
-- rock is gone and its dropped items are picked up, robot-built gravel is
-- ordered for deconstruction; gravel built by a player is left in place.

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
  storage.rocks_pending_gravel_cleanup = storage.rocks_pending_gravel_cleanup or {}
  storage.rocks_pending_gravel_cleanup_next_index = storage.rocks_pending_gravel_cleanup_next_index or 1
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

local function queue_indices_at(surface_index, x, y)
  local by_surface = storage.tiles_queued_by_rock_remover[surface_index]
  local by_x = by_surface and by_surface[x]
  return by_x and by_x[y] or nil
end

local function ensure_tile_ghost(surface, x, y, force_name)
  local tile = surface.get_tile(x, y)
  if not tile or not tile.prototype.destroys_dropped_items then
    return
  end
  for _, ghost in pairs(tile.get_tile_ghosts(force_name)) do
    if ghost.valid and ghost.ghost_name == REPLACEMENT_TILE then
      return false
    end
  end

  return surface.create_entity({
    name = TILE_GHOST_NAME,
    inner_name = REPLACEMENT_TILE,
    position = { x + 0.5, y + 0.5 },
    force = force_name,
  })
end

local function queue_uses_tile(surface_index, x, y)
  local by_surface = storage.tiles_queued_by_rock_remover[surface_index]
  local by_x = by_surface and by_surface[x]
  local by_y = by_x and by_x[y]
  return by_y ~= nil and next(by_y) ~= nil
end

local function remove_created_ghosts(entry)
  for _, created in pairs(entry.created_ghosts or {}) do
    if not queue_uses_tile(entry.surface_index, created.x, created.y) then
      local ghost = created.ghost
      if ghost and ghost.valid and ghost.ghost_name == REPLACEMENT_TILE then
        ghost.destroy({ raise_destroy = true })
      end
    end
  end
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
  remove_created_ghosts(entry)
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
    created_ghosts = {},
    built_by = {},
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
    local ghost = ensure_tile_ghost(surface, tile.x, tile.y, entry.force)
    if ghost then
      entry.created_ghosts[tile.key] = {
        ghost = ghost,
        x = tile.x,
        y = tile.y,
      }
    end
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

local function create_pending_gravel_cleanup(entry)
  local entity = entry.entity
  if not entity or not entity.valid then
    return
  end

  local surface = entity.surface
  local tiles = {}
  for key, builder in pairs(entry.built_by or {}) do
    if builder == "robot" then
      local created = entry.created_ghosts and entry.created_ghosts[key]
      if created then
        local tile = surface.get_tile(created.x, created.y)
        if tile and tile.name == REPLACEMENT_TILE then
          tiles[#tiles + 1] = { x = created.x, y = created.y }
        end
      end
    end
  end

  if #tiles == 0 then
    return
  end

  local left, right, top, bottom = get_floor_bounds(entity)
  local index = storage.rocks_pending_gravel_cleanup_next_index
  storage.rocks_pending_gravel_cleanup_next_index = index + 1
  storage.rocks_pending_gravel_cleanup[index] = {
    entity = entity,
    surface_index = entry.surface_index,
    force = entry.force,
    area = {
      { left, top },
      { right + 1, bottom + 1 },
    },
    tiles = tiles,
    state = "waiting_rock",
  }
end

local function order_cleanup_tiles(pending)
  local surface = game.surfaces[pending.surface_index]
  if not surface or not surface.valid then
    return {}
  end

  local force = game.forces[pending.force]
  local remaining = {}
  for _, tile_position in pairs(pending.tiles or {}) do
    local tile = surface.get_tile(tile_position.x, tile_position.y)
    if tile and tile.name == REPLACEMENT_TILE then
      if queue_uses_tile(pending.surface_index, tile_position.x, tile_position.y) then
        remaining[#remaining + 1] = tile_position
      elseif force and not tile.to_be_deconstructed(force) then
        tile.order_deconstruction(force)
      end
    end
  end
  return remaining
end

local function process_pending_gravel_cleanup()
  ensure_storage()
  for index, pending in pairs(storage.rocks_pending_gravel_cleanup) do
    local entity = pending.entity
    if pending.state == "waiting_rock" then
      if not entity or not entity.valid then
        pending.state = "waiting_items"
        pending.wait_until = game.tick + 30
      end
    end

    if pending.state == "waiting_items" and game.tick >= (pending.wait_until or 0) then
      local surface = game.surfaces[pending.surface_index]
      if not surface or not surface.valid then
        storage.rocks_pending_gravel_cleanup[index] = nil
      else
        local items = surface.find_entities_filtered({
          name = "item-on-ground",
          area = pending.area,
        })
        local has_items = false
        for _, item in pairs(items) do
          if item.valid then
            has_items = true
            break
          end
        end

        if not has_items then
          local remaining = order_cleanup_tiles(pending)
          if #remaining == 0 then
            storage.rocks_pending_gravel_cleanup[index] = nil
          else
            pending.tiles = remaining
          end
        end
      end
    end
  end
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
    create_pending_gravel_cleanup(entry)
    cleanup_entry(index)
    reissue_deconstruction(entry)
    return
  end

  entry.remaining = {}
  entry.created_ghosts = entry.created_ghosts or {}
  for _, tile in ipairs(unsafe) do
    entry.remaining[tile.key] = { x = tile.x, y = tile.y }
    local ghost = ensure_tile_ghost(surface, tile.x, tile.y, entry.force)
    if ghost then
      entry.created_ghosts[tile.key] = {
        ghost = ghost,
        x = tile.x,
        y = tile.y,
      }
    end
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

local function record_ghost_builders(event, builder)
  if not builder or not event.tile or event.tile.name ~= REPLACEMENT_TILE then
    return
  end

  for _, tile in pairs(event.tiles or {}) do
    local position = tile.position
    local key = tile_key(position.x, position.y)
    local indices = queue_indices_at(event.surface_index, position.x, position.y)
    for index in pairs(indices or {}) do
      local entry = storage.rocks_queued_for_removal[index]
      if entry and entry.created_ghosts and entry.created_ghosts[key] then
        entry.built_by = entry.built_by or {}
        entry.built_by[key] = builder
      end
    end
  end
end

local function on_tiles_changed(event, check_marked_rocks, only_unsafe_tiles, builder)
  ensure_storage()
  prune_invalid_entries()
  local surface = game.surfaces[event.surface_index]
  if not surface or not surface.valid then
    return
  end

  record_ghost_builders(event, builder)

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

local function apply_undo_actions(actions)
  ensure_storage()
  local removed = 0

  for _, action in pairs(actions or {}) do
    local target = action.target
    if target and target.name and ROCK_NAMES[target.name] and target.position then
      local surface_index = action.surface_index
      for index, entry in pairs(storage.rocks_queued_for_removal) do
        local entity = entry.entity
        if
          entity
          and entity.valid
          and entity.name == target.name
          and entity.position.x == target.position.x
          and entity.position.y == target.position.y
          and (not surface_index or entry.surface_index == surface_index)
        then
          cleanup_entry(index)
          removed = removed + 1
          break
        end
      end

      for pending_index, pending in pairs(storage.rocks_pending_gravel_cleanup or {}) do
        local entity = pending.entity
        if
          entity
          and entity.valid
          and entity.name == target.name
          and entity.position.x == target.position.x
          and entity.position.y == target.position.y
          and (not surface_index or pending.surface_index == surface_index)
        then
          order_cleanup_tiles(pending)
          storage.rocks_pending_gravel_cleanup[pending_index] = nil
        end
      end
    end
  end

  return removed
end

if script.active_mods["funit"] then
  Muluna.funit.apply_rock_removal_undo = apply_undo_actions
  Muluna.funit.record_rock_floor_build = function(surface_index, tiles, tile_name, builder)
    record_ghost_builders({
      surface_index = surface_index,
      tiles = tiles,
      tile = { name = tile_name },
    }, builder)
  end
  Muluna.funit.clear_rock_removal_state = function(surface_index)
    for index, entry in pairs(storage.rocks_queued_for_removal or {}) do
      if entry.surface_index == surface_index then
        cleanup_entry(index)
      end
    end
    for index, pending in pairs(storage.rocks_pending_gravel_cleanup or {}) do
      if pending.surface_index == surface_index then
        storage.rocks_pending_gravel_cleanup[index] = nil
      end
    end
    storage.tiles_queued_by_rock_remover = storage.tiles_queued_by_rock_remover or {}
    storage.tiles_queued_by_rock_remover[surface_index] = nil
  end
end

Muluna.events.on_event(Muluna.events.events.on_init(), function()
  ensure_storage()
end)

Muluna.events.on_event(defines.events.on_marked_for_deconstruction, on_marked_for_deconstruction)
Muluna.events.on_event(Muluna.events.events.on_built_tile(), function(event)
  local builder = event.name == defines.events.on_player_built_tile and "player" or "robot"
  on_tiles_changed(event, false, nil, builder)
end)
Muluna.events.on_event(defines.events.script_raised_set_tiles, function(event)
  on_tiles_changed(event, true, true)
end)
Muluna.events.on_event(Muluna.events.events.on_mined_tile(), function(event)
  on_tiles_changed(event, true)
end)
Muluna.events.on_event(defines.events.on_undo_applied, function(event)
  apply_undo_actions(event.actions)
end)
Muluna.events.on_nth_tick(30, process_pending_gravel_cleanup)
Muluna.events.on_nth_tick(60, prune_invalid_entries)
