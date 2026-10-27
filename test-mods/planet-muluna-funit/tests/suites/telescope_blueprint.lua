-- Regression test for telescope blueprint direction preservation.
--
-- This blueprint was captured on Muluna with the Muluna observation recipe. On
-- Nauvis the recipe cannot be used, so the game and the telescope build handler
-- replace it with the Nauvis observation recipe. The telescope was facing south
-- when captured and must still face south after the paste.
local runner = require("__funit__.test_runner")
local helpers = require("__planet-muluna-funit__.tests.helpers")

local BLUEPRINT = "0eNrVWdty4jgQ/Rc9y1NY8pWa3a+YtxRFybaSqMaWPJLMbCqVf9+WAUNAJoiarYXKQ4Iu56iPulvd5B1V7cB7LaRFy3ckaiUNWj69IyNeJGvdmGQdR0vUDe0gWWR5y02teo4+MBKy4f+gZfyxwohLK6zg293jh7e1HLqKa1iA9yia/xq4sVxH9Sv8Rhj1ysA+JR0VYKWLbylGb7CHpN9S4NjtWD+LFrYZt8zw2u3YUu3PgNG04tPojlhoJaO+ZZYD56+BtXA+GJZKd2AmRrXqeqaZVXBc9Nc4MDhNaLYAO7teaTiCVp3bw4aNMGD/REMmGmAwVtRRxXQYT1wsZolW8OPYTlQ9sD4DaSSk4RoE8Gga7zWNy1HTRuithGiZYNQJrd1xrB64O4+0WrXrir+yjXDj76gWuh6EXXPJqpY309LdMGxpJr5noeG25tynYgbUeWW6iRotNqMXOZ+zbBTBafBJob/Rh890OpnOjOFd1Qr5EnWsfhWSR/SSAoScKhCT44vSTDsPgVnRXzr3fsnac8fC8m7nhs2RBKbnvIk61QytO+THtND50VrIDRip9NvOf6dPcEMgT/0TLRdbl/PMxLMzZHaGOq9aecRNJnHNUMHiUaZzSck+TH0XlE4YdtCViqxm0jjfjire+sKeTC6an7moBz+72vcPwMUpcOEBzgNSFTkJq0uhM8XIIYieWWv4n8tw854akoaCs1ARfhNkcXYT/2/eSU/TzndIO/+h3O69HAw/3Lizy6NtGRpFNCyK4kUoQRJIcNCr4qz25pHk5ME/y8V/Np3Gs+k0PkqnM6kxJiH2FPdvDw2wh5L7tycJsecB/C34HU0DAzQLJcjmCXzvaZzfTnDVgx0XtxOUV0lUXlcP5fuo99bqwZk2DzsluSLT5g+UaQkJsOcBIpnQUAco5h3AFwfkKPUN7c9LhVjxqRDzYaWh/VU5318lN7RXEZSS0LCrTtSsjRpm2YWGy2dAdlqnOYyodmXkxdMnM4LkN+KlM3jFjXjZDF55I17ux6OLG/GKGbyzuvnwPdIFOOprFL50pgk6UhXEwGZM2NF28u76dpcuMLLsZcSDPqES0vUJJ20iRmqw/WDXzHWkSjS7Tsfs20if6EdfS0EYu7DqtdqIZr6lzRafko4PlF7b7x2wPP2eD/nr2i2LH+gFo2mAPQ/wgtHsa3seqZejeYg999/L0SLAngfo5WgZYs+9+Rsk9d+Q7xz3E8EE55is8FOCUwz9RAp/wgAuYHC15XZWTv+JwahlUBXC2I+jZ3LDtRltTzNSpglJyqJMSwr9xr/HyZKO"

local NAUVIS_RECIPE = "muluna-telescope-observation-nauvis"

---The captured blueprint below contains quality data. Factorio cannot import it
---when the quality mod is disabled, so assert that limitation explicitly and
---skip the direction regression in that mod set.
local function skip_without_quality(test_name)
  if script.active_mods["quality"] then
    return false
  end

  local inventory = game.create_inventory(1)
  local blueprint = inventory[1]
  local import_result = blueprint.import_stack(BLUEPRINT)
  runner.assert(
    import_result ~= 0,
    "quality is disabled but the captured blueprint imported; the no-quality skip premise changed"
  )
  runner.log(
    test_name .. ": quality is disabled; the captured blueprint contains quality data and cannot be imported"
  )
  inventory.destroy()
  return true
end

