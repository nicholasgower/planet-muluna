-- Data-stage checks for Muluna's science packs and research gating.
local results = require("lib.results")

local SUITE = "science"

local function contains(list, value)
  for _, entry in pairs(list or {}) do
    if entry == value then return true end
  end
  return false
end

results.check(SUITE, "interstellar-pack-item", function()
  assert(data.raw["item"]["interstellar-science-pack"], "interstellar-science-pack item is missing")
end)

results.check(SUITE, "interstellar-pack-recipe", function()
  local recipe = data.raw["recipe"]["interstellar-science-pack"]
  assert(recipe, "interstellar-science-pack recipe is missing")
  assert(recipe.main_product == "interstellar-science-pack", "interstellar recipe main_product is wrong")
end)

results.check(SUITE, "interstellar-pack-tech-replaced-or-present", function()
  -- Depending on the active branch/optional patches the original technology may
  -- either remain or be replaced by pair-specific "interstellar-science-pack-*"
  -- technologies. What matters is that the pack itself is still researchable.
  local has_original = data.raw["technology"]["interstellar-science-pack"] ~= nil
  local has_replacement = false
  for name in pairs(data.raw["technology"]) do
    if string.sub(name, 1, #"interstellar-science-pack-") == "interstellar-science-pack-" then
      has_replacement = true
      break
    end
  end
  assert(has_original or has_replacement, "no technology unlocks interstellar-science-pack")
end)

results.check(SUITE, "interstellar-conditions-mod-data", function()
  local conditions = data.raw["mod-data"]["muluna-interstellar-science-pack-conditions"]
  assert(conditions and conditions.data, "muluna-interstellar-science-pack-conditions is missing")
  assert(conditions.data.gated_technology == "muluna-nanofoamed-polymers", "gated technology name changed")
  local gated = data.raw["technology"][conditions.data.gated_technology]
  assert(gated, "gated technology prototype is missing")
  assert(type(conditions.data.science_packs) == "table", "science pack list is not a table")
  assert(#conditions.data.science_packs > 0, "science pack list is empty")
  assert(type(conditions.data.packs) == "table", "pack groups are not a table")
  assert(#conditions.data.packs > 0, "pack groups are empty")
  assert(#conditions.data.packs == #conditions.data.science_packs, "pack groups and representatives disagree")
  assert(type(conditions.data.required_science_packs) == "number", "required_science_packs is not a number")
  assert(conditions.data.required_science_packs > 0, "required_science_packs is not positive")
  assert(conditions.data.required_science_packs <= #conditions.data.packs, "required_science_packs exceeds the pack count")
  assert(gated.research_trigger and gated.research_trigger.type == "scripted", "gated technology does not use the scripted trigger")
end)

results.check(SUITE, "interstellar-science-pack-list-valid", function()
  local conditions = data.raw["mod-data"]["muluna-interstellar-science-pack-conditions"].data
  for _, pack in pairs(conditions.science_packs) do
    assert(data.raw["technology"][pack], "science pack technology is missing: " .. tostring(pack))
  end
  for _, group in pairs(conditions.packs) do
    assert(type(group.technologies) == "table" and #group.technologies > 0, "pack group has no technologies")
    for _, technology_name in pairs(group.technologies) do
      assert(data.raw["technology"][technology_name], "pack contributor technology is missing: " .. tostring(technology_name))
    end
  end
end)

results.check(SUITE, "space-science-pack-recipe-moved", function()
  local tech = data.raw["technology"]["space-science-pack"]
  assert(tech, "space-science-pack technology is missing")
  local unlocks_muluna = false
  local unlocks_vanilla = false
  for _, effect in pairs(tech.effects or {}) do
    if effect.type == "unlock-recipe" and effect.recipe == "space-science-pack-muluna" then
      unlocks_muluna = true
    end
    if effect.type == "unlock-recipe" and effect.recipe == "space-science-pack" then
      unlocks_vanilla = true
    end
  end
  assert(unlocks_muluna, "space-science-pack technology does not unlock space-science-pack-muluna")
  assert(data.raw["recipe"]["space-science-pack-muluna"], "space-science-pack-muluna recipe is missing")

  if mods["Krastorio2-spaced-out"] then
    -- K2SO keeps the vanilla recipe and uses kr-space-research-data for space
    -- science, so Muluna deliberately leaves the vanilla unlock in place and
    -- adds a zero-gravity variant of the K2SO recipe instead.
    assert(
      unlocks_vanilla,
      "K2SO build should keep the vanilla space-science-pack recipe unlocked"
    )
    assert(
      data.raw["recipe"]["kr-space-research-data"],
      "K2SO build is missing kr-space-research-data"
    )
    assert(
      data.raw["recipe"]["kr-space-research-data-advanced"],
      "K2SO build is missing the zero-gravity kr-space-research-data-advanced recipe"
    )
  else
    assert(
      not unlocks_vanilla,
      "space-science-pack technology still unlocks the vanilla recipe"
    )
  end
end)

results.check(SUITE, "labs-accept-interstellar-pack", function()
  local vanilla_lab = data.raw["lab"]["lab"]
  assert(vanilla_lab and contains(vanilla_lab.inputs, "interstellar-science-pack"), "vanilla lab does not accept interstellar-science-pack")
  if data.raw["lab"]["cryogenic-lab"] then
    assert(contains(data.raw["lab"]["cryogenic-lab"].inputs, "interstellar-science-pack"), "cryogenic lab does not accept interstellar-science-pack")
  end
end)

results.check(SUITE, "science-pack-import-location", function()
  local item = data.raw["item"]["interstellar-science-pack"]
  assert(item.default_import_location == "muluna", "interstellar-science-pack import location is not muluna")
end)

results.check(SUITE, "muluna-constants-mod-data", function()
  local constants = data.raw["mod-data"]["muluna-constants"]
  assert(constants and constants.data, "muluna-constants mod-data is missing")
  assert(constants.data.oxygen_per_MJ == 10000, "oxygen_per_MJ constant changed")
  assert(type(constants.data.cargo_drop_spawn_imports) == "table", "cargo_drop_spawn_imports is missing")
end)
