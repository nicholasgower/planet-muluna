-- Core runtime smoke tests: surface generation, cargo pods, and remote storage.
local runner = require("__funit__.test_runner")
local helpers = require("__planet-muluna-funit__.tests.helpers")

local function distance_from_origin(position)
  return math.sqrt(position.x * position.x + position.y * position.y)
end

runner.test("Muluna surface can be generated", function()
  local surface = helpers.get_muluna()
  runner.assert(surface and surface.valid, "Muluna surface was not created")
  runner.assert(surface.planet and surface.planet.name == "muluna", "surface is not attached to the Muluna planet")
  runner.assert(surface.get_property("is-muluna") == 1, "is-muluna surface property is not 1")
end)

runner.test("Muluna surface has zero wind", function()
  local surface = helpers.get_muluna()
  runner.assert(surface.wind_speed == 0, "wind_speed should be 0, got " .. tostring(surface.wind_speed))
  runner.assert(surface.wind_orientation == 0, "wind_orientation should be 0")
  runner.assert(surface.wind_orientation_change == 0, "wind_orientation_change should be 0")
end)

runner.test("Cargo pods spawned on Muluna", function()
  local surface = helpers.get_muluna()
  local pods = surface.find_entities_filtered({ name = "fulgoran-cargo-pod-container" })
  runner.assert(#pods > 0, "no fulgoran-cargo-pod-container entities were spawned")
  for _, pod in pairs(pods) do
    runner.assert(distance_from_origin(pod.position) <= 200, "cargo pod spawned outside the configured drop radius")
  end
end)

runner.test("Cargo pods contain items", function()
  local surface = helpers.get_muluna()
  local pods = surface.find_entities_filtered({ name = "fulgoran-cargo-pod-container" })
  local found_item = false
  for _, pod in pairs(pods) do
    local inventory = pod.get_output_inventory()
    if inventory and not inventory.is_empty() then
      found_item = true
      break
    end
  end
  runner.assert(found_item, "all spawned cargo pods were empty")
end)

runner.test("Lunar rocks spawned on Muluna", function()
  local surface = helpers.get_muluna()
  local rocks = surface.find_entities_filtered({ name = "lunar-rock" })
  runner.assert(#rocks > 0, "no lunar-rock entities were spawned")
end)

runner.test("muluna.get_storage returns the runtime storage table", function()
  local storage = helpers.storage()
  runner.assert(type(storage) == "table", "get_storage did not return a table")
  runner.assert(type(storage.telescopes) == "table", "storage.telescopes is missing")
  runner.assert(type(storage.burner_roboports) == "table", "storage.burner_roboports is missing")
end)

runner.test("muluna_funit interface is available", function()
  local storage = helpers.funit_call("get_storage")
  runner.assert(type(storage) == "table", "muluna_funit.get_storage did not return a table")
end)
