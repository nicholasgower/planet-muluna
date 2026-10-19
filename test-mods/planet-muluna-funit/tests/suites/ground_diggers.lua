-- Runtime tests for ground diggers on Muluna.
--
-- PlanetsLib converts a supported mining drill into its shared
-- "<drill>-ground-digger" assembling machine from the player-driven
-- PlanetsLib-build input. The headless FUnit scenario has no players, so the
-- conversion entry point can only be checked for its missing-player guard.
-- The resulting digger's runtime recipe assignment is fully exercised by
-- creating the shared digger prototype directly.
local runner = require("__funit__.test_runner")
local helpers = require("__planet-muluna-funit__.tests.helpers")

local DRILL = "electric-mining-drill"
local DIGGER = "electric-mining-drill-ground-digger"
local RECIPE = "muluna-regolith-digging"
local TECHNOLOGY = "muluna-regolith-digging"
local MARKER = "PlanetsLib-has-ground-diggers"

local function find_near(surface, name, position, radius)
  local entities = surface.find_entities_filtered({
    name = name,
    position = position,
    radius = radius or 8,
  })
  return entities[1]
end

local function clean_areas()
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

local function create_digger(runner, surface, position, raise_built)
  local digger = helpers.entity_at(surface, DIGGER, position, { raise_built = raise_built })
  runner.assert(
    digger and digger.valid,
    "could not create " .. DIGGER .. " at (" .. tostring(position.x) .. ", " .. tostring(position.y) .. ")"
  )
  return digger
end

local function assert_muluna_recipe(runner, digger)
  local recipe = digger.get_recipe()
  runner.assert(recipe, "built Muluna digger has no recipe")
  runner.assert(
    recipe.name == RECIPE,
    "built Muluna digger has recipe " .. tostring(recipe.name) .. ", expected " .. RECIPE
  )
  runner.assert(digger.recipe_locked == true, "built Muluna digger recipe is not locked")

  local recipe_prototype = prototypes.recipe[RECIPE]
  runner.assert(recipe_prototype, RECIPE .. " recipe prototype is missing")
  local has_category = false
  for _, category in pairs(recipe_prototype.categories or {}) do
    if category == "ground-digging" then
      has_category = true
    end
  end
  runner.assert(has_category, RECIPE .. " is not in the ground-digging category")

  local digger_prototype = prototypes.entity[DIGGER]
  runner.assert(digger_prototype, DIGGER .. " prototype is missing")
  runner.assert(
    digger_prototype.crafting_categories and digger_prototype.crafting_categories["ground-digging"],
    DIGGER .. " does not accept the ground-digging category"
  )
end

