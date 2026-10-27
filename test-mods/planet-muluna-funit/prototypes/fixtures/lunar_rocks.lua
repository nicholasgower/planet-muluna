-- Data-stage checks for lunar rock mining yields.
local results = require("lib.results")

local SUITE = "lunar_rocks"

local function mining_yields(name)
  local entity = data.raw["simple-entity"][name]
  assert(entity, name .. " is missing")
  assert(entity.minable, name .. " has no minable definition")
  assert(entity.minable.results, name .. " has no minable results")
  assert(entity.minable.result == nil, name .. " still has a singular minable.result")
  assert(entity.minable.count == nil, name .. " still has a singular minable.count")

  local yields = {}
  for _, result in pairs(entity.minable.results) do
    assert(result.type == "item", name .. " has a non-item mining result")
    local amount = result.amount
    if amount == nil then
      -- Other mods (for example BZ Zirconium) add range results with
      -- amount_min/amount_max instead of a fixed amount.
      assert(
        result.amount_min and result.amount_max,
        name .. " result " .. tostring(result.name) .. " has neither amount nor an amount range"
      )
      amount = (result.amount_min + result.amount_max) / 2
    end
    yields[result.name] = (yields[result.name] or 0) + amount
  end
  return yields
end

results.check(SUITE, "big-rock-yields", function()
  local yields = mining_yields("lunar-rock")
  assert(yields.stone == 15, "lunar-rock stone yield is " .. tostring(yields.stone) .. ", expected 15")
  assert(
    yields["stone-crushed"] == 5,
    "lunar-rock crushed stone yield is " .. tostring(yields["stone-crushed"]) .. ", expected 5"
  )
  assert(yields.sulfur == 2, "lunar-rock sulfur yield is " .. tostring(yields.sulfur) .. ", expected 2")
end)

results.check(SUITE, "huge-rock-yields", function()
  local yields = mining_yields("lunar-huge-rock")
  assert(yields.stone == 30, "lunar-huge-rock stone yield is " .. tostring(yields.stone) .. ", expected 30")
  assert(
    yields["stone-crushed"] == 10,
    "lunar-huge-rock crushed stone yield is " .. tostring(yields["stone-crushed"]) .. ", expected 10"
  )
  assert(yields.sulfur == 5, "lunar-huge-rock sulfur yield is " .. tostring(yields.sulfur) .. ", expected 5")
end)

results.check(SUITE, "planetslib-removal-floor-rules", function()
  local constants = data.raw["mod-data"]["Planetslib"].data
  local rules = constants.entity_removal_floors and constants.entity_removal_floors["muluna"]
  assert(rules, "Muluna has no PlanetsLib entity removal floor rules")
  for _, name in ipairs({ "lunar-rock", "lunar-huge-rock" }) do
    local rule = rules[name]
    assert(rule, name .. " has no entity removal floor rule")
    assert(rule.default_tile == "muluna-gravel", name .. " uses the wrong default tile")
    assert(rule.default_tile_item == "stone-crushed", name .. " uses the wrong default tile item")
    assert(
      rule.waiting_message and rule.waiting_message[1] == "lunar-rock-removal.waiting-for-floor",
      name .. " uses the wrong waiting message"
    )
  end
end)
