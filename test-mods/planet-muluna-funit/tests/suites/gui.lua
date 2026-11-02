-- Runtime regression tests for Muluna's relative GUI.
--
-- Historical crash reports covered here:
--   #507  Opening the satellite radar GUI crashed when the blueprint tags
--         stored a nil `enabled` value, which Factorio rejects as a checkbox
--         `state`.
--   #408  Clicking a telescope GUI button crashed when `player.opened` was nil.
--
-- The headless scenario has no player, so these tests drive the production GUI
-- functions through the muluna_funit seams. The seam builds the frame against a
-- stub root that records every element definition and enforces the engine's
-- checkbox state type.
local runner = require("__funit__.test_runner")
local helpers = require("__planet-muluna-funit__.tests.helpers")

local TELESCOPE = "muluna-telescope"
local TELESCOPE_RECIPE = "muluna-telescope-observation-muluna"
local RADAR = "muluna-satellite-radar"
local STARTER_PACK = "space-platform-starter-pack"
local PLATFORM_PREFIX = "funit-gui-"

local function destroy_entity(entity)
  if entity and entity.valid then
    pcall(function()
      entity.destroy({ raise_destroy = true })
    end)
  end
end

local function clean_platforms()
  local stale = {}
  for _, force in pairs(game.forces) do
    for _, platform in pairs(force.platforms) do
      if platform.name:find("^funit%-gui%-") then
        table.insert(stale, platform)
      end
    end
  end
  for _, platform in pairs(stale) do
    pcall(function()
      platform.destroy()
    end)
  end
  local surfaces = {}
  for _, surface in pairs(game.surfaces) do
    if surface.name:find("^funit%-gui%-") then
      table.insert(surfaces, surface)
    end
  end
  for _, surface in pairs(surfaces) do
    pcall(game.delete_surface, surface)
  end
end

local function clean_areas()
  clean_platforms()
  pcall(helpers.reset_test_areas)
end

local function create_platform(name)
  runner.assert(prototypes.item[STARTER_PACK], STARTER_PACK .. " item prototype is missing")
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
  return platform
end

local function find_element(result, name)
  for _, element in pairs(result.elements or {}) do
    if element.name == name then
      return element
    end
  end
end

local function build_telescope()
  local surface = helpers.get_muluna()
  local center = helpers.center(helpers.muluna_area())
  local recipe = game.forces["player"].recipes[TELESCOPE_RECIPE]
  runner.assert(recipe ~= nil, "player force has no LuaRecipe for " .. TELESCOPE_RECIPE)
  local was_enabled = recipe.enabled
  recipe.enabled = true

  local telescope = helpers.entity_at(surface, TELESCOPE, center)
  runner.assert(telescope and telescope.valid, "could not create " .. TELESCOPE)
  return telescope, recipe, was_enabled
end

runner.test("radar GUI with empty blueprint tags builds a boolean checkbox", function()
  -- Regression: #507. build_nav_beacon used to copy tags.enabled (nil) into
  -- storage, and the radar GUI passed it straight to the checkbox state.
  clean_areas()
  local platform = create_platform(PLATFORM_PREFIX .. "radar")
  local ok, err = pcall(function()
    local radar = helpers.entity_at(platform.surface, RADAR, { x = 0, y = 0 }, { raise_built = false })
    runner.assert(radar and radar.valid, "could not create " .. RADAR .. " on the platform")
    helpers.funit_call("build_nav_beacon", radar, {})

    -- built_nav_beacon replaces the passed radar with the registered one.
    local beacon = helpers.storage().beaconed_platforms[platform.index]
    runner.assert(beacon ~= nil and beacon.valid, "build_nav_beacon did not register a platform radar")

    local result = helpers.funit_call("build_entity_gui", beacon, beacon)
    runner.assert(result.ok, "opening the radar GUI with empty tags crashed (#507): " .. tostring(result.error))

    local checkbox = find_element(result, "muluna-satellite-radar-enable-checkbox")
    runner.assert(checkbox ~= nil, "radar GUI did not build the enable checkbox")
    runner.assert(
      checkbox.state == true,
      "radar GUI checkbox state should default to true, got " .. tostring(checkbox.state)
    )

    destroy_entity(beacon)
  end)
  pcall(function()
    platform.destroy()
  end)
  clean_areas()
  if not ok then
    error(err, 0)
  end
end)

runner.test("telescope GUI builds its goto button", function()
  clean_areas()
  local telescope, recipe, was_enabled = build_telescope()
  local ok, err = pcall(function()
    local result = helpers.funit_call("build_entity_gui", telescope, telescope)
    runner.assert(result.ok, "opening the telescope GUI crashed: " .. tostring(result.error))
    runner.assert(
      find_element(result, "muluna-goto-button-telescope-unit") ~= nil,
      "telescope GUI did not build its goto button"
    )
  end)
  destroy_entity(telescope)
  if recipe.valid then
    recipe.enabled = was_enabled
  end
  clean_areas()
  if not ok then
    error(err, 0)
  end
end)

runner.test("telescope goto click with no opened entity does not crash", function()
  -- Regression: #408. The click handler indexed player.opened unconditionally.
  local result = helpers.funit_call("handle_gui_click", "muluna-goto-button-telescope-unit", nil)
  runner.assert(
    result.ok,
    "clicking a telescope goto button with no opened entity crashed (#408): " .. tostring(result.error)
  )
  runner.assert(result.opened == nil, "the click handler opened an entity when none was selected")
end)

