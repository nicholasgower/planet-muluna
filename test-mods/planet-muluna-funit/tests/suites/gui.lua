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
