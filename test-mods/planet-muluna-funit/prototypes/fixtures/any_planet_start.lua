-- Data-stage checks for Any Planet Start with Muluna as the starting planet.
--
-- The FUnit profile pins aps-planet to "muluna" in settings-updates.lua. This
-- fixture is registered only when any-planet-start is active; the other FUnit
-- mod sets require the file without recording results.
local results = require("lib.results")

local SUITE = "any_planet_start"

if not mods["any-planet-start"] then
  return
end

if settings.startup["aps-planet"].value ~= "muluna" then
  results.record(
    SUITE,
    "aps-planet-muluna",
    false,
    "any-planet-start is active with aps-planet = "
      .. tostring(settings.startup["aps-planet"].value)
      .. "; the Muluna-start fixtures expect 'muluna'"
  )
  return
end

local function ingredient_names(recipe)
  local names = {}
  for _, ingredient in ipairs(recipe.ingredients or {}) do
    names[ingredient.name] = (names[ingredient.name] or 0) + (ingredient.amount or 0)
  end
  return names
end

local function technology_unlocks(technology_name, recipe_name)
  local technology = data.raw["technology"][technology_name]
  if not technology then
    return false
  end
  for _, effect in ipairs(technology.effects or {}) do
    if effect.type == "unlock-recipe" and effect.recipe == recipe_name then
      return true
    end
  end
  return false
end

local function count_technologies_unlocking(recipe_name)
  local count = 0
  for _, technology in pairs(data.raw["technology"]) do
    if technology_unlocks(technology.name, recipe_name) then
      count = count + 1
    end
  end
  return count
end

local function technology_has_prerequisite(technology_name, prerequisite_name)
  local technology = data.raw["technology"][technology_name]
  assert(technology, "technology " .. technology_name .. " is missing")
  for _, prerequisite in ipairs(technology.prerequisites or {}) do
    if prerequisite == prerequisite_name then
      return true
    end
  end
  return false
end

results.check(SUITE, "aps-planet-muluna", function()
  assert(
    settings.startup["aps-planet"].value == "muluna",
    "aps-planet is " .. tostring(settings.startup["aps-planet"].value) .. ", expected muluna"
  )
  assert(data.raw["planet"]["muluna"], "planet muluna is missing")
end)

results.check(SUITE, "discovery-technologies-swapped", function()
  local muluna_discovery = data.raw["technology"]["planet-discovery-muluna"]
  assert(muluna_discovery, "planet-discovery-muluna was removed instead of hidden")
  assert(muluna_discovery.hidden == true, "planet-discovery-muluna is not hidden")
  assert(
    muluna_discovery.prerequisites == nil or #muluna_discovery.prerequisites == 0,
    "planet-discovery-muluna still has prerequisites"
  )

  for name, technology in pairs(data.raw["technology"]) do
    for _, prerequisite in ipairs(technology.prerequisites or {}) do
      assert(
        prerequisite ~= "planet-discovery-muluna",
        name .. " still requires planet-discovery-muluna"
      )
    end
  end

  local nauvis_discovery = data.raw["technology"]["planet-discovery-nauvis"]
  assert(nauvis_discovery, "planet-discovery-nauvis is missing")
  local unlocks_nauvis = false
  for _, effect in ipairs(nauvis_discovery.effects or {}) do
    if effect.type == "unlock-space-location" and effect.space_location == "nauvis" then
      unlocks_nauvis = true
    end
  end
  assert(unlocks_nauvis, "planet-discovery-nauvis does not unlock the nauvis space location")
end)

results.check(SUITE, "starting-orbit-and-connection", function()
  local muluna = data.raw["planet"]["muluna"]
  assert(muluna.orbit and muluna.orbit.parent, "Muluna has no orbit parent")
  assert(
    muluna.orbit.parent.name == "nauvis",
    "Muluna orbit parent is " .. tostring(muluna.orbit.parent.name) .. ", expected nauvis"
  )

  local connection = data.raw["space-connection"]["nauvis-muluna"]
  assert(connection, "space-connection nauvis-muluna is missing")
  assert(connection.from == "nauvis", "nauvis-muluna starts from " .. tostring(connection.from))
  assert(connection.to == "muluna", "nauvis-muluna ends at " .. tostring(connection.to))
end)

results.check(SUITE, "aluminum-automation-science-pack", function()
  local recipe = data.raw["recipe"]["automation-science-pack-muluna"]
  assert(recipe, "automation-science-pack-muluna recipe is missing")

  local ingredients = ingredient_names(recipe)
  assert(ingredients["aluminum-plate"], "automation-science-pack-muluna does not use aluminum plate")
  assert(not ingredients["copper-plate"], "automation-science-pack-muluna still uses copper plate")

  assert(
    technology_unlocks("automation-science-pack", "automation-science-pack-muluna"),
    "automation-science-pack does not unlock automation-science-pack-muluna"
  )
  local unlock_count = count_technologies_unlocking("automation-science-pack-muluna")
  assert(
    unlock_count == 1,
    "automation-science-pack-muluna is unlocked by "
      .. tostring(unlock_count)
      .. " technologies, expected exactly automation-science-pack"
  )
end)

results.check(SUITE, "electronics-aluminum-trigger", function()
  local electronics = data.raw["technology"]["electronics"]
  assert(electronics, "electronics technology is missing")
  assert(electronics.research_trigger, "electronics has no research trigger")
  assert(
    electronics.research_trigger.item == "aluminum-plate",
    "electronics research trigger is "
      .. tostring(electronics.research_trigger.item)
      .. ", expected aluminum-plate"
  )
end)

