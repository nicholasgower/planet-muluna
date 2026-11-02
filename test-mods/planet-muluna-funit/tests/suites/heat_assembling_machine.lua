-- Runtime tests for heat assembling machines.
--
-- A heat assembling machine is an assembling machine with a hidden reactor at
-- the same position. The build handler links the two, stores them under the
-- assembling machine's unit number, and the reactor is what carries the heat
-- buffer. These tests exercise registration, the fixed recipe, reactor
-- destruction/cleanup, and independence between multiple machines.
local runner = require("__funit__.test_runner")
local helpers = require("__planet-muluna-funit__.tests.helpers")

local function get_constants()
  return prototypes.mod_data["muluna-constants"].data
end

local function get_machine_config()
  local machines = get_constants().heat_assembling_machines
  runner.assert(type(machines) == "table", "heat_assembling_machines constants are missing")
  for _, machine in pairs(machines) do
    runner.assert(machine["assembling-machine"], "heat machine entry has no assembling-machine")
    runner.assert(machine.reactor, "heat machine entry has no reactor")
    return machine
  end
  error("heat_assembling_machines constants are empty")
end

local function clean_areas()
  pcall(helpers.reset_test_areas)
end

local function with_clean_areas(fn)
  clean_areas()
  local ok, err = xpcall(fn, debug.traceback)
  clean_areas()
  if not ok then
    error(err, 0)
  end
end

local function build_machine(surface, machine, position)
  local assembler = helpers.entity_at(surface, machine["assembling-machine"], position)
  runner.assert(
    assembler and assembler.valid,
    "could not create " .. machine["assembling-machine"] .. " at ("
      .. tostring(position.x) .. ", " .. tostring(position.y) .. ")"
  )
  local data = helpers.funit_call("get_heat_assembling_machine_data", assembler.unit_number)
  runner.assert(data ~= nil, "heat assembling machine was not registered in storage")
  runner.assert(data["assembling-machine"] == assembler, "storage entry points at the wrong assembling machine")
  runner.assert(data.reactor and data.reactor.valid, "heat assembling machine has no valid reactor")
  runner.assert(data.reactor.name == machine.reactor, "reactor has the wrong prototype name")
  runner.assert(
    math.abs(data.reactor.position.x - assembler.position.x) < 0.1
      and math.abs(data.reactor.position.y - assembler.position.y) < 0.1,
    "reactor is not at the assembling machine position"
  )
  return assembler, data
end

---The fixed recipe's fluid ingredient. It is oxygen in vanilla and kr-oxygen
---when Krastorio 2 Spaced Out is loaded; derive it instead of hardcoding.
local function recipe_fluid_name(assembler)
  local recipe = assembler.prototype.fixed_recipe
  runner.assert(recipe ~= nil, "heat machine has no fixed recipe")
  for _, ingredient in pairs(recipe.ingredients) do
    if ingredient.type == "fluid" then
      return ingredient.name
    end
  end
  error("heat machine recipe has no fluid ingredient")
end

runner.test("heat assembling machine: build links a reactor and the fixed recipe", function()
  with_clean_areas(function()
    local surface = helpers.get_muluna()
    local machine = get_machine_config()
    local center = helpers.center(helpers.muluna_area())
    local assembler, data = build_machine(surface, machine, center)

    runner.assert(data.reactor.force == assembler.force, "reactor force does not match the assembling machine")
    runner.assert(data.reactor.quality.name == assembler.quality.name, "reactor quality does not match")

    local recipe = assembler.get_recipe()
    runner.assert(recipe ~= nil, "heat assembling machine has no recipe")
    runner.assert(
      recipe.name == "muluna-vacuum-heating",
      "heat assembling machine recipe should be muluna-vacuum-heating, got " .. tostring(recipe.name)
    )

    -- The heat buffer lives on the reactor, not on the assembling machine.
    local temperature = data.reactor.temperature
    runner.assert(type(temperature) == "number", "reactor does not expose a numeric temperature")
    data.reactor.temperature = 500
    runner.assert(
      math.abs(data.reactor.temperature - 500) < 1e-6,
      "reactor temperature is not writable: " .. tostring(data.reactor.temperature)
    )
  end)
end)

