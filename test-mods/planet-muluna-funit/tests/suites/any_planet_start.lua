-- Runtime tests for Any Planet Start with Muluna as the starting planet.
--
-- The headless FUnit scenario has no player, so APS cannot run its
-- on_player_created teleport to Muluna. The suite checks the selected starting
-- planet through APS's public remote interface and verifies the final
-- prototype state that a Muluna start uses.
local runner = require("__funit__.test_runner")

if not script.active_mods["any-planet-start"] then
  return
end

local function ingredient_amounts(recipe)
  local amounts = {}
  for _, ingredient in ipairs(recipe.ingredients or {}) do
    amounts[ingredient.name] = (amounts[ingredient.name] or 0) + (ingredient.amount or 0)
  end
  return amounts
end

runner.test("aps: aps-planet startup setting is muluna", function()
  runner.assert(
    settings.startup["aps-planet"].value == "muluna",
    "aps-planet is " .. tostring(settings.startup["aps-planet"].value) .. ", expected muluna"
  )
end)

runner.test("aps: APS reports Muluna as the starting planet", function()
  local interface = remote.interfaces["APS"]
  runner.assert(interface, "APS remote interface is missing")
  runner.assert(interface.get_planet, "APS remote interface has no get_planet function")
  runner.assert(
    remote.call("APS", "get_planet") == "muluna",
    "APS get_planet returned " .. tostring(remote.call("APS", "get_planet")) .. ", expected muluna"
  )
end)

runner.test("aps: Muluna and Nauvis planets are available", function()
  runner.assert(game.planets["muluna"], "Muluna planet is missing")
  runner.assert(game.planets["nauvis"], "Nauvis planet is missing")
  runner.assert(
    game.planets["muluna"].prototype.name == "muluna",
    "game.planets.muluna has the wrong planet prototype"
  )
end)

runner.test("aps: discovery technologies are swapped", function()
  local muluna_discovery = prototypes.technology["planet-discovery-muluna"]
  runner.assert(muluna_discovery, "planet-discovery-muluna was removed instead of hidden")
  runner.assert(muluna_discovery.hidden == true, "planet-discovery-muluna is not hidden")
  local prerequisites = muluna_discovery.prerequisites
  runner.assert(
    prerequisites == nil or next(prerequisites) == nil,
    "planet-discovery-muluna still has prerequisites"
  )
  runner.assert(
    prototypes.technology["planet-discovery-nauvis"],
    "planet-discovery-nauvis is missing"
  )
end)

runner.test("aps: aluminum automation science pack is available", function()
  local recipe = prototypes.recipe["automation-science-pack-muluna"]
  runner.assert(recipe, "automation-science-pack-muluna recipe is missing")

  local ingredients = ingredient_amounts(recipe)
  runner.assert(ingredients["aluminum-plate"], "automation-science-pack-muluna does not use aluminum plate")
  runner.assert(not ingredients["copper-plate"], "automation-science-pack-muluna still uses copper plate")
  runner.assert(
    game.forces.player.recipes["automation-science-pack-muluna"],
    "the player force has no automation-science-pack-muluna recipe"
  )
end)

runner.test("aps: electronics research trigger uses aluminum", function()
  local electronics = prototypes.technology["electronics"]
  runner.assert(electronics, "electronics technology is missing")
  runner.assert(electronics.research_trigger, "electronics has no research trigger")
  local trigger_item = electronics.research_trigger.item
  local item_name = type(trigger_item) == "table" and trigger_item.name or trigger_item
  runner.assert(
    item_name == "aluminum-plate",
    "electronics research trigger is " .. tostring(item_name) .. ", expected aluminum-plate"
  )
end)

runner.test("aps: item import locations default to Muluna", function()
  local iron_plate = prototypes.item["iron-plate"]
  runner.assert(iron_plate, "iron-plate item is missing")
  runner.assert(iron_plate.default_import_location, "iron-plate has no default import location")
  runner.assert(
    iron_plate.default_import_location.name == "muluna",
    "iron-plate default import location is "
      .. tostring(iron_plate.default_import_location.name)
      .. ", expected muluna"
  )

  local uranium_ore = prototypes.item["uranium-ore"]
  runner.assert(uranium_ore, "uranium-ore item is missing")
  runner.assert(uranium_ore.default_import_location, "uranium-ore has no default import location")
  runner.assert(
    uranium_ore.default_import_location.name == "nauvis",
    "uranium-ore default import location is "
      .. tostring(uranium_ore.default_import_location.name)
      .. ", expected nauvis"
  )
end)
