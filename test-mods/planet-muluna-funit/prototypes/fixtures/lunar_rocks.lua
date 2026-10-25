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
    yields[result.name] = (yields[result.name] or 0) + result.amount
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