runner.test("heat assembling machine: script placement without raise_built stays unregistered", function()
  with_clean_areas(function()
    local surface = helpers.get_muluna()
    local machine = get_machine_config()
    local center = helpers.center(helpers.muluna_area())
    local position = { x = center.x - 25, y = center.y - 25 }

    local assembler = helpers.entity_at(surface, machine["assembling-machine"], position, { raise_built = false })
    runner.assert(assembler and assembler.valid, "could not create heat assembling machine without raise_built")
    runner.assert(
      helpers.funit_call("get_heat_assembling_machine_data", assembler.unit_number) == nil,
      "unbuilt heat assembling machine was registered in storage"
    )
    runner.assert(
      surface.find_entity(machine.reactor, position) == nil,
      "unbuilt heat assembling machine got a reactor"
    )
  end)
end)

runner.test("heat assembling machine: destroying the assembling machine removes the reactor", function()
  with_clean_areas(function()
    local surface = helpers.get_muluna()
    local machine = get_machine_config()
    local center = helpers.center(helpers.muluna_area())
    local assembler, data = build_machine(surface, machine, center)
    local unit_number = assembler.unit_number

    local ok, err = pcall(function()
      assembler.destroy({ raise_destroy = true })
    end)
    runner.assert(ok, "destroying the heat assembling machine errored: " .. tostring(err))
    runner.assert(not assembler.valid, "assembling machine is still valid after destroy")
    runner.assert(not data.reactor.valid, "linked reactor survived the assembling machine")
    runner.assert(
      helpers.funit_call("get_heat_assembling_machine_data", unit_number) == nil,
      "storage entry survived the assembling machine"
    )
  end)
end)

runner.test("heat assembling machine: destroying the reactor removes the assembling machine", function()
  with_clean_areas(function()
    local surface = helpers.get_muluna()
    local machine = get_machine_config()
    local center = helpers.center(helpers.muluna_area())
    local assembler, data = build_machine(surface, machine, center)
    local unit_number = assembler.unit_number

    local ok, err = pcall(function()
      data.reactor.destroy({ raise_destroy = true })
    end)
    runner.assert(ok, "destroying the linked reactor errored: " .. tostring(err))
    runner.assert(not data.reactor.valid, "reactor is still valid after destroy")
    runner.assert(not assembler.valid, "assembling machine survived its reactor")
    runner.assert(
      helpers.funit_call("get_heat_assembling_machine_data", unit_number) == nil,
      "storage entry survived the reactor"
    )
  end)
end)

runner.test("heat assembling machine: multiple machines are tracked independently", function()
  with_clean_areas(function()
    local surface = helpers.get_muluna()
    local machine = get_machine_config()
    local center = helpers.center(helpers.muluna_area())
    local first, first_data = build_machine(surface, machine, { x = center.x - 25, y = center.y })
    local second, second_data = build_machine(surface, machine, { x = center.x + 25, y = center.y })

    first.destroy({ raise_destroy = true })
    runner.assert(not first_data.reactor.valid, "first reactor survived its assembling machine")
    runner.assert(second.valid, "destroying the first machine invalidated the second")
    runner.assert(second_data.reactor.valid, "destroying the first machine invalidated the second reactor")
    runner.assert(
      helpers.funit_call("get_heat_assembling_machine_data", second.unit_number) ~= nil,
      "destroying the first machine removed the second storage entry"
    )
  end)
end)

