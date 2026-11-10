-- Runtime test for a mod that is removed from a save and added back.
--
-- Factorio drops a removed mod's migration bookkeeping and storage table. When
-- the mod is added back it is treated as new: storage starts empty and every
-- migration is replayed against a save that is already up to date. This suite
-- emulates that lifecycle through the muluna_funit seam and checks that already
-- migrated state survives it.

local runner = require("__funit__.test_runner")
local helpers = require("__planet-muluna-funit__.tests.helpers")

local AREA = helpers.muluna_area()
local TELESCOPE_RECIPE = "muluna-telescope-observation-muluna"
-- The chunks generated around the origin in `build_context` (16 chunks is
-- 512 tiles in each direction).
local RESOURCE_AREA = {
  left_top = { -512, -512 },
  right_bottom = { 512, 512 },
}

-- Technologies used as sentinels. `existing_save` historically granted these
-- when a force had space science without the Muluna discovery technology,
-- which is also the normal state of a save that re-adds Muluna before visiting
-- the moon.
local TRACKED_TECHNOLOGIES = {
  "planet-discovery-muluna",
  "asteroid-collector",
  "space-science-pack",
  "space-platform-thruster",
}

local function snapshot_technologies(force)
  local snapshot = {}
  for _, name in ipairs(TRACKED_TECHNOLOGIES) do
    local technology = force.technologies[name]
    if technology then
      snapshot[name] = {
        researched = technology.researched,
        saved_progress = technology.saved_progress,
      }
    end
  end
  return snapshot
end

local function restore_technologies(force, snapshot)
  for name, state in pairs(snapshot) do
    local technology = force.technologies[name]
    if technology then
      technology.researched = state.researched
      technology.saved_progress = state.saved_progress
    end
  end
end

local function find_generated_entity(surface, filter)
  local entities = surface.find_entities_filtered(filter)
  runner.assert(
    #entities > 0,
    "no generated " .. tostring(filter.name) .. " found on Muluna to use as a re-add sentinel"
  )
  return entities[1]
end

