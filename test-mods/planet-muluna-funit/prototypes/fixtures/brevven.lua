-- Data-stage checks for Brevven's BZ mods that have a Factorio 2.1 release.
--
-- Muluna adds BZ byproducts to regolith digging, renames the silicon-processing
-- technology, and migrates Tin's removed `probability` product field. This
-- fixture is registered only when at least one BZ mod is active.
local results = require("lib.results")

local SUITE = "brevven"

local BZ_MODS = {
  "bzcarbon",
  "bzlead",
  "bzsilicon",
  "bztin",
  "bztitanium",
  "bzzirconium",
}

local any_bz = false
for _, name in ipairs(BZ_MODS) do
  if mods[name] then
    any_bz = true
  end
end
if not any_bz then
  return
end

results.check(SUITE, "bz-mods-loaded", function()
  local loaded = {}
  for _, name in ipairs(BZ_MODS) do
    if mods[name] then
      loaded[#loaded + 1] = name
    end
  end
  assert(#loaded > 0, "no BZ mod is active in the Brevven FUnit mod set")
end)

results.check(SUITE, "regolith-digging-bz-byproducts", function()
  local recipe = data.raw["recipe"]["muluna-regolith-digging"]
  assert(recipe, "muluna-regolith-digging recipe is missing")

  local function find_result(name)
    for _, result in ipairs(recipe.results or {}) do
      if result.name == name then
        return result
      end
    end
  end

  if mods["bztitanium"] then
    local titanium = find_result("titanium-ore")
    assert(titanium, "bztitanium is loaded but regolith digging has no titanium-ore result")
    assert(
      titanium.independent_probability == 0.025,
      "regolith titanium-ore probability is "
        .. tostring(titanium.independent_probability)
        .. ", expected 0.025"
    )
  end

  if mods["bzzirconium"] then
    local zircon = find_result("zircon")
    assert(zircon, "bzzirconium is loaded but regolith digging has no zircon result")
    assert(
      zircon.independent_probability == 0.05,
      "regolith zircon probability is " .. tostring(zircon.independent_probability) .. ", expected 0.05"
    )
  end
end)

results.check(SUITE, "bztitanium-wood-gas-science", function()
  if not mods["bztitanium"] then
    return
  end
  local tech = data.raw["technology"]["wood-gas-processing-to-crude-oil"]
  assert(tech, "wood-gas-processing-to-crude-oil technology is missing")
  for _, ingredient in ipairs((tech.unit and tech.unit.ingredients) or {}) do
    assert(
      ingredient[1] ~= "space-science-pack" and ingredient[1] ~= "production-science-pack",
      "wood-gas-processing-to-crude-oil still requires " .. tostring(ingredient[1])
    )
  end
end)

results.check(SUITE, "bzsilicon-processing-alt-name", function()
  if not mods["bzsilicon"] then
    return
  end
  local tech = data.raw["technology"]["muluna-silicon-processing"]
  assert(tech, "muluna-silicon-processing technology is missing")
  assert(
    tech.localised_name and tech.localised_name[1] == "technology-name.muluna-silicon-processing-alt",
    "muluna-silicon-processing does not use the BZ alternate localised name"
  )
end)

results.check(SUITE, "bztin-probability-migrated", function()
  if not mods["bztin"] then
    return
  end
  local offenders = {}
  for name, recipe in pairs(data.raw["recipe"]) do
    for _, result in ipairs(recipe.results or {}) do
      if type(result) == "table" and result.probability ~= nil then
        offenders[#offenders + 1] = name
      end
    end
  end
  assert(
    #offenders == 0,
    "recipes still use the removed probability field: " .. table.concat(offenders, ", ")
  )
end)
