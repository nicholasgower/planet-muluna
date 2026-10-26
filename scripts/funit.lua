-- Test-only remote interface used by the FUnit scenario.
--
-- This file is required only when the funit mod is active. It is inert in
-- normal play and exposes a few internal helpers that cannot be reached through
-- regular game events in a headless test.
local Public = {}

local function stage()
  return Muluna.funit
end

remote.add_interface("muluna_funit", {
  get_storage = function()
    return storage
  end,

  get_constants = function()
    return prototypes.mod_data["muluna-constants"].data
  end,

  get_telescope_data = function(unit_number)
    return storage.telescopes and storage.telescopes[unit_number]
  end,

  update_telescope = function(unit_number)
    local telescope = storage.telescopes and storage.telescopes[unit_number]
    if telescope then
      Muluna.update_telescope_daytime(telescope)
    end
  end,

  get_telescope_signals = function(unit_number)
    local telescope = storage.telescopes and storage.telescopes[unit_number]
    if not telescope then return nil end
    local combinator = telescope["constant-combinator"]
    if not combinator or not combinator.valid then return nil end
    return stage().get_telescope_combinator_signals(combinator.surface, combinator.force, telescope)
  end,

  get_telescope_probability = function(pollution, quality_level)
    return Muluna.get_telescope_probability(pollution, { level = quality_level or 0 })
  end,

  get_telescope_min_pollution = function(quality_level)
    return Muluna.get_telescope_min_pollution({ level = quality_level or 0 })
  end,

  get_telescope_max_pollution = function(quality_level)
    return Muluna.get_telescope_max_pollution({ level = quality_level or 0 })
  end,

  get_state_integer = function(state)
    return stage().get_state_integer(state)
  end,

  get_time_to_next_asteroid_check = function(unit_number)
    local telescope = storage.telescopes and storage.telescopes[unit_number]
    if not telescope then return nil end
    return stage().get_time_to_next_asteroid_check(telescope)
  end,

  short_update_roboport = function(unit_number)
    local entry = storage.burner_roboports and storage.burner_roboports[unit_number]
    local refueler = entry and entry.refueler
    if refueler and refueler.valid then
      stage().short_update_roboport(refueler)
    end
  end,

  set_cheat_mode = function(force_name)
    return stage().set_cheat_mode(game.forces[force_name or "player"])
  end,

  get_burner_roboport_data = function(unit_number)
    return storage.burner_roboports and storage.burner_roboports[unit_number]
  end,

  get_nav_scan_area = function(unit_number)
    local beacon = storage.nav_beacons and storage.nav_beacons[unit_number]
    if not beacon or not beacon.valid then return nil end
    return stage().get_nav_scan_area(beacon)
  end,

  set_nav_beacon_enabled = function(unit_number, enabled)
    local settings = storage.nav_beacons_other and storage.nav_beacons_other[unit_number]
    local beacon = storage.nav_beacons and storage.nav_beacons[unit_number]
    if not settings or not beacon or not beacon.valid then return false end
    settings.gui = settings.gui or {}
    settings.gui.enabled = enabled
    Muluna.update_nav_beacon_status(beacon)
    return true
  end,

  get_heat_assembling_machine_data = function(unit_number)
    return storage.heat_assembling_machines and storage.heat_assembling_machines[unit_number]
  end,

  get_compound_blueprint_tags = function(unit_number)
    return stage().capture_compound_blueprint_tags(unit_number)
  end,

  transform_compound_offset = function(offset, direction, flip_horizontal, flip_vertical)
    return stage().transform_compound_offset(offset, direction, flip_horizontal, flip_vertical)
  end,

  get_walking_controller_branch = function(input_method)
    return stage().is_game_controller_input(input_method)
  end,

  apply_rock_removal_undo = function(actions)
    return stage().apply_rock_removal_undo(actions)
  end,

  record_rock_floor_build = function(surface_index, tiles, tile_name, builder)
    return stage().record_rock_floor_build(surface_index, tiles, tile_name, builder)
  end,

  select_rock_replacement_tile = function(
    contents,
    crushed_stone_count,
    required_count,
    in_stationary_roboport_range,
    is_character
  )
    return stage().select_rock_replacement_tile(
      contents,
      crushed_stone_count,
      required_count,
      in_stationary_roboport_range,
      is_character
    )
  end,

  queue_rock_with_replacement = function(entity, replacement_tile, force_name)
    return stage().queue_rock_with_replacement(entity, replacement_tile, force_name)
  end,

  has_stationary_roboport_coverage = function(surface_index, force_name, position)
    return stage().has_stationary_roboport_coverage(surface_index, force_name, position)
  end,

  clear_rock_removal_state = function(surface_index)
    return stage().clear_rock_removal_state(surface_index)
  end,
})

return Public