results.check(SUITE, "rocket-silo-trigger", function()
  local rocket_silo = data.raw["technology"]["rocket-silo"]
  assert(rocket_silo, "rocket-silo technology is missing")
  assert(rocket_silo.research_trigger, "rocket-silo has no research trigger")
  assert(
    rocket_silo.research_trigger.item == "rocket-fuel",
    "rocket-silo research trigger is "
      .. tostring(rocket_silo.research_trigger.item)
      .. ", expected rocket-fuel"
  )
  assert(
    not technology_has_prerequisite("rocket-silo", "logistic-robotics"),
    "rocket-silo still requires logistic-robotics"
  )
  assert(
    not technology_has_prerequisite("rocket-silo", "cargo-planes"),
    "rocket-silo still requires cargo-planes"
  )
end)

results.check(SUITE, "collapsed-start-technologies", function()
  local moved_recipes = {
    { deleted = "electric-mining-drill", replacement = "metallic-asteroid-crushing", recipe = "electric-mining-drill" },
    { deleted = "advanced-circuit", replacement = "electronics", recipe = "advanced-circuit" },
    { deleted = "landfill", replacement = "muluna-greenhouses", recipe = "landfill" },
    { deleted = "muluna-burner-roboport", replacement = "robotics", recipe = "muluna-burner-roboport" },
  }

  for _, entry in ipairs(moved_recipes) do
    assert(
      data.raw["technology"][entry.deleted] == nil,
      entry.deleted .. " technology was not removed from the Muluna-start tree"
    )
    assert(
      technology_unlocks(entry.replacement, entry.recipe),
      entry.replacement .. " does not unlock " .. entry.recipe
    )
  end

  assert(
    technology_has_prerequisite("steel-axe", "metallic-asteroid-crushing"),
    "steel-axe does not require metallic-asteroid-crushing"
  )
end)

results.check(SUITE, "wood-gasification-productivity", function()
  local technology = data.raw["technology"]["wood-gas-processing-productivity"]
  assert(technology, "wood-gas-processing-productivity technology is missing")
  assert(technology.unit, "wood-gas-processing-productivity has no unit")

  local ingredients = {}
  for _, ingredient in ipairs(technology.unit.ingredients or {}) do
    ingredients[ingredient[1]] = ingredient[2]
  end
  assert(ingredients["automation-science-pack"], "wood-gasification-productivity does not use automation science")
  assert(ingredients["logistic-science-pack"], "wood-gasification-productivity does not use logistic science")
  assert(ingredients["space-science-pack"], "wood-gasification-productivity does not use space science")
  assert(
    not ingredients["chemical-science-pack"],
    "wood-gasification-productivity still uses chemical science"
  )
  assert(
    not ingredients["production-science-pack"],
    "wood-gasification-productivity still uses production science"
  )

  for _, prerequisite in ipairs(technology.prerequisites or {}) do
    assert(
      prerequisite ~= "space-science-pack",
      "wood-gasification-productivity still requires space-science-pack"
    )
  end
end)

results.check(SUITE, "default-import-location", function()
  local iron_plate = data.raw["item"]["iron-plate"]
  assert(iron_plate, "iron-plate item is missing")
  assert(
    iron_plate.default_import_location == "muluna",
    "iron-plate default import location is "
      .. tostring(iron_plate.default_import_location)
      .. ", expected muluna"
  )

  local wood = data.raw["item"]["wood"]
  assert(wood, "wood item is missing")
  assert(
    wood.default_import_location == "nauvis",
    "wood default import location is " .. tostring(wood.default_import_location) .. ", expected nauvis"
  )

  local uranium_ore = data.raw["item"]["uranium-ore"]
  assert(uranium_ore, "uranium-ore item is missing")
  assert(
    uranium_ore.default_import_location == "nauvis",
    "uranium-ore default import location is "
      .. tostring(uranium_ore.default_import_location)
      .. ", expected nauvis"
  )
end)

results.check(SUITE, "autoplace-control-ordering", function()
  local muluna_controls = {
    "oxide-asteroid-chunk",
    "metallic-asteroid-chunk",
    "carbonic-asteroid-chunk",
    "anorthite-chunk",
  }
  for _, name in ipairs(muluna_controls) do
    local control = data.raw["autoplace-control"][name]
    assert(control, "autoplace-control " .. name .. " is missing")
    assert(control.order, "autoplace-control " .. name .. " has no order")
    assert(
      string.sub(control.order, 1, 3) == "aaa",
      "autoplace-control " .. name .. " order is " .. control.order .. ", expected an 'aaa' prefix"
    )
  end

  local iron_ore = data.raw["autoplace-control"]["iron-ore"]
  assert(iron_ore, "autoplace-control iron-ore is missing")
  assert(iron_ore.order, "autoplace-control iron-ore has no order")
  assert(
    string.sub(iron_ore.order, 1, 2) == "ab",
    "autoplace-control iron-ore order is " .. iron_ore.order .. ", expected an 'ab' prefix"
  )
end)

results.check(SUITE, "eco-unfriendly-achievement-removed", function()
  assert(
    data.raw["research-achievement"]["eco-unfriendly"] == nil,
    "eco-unfriendly research achievement was not removed for Muluna start"
  )
end)
