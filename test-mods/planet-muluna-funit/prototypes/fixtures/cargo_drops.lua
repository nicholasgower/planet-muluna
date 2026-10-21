-- Data-stage checks for cargo drop content and settings.
local results = require("lib.results")

local SUITE = "cargo_drops"

results.check(SUITE, "cargo-drop-spawn-imports", function()
  local imports = Muluna.constants.cargo_drop_spawn_imports
  assert(type(imports) == "table", "cargo_drop_spawn_imports is missing")
  assert(#imports > 0, "cargo_drop_spawn_imports is empty")
  for _, import in pairs(imports) do
    local spawn = require(import)
    assert(type(spawn) == "table", "cargo drop import did not return a table: " .. tostring(import))
    assert(type(spawn.pod_count) == "function", "cargo drop has no pod_count: " .. tostring(import))
    assert(type(spawn.item_quantity) == "function", "cargo drop has no item_quantity: " .. tostring(import))
  end
end)

results.check(SUITE, "rare-drop-table", function()
  local rare = Muluna.constants.cargo_drop_rare_drops
  assert(type(rare) == "table", "cargo_drop_rare_drops is missing")
  assert(next(rare), "cargo_drop_rare_drops is empty")
end)

results.check(SUITE, "cargo-drop-tech-when-locked", function()
  if settings.startup["muluna-hardcore-lock-cargo-drops"].value == true then
    assert(data.raw["technology"]["muluna-cargo-drops"], "muluna-cargo-drops technology should exist when cargo drops are locked")
  end
end)

results.check(SUITE, "cargo-pod-container-prototype", function()
  assert(data.raw["temporary-container"]["fulgoran-cargo-pod-container"], "fulgoran-cargo-pod-container is missing")
end)
