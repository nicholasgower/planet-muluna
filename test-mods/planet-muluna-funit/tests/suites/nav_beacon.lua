-- Runtime tests for satellite radar / nav beacons.
--
-- Nav beacons are only registered when a radar is built on a space platform
-- (`surface.platform ~= nil`). Planet placement is deliberately inert in
-- scripts/nav-beacon.lua. The headless FUnit scenario has no players, but it
-- can create space platforms and script-build radars, which exercises the real
-- registration, update-tick and destruction handlers.
local runner = require("__funit__.test_runner")
local helpers = require("__planet-muluna-funit__.tests.helpers")

local RADAR = "muluna-satellite-radar"
local STARTER_PACK = "space-platform-starter-pack"

local function count_entries(tbl)
  local count = 0
  for _ in pairs(tbl or {}) do
    count = count + 1
  end
  return count
end

local function nav_keys()
  local keys = {}
  for key in pairs(helpers.storage().nav_beacons or {}) do
    keys[key] = true
  end
  return keys
end

local function snapshot()
  local storage = helpers.storage()
  return {
    nav_beacons = count_entries(storage.nav_beacons),
    nav_surfaces = count_entries(storage.nav_surfaces),
    beaconed_platforms = count_entries(storage.beaconed_platforms),
    nav_beacons_other = count_entries(storage.nav_beacons_other),
    has_nav_beacons = storage.has_nav_beacons,
  }
end

local function assert_snapshot(before, message)
  local after = snapshot()
  runner.assert(
    after.nav_beacons == before.nav_beacons,
    message
      .. ": storage.nav_beacons changed from "
      .. before.nav_beacons
      .. " to "
      .. after.nav_beacons
  )
  runner.assert(
    after.nav_surfaces == before.nav_surfaces,
    message
      .. ": storage.nav_surfaces changed from "
      .. before.nav_surfaces
      .. " to "
      .. after.nav_surfaces
  )
  runner.assert(
    after.beaconed_platforms == before.beaconed_platforms,
    message
      .. ": storage.beaconed_platforms changed from "
      .. before.beaconed_platforms
      .. " to "
      .. after.beaconed_platforms
  )
  runner.assert(
    after.nav_beacons_other == before.nav_beacons_other,
    message
      .. ": storage.nav_beacons_other changed from "
      .. before.nav_beacons_other
      .. " to "
      .. after.nav_beacons_other
  )
  runner.assert(
    after.has_nav_beacons == before.has_nav_beacons,
    message
      .. ": storage.has_nav_beacons changed from "
      .. tostring(before.has_nav_beacons)
      .. " to "
      .. tostring(after.has_nav_beacons)
  )
  return after
end

local function clean_areas()
  -- Remove any temporary surfaces or platforms left by an earlier failed run.
  local stale_surfaces = {}
  for _, surface in pairs(game.surfaces) do
    if surface.name:find("^funit%-nav%-", 1) then
      table.insert(stale_surfaces, surface)
    end
  end
  for _, surface in pairs(stale_surfaces) do
    pcall(game.delete_surface, surface)
  end

  local stale_platforms = {}
  for _, force in pairs(game.forces) do
    for _, platform in pairs(force.platforms) do
      if platform.name:find("^funit%-nav%-", 1) then
        table.insert(stale_platforms, platform)
      end
    end
  end
  for _, platform in pairs(stale_platforms) do
    pcall(function()
      platform.destroy()
    end)
  end

  pcall(helpers.reset_test_areas)
end

local function with_clean_areas(fn)
  clean_areas()
  local ok, err = pcall(fn)
  clean_areas()
  if not ok then
    error(err, 0)
  end
end

local function create_platform(name)
  runner.assert(
    prototypes.item[STARTER_PACK],
    STARTER_PACK .. " item prototype is missing; cannot create a space platform"
  )
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

