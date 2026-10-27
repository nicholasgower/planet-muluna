-- Data-stage checks for Muluna's natural tiles and their dropped-item effect.
local results = require("lib.results")

local SUITE = "muluna_tiles"
local SMOKE_NAME = "muluna-dropped-item-smoke"
local VANILLA_SMOKE_NAME = "smoke"
local VANILLA_SMOKE_DURATION = 600
local DISPERSAL_DIVISOR = 6

local function each_natural_tile(fn)
  for i = 1, 9 do
    local name = "muluna-dirt-" .. tostring(i)
    local tile = data.raw["tile"][name]
    assert(tile, name .. " is missing")
    fn(name, tile)
  end
end

local function dropped_item_smoke_name(tile)
  local trigger = tile.default_destroyed_dropped_item_trigger
  assert(trigger, "tile has no default_destroyed_dropped_item_trigger")
  local delivery = trigger.action_delivery
  assert(delivery, "dropped-item trigger has no action_delivery")
  local effects = delivery.source_effects
  assert(effects, "dropped-item trigger has no source_effects")
  assert(effects.type == "create-trivial-smoke", "dropped-item effect is not create-trivial-smoke")
  return effects.smoke_name
end

results.check(SUITE, "dropped-item-smoke-exists", function()
  assert(data.raw["trivial-smoke"][SMOKE_NAME], SMOKE_NAME .. " is missing")
end)

results.check(SUITE, "dropped-item-smoke-disperses-six-times-faster", function()
  local vanilla = data.raw["trivial-smoke"][VANILLA_SMOKE_NAME]
  assert(vanilla, VANILLA_SMOKE_NAME .. " is missing")
  assert(
    vanilla.duration == VANILLA_SMOKE_DURATION,
    "vanilla smoke duration is " .. tostring(vanilla.duration) .. ", expected " .. VANILLA_SMOKE_DURATION
  )

  local smoke = data.raw["trivial-smoke"][SMOKE_NAME]
  assert(smoke, SMOKE_NAME .. " is missing")
  assert(
    smoke.duration == VANILLA_SMOKE_DURATION / DISPERSAL_DIVISOR,
    "dropped-item smoke duration is " .. tostring(smoke.duration) .. ", expected " .. tostring(VANILLA_SMOKE_DURATION / DISPERSAL_DIVISOR)
  )
  assert(
    smoke.spread_duration == vanilla.spread_duration / DISPERSAL_DIVISOR,
    "dropped-item smoke spread_duration is " .. tostring(smoke.spread_duration)
  )
  assert(
    smoke.fade_away_duration == vanilla.fade_away_duration / DISPERSAL_DIVISOR,
    "dropped-item smoke fade_away_duration is " .. tostring(smoke.fade_away_duration)
  )
end)

results.check(SUITE, "natural-tiles-destroy-dropped-items", function()
  each_natural_tile(function(name, tile)
    assert(tile.destroys_dropped_items == true, name .. " does not destroy dropped items")
  end)
end)

results.check(SUITE, "natural-tiles-use-fast-dropped-item-smoke", function()
  each_natural_tile(function(name, tile)
    local smoke_name = dropped_item_smoke_name(tile)
    assert(smoke_name == SMOKE_NAME, name .. " uses smoke " .. tostring(smoke_name) .. ", expected " .. SMOKE_NAME)
  end)
end)