runner.test("heat assembling machine: reactor fluid box links back to the machine", function()
  with_clean_areas(function()
    local surface = helpers.get_muluna()
    local machine = get_machine_config()
    local center = helpers.center(helpers.muluna_area())
    local assembler, data = build_machine(surface, machine, center)

    local linked_entity, linked_id = data.reactor.get_fluid_box_linked_connection(1)
    runner.assert(linked_entity == assembler, "reactor fluid box 1 is not linked to its assembling machine")
    runner.assert(linked_id == 1, "reactor fluid box link uses unexpected remote id " .. tostring(linked_id))
  end)
end)

runner.test("heat assembling machine: idle machine does not craft and stays cold", function()
  clean_areas()
  local surface = helpers.get_muluna()
  local machine = get_machine_config()
  local center = helpers.center(helpers.muluna_area())
  local assembler, data = build_machine(surface, machine, center)
  local fluid_name = recipe_fluid_name(assembler)
  local start_temperature = data.reactor.temperature
  local start_energy = data.reactor.energy

  runner.after_n_ticks_do(5, function()
    runner.assert(
      assembler.crafting_progress == 0,
      "idle heat machine made crafting progress: " .. tostring(assembler.crafting_progress)
    )
    runner.assert(
      data.reactor.energy == start_energy,
      "idle heat machine changed reactor energy: " .. tostring(start_energy) .. " -> " .. tostring(data.reactor.energy)
    )
    runner.assert(
      data.reactor.temperature <= start_temperature + 0.01,
      "idle heat machine heated the reactor: "
        .. tostring(start_temperature) .. " -> " .. tostring(data.reactor.temperature)
    )
    runner.assert(
      assembler.get_fluid_count(fluid_name) == 0,
      "idle heat machine unexpectedly contains " .. fluid_name
    )
    clean_areas()
  end)
end)

runner.test("heat assembling machine: fuel and the recipe fluid produce progress, heat fluid and pipe heat", function()
  clean_areas()
  local surface = helpers.get_muluna()
  local machine = get_machine_config()
  local center = helpers.center(helpers.muluna_area())
  local assembler, data = build_machine(surface, machine, center)
  local fluid_name = recipe_fluid_name(assembler)

  local oxygen_inserted = assembler.insert_fluid({ name = fluid_name, amount = 200, temperature = 15 })
  local fuel_inserted = assembler.insert({ name = "coal", count = 10 })
  runner.assert(
    oxygen_inserted == 200,
    "could not insert " .. fluid_name .. " into the heat machine, inserted " .. tostring(oxygen_inserted)
  )
  runner.assert(
    fuel_inserted == 10,
    "could not insert coal into the heat machine, inserted " .. tostring(fuel_inserted)
  )

  -- Heat is produced by the machine and carried by the linked reactor. Seed the
  -- buffer to exercise the writable reactor temperature for an existing save.
  data.reactor.temperature = 600
  runner.assert(
    data.reactor.temperature > 500,
    "could not seed the linked reactor heat buffer, temperature=" .. tostring(data.reactor.temperature)
  )
  local pipe = helpers.entity_at(surface, "heat-pipe", { center.x + 2, center.y })
  runner.assert(pipe and pipe.valid, "could not create a heat pipe next to the heat reactor")

  runner.after_n_ticks_do(10, function()
    runner.assert(
      assembler.crafting_progress > 0,
      "heat machine did not gain crafting progress, progress=" .. tostring(assembler.crafting_progress)
    )
    runner.assert(
      assembler.get_fluid_count(fluid_name) < 200,
      "heat machine did not consume " .. fluid_name .. ", remaining=" .. tostring(assembler.get_fluid_count(fluid_name))
    )
    runner.assert(
      assembler.get_fluid_count("carbon-dioxide") > 0,
      "heat machine did not produce carbon-dioxide"
    )
    runner.assert(
      data.reactor.get_fluid_count("muluna-heat") > 0,
      "linked reactor did not receive muluna-heat fluid"
    )
    runner.assert(
      data.reactor.energy > 0,
      "linked reactor heat buffer did not gain energy"
    )
    runner.assert(
      pipe.temperature > 15,
      "heat did not transfer from the reactor to the adjacent heat pipe, pipe temperature="
        .. tostring(pipe.temperature)
    )
    clean_areas()
  end)
end)