runner.test("telescope goto click focuses the combinator", function()
  clean_areas()
  local telescope, recipe, was_enabled = build_telescope()
  local ok, err = pcall(function()
    local result = helpers.funit_call("handle_gui_click", "muluna-goto-button-telescope-unit", telescope)
    runner.assert(result.ok, "telescope goto click crashed: " .. tostring(result.error))
    local data = helpers.funit_call("get_telescope_data", telescope.unit_number)
    runner.assert(data ~= nil, "telescope is not registered in storage")
    runner.assert(
      result.opened == data["constant-combinator"],
      "telescope goto click did not focus the telescope's combinator"
    )
  end)
  destroy_entity(telescope)
  if recipe.valid then
    recipe.enabled = was_enabled
  end
  clean_areas()
  if not ok then
    error(err, 0)
  end
end)

runner.test("telescope combinator goto click focuses the telescope", function()
  -- The combinator -> telescope direction is a child lookup; it must resolve
  -- through the child index (or the compatibility scan) and open the machine.
  clean_areas()
  local telescope, recipe, was_enabled = build_telescope()
  local ok, err = pcall(function()
    local data = helpers.funit_call("get_telescope_data", telescope.unit_number)
    runner.assert(data ~= nil, "telescope is not registered in storage")
    local combinator = data["constant-combinator"]
    runner.assert(combinator and combinator.valid, "telescope has no valid combinator")

    local result = helpers.funit_call("handle_gui_click", "muluna-goto-button-telescope-combinator", combinator)
    runner.assert(result.ok, "telescope combinator goto click crashed: " .. tostring(result.error))
    runner.assert(
      result.opened == telescope,
      "telescope combinator goto click did not focus the telescope"
    )
  end)
  destroy_entity(telescope)
  if recipe.valid then
    recipe.enabled = was_enabled
  end
  clean_areas()
  if not ok then
    error(err, 0)
  end
end)

runner.test("compound GUI goto buttons resolve both directions", function()
  -- The two compound bodies that are not a telescope: the reactor of a heat
  -- assembling machine (child -> parent through the child index) and the hidden
  -- roboport of a burner roboport (child -> parent through the refueler key).
  clean_areas()
  local surface = helpers.get_muluna()
  local center = helpers.center(helpers.muluna_area())
  local constants = prototypes.mod_data["muluna-constants"].data
  local heat_key, heat = next(constants.heat_assembling_machines or {})
  local vacuum_key, vacuum = next(constants.vacuum_roboports or {})
  runner.assert(heat_key ~= nil and heat ~= nil, "heat_assembling_machines constants are empty")
  runner.assert(vacuum_key ~= nil and vacuum ~= nil, "vacuum_roboports constants are empty")

  local ok, err = pcall(function()
    local assembler = helpers.entity_at(surface, heat["assembling-machine"], { x = center.x - 30, y = center.y })
    runner.assert(assembler and assembler.valid, "could not build the heat assembling machine")
    local heat_data = helpers.funit_call("get_heat_assembling_machine_data", assembler.unit_number)
    runner.assert(heat_data ~= nil, "the heat assembling machine was not registered")

    local to_parent = helpers.funit_call(
      "handle_gui_click",
      "muluna-goto-button-heat-assembling-machine-reactor",
      heat_data.reactor
    )
    runner.assert(to_parent.ok, "heat reactor goto click crashed: " .. tostring(to_parent.error))
    runner.assert(to_parent.opened == assembler, "heat reactor goto click did not focus the machine")

    local to_child = helpers.funit_call(
      "handle_gui_click",
      "muluna-goto-button-heat-assembling-machine-unit",
      assembler
    )
    runner.assert(to_child.ok, "heat machine goto click crashed: " .. tostring(to_child.error))
    runner.assert(to_child.opened == heat_data.reactor, "heat machine goto click did not focus the reactor")

    local refueler = helpers.entity_at(surface, vacuum.refueler, { x = center.x + 30, y = center.y })
    runner.assert(refueler and refueler.valid, "could not build the burner roboport refueler")
    local roboport_data = helpers.funit_call("get_burner_roboport_data", refueler.unit_number)
    runner.assert(roboport_data ~= nil, "the burner roboport was not registered")

    local roboport_to_parent = helpers.funit_call(
      "handle_gui_click",
      "muluna-goto-button-burner-roboport-unit",
      roboport_data.roboport
    )
    runner.assert(
      roboport_to_parent.ok,
      "roboport goto click crashed: " .. tostring(roboport_to_parent.error)
    )
    runner.assert(
      roboport_to_parent.opened == refueler,
      "roboport goto click did not focus the refueler"
    )

    local refueler_to_child = helpers.funit_call(
      "handle_gui_click",
      "muluna-goto-button-burner-roboport-refueler",
      refueler
    )
    runner.assert(
      refueler_to_child.ok,
      "refueler goto click crashed: " .. tostring(refueler_to_child.error)
    )
    runner.assert(
      refueler_to_child.opened == roboport_data.roboport,
      "refueler goto click did not focus the hidden roboport"
    )
  end)
  clean_areas()
  if not ok then
    error(err, 0)
  end
end)
