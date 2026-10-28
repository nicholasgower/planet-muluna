-- Data-stage assertions for the dynamic exploration science pack discovery.
--
-- This runs after planet-muluna's data-final-fixes, so it sees the authoritative
-- group list that ships to players.
local results = require("lib.results")

local SUITE = "science"
local EXPLORATION_TECHNOLOGY = "interstellar-science-pack"

local function conditions()
  local mod_data = data.raw["mod-data"]["muluna-interstellar-science-pack-conditions"]
  assert(mod_data and mod_data.data, "interstellar conditions mod-data is missing")
  return mod_data.data
end

local function find_group(predicate)
  for _, group in ipairs(conditions().packs or {}) do
    if predicate(group) then return group end
  end
end

local function find_group_by_item(item_name)
  return find_group(function(group) return group.item == item_name end)
end

local function find_group_by_key(key)
  return find_group(function(group) return group.key == key end)
end

local function contains(list, value)
  for _, entry in ipairs(list or {}) do
    if entry == value then return true end
  end
  return false
end

local function has_technology(group, technology_name)
  return group and contains(group.technologies, technology_name)
end

local function has_label(technology_name)
  local technology = data.raw["technology"][technology_name]
  if not technology then return false end
  for _, effect in ipairs(technology.effects or {}) do
    if effect.type == "nothing"
      and type(effect.effect_description) == "table"
      and effect.effect_description[1] == "technology-effect.contributes-to-discovery"
      and effect.effect_description[2] == "muluna-nanofoamed-polymers"
    then
      return true
    end
  end
  return false
end

local function ingredient_name(ingredient)
  if type(ingredient) == "string" then return ingredient end
  if type(ingredient) == "table" then return ingredient.name or ingredient[1] end
end