runner.test("heat assembling machine: child index resolves each machine independently", function()
  -- Regression guard for the reverse index: destroying a reactor must remove
  -- only its own pair, even with sparse unit numbers, and must not leave or
  -- delete another pair's index entry.
  with_clean_areas(function()
    local surface = helpers.get_muluna()
    local machine = get_machine_config()
    local center = helpers.center(helpers.muluna_area())
    local first, first_data = build_machine(surface, machine, { x = center.x - 25, y = center.y })
    local middle, middle_data = build_machine(surface, machine, { x = center.x, y = center.y })
    local last, last_data = build_machine(surface, machine, { x = center.x + 25, y = center.y })

    local first_reactor_unit = first_data.reactor.unit_number
    local middle_reactor_unit = middle_data.reactor.unit_number
    local last_reactor_unit = last_data.reactor.unit_number
    local children = helpers.storage().heat_assembling_machine_children
    runner.assert(type(children) == "table", "storage.heat_assembling_machine_children is missing")
    runner.assert(
      children[first_reactor_unit] == first.unit_number,
      "child index does not map the first reactor to its machine"
    )
    runner.assert(
      children[middle_reactor_unit] == middle.unit_number,
      "child index does not map the middle reactor to its machine"
    )
    runner.assert(
      children[last_reactor_unit] == last.unit_number,
      "child index does not map the last reactor to its machine"
    )

    middle_data.reactor.destroy({ raise_destroy = true })
    runner.assert(not middle.valid, "destroying the middle reactor did not remove its machine")
    runner.assert(first.valid and last.valid, "destroying the middle reactor removed another machine")

    local after = helpers.storage()
    runner.assert(
      after.heat_assembling_machine_children[middle_reactor_unit] == nil,
      "the destroyed pair left a stale child index entry"
    )
    runner.assert(
      after.heat_assembling_machine_children[first_reactor_unit] == first.unit_number,
      "destroying the middle pair removed the first pair's child index entry"
    )
    runner.assert(
      after.heat_assembling_machine_children[last_reactor_unit] == last.unit_number,
      "destroying the middle pair removed the last pair's child index entry"
    )

    -- The remaining pairs must still resolve through the index.
    last_data.reactor.destroy({ raise_destroy = true })
    runner.assert(not last.valid, "the last reactor no longer resolves to its machine")
    runner.assert(first.valid, "destroying the last pair removed the first machine")
    first_data.reactor.destroy({ raise_destroy = true })
    runner.assert(not first.valid, "the first reactor no longer resolves to its machine")
  end)
end)

runner.test("heat assembling machine: child lookup falls back when the index is missing", function()
  -- Saves created before the child index existed have storage entries but no
  -- index entry. Destroying their reactor must still find the machine by the
  -- original scan.
  with_clean_areas(function()
    local surface = helpers.get_muluna()
    local machine = get_machine_config()
    local center = helpers.center(helpers.muluna_area())
    local assembler, data = build_machine(surface, machine, { x = center.x - 25, y = center.y })
    local assembler_unit = assembler.unit_number
    local reactor_unit = data.reactor.unit_number

    helpers.funit_call("set_compound_child_index", "heat_assembling_machine_children", reactor_unit, nil)
    runner.assert(
      helpers.storage().heat_assembling_machine_children[reactor_unit] == nil,
      "could not remove the child index entry"
    )

    data.reactor.destroy({ raise_destroy = true })
    runner.assert(not assembler.valid, "the reactor did not remove its machine through the fallback scan")
    runner.assert(
      helpers.funit_call("get_heat_assembling_machine_data", assembler_unit) == nil,
      "the storage entry survived the fallback cleanup"
    )
  end)
end)