-- The set and amount of generated resources depends on the map seed, so pick
-- one that exists on this surface instead of assuming a specific prototype.
local function find_generated_resource(surface, area)
  local counts = surface.get_resource_counts()
  local names = {}
  for name, count in pairs(counts) do
    if count > 0 then names[#names + 1] = name end
  end
  table.sort(names)
  runner.assert(#names > 0, "Muluna has no generated resources to use as a re-add sentinel")
  local name = names[1]
  local entities = surface.find_entities_filtered({
    type = "resource",
    name = name,
    area = area,
    limit = 1,
  })
  runner.assert(#entities > 0, "resource counts listed " .. name .. " but no resource entity was found")
  return entities[1], name
end

local function build_context()
  helpers.reset_test_areas()

  local surface = helpers.get_muluna()
  local force = game.forces["player"]
  local center = helpers.center(AREA)

  -- The headless scenario starts with very few generated chunks. Generate a
  -- region around the origin so at least one autoplaced resource exists to use
  -- as a sentinel.
  surface.request_to_generate_chunks({ x = 0, y = 0 }, 16)
  surface.force_generate_chunk_requests()

  local technology_snapshot = snapshot_technologies(force)

  -- Real autoplaced entities. `create_entity` entities are not tagged as
  -- autoplaced, so only generated ones prove that the regeneration migrations
  -- did not run again.
  local lunar_rock = find_generated_entity(surface, { name = "lunar-rock" })
  local resource, resource_name = find_generated_resource(surface, RESOURCE_AREA)
  local counts = {
    lunar_rocks = surface.count_entities_filtered({ name = "lunar-rock" }),
    resources = surface.count_entities_filtered({ type = "resource" }),
  }

  local recipe = force.recipes[TELESCOPE_RECIPE]
  runner.assert(recipe ~= nil, "telescope recipe " .. TELESCOPE_RECIPE .. " is missing")
  local recipe_was_enabled = recipe.enabled
  recipe.enabled = true
  local telescope = helpers.entity_at(surface, "muluna-telescope", center)
  recipe.enabled = recipe_was_enabled
  runner.assert(telescope ~= nil, "could not create a muluna-telescope sentinel")

  return {
    surface = surface,
    force = force,
    lunar_rock = lunar_rock,
    resource = resource,
    resource_name = resource_name,
    counts = counts,
    telescope = telescope,
    recipe = recipe,
    recipe_was_enabled = recipe_was_enabled,
    technology_snapshot = technology_snapshot,
  }
end

local function cleanup_context(context)
  if not context then return end
  if context.recipe then
    context.recipe.enabled = context.recipe_was_enabled
  end
  if context.force and context.force.valid then
    restore_technologies(context.force, context.technology_snapshot)
  end
  if context.surface and context.surface.valid then
    helpers.clear_area(context.surface, AREA)
  end
end

local function format_errors(errors)
  local lines = {}
  for _, failure in ipairs(errors) do
    lines[#lines + 1] = tostring(failure.step) .. ": " .. tostring(failure.message)
  end
  return table.concat(lines, "\n")
end

runner.test("removing and re-adding Muluna replays migrations without damaging the save", function()
  local context = build_context()
  local ok, err = pcall(function()
    local force = context.force

    -- Reproduce a save that has space science but has not discovered Muluna,
    -- which is what `existing_save` reacts to.
    force.technologies["space-science-pack"].researched = true
    force.technologies["space-platform-thruster"].researched = true
    force.technologies["planet-discovery-muluna"].researched = false
    force.technologies["asteroid-collector"].researched = false

    local report = helpers.funit_call("simulate_re_add_migrations")
    runner.assert(type(report) == "table", "re-add simulation did not return a report")
    local errors = report.errors or {}
    runner.assert(
      #errors == 0,
      "migrations crashed when the mod was added back to the save:\n" .. format_errors(errors)
    )

    -- The migrations that reset autoplace settings must not regenerate a world
    -- that is already migrated: that both replaces existing entities and
    -- duplicates resources.
    local lunar_rock_count = context.surface.count_entities_filtered({ name = "lunar-rock" })
    local resource_count = context.surface.count_entities_filtered({ type = "resource" })
    runner.assert(context.lunar_rock.valid, "re-adding Muluna replaced the lunar rock sentinel")
    runner.assert(
      context.resource.valid,
      "re-adding Muluna replaced the " .. tostring(context.resource_name) .. " sentinel"
    )
    runner.assert(
      lunar_rock_count == context.counts.lunar_rocks,
      "re-adding Muluna regenerated lunar rocks (" .. context.counts.lunar_rocks .. " -> " .. lunar_rock_count .. ")"
    )
    runner.assert(
      resource_count == context.counts.resources,
      "re-adding Muluna regenerated resources (" .. context.counts.resources .. " -> " .. resource_count .. ")"
    )

    -- Old-save convenience research must not run against a save that is
    -- already on the current version.
    runner.assert(
      force.technologies["planet-discovery-muluna"].researched == false,
      "re-adding Muluna force-researched planet-discovery-muluna"
    )
    runner.assert(
      force.technologies["asteroid-collector"].researched == false,
      "re-adding Muluna force-researched asteroid-collector"
    )

    -- Storage is expected to be lost. The recovery migrations should rebuild
    -- the telescope indexes from the entities that are still on the map.
    local initialized = report.initialized or {}
    runner.assert(initialized.telescopes, "storage.telescopes was not initialized")
    runner.assert(initialized.telescopes_on_surface, "storage.telescopes_on_surface was not initialized")
    runner.assert(initialized.nav_beacons, "storage.nav_beacons was not initialized")

    local telescope_data = (report.telescopes or {})[context.telescope.unit_number]
    runner.assert(telescope_data ~= nil, "re-adding Muluna did not recover telescope storage")
    runner.assert(telescope_data.has_entity, "recovered telescope storage has no assembling machine")
    runner.assert(telescope_data.has_combinator, "recovered telescope storage has no combinator")
    runner.assert(
      (report.telescopes_on_surface or {})["muluna"]
        and report.telescopes_on_surface["muluna"][context.telescope.unit_number] == true,
      "re-adding Muluna did not rebuild the per-surface telescope index"
    )
  end)

  local cleanup_ok, cleanup_err = pcall(cleanup_context, context)
  if not ok then
    error(err, 0)
  end
  runner.assert(cleanup_ok, "re-add migration cleanup failed: " .. tostring(cleanup_err))
end)