runner.test("script-placed drill on Muluna without resources stays a drill", function()
  with_clean_areas(function()
    local surface = helpers.get_muluna()
    local center = helpers.center(helpers.muluna_area())

    local drill = helpers.entity_at(surface, DRILL, center)
    runner.assert(drill and drill.valid, "could not create " .. DRILL .. " on Muluna")
    runner.assert(drill.name == DRILL, "created entity is not " .. DRILL)
    runner.assert(drill.type == "mining-drill", "created entity is not a mining drill")

    -- Conversion is done by PlanetsLib's custom build input, not by an
    -- on_built handler, so script placement must leave the drill alone.
    runner.assert(
      find_near(surface, DIGGER, center) == nil,
      "script-placed drill was unexpectedly converted into " .. DIGGER
    )

    -- The same conversion entry point, driven without a player, must be a safe
    -- no-op (PlanetsLib's documented missing-player guard).
    local interface = remote.interfaces["planetslib_funit"]
    if interface and interface.construct_ground_digger then
      local ok, err = pcall(remote.call, "planetslib_funit", "construct_ground_digger", {
        player_index = 9999,
        cursor_position = center,
        cursor_direction = defines.direction.north,
        input_name = "PlanetsLib-build",
      })
      runner.assert(ok, "construct_ground_digger errored without a player: " .. tostring(err))
    else
      runner.log("planetslib_funit.construct_ground_digger is not available; skipped entry-point guard check")
    end

    drill.destroy({ raise_destroy = true })
    runner.assert(not drill.valid, "drill is still valid after destroy")
  end)
end)

runner.test("digger built on Muluna gets and locks the regolith recipe", function()
  with_clean_areas(function()
    local surface = helpers.get_muluna()
    local center = helpers.center(helpers.muluna_area())
    local position = { x = center.x - 20, y = center.y - 20 }

    runner.assert(
      surface.get_property(MARKER) == 1,
      "Muluna surface is not marked with " .. MARKER
    )

    local digger = create_digger(runner, surface, position, true)
    assert_muluna_recipe(runner, digger)

    digger.destroy({ raise_destroy = true })
    runner.assert(not digger.valid, "digger is still valid after destroy")
  end)
end)

runner.test("raising built is what assigns the digger recipe", function()
  with_clean_areas(function()
    local surface = helpers.get_muluna()
    local center = helpers.center(helpers.muluna_area())

    local unbuilt = create_digger(
      runner,
      surface,
      { x = center.x - 40, y = center.y - 40 },
      false
    )
    runner.assert(
      unbuilt.get_recipe() == nil,
      "digger created without raise_built unexpectedly has a recipe"
    )
    runner.assert(
      unbuilt.recipe_locked == false,
      "digger created without raise_built is unexpectedly recipe-locked"
    )

    local built = create_digger(
      runner,
      surface,
      { x = center.x + 40, y = center.y + 40 },
      true
    )
    assert_muluna_recipe(runner, built)

    unbuilt.destroy({ raise_destroy = true })
    built.destroy({ raise_destroy = true })
  end)
end)

runner.test("drills and diggers on Nauvis do not get Muluna behavior", function()
  with_clean_areas(function()
    local surface = helpers.get_nauvis()
    local center = helpers.center(helpers.nauvis_area())

    local drill = helpers.entity_at(surface, DRILL, { x = center.x - 40, y = center.y - 40 })
    runner.assert(drill and drill.valid, "could not create " .. DRILL .. " on Nauvis")
    runner.assert(
      find_near(surface, DIGGER, { x = center.x - 40, y = center.y - 40 }) == nil,
      "Nauvis drill was converted into a ground digger"
    )

    local digger = create_digger(runner, surface, { x = center.x + 40, y = center.y + 40 }, true)
    runner.assert(
      digger.get_recipe() == nil,
      "Nauvis digger received a recipe: " .. tostring(digger.get_recipe() and digger.get_recipe().name)
    )
    runner.assert(
      digger.recipe_locked == false,
      "Nauvis digger recipe was locked even though Nauvis has no ground digger config"
    )

    drill.destroy({ raise_destroy = true })
    digger.destroy({ raise_destroy = true })
  end)
end)

runner.test("drill on a Muluna resource patch is not converted", function()
  with_clean_areas(function()
    local surface = helpers.get_muluna()
    local center = helpers.center(helpers.muluna_area())
    local position = { x = center.x - 20, y = center.y - 20 }

    local resource = surface.create_entity({
      name = "iron-ore",
      position = position,
      amount = 1000,
    })
    runner.assert(resource and resource.valid, "could not create iron-ore on Muluna")

    local nearby_resources = surface.find_entities_filtered({
      type = "resource",
      position = position,
      radius = 8,
    })
    runner.assert(#nearby_resources > 0, "test resource is not near the drill position")

    local drill = helpers.entity_at(surface, DRILL, { x = position.x + 3, y = position.y })
    runner.assert(drill and drill.valid, "could not create " .. DRILL .. " next to the resource")
    runner.assert(
      find_near(surface, DIGGER, { x = position.x + 3, y = position.y }, 10) == nil,
      "drill with a nearby resource was converted into " .. DIGGER
    )

    drill.destroy({ raise_destroy = true })
    resource.destroy({ raise_destroy = true })
  end)
end)

runner.test("building a Muluna digger completes the regolith digging technology", function()
  with_clean_areas(function()
    local force = game.forces.player
    local technology = force.technologies[TECHNOLOGY]
    runner.assert(technology, TECHNOLOGY .. " technology is missing")
    local was_researched = technology.researched

    technology.researched = false
    runner.assert(not technology.researched, "could not reset " .. TECHNOLOGY .. " for the test")

    local nauvis = helpers.get_nauvis()
    local nauvis_center = helpers.center(helpers.nauvis_area())
    local nauvis_digger = create_digger(
      runner,
      nauvis,
      { x = nauvis_center.x + 40, y = nauvis_center.y + 40 },
      true
    )
    runner.assert(
      not technology.researched,
      "building a digger on Nauvis completed Muluna's " .. TECHNOLOGY .. " technology"
    )
    nauvis_digger.destroy({ raise_destroy = true })

    local muluna = helpers.get_muluna()
    local muluna_center = helpers.center(helpers.muluna_area())
    local muluna_digger = create_digger(
      runner,
      muluna,
      { x = muluna_center.x - 40, y = muluna_center.y - 40 },
      true
    )
    runner.assert(
      technology.researched,
      "building a digger on Muluna did not complete " .. TECHNOLOGY
    )
    muluna_digger.destroy({ raise_destroy = true })

    technology.researched = was_researched
  end)
end)

runner.test("destroying a Muluna digger doesn't error", function()
  with_clean_areas(function()
    local surface = helpers.get_muluna()
    local center = helpers.center(helpers.muluna_area())
    local position = { x = center.x + 20, y = center.y + 20 }

    local digger = create_digger(runner, surface, position, true)
    runner.assert(digger.get_recipe() ~= nil, "digger is missing its recipe before destroy")

    local ok, err = pcall(function()
      digger.destroy({ raise_destroy = true })
    end)
    runner.assert(ok, "destroying the digger errored: " .. tostring(err))
    runner.assert(not digger.valid, "digger is still valid after destroy")
    runner.assert(
      find_near(surface, DIGGER, position, 2) == nil,
      "digger still present at its position after destroy"
    )
  end)
end)
