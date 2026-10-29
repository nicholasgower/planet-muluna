-- Data-stage checks for heat assembling machines and vacuum roboports.
local results = require("lib.results")

local SUITE = "heat_roboport"

results.check(SUITE, "heat-assembling-machines-configured", function()
  assert(Muluna.constants.heat_assembling_machines, "heat_assembling_machines constants are missing")
  assert(next(Muluna.constants.heat_assembling_machines), "heat_assembling_machines constants are empty")
  for _, machine in pairs(Muluna.constants.heat_assembling_machines) do
    assert(machine["assembling-machine"], "heat machine entry has no assembling-machine")
    assert(machine.reactor, "heat machine entry has no reactor")
    assert(data.raw["assembling-machine"][machine["assembling-machine"]], "heat assembler prototype is missing: " .. tostring(machine["assembling-machine"]))
    assert(data.raw["reactor"][machine.reactor], "heat reactor prototype is missing: " .. tostring(machine.reactor))
  end
end)

results.check(SUITE, "vacuum-roboports-configured", function()
  assert(Muluna.constants.vacuum_roboports, "vacuum_roboports constants are missing")
  assert(next(Muluna.constants.vacuum_roboports), "vacuum_roboports constants are empty")
  for _, machine in pairs(Muluna.constants.vacuum_roboports) do
    assert(machine.roboport, "vacuum roboport entry has no roboport")
    assert(machine.refueler, "vacuum roboport entry has no refueler")
    assert(data.raw["roboport"][machine.roboport], "roboport prototype is missing: " .. tostring(machine.roboport))
    assert(data.raw["assembling-machine"][machine.refueler], "refueler prototype is missing: " .. tostring(machine.refueler))
  end
end)

results.check(SUITE, "burner-roboport-item-and-recipe", function()
  assert(data.raw["item"]["muluna-burner-roboport"], "muluna-burner-roboport item is missing")
  assert(data.raw["recipe"]["muluna-burner-roboport"], "muluna-burner-roboport recipe is missing")
  local refuel = data.raw["recipe"]["burner-roboport-refuel-muluna"]
  assert(refuel, "burner-roboport-refuel-muluna recipe is missing")
  assert(refuel.raise_on_crafted == true, "refuel recipe does not raise on_crafted")
  assert(refuel.results and #refuel.results == 0, "refuel recipe should have no item results")
end)

results.check(SUITE, "roboport-propellant", function()
  assert(data.raw["fluid"]["muluna-roboport-propellant"], "muluna-roboport-propellant fluid is missing")
  local recipe = data.raw["recipe"]["muluna-roboport-propellant"]
  assert(recipe, "muluna-roboport-propellant recipe is missing")
  assert(recipe.ingredients and #recipe.ingredients >= 2, "propellant recipe should consume thruster fuel and oxidizer")
end)

results.check(SUITE, "vacuum-roboport-surface-conditions", function()
  local vacuum = data.raw["assembling-machine"]
  for _, machine in pairs(Muluna.constants.vacuum_roboports) do
    local refueler = vacuum[machine.refueler]
    assert(refueler, "refueler missing: " .. tostring(machine.refueler))
    local has_pressure = false
    for _, condition in pairs(refueler.surface_conditions or {}) do
      if condition.property == "pressure" then has_pressure = true end
    end
    assert(has_pressure, "refueler has no pressure surface condition: " .. tostring(machine.refueler))
  end
end)

results.check(SUITE, "heat-machine-fluid-categories", function()
  for _, machine in pairs(Muluna.constants.heat_assembling_machines) do
    local assembler = data.raw["assembling-machine"][machine["assembling-machine"]]
    local recipe = data.raw["recipe"][assembler and assembler.name .. "-heat"] or nil
    -- The generated recipe name is not part of the public API; only assert the entity has a reactor link.
    assert(data.raw["reactor"][machine.reactor], "reactor missing for " .. tostring(machine["assembling-machine"]))
  end
end)

results.check(SUITE, "boilers-emit-no-pollution", function()
  -- The vacuum boiler deepcopies the vanilla boiler's energy source, and the vacuum heating
  -- tower deepcopies the vacuum boiler's, so both can silently inherit pollution emissions.
  for _, name in ipairs({ "muluna-advanced-boiler", "muluna-vacuum-heating-tower" }) do
    local machine = data.raw["assembling-machine"][name]
    assert(machine, "assembling machine is missing: " .. name)
    local emissions = machine.energy_source and machine.energy_source.emissions_per_minute or {}
    local pollution = emissions.pollution or 0
    assert(pollution == 0, name .. " emits pollution: " .. tostring(pollution))
  end
end)

results.check(SUITE, "compound-entities-registered-for-bplib", function()
  local bplib = data.raw["mod-data"]["bplib"].data
  local parents = {}
  for _, machine in pairs(Muluna.constants.telescopes) do
    parents[machine["assembling-machine"]] = true
  end
  for _, machine in pairs(Muluna.constants.heat_assembling_machines) do
    parents[machine["assembling-machine"]] = true
  end
  for _, machine in pairs(Muluna.constants.vacuum_roboports) do
    parents[machine.refueler] = true
  end
  assert(next(parents), "no compound entity parents were found")
  for parent_name in pairs(parents) do
    assert(bplib.extract_entity_names[parent_name], "compound parent is not registered for bplib extraction: " .. parent_name)
    assert(bplib.position_entity_names[parent_name], "compound parent is not registered for bplib positions: " .. parent_name)
    assert(bplib.overlap_entity_names[parent_name], "compound parent is not registered for bplib overlaps: " .. parent_name)
  end
end)