runner.test("heat assembling machine: a stale child index entry does not remove another machine", function()
  with_clean_areas(function()
    local surface = helpers.get_muluna()
    local machine = get_machine_config()
    local center = helpers.center(helpers.muluna_area())
    local first, first_data = build_machine(surface, machine, { x = center.x - 25, y = center.y })
    local second, second_data = build_machine(surface, machine, { x = center.x + 25, y = center.y })
    local first_reactor_unit = first_data.reactor.unit_number
    local second_reactor_unit = second_data.reactor.unit_number

    -- Point the first reactor at the second machine, the shape a reassigned unit
    -- number would produce.
    helpers.funit_call(
      "set_compound_child_index",
      "heat_assembling_machine_children",
      first_reactor_unit,
      second.unit_number
    )

    first_data.reactor.destroy({ raise_destroy = true })
    runner.assert(not first.valid, "the first machine survived its reactor")
    runner.assert(second.valid, "a stale index entry removed the wrong machine")
    runner.assert(second_data.reactor.valid, "a stale index entry destroyed the wrong reactor")

    local after = helpers.storage()
    runner.assert(
      after.heat_assembling_machine_children[second_reactor_unit] == second.unit_number,
      "the wrong pair's index entry was removed"
    )
    runner.assert(
      after.heat_assembling_machine_children[first_reactor_unit] == nil,
      "the destroyed pair left its index entry behind"
    )
  end)
end)

runner.test("compound: the wire retry timer starts when a wire is queued and stops when it drains", function()
  clean_areas()
  local surface = helpers.get_muluna()
  local machine = get_machine_config()
  local center = helpers.center(helpers.muluna_area())
  local assembler = build_machine(surface, machine, center)

  local queued = helpers.funit_call("queue_test_pending_wire", assembler.unit_number)
  runner.assert(queued, "could not queue a pending wire for " .. tostring(assembler.unit_number))

  local queued_state = helpers.funit_call("get_compound_retry_state")
  runner.assert(queued_state.pending == 1, "the queued wire is not pending")
  runner.assert(queued_state.enabled == true, "the retry timer did not start when a wire was queued")

  -- The placeholder wire can never resolve, so the first retry drops it.
  runner.after_n_ticks_do(35, function()
    local ok, err = pcall(function()
      local state = helpers.funit_call("get_compound_retry_state")
      runner.assert(state.pending == 0, "the retry did not drop the unresolvable wire")
      runner.assert(state.enabled == false, "the retry timer did not stop when the queue drained")
    end)
    local cleanup_ok, cleanup_err = pcall(clean_areas)
    if not ok then
      error(err, 0)
    end
    runner.assert(cleanup_ok, "cleanup failed: " .. tostring(cleanup_err))
  end)
end)

runner.test("heat assembling machine: reactor destroyed after a silent machine removal does not crash", function()
  -- A script or a deleted surface can remove the machine without raising a
  -- destroy event, leaving storage pointing at an invalid entity. Destroying the
  -- orphaned reactor must drop the pair instead of reading entity.unit_number
  -- from the invalid machine.
  with_clean_areas(function()
    local surface = helpers.get_muluna()
    local machine = get_machine_config()
    local center = helpers.center(helpers.muluna_area())
    local assembler, data = build_machine(surface, machine, center)
    local unit_number = assembler.unit_number
    local reactor_unit = data.reactor.unit_number

    assembler.destroy({ raise_destroy = false })
    runner.assert(not assembler.valid, "the machine is still valid after a silent destroy")
    runner.assert(data.reactor.valid, "the reactor died with the silently removed machine")

    local ok, err = pcall(function()
      data.reactor.destroy({ raise_destroy = true })
    end)
    runner.assert(ok, "destroying the orphaned reactor crashed: " .. tostring(err))
    runner.assert(
      helpers.funit_call("get_heat_assembling_machine_data", unit_number) == nil,
      "the orphaned pair is still in storage"
    )
    runner.assert(
      helpers.storage().heat_assembling_machine_children[reactor_unit] == nil,
      "the orphaned pair left its child index entry behind"
    )
  end)
end)