local function is_exploration_name(name)
  if name == EXPLORATION_TECHNOLOGY then return true end
  local prefix = EXPLORATION_TECHNOLOGY .. "-"
  return string.sub(name, 1, #prefix) == prefix
end

local function technology_depends_on_exploration(technology_name, visiting)
  visiting = visiting or {}
  if visiting[technology_name] then return false end
  visiting[technology_name] = true

  local technology = data.raw["technology"][technology_name]
  if not technology then return false end

  for _, ingredient in ipairs((technology.unit and technology.unit.ingredients) or {}) do
    if is_exploration_name(ingredient_name(ingredient)) then
      return true
    end
  end

  for _, prerequisite in ipairs(technology.prerequisites or {}) do
    if is_exploration_name(prerequisite)
      or technology_depends_on_exploration(prerequisite, visiting)
    then
      return true
    end
  end
  return false
end

results.check(SUITE, "science-discovery-groups-exist", function()
  local data_table = conditions()
  assert(type(data_table.packs) == "table", "packs is not a table")
  assert(#data_table.packs > 0, "packs is empty")
  assert(type(data_table.diagnostics) == "table", "diagnostics is not a table")

  assert(#data_table.science_packs == #data_table.packs, "science_packs does not have one representative per pack")
  for index, group in ipairs(data_table.packs) do
    assert(type(group.technologies) == "table" and #group.technologies > 0, "pack group has no technologies")
    assert(group.representative, "pack group has no representative")
    assert(data_table.science_packs[index] == group.representative, "science_packs is not in pack order")
    assert(has_technology(group, group.representative), "representative is not a group technology")
    for _, technology_name in ipairs(group.technologies) do
      assert(has_label(technology_name), "pack contributor has no discovery label: " .. technology_name)
    end
  end
end)

results.check(SUITE, "science-discovery-vanilla-baseline", function()
  for _, item_name in ipairs({
    "metallurgic-science-pack",
    "agricultural-science-pack",
    "electromagnetic-science-pack",
  }) do
    if data.raw["item"][item_name] then
      local group = find_group_by_item(item_name)
      assert(group, "baseline group is missing: " .. item_name)
      assert(has_technology(group, item_name), "baseline technology is missing from group: " .. item_name)
      assert(has_label(item_name), "baseline technology has no discovery label: " .. item_name)
    end
  end
end)

results.check(SUITE, "science-discovery-vanilla-list-order", function()
  local expected = {}
  for _, item_name in ipairs({
    "metallurgic-science-pack",
    "agricultural-science-pack",
    "electromagnetic-science-pack",
  }) do
    if data.raw["item"][item_name] then
      expected[#expected + 1] = item_name
    end
  end

  local data_table = conditions()
  for index, item_name in ipairs(expected) do
    local group = data_table.packs[index]
    assert(group, "missing pack group at position " .. index)
    assert(group.item == item_name, "vanilla pack is not in the hardcoded list position: " .. item_name)
    assert(
      data_table.science_packs[index] == group.representative,
      "representative list does not match vanilla pack order at position " .. index
    )
  end
end)

results.check(SUITE, "science-discovery-one-pack-per-planet", function()
  local muluna_groups = {}
  for _, group in ipairs(conditions().packs) do
    if group.item and group.planet == "muluna" then
      muluna_groups[#muluna_groups + 1] = group
    end
  end
  assert(#muluna_groups == 1, "Muluna has more than one contributing science pack")
  assert(muluna_groups[1].item == "muluna-funit-science-pack", "the first Muluna pack was not selected")

  for _, group in ipairs(conditions().packs) do
    assert(
      not has_technology(group, "muluna-funit-aaa-science"),
      "a second pack on the same planet contributed progress"
    )
  end
  assert(not has_label("muluna-funit-aaa-science"), "the second pack technology has a label")
end)

results.check(SUITE, "science-discovery-alternative-recipe", function()
  local group = find_group_by_item("muluna-funit-science-pack")
  assert(group, "synthetic pack group is missing")
  assert(has_technology(group, "muluna-funit-science-pack"), "canonical synthetic technology is missing")
  assert(has_technology(group, "muluna-funit-science-pack-alt"), "alternative synthetic recipe technology is missing")
  assert(has_label("muluna-funit-science-pack"), "canonical synthetic technology has no label")
  assert(has_label("muluna-funit-science-pack-alt"), "alternative synthetic technology has no label")
end)

results.check(SUITE, "science-discovery-alternative-vanilla-recipe", function()
  local group = find_group_by_item("metallurgic-science-pack")
  assert(group, "metallurgic group is missing")
  assert(
    has_technology(group, "muluna-funit-alt-metallurgic-science"),
    "alternative metallurgic recipe technology was not added to the pack group"
  )
  assert(has_label("muluna-funit-alt-metallurgic-science"), "alternative metallurgic technology has no label")
end)

results.check(SUITE, "science-discovery-negative-cases", function()
  assert(find_group_by_item("muluna-funit-shared-science-pack") == nil, "shared pack became a dynamic group")
  assert(find_group_by_item("muluna-funit-forced-false-science-pack") == nil, "forced-false pack group was not removed")

  for _, group in ipairs(conditions().packs) do
    assert(
      not has_technology(group, "muluna-funit-recycling-science"),
      "recycling technology contributed to a pack group"
    )
    assert(
      not has_technology(group, "muluna-funit-shared-science-pack-alt"),
      "an alternative recipe made a shared pack eligible"
    )
    assert(
      not has_technology(group, "muluna-funit-rigor-science"),
      "a Rigor Module-generated recipe contributed to a pack group"
    )
  end
  assert(not has_label("muluna-funit-shared-science-pack"), "shared pack technology has a label")
  assert(not has_label("muluna-funit-shared-science-pack-alt"), "shared pack alternative technology has a label")
  assert(not has_label("muluna-funit-recycling-science"), "recycling technology has a label")
  assert(not has_label("muluna-funit-rigor-science"), "Rigor Module-generated recipe technology has a label")
  assert(not has_label("muluna-funit-forced-false-science-pack"), "forced-false technology has a label")
end)

results.check(SUITE, "science-discovery-forced-true-tech", function()
  local group = find_group_by_key("muluna-funit-forced-true-tech")
  assert(group, "forced-true technology did not create a group")
  assert(has_technology(group, "muluna-funit-forced-true-tech"), "forced-true group does not contain its technology")
  assert(has_label("muluna-funit-forced-true-tech"), "forced-true technology has no label")
end)

results.check(SUITE, "science-discovery-legacy-pack-fallback", function()
  local technology_name = "athletic-science-pack"
  assert(data.raw["technology"][technology_name], "athletic science pack technology is missing")
  local group = find_group_by_key(technology_name) or find_group_by_item(technology_name)
  assert(group, "athletic science pack did not create a progress group")
  assert(has_technology(group, technology_name), "athletic science pack technology is not in its group")
  assert(has_label(technology_name), "athletic science pack technology has no discovery label")
end)

results.check(SUITE, "science-discovery-no-duplicates", function()
  local seen_items = {}
  for _, group in ipairs(conditions().packs) do
    if group.item then
      assert(not seen_items[group.item], "duplicate pack item: " .. group.item)
      seen_items[group.item] = true
    end
    local group_techs = {}
    for _, technology_name in ipairs(group.technologies) do
      assert(not group_techs[technology_name], "duplicate technology in group: " .. technology_name)
      group_techs[technology_name] = true
    end
  end
end)

results.check(SUITE, "science-discovery-space-and-post-exploration-excluded", function()
  assert(find_group_by_item("space-science-pack") == nil, "space science pack became a group")
  assert(find_group_by_item("promethium-science-pack") == nil, "promethium science pack became a group")
  assert(
    find_group_by_item("interstellar-science-pack") == nil,
    "the exploration science pack contributed to its own discovery"
  )

  local aquilo_discovery = data.raw["technology"]["planet-discovery-aquilo"]
  if aquilo_discovery and technology_depends_on_exploration("planet-discovery-aquilo") then
    assert(
      find_group_by_item("cryogenic-science-pack") == nil,
      "cryogenic science pack should be excluded when Aquilo is gated by exploration science"
    )
  end
end)

results.check(SUITE, "science-discovery-required-count", function()
  local data_table = conditions()
  if #data_table.packs == 0 then
    assert(data_table.required_science_packs == 0, "required_science_packs should be zero for an empty pack list")
  else
    assert(
      data_table.required_science_packs >= 1 and data_table.required_science_packs <= #data_table.packs,
      "required_science_packs is outside the pack-list range"
    )
  end
end)