local function build_platform_radar(platform)
  local before = nav_keys()
  local position = { x = 0, y = 0 }

  platform.surface.create_entity({
    name = RADAR,
    position = position,
    force = "player",
    raise_built = true,
  })

  local storage = helpers.storage()
  local new_keys = {}
  for key in pairs(storage.nav_beacons or {}) do
    if not before[key] then
      new_keys[#new_keys + 1] = key
    end
  end
  table.sort(new_keys)
  runner.assert(
    #new_keys == 1,
    "expected exactly one new nav beacon registration on "
      .. platform.name
      .. ", got "
      .. #new_keys
  )

  local key = new_keys[1]
  local beacon = storage.nav_beacons[key]
  runner.assert(beacon and beacon.valid, "registered nav beacon " .. tostring(key) .. " is not valid")
  runner.assert(beacon.name == RADAR, "registered nav beacon is not " .. RADAR)
  runner.assert(beacon.unit_number == key, "nav beacon storage key does not match its unit number")
  runner.assert(
    beacon.surface.platform and beacon.surface.platform.index == platform.index,
    "registered nav beacon is not on platform " .. platform.name
  )
  local connectors = beacon.get_wire_connectors(true)
  runner.assert(
    connectors[defines.wire_connector_id.circuit_red],
    "registered nav beacon has no red circuit wire connector"
  )
  runner.assert(
    connectors[defines.wire_connector_id.circuit_green],
    "registered nav beacon has no green circuit wire connector"
  )
  return key, beacon
end

local function assert_nav_status(beacon, enabled, platform)
  local status = beacon.custom_status
  runner.assert(status, "nav beacon has no custom status")
  if enabled then
    runner.assert(
      status.diode == defines.entity_status_diode.green,
      "enabled nav beacon status should have a green diode"
    )
    local location = platform.space_location
    if location then
      runner.assert(
        status.label and status.label[1] == "custom-status.muluna-satellite-radar-looking-at",
        "enabled nav beacon status should be the looking-at status"
      )
      runner.assert(
        status.label[2] and status.label[2][1] == "space-location-name." .. location.name,
        "enabled nav beacon status does not name the platform's space location"
      )
    else
      runner.assert(
        status.label and status.label[1] == "custom-status.muluna-satellite-radar-looking-at-deep-space",
        "enabled nav beacon in transit should use the deep-space status"
      )
    end
    runner.assert(
      beacon.disabled_by_script == false,
      "enabled nav beacon should not be disabled_by_script"
    )
  else
    runner.assert(
      status.diode == defines.entity_status_diode.red,
      "disabled nav beacon status should have a red diode"
    )
    runner.assert(
      status.label and status.label[1] == "custom-status.muluna-satellite-radar-scanning-disabled",
      "disabled nav beacon status should be the scanning-disabled status"
    )
    runner.assert(
      beacon.disabled_by_script == true,
      "disabled nav beacon should be disabled_by_script"
    )
  end
end

local function assert_planet_radar_is_inert(surface, area, expected_planet)
  local center = helpers.center(area)
  local position = { x = center.x - 20, y = center.y - 20 }
  local before = snapshot()

  local radar = helpers.entity_at(surface, RADAR, position)
  runner.assert(radar and radar.valid, "could not create " .. RADAR .. " on " .. expected_planet)
  runner.assert(radar.name == RADAR, "created entity is not " .. RADAR)
  runner.assert(
    radar.surface.planet and radar.surface.planet.name == expected_planet,
    "radar was created on the wrong planet: " .. tostring(radar.surface.planet and radar.surface.planet.name)
  )

  -- The radar prototype has a gravity surface condition (0..0). A real planet
  -- build is therefore rejected even though script creation succeeds.
  local placeable = surface.can_place_entity({
    name = RADAR,
    position = position,
    force = "player",
  })
  runner.assert(
    not placeable,
    "surface conditions unexpectedly allow " .. RADAR .. " on " .. expected_planet
  )

  local storage = helpers.storage()
  runner.assert(
    storage.nav_beacons[radar.unit_number] == nil,
    "planet radar was registered in storage.nav_beacons (unit_number "
      .. tostring(radar.unit_number)
      .. ")"
  )
  runner.assert(
    storage.nav_surfaces[radar.unit_number] == nil,
    "planet radar was registered in storage.nav_surfaces"
  )
  assert_snapshot(before, "building " .. RADAR .. " on " .. expected_planet)

  local ok, err = pcall(function()
    radar.destroy({ raise_destroy = true })
  end)
  runner.assert(ok, "destroying " .. RADAR .. " on " .. expected_planet .. " errored: " .. tostring(err))
  runner.assert(not radar.valid, "radar still valid after destroy")
  assert_snapshot(before, "destroying " .. RADAR .. " on " .. expected_planet)
end

runner.test("nav beacon storage tables are initialized", function()
  local storage = helpers.storage()
  runner.assert(type(storage.nav_beacons) == "table", "storage.nav_beacons is not a table")
  runner.assert(type(storage.nav_surfaces) == "table", "storage.nav_surfaces is not a table")
  runner.assert(type(storage.beaconed_platforms) == "table", "storage.beaconed_platforms is not a table")
  runner.assert(type(storage.nav_beacons_other) == "table", "storage.nav_beacons_other is not a table")
  runner.assert(type(storage.has_nav_beacons) == "boolean", "storage.has_nav_beacons is not a boolean")
end)

runner.test("radar on Muluna is not registered as a nav beacon", function()
  with_clean_areas(function()
    assert_planet_radar_is_inert(helpers.get_muluna(), helpers.muluna_area(), "muluna")
  end)
end)

runner.test("radar on Nauvis is not registered as a nav beacon", function()
  with_clean_areas(function()
    assert_planet_radar_is_inert(helpers.get_nauvis(), helpers.nauvis_area(), "nauvis")
  end)
end)

runner.test("space platform radar registers and survives the nav beacon update tick", function()
  clean_areas()
  local before = snapshot()
  local platform = create_platform("funit-nav-platform-single")

  local key, beacon = build_platform_radar(platform)
  local storage = helpers.storage()
  runner.assert(storage.has_nav_beacons == true, "building a platform radar did not set has_nav_beacons")
  runner.assert(
    storage.nav_surfaces[key] ~= nil,
    "registered nav beacon has no entry in storage.nav_surfaces"
  )
  if platform.space_location then
    runner.assert(
      storage.nav_surfaces[key] == platform.space_location,
      "storage.nav_surfaces does not match the platform's space location"
    )
  end
  local platform_beacon = storage.beaconed_platforms[platform.index]
  runner.assert(platform_beacon, "platform is not recorded in storage.beaconed_platforms")
  runner.assert(
    platform_beacon.unit_number == key,
    "storage.beaconed_platforms points at the wrong entity"
  )
  local beacon_settings = storage.nav_beacons_other[key]
  runner.assert(beacon_settings, "registered nav beacon has no settings entry")
  runner.assert(
    beacon_settings.gui and beacon_settings.gui.enabled == true,
    "registered nav beacon is not enabled by default"
  )

  local unit_number = beacon.unit_number
  local scan_area = helpers.funit_call("get_nav_scan_area", unit_number)
  runner.assert(
    scan_area == 100,
    "nav scan size should use scan_area (100), got " .. tostring(scan_area)
      .. "; the runtime scan path may be using energy_per_scan"
  )
  local energy_before
  local energy_is_writable = pcall(function()
    beacon.energy = 1234567
    energy_before = beacon.energy
  end)

  -- The update handler runs every nav-beacon-update-ticks (60 by default).
  -- There are no players to scan for, so a registered beacon must stay valid
  -- and keep its energy. Wait for the real interval instead of a hardcoded
  -- tick count so this keeps testing the update path if the setting changes.
  local update_ticks = math.floor(settings.startup["nav-beacon-update-ticks"].value)
  runner.after_n_ticks_do(update_ticks + 5, function()
    local callback_ok, callback_err = pcall(function()
      local current = helpers.storage()
      local current_beacon = current.nav_beacons[unit_number]
      runner.assert(current_beacon, "the update tick removed the registered nav beacon")
      runner.assert(current_beacon.valid, "the registered nav beacon became invalid during the update tick")
      runner.assert(current.has_nav_beacons == true, "the update tick cleared has_nav_beacons")
      if energy_is_writable then
        -- The radar has a 1 MW passive draw, but no player was in remote view
        -- to trigger a scan. The drain must stay far below one scan's cost
        -- (platform-power-consumption MJ in this profile).
        local scan_cost = settings.startup["platform-power-consumption"].value * 1e6
        runner.assert(
          energy_before - current_beacon.energy < scan_cost / 2,
          "nav beacon spent scan-level energy without a player to drive a scan: "
            .. tostring(energy_before)
            .. " -> "
            .. tostring(current_beacon.energy)
        )
      end

      local destroy_ok, destroy_err = pcall(function()
        current_beacon.destroy({ raise_destroy = true })
      end)
      runner.assert(destroy_ok, "destroying the platform nav beacon errored: " .. tostring(destroy_err))
      local after = helpers.storage()
      runner.assert(after.nav_beacons[unit_number] == nil, "destroyed nav beacon is still registered")
      runner.assert(after.nav_surfaces[unit_number] == nil, "destroyed nav beacon still has a nav surface")
      runner.assert(
        after.beaconed_platforms[platform.index] == nil,
        "destroyed nav beacon still has a beaconed platform entry"
      )
      assert_snapshot(before, "registering and destroying a platform nav beacon")
    end)

    destroy_platform(platform)
    clean_areas()
    if not callback_ok then
      error(callback_err, 0)
    end
  end)
end)

runner.test("nav beacon status follows the tile revealing setting", function()
  clean_areas()
  local platform = create_platform("funit-nav-platform-status")
  local key, beacon = build_platform_radar(platform)

  assert_nav_status(beacon, true, platform)

  local disable_ok = helpers.funit_call("set_nav_beacon_enabled", key, false)
  runner.assert(disable_ok, "could not disable the nav beacon")
  assert_nav_status(beacon, false, platform)

  local enable_ok = helpers.funit_call("set_nav_beacon_enabled", key, true)
  runner.assert(enable_ok, "could not re-enable the nav beacon")
  assert_nav_status(beacon, true, platform)

  local destroy_ok, destroy_err = pcall(function()
    beacon.destroy({ raise_destroy = true })
  end)
  runner.assert(destroy_ok, "destroying the status-test nav beacon errored: " .. tostring(destroy_err))
  runner.assert(helpers.storage().nav_beacons[key] == nil, "destroyed status-test nav beacon is still registered")

  destroy_platform(platform)
  clean_areas()
end)

runner.test("destroying the lower unit number of two nav beacons leaves the other registered", function()
  -- Regression for sparse, unit-number-keyed beacon storage. Unit numbers are
  -- not sequential, so removing the lower key must not remove or invalidate
  -- the higher-keyed beacon.
  clean_areas()
  local platform_lower = create_platform("funit-nav-platform-lower")
  local platform_upper = create_platform("funit-nav-platform-upper")

  local lower_key = build_platform_radar(platform_lower)
  -- Consume a unit number between the two beacons so the storage keys are
  -- unambiguously sparse, not merely sequential.
  local filler = helpers.entity_at(helpers.get_nauvis(), "wooden-chest", helpers.center(helpers.nauvis_area()))
  runner.assert(filler and filler.valid, "could not create a filler entity between nav beacons")
  local upper_key = build_platform_radar(platform_upper)
  runner.assert(
    upper_key > lower_key + 1,
    "nav beacon unit numbers are not sparse ("
      .. tostring(lower_key)
      .. ", "
      .. tostring(upper_key)
      .. ")"
  )
  filler.destroy({ raise_destroy = true })

  local before_destroy = helpers.storage()
  local lower = before_destroy.nav_beacons[lower_key]
  local upper = before_destroy.nav_beacons[upper_key]
  runner.assert(lower and lower.valid, "lower nav beacon is missing before destroy")
  runner.assert(upper and upper.valid, "upper nav beacon is missing before destroy")

  local ok, err = pcall(function()
    lower.destroy({ raise_destroy = true })
  end)
  runner.assert(ok, "destroying the lower nav beacon errored: " .. tostring(err))

  local after = helpers.storage()
  runner.assert(after.nav_beacons[lower_key] == nil, "lower nav beacon is still registered")
  runner.assert(after.nav_surfaces[lower_key] == nil, "lower nav beacon still has a nav surface")
  runner.assert(
    after.beaconed_platforms[platform_lower.index] == nil,
    "lower platform still has a beaconed platform entry"
  )
  runner.assert(
    after.nav_beacons_other[lower_key] == nil,
    "lower nav beacon still has a settings entry"
  )
  runner.assert(
    after.nav_beacons_other[upper_key] ~= nil,
    "destroying the lower key removed the higher-keyed beacon's settings"
  )

  local remaining = after.nav_beacons[upper_key]
  runner.assert(remaining, "destroying the lower key removed the higher-keyed nav beacon")
  runner.assert(remaining.valid, "the remaining nav beacon was invalidated")
  runner.assert(remaining.unit_number == upper_key, "the remaining nav beacon changed identity")
  runner.assert(
    after.nav_surfaces[upper_key] ~= nil,
    "the remaining nav beacon lost its nav surface"
  )
  local upper_platform_beacon = after.beaconed_platforms[platform_upper.index]
  runner.assert(upper_platform_beacon, "the upper platform lost its beaconed platform entry")
  runner.assert(
    upper_platform_beacon.unit_number == upper_key,
    "the upper platform points at the wrong beacon"
  )

  -- Regression: scripts/nav-beacon.lua must not use #storage.nav_beacons to
  -- decide whether any beacon remains, because Lua's length operator is
  -- undefined for sparse unit-number keys.
  runner.assert(
    after.has_nav_beacons == true,
    "has_nav_beacons was cleared while nav beacon " .. tostring(upper_key) .. " is still registered"
  )

  local destroy_ok, destroy_err = pcall(function()
    remaining.destroy({ raise_destroy = true })
  end)
  runner.assert(destroy_ok, "destroying the remaining nav beacon errored: " .. tostring(destroy_err))
  local final = helpers.storage()
  runner.assert(count_entries(final.nav_beacons) == 0, "nav beacon storage is not empty after destroying both beacons")
  runner.assert(
    count_entries(final.nav_surfaces) == 0,
    "nav surface storage is not empty after destroying both beacons"
  )
  runner.assert(
    count_entries(final.beaconed_platforms) == 0,
    "beaconed platform storage is not empty after destroying both beacons"
  )
  runner.assert(final.has_nav_beacons == false, "has_nav_beacons is still true with no nav beacons")

  destroy_platform(platform_lower)
  destroy_platform(platform_upper)
  clean_areas()
end)

runner.test("scan energy and scan area scale with quality", function()
  local prototype = prototypes.entity[RADAR]
  runner.assert(prototype, RADAR .. " entity prototype is missing")

  local fields = prototype.custom_tooltip_fields
  runner.assert(fields and #fields >= 2, RADAR .. " does not expose the scan tooltip fields")

  local energy_field = fields[1]
  local size_field = fields[2]
  if not (energy_field.quality_values and size_field.quality_values) then
    runner.log("quality feature is disabled; skipping quality scan scaling checks")
    return
  end

  local radar_data = prototypes.mod_data[RADAR].data
  local base = radar_data.entities[RADAR]
  runner.assert(base, RADAR .. " is missing from the satellite radar mod-data")

  local function quality_value(field, quality)
    local entry = field.quality_values[quality]
    runner.assert(entry, "missing " .. quality .. " value for " .. tostring(field.name))
    return tonumber(entry[2] or entry[1])
  end

  local checked = 0
  for quality_name, quality in pairs(prototypes.quality) do
    if energy_field.quality_values[quality_name] and size_field.quality_values[quality_name] then
      local level = quality.level
      local expected_energy = tonumber(string.format("%.0f", base.energy_per_scan / (1 + 0.3 * level)))
      local expected_size = tonumber(string.format("%.0f", base.scan_area * (1 + 0.3 * level)))

      runner.assert(
        quality_value(energy_field, quality_name) == expected_energy,
        "scan energy for "
          .. quality_name
          .. " is "
          .. tostring(quality_value(energy_field, quality_name))
          .. ", expected "
          .. tostring(expected_energy)
          .. " (quality level "
          .. tostring(level)
          .. ")"
      )
      runner.assert(
        quality_value(size_field, quality_name) == expected_size,
        "scan area for "
          .. quality_name
          .. " is "
          .. tostring(quality_value(size_field, quality_name))
          .. ", expected "
          .. tostring(expected_size)
          .. " (quality level "
          .. tostring(level)
          .. ")"
      )
      checked = checked + 1
    end
  end

  runner.assert(checked >= 2, "fewer than two qualities had scan tooltip values")
  runner.assert(
    quality_value(energy_field, "uncommon") < quality_value(energy_field, "normal"),
    "uncommon scan energy is not lower than normal"
  )
  runner.assert(
    quality_value(size_field, "uncommon") > quality_value(size_field, "normal"),
    "uncommon scan area is not larger than normal"
  )
end)