local function find_telescope(surface)
  local telescopes = helpers.find_entities(surface, "muluna-telescope", helpers.nauvis_area())
  runner.assert(#telescopes == 1, "expected exactly one telescope, found " .. tostring(#telescopes))
  return telescopes[1]
end

runner.test("telescope blueprint: direction follows blueprint rotation on Nauvis", function()
  if skip_without_quality("telescope blueprint: direction follows blueprint rotation on Nauvis") then
    return
  end
  helpers.reset_test_areas()
  local surface = helpers.get_nauvis()
  local force = game.forces["player"]
  local recipe = force.recipes[NAUVIS_RECIPE]
  runner.assert(recipe ~= nil, "Nauvis observation recipe is missing")
  local was_enabled = recipe.enabled
  recipe.enabled = true

  local ok, err = pcall(function()
    local tiles = {}
    for x = -11965, -11935 do
      for y = -11965, -11935 do
        tiles[#tiles + 1] = { name = "landfill", position = { x = x, y = y } }
      end
    end
    helpers.set_tiles(surface, tiles, { remove_colliding_entities = true })

    local inventory = game.create_inventory(1)
    local blueprint = inventory[1]
    runner.assert(blueprint.import_stack(BLUEPRINT) == 0, "could not import the telescope blueprint")

    local built = blueprint.build_blueprint({
      surface = surface,
      force = force,
      position = { x = -11950, y = -11950 },
      direction = defines.direction.east,
      build_mode = defines.build_mode.forced,
      skip_fog_of_war = true,
      raise_built = true,
    })
    runner.assert(#built > 0, "rotated blueprint did not create any entities")

    local telescope_ghost
    for _, entity in pairs(built) do
      if entity.ghost_name == "muluna-telescope" then
        telescope_ghost = entity
      end
    end
    runner.assert(telescope_ghost ~= nil, "rotated blueprint did not create a telescope ghost")
    local expected_direction = telescope_ghost.direction
    runner.assert(
      expected_direction ~= defines.direction.south,
      "rotated blueprint ghost direction was not transformed"
    )

    local telescope_index
    for index, entity in pairs(blueprint.get_blueprint_entities()) do
      if entity.name == "muluna-telescope" then
        telescope_index = index
        break
      end
    end
    runner.assert(telescope_index ~= nil, "blueprint telescope index is missing")
    helpers.raise_bplib_event("bplib-positions", {
      blueprint = blueprint,
      positions = { [telescope_index] = telescope_ghost.position },
      orientation_info = { direction = defines.direction.east },
      surface_index = surface.index,
    })

    local _, telescope = telescope_ghost.revive({ raise_revive = true })
    runner.assert(telescope and telescope.valid, "rotated telescope ghost did not revive")
    runner.assert(
      telescope.direction == expected_direction,
      "rotated telescope direction changed from " .. tostring(expected_direction) .. " to " .. tostring(telescope.direction)
    )
  end)

  recipe.enabled = was_enabled
  helpers.reset_test_areas()
  if not ok then
    error(err, 0)
  end
end)

runner.test("telescope blueprint: direction survives recipe replacement on Nauvis", function()
  if skip_without_quality("telescope blueprint: direction survives recipe replacement on Nauvis") then
    return
  end
  helpers.reset_test_areas()
  local surface = helpers.get_nauvis()
  local force = game.forces["player"]
  local recipe = force.recipes[NAUVIS_RECIPE]
  runner.assert(recipe ~= nil, "Nauvis observation recipe is missing")
  local was_enabled = recipe.enabled
  recipe.enabled = true

  local ok, err = pcall(function()
    local tiles = {}
    for x = -11965, -11935 do
      for y = -11965, -11935 do
        tiles[#tiles + 1] = { name = "landfill", position = { x = x, y = y } }
      end
    end
    helpers.set_tiles(surface, tiles, { remove_colliding_entities = true })

    local inventory = game.create_inventory(1)
    local blueprint = inventory[1]
    local import_result = blueprint.import_stack(BLUEPRINT)
    runner.assert(import_result == 0, "could not import the telescope blueprint: " .. tostring(import_result))
    runner.assert(blueprint.is_blueprint_setup(), "imported telescope blueprint is empty")

    local blueprint_telescope
    for _, entity in pairs(blueprint.get_blueprint_entities()) do
      if entity.name == "muluna-telescope" then
        blueprint_telescope = entity
        break
      end
    end
    runner.assert(blueprint_telescope ~= nil, "blueprint has no telescope")
    runner.assert(
      blueprint_telescope.direction == defines.direction.south,
      "blueprint telescope should face south, got " .. tostring(blueprint_telescope.direction)
    )

    local built = blueprint.build_blueprint({
      surface = surface,
      force = force,
      position = { x = -11950, y = -11950 },
      build_mode = defines.build_mode.forced,
      skip_fog_of_war = true,
      raise_built = true,
    })
    runner.assert(#built > 0, "blueprint did not create any entities")

    local telescope_ghost
    for _, entity in pairs(built) do
      if entity.ghost_name == "muluna-telescope" then
        telescope_ghost = entity
      end
    end
    runner.assert(telescope_ghost ~= nil, "blueprint did not create a telescope ghost")
    runner.assert(
      telescope_ghost.direction == defines.direction.south,
      "blueprint telescope ghost should face south, got " .. tostring(telescope_ghost.direction)
    )

    local telescope_index
    for index, entity in pairs(blueprint.get_blueprint_entities()) do
      if entity.name == "muluna-telescope" then
        telescope_index = index
        break
      end
    end
    runner.assert(telescope_index ~= nil, "blueprint telescope index is missing")
    helpers.raise_bplib_event("bplib-positions", {
      blueprint = blueprint,
      positions = { [telescope_index] = telescope_ghost.position },
      orientation_info = { direction = defines.direction.north },
      surface_index = surface.index,
    })

    local _, telescope = telescope_ghost.revive({ raise_revive = true })
    runner.assert(telescope and telescope.valid, "telescope ghost did not revive")
    runner.assert(
      telescope.direction == defines.direction.south,
      "telescope direction changed from south to " .. tostring(telescope.direction)
    )
    local current_recipe = telescope.get_recipe()
    runner.assert(current_recipe, "built telescope has no recipe")
    runner.assert(
      current_recipe.name == NAUVIS_RECIPE,
      "telescope recipe should be " .. NAUVIS_RECIPE .. ", got " .. tostring(current_recipe.name)
    )
  end)

  recipe.enabled = was_enabled
  helpers.reset_test_areas()
  if not ok then
    error(err, 0)
  end
end)
