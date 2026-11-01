-- Runtime tests for recycler recipe selection.
--
-- Muluna replaces the copper-cable recycling recipe with a Muluna-only variant.
-- The recycler finds recycling recipes automatically, so that replacement must
-- be unlocked by the same technology as the recipe it replaces.
local runner = require("__funit__.test_runner")
local helpers = require("__planet-muluna-funit__.tests.helpers")

local RECYCLING_TECHNOLOGY = "recycling"
local COPPER_CABLE = "copper-cable"
local MULUNA_RECIPE = "copper-cable-recycling-muluna"
local NAUVIS_RECIPE = "copper-cable-recycling"
local RECIPE_NAMES = { MULUNA_RECIPE, NAUVIS_RECIPE }

local function begin_recycling_test()
  local force = game.forces.player
  local technology = force.technologies[RECYCLING_TECHNOLOGY]
  runner.assert(technology, "recycling technology is missing")

  local previous = {
    researched = technology.researched,
    saved_progress = technology.saved_progress,
    recipes = {},
  }
  for _, name in ipairs(RECIPE_NAMES) do
    local recipe = force.recipes[name]
    if recipe then
      previous.recipes[name] = recipe.enabled
    end
  end

  technology.researched = true

  return function()
    technology.researched = previous.researched
    technology.saved_progress = previous.saved_progress
    for name, enabled in pairs(previous.recipes) do
      local recipe = force.recipes[name]
      if recipe then
        recipe.enabled = enabled
      end
    end
  end
end

local function run_recycler_test(surface, expected_recipe, label)
  local restore = begin_recycling_test()
  pcall(helpers.reset_test_areas)

  local center = helpers.center(helpers.muluna_area())
  local recycler = surface.create_entity({
    name = "recycler",
    position = center,
    force = "player",
  })
  local inserter = surface.create_entity({
    name = "burner-inserter",
    position = { x = center.x - 1.5, y = center.y },
    direction = defines.direction.west,
    force = "player",
  })
  local chest = surface.create_entity({
    name = "steel-chest",
    position = { x = center.x - 2.5, y = center.y },
    force = "player",
  })

  if not (recycler and inserter and chest) then
    restore()
    pcall(helpers.reset_test_areas)
    runner.assert(false, label .. ": could not create the recycler test setup")
    return
  end

  chest.insert({ name = COPPER_CABLE, count = 10 })
  inserter.insert({ name = "coal", count = 10 })
  local chest_inventory = chest.get_inventory(defines.inventory.chest)

  local finished = false
  local function finish()
    if finished then return end
    finished = true
    restore()
    pcall(helpers.reset_test_areas)
  end

  helpers.wait_until(runner, function()
    local recipe = recycler.get_recipe()
    return recipe ~= nil
      and recipe.name == expected_recipe
      and chest_inventory.get_item_count(COPPER_CABLE) < 10
  end, {
    timeout = 180,
    interval = 10,
    message = label .. ": inserter did not feed the recycler; expected recipe " .. expected_recipe,
    on_success = finish,
    on_failure = finish,
  })
end

runner.test("Muluna recycler accepts copper cable from an inserter", function()
  run_recycler_test(helpers.get_muluna(), MULUNA_RECIPE, "Muluna recycler")
end)

runner.test("Nauvis recycler still accepts copper cable from an inserter", function()
  run_recycler_test(helpers.get_nauvis(), NAUVIS_RECIPE, "Nauvis recycler")
end)
