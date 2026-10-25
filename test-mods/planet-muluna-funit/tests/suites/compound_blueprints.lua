-- Runtime tests for compound-entity blueprint support.
--
-- Blueprints only save a compound entity's parent. The parent's blueprint tags
-- use bplib to carry the subentity circuit wires and control behavior settings.
-- These tests capture those tags from a live compound entity, rebuild the parent
-- from those tags, and verify that the wires and settings came back.
local runner = require("__funit__.test_runner")
local helpers = require("__planet-muluna-funit__.tests.helpers")

local RED = defines.wire_connector_id.circuit_red
local GREEN = defines.wire_connector_id.circuit_green
local TELESCOPE_RECIPE = "muluna-telescope-observation-muluna"

local function get_constants()
  return prototypes.mod_data["muluna-constants"].data
end

local function first_entry(entries)
  runner.assert(type(entries) == "table", "constants table is missing")
  for _, entry in pairs(entries) do
    return entry
  end
  error("constants table is empty")
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

---Telescope builds need the observation recipe enabled on the player force.
local function with_telescope_recipe(fn)
  local recipe = game.forces["player"].recipes[TELESCOPE_RECIPE]
  local was_enabled = recipe and recipe.enabled
  if recipe then recipe.enabled = true end
  local ok, err = xpcall(fn, debug.traceback)
  if recipe and recipe.valid then recipe.enabled = was_enabled end
  if not ok then
    error(err, 0)
  end
end

---Build a parent without registering it, then raise the build event with tags.
---This is the same event path used by a blueprint that carries bplib tags.
local function build_parent_from_tags(surface, name, position, tags)
  local parent = helpers.entity_at(surface, name, position, { raise_built = false })
  runner.assert(parent and parent.valid, "could not create " .. name)
  script.raise_event(defines.events.script_raised_built, {
    entity = parent,
    tags = { muluna_compound = tags },
  })
  return parent
end

local function get_tags(parent)
  local tags = helpers.funit_call("get_compound_blueprint_tags", parent.unit_number)
  runner.assert(type(tags) == "table", "compound entity did not produce blueprint tags")
  runner.assert(type(tags.subentities) == "table", "compound tags have no subentities")
  return tags
end

local function get_compound_data(storage_key, unit_number)
  local storage = helpers.storage()
  local entries = storage[storage_key]
  return entries and entries[unit_number]
end

runner.test("compound blueprint: heat machine restores subentity wires", function()
  with_clean_areas(function()
    local surface = helpers.get_muluna()
    local machine = first_entry(get_constants().heat_assembling_machines)
    local center = helpers.center(helpers.muluna_area())
    local combinator_position = { x = center.x - 8, y = center.y }

    local parent = helpers.entity_at(surface, machine["assembling-machine"], center)
    local data = get_compound_data("heat_assembling_machines", parent.unit_number)
    runner.assert(data and data.reactor and data.reactor.valid, "heat machine has no reactor")

    local combinator = helpers.entity_at(surface, "constant-combinator", combinator_position)
    runner.assert(combinator and combinator.valid, "could not create the wire target")

    -- Wire the subentity to an external entity and to its own parent.
    local reactor_red = data.reactor.get_wire_connector(RED, true)
    local combinator_red = combinator.get_wire_connector(RED, true)
    runner.assert(reactor_red and combinator_red, "circuit connectors are missing")
    runner.assert(reactor_red.connect_to(combinator_red), "could not wire the reactor to the combinator")

    local reactor_green = data.reactor.get_wire_connector(GREEN, true)
    local parent_green = parent.get_wire_connector(GREEN, true)
    if reactor_green and parent_green then
      reactor_green.connect_to(parent_green)
    end

    local tags = get_tags(parent)
    parent.destroy({ raise_destroy = true })
    runner.assert(not data.reactor.valid, "reactor survived its parent")

    local rebuilt = build_parent_from_tags(surface, machine["assembling-machine"], center, tags)
    local rebuilt_data = get_compound_data("heat_assembling_machines", rebuilt.unit_number)
    runner.assert(rebuilt_data and rebuilt_data.reactor and rebuilt_data.reactor.valid, "rebuilt heat machine has no reactor")

    local rebuilt_red = rebuilt_data.reactor.get_wire_connector(RED, false)
    local rebuilt_combinator_red = combinator.get_wire_connector(RED, false)
    runner.assert(
      rebuilt_red and rebuilt_combinator_red and rebuilt_red.is_connected_to(rebuilt_combinator_red),
      "subentity wire to the external entity was not restored"
    )

    if reactor_green and parent_green then
      local rebuilt_green = rebuilt_data.reactor.get_wire_connector(GREEN, false)
      local rebuilt_parent_green = rebuilt.get_wire_connector(GREEN, false)
      runner.assert(
        rebuilt_green and rebuilt_parent_green and rebuilt_green.is_connected_to(rebuilt_parent_green),
        "subentity wire to its parent was not restored"
      )
    end
  end)
end)

runner.test("compound blueprint: heat machine restores reactor control behavior", function()
  with_clean_areas(function()
    local surface = helpers.get_muluna()
    local machine = first_entry(get_constants().heat_assembling_machines)
    local center = helpers.center(helpers.muluna_area())

    local parent = helpers.entity_at(surface, machine["assembling-machine"], center)
    local data = get_compound_data("heat_assembling_machines", parent.unit_number)
    runner.assert(data and data.reactor and data.reactor.valid, "heat machine has no reactor")

    local behavior = data.reactor.get_or_create_control_behavior()
    runner.assert(behavior, "heat reactor has no control behavior")
    behavior.read_temperature = true
    behavior.temperature_signal = { type = "virtual", name = "signal-T" }
    behavior.output_networks = { red = true, green = false }

    local tags = get_tags(parent)
    parent.destroy({ raise_destroy = true })

    local rebuilt = build_parent_from_tags(surface, machine["assembling-machine"], center, tags)
    local rebuilt_data = get_compound_data("heat_assembling_machines", rebuilt.unit_number)
    runner.assert(rebuilt_data and rebuilt_data.reactor and rebuilt_data.reactor.valid, "rebuilt heat machine has no reactor")

    local rebuilt_behavior = rebuilt_data.reactor.get_or_create_control_behavior()
    runner.assert(rebuilt_behavior, "rebuilt heat reactor has no control behavior")
    runner.assert(rebuilt_behavior.read_temperature == true, "read_temperature was not restored")
    runner.assert(
      rebuilt_behavior.temperature_signal and rebuilt_behavior.temperature_signal.name == "signal-T",
      "temperature_signal was not restored"
    )
    runner.assert(
      rebuilt_behavior.output_networks
        and rebuilt_behavior.output_networks.red == true
        and rebuilt_behavior.output_networks.green == false,
      "reactor output_networks was not restored"
    )
  end)
end)

runner.test("compound blueprint: burner roboport restores subentity wires", function()
  with_clean_areas(function()
    local surface = helpers.get_muluna()
    local machine = first_entry(get_constants().vacuum_roboports)
    local center = helpers.center(helpers.muluna_area())
    local combinator_position = { x = center.x + 8, y = center.y }

    local parent = helpers.entity_at(surface, machine.refueler, center)
    local data = get_compound_data("burner_roboports", parent.unit_number)
    runner.assert(data and data.roboport and data.roboport.valid, "burner roboport has no hidden roboport")

    local combinator = helpers.entity_at(surface, "constant-combinator", combinator_position)
    local roboport_red = data.roboport.get_wire_connector(RED, true)
    local combinator_red = combinator.get_wire_connector(RED, true)
    runner.assert(roboport_red and combinator_red, "circuit connectors are missing")
    runner.assert(roboport_red.connect_to(combinator_red), "could not wire the roboport to the combinator")

    local tags = get_tags(parent)
    parent.destroy({ raise_destroy = true })

    local rebuilt = build_parent_from_tags(surface, machine.refueler, center, tags)
    local rebuilt_data = get_compound_data("burner_roboports", rebuilt.unit_number)
    runner.assert(rebuilt_data and rebuilt_data.roboport and rebuilt_data.roboport.valid, "rebuilt burner roboport is missing its subentity")

    local rebuilt_red = rebuilt_data.roboport.get_wire_connector(RED, false)
    local rebuilt_combinator_red = combinator.get_wire_connector(RED, false)
    runner.assert(
      rebuilt_red and rebuilt_combinator_red and rebuilt_red.is_connected_to(rebuilt_combinator_red),
      "burner roboport subentity wire was not restored"
    )
  end)
end)

runner.test("compound blueprint: burner roboport restores subentity control behavior", function()
  with_clean_areas(function()
    local surface = helpers.get_muluna()
    local machine = first_entry(get_constants().vacuum_roboports)
    local center = helpers.center(helpers.muluna_area())

    local parent = helpers.entity_at(surface, machine.refueler, center)
    local data = get_compound_data("burner_roboports", parent.unit_number)
    runner.assert(data and data.roboport and data.roboport.valid, "burner roboport has no hidden roboport")

    local behavior = data.roboport.get_or_create_control_behavior()
    runner.assert(behavior, "burner roboport has no control behavior")
    behavior.read_robot_stats = true
    behavior.read_items_mode = defines.control_behavior.roboport.read_items_mode.logistics
    behavior.total_logistic_output_signal = { type = "virtual", name = "signal-A" }

    local tags = get_tags(parent)
    parent.destroy({ raise_destroy = true })

    local rebuilt = build_parent_from_tags(surface, machine.refueler, center, tags)
    local rebuilt_data = get_compound_data("burner_roboports", rebuilt.unit_number)
    runner.assert(rebuilt_data and rebuilt_data.roboport and rebuilt_data.roboport.valid, "rebuilt burner roboport is missing its subentity")

    local rebuilt_behavior = rebuilt_data.roboport.get_or_create_control_behavior()
    runner.assert(rebuilt_behavior, "rebuilt burner roboport has no control behavior")
    runner.assert(rebuilt_behavior.read_robot_stats == true, "read_robot_stats was not restored")
    runner.assert(
      rebuilt_behavior.read_items_mode == defines.control_behavior.roboport.read_items_mode.logistics,
      "read_items_mode was not restored"
    )
    runner.assert(
      rebuilt_behavior.total_logistic_output_signal
        and rebuilt_behavior.total_logistic_output_signal.name == "signal-A",
      "total_logistic_output_signal was not restored"
    )
  end)
end)

runner.test("compound blueprint: telescope tags include its combinator", function()
  with_clean_areas(function()
    local surface = helpers.get_muluna()
    local center = helpers.center(helpers.muluna_area())
    local telescope = helpers.entity_at(surface, "muluna-telescope", center)
    local data = get_compound_data("telescopes", telescope.unit_number)
    runner.assert(data and data["constant-combinator"] and data["constant-combinator"].valid, "telescope has no combinator")

    local tags = get_tags(telescope)
    runner.assert(#tags.subentities > 0, "telescope tags have no subentity entry")
    runner.assert(
      tags.subentities[1].name == data["constant-combinator"].name,
      "telescope tags do not describe its combinator"
    )
  end)
end)

runner.test("compound blueprint: telescope restores combinator control behavior", function()
  with_clean_areas(function()
    with_telescope_recipe(function()
      local surface = helpers.get_muluna()
      local center = helpers.center(helpers.muluna_area())

      local telescope = helpers.entity_at(surface, "muluna-telescope", center)
      local data = get_compound_data("telescopes", telescope.unit_number)
      runner.assert(data and data["constant-combinator"] and data["constant-combinator"].valid, "telescope has no combinator")

      local behavior = data["constant-combinator-control-behavior"]
        or data["constant-combinator"].get_or_create_control_behavior()
      runner.assert(behavior, "telescope combinator has no control behavior")
      behavior.enabled = true

      local tags = get_tags(telescope)
      telescope.destroy({ raise_destroy = true })

      local rebuilt = build_parent_from_tags(surface, "muluna-telescope", center, tags)
      local rebuilt_data = get_compound_data("telescopes", rebuilt.unit_number)
      runner.assert(rebuilt_data and rebuilt_data["constant-combinator"] and rebuilt_data["constant-combinator"].valid, "rebuilt telescope has no combinator")

      local rebuilt_behavior = rebuilt_data["constant-combinator-control-behavior"]
        or rebuilt_data["constant-combinator"].get_or_create_control_behavior()
      runner.assert(rebuilt_behavior, "rebuilt telescope combinator has no control behavior")
      runner.assert(rebuilt_behavior.enabled == true, "telescope combinator enabled state was not restored")
    end)
  end)
end)

runner.test("compound blueprint: bplib extract and overlap preserve subentity wires", function()
  with_clean_areas(function()
    local surface = helpers.get_muluna()
    local machine = first_entry(get_constants().heat_assembling_machines)
    local center = helpers.center(helpers.muluna_area())

    local parent = helpers.entity_at(surface, machine["assembling-machine"], center)
    local data = get_compound_data("heat_assembling_machines", parent.unit_number)
    runner.assert(data and data.reactor and data.reactor.valid, "heat machine has no reactor")

    local combinator = helpers.entity_at(surface, "constant-combinator", { x = center.x - 8, y = center.y })
    local reactor_red = data.reactor.get_wire_connector(RED, true)
    local combinator_red = combinator.get_wire_connector(RED, true)
    runner.assert(reactor_red.connect_to(combinator_red), "could not wire the reactor to the combinator")

    -- Build a minimal blueprint that already has an unrelated tag.
    local blueprint = helpers.blueprint_with_entities({
      { entity_number = 1, name = machine["assembling-machine"], position = { x = 0, y = 0 } },
    }, {
      [1] = { unrelated = "keep" },
    })

    -- Extraction must add the compound tag without dropping the existing tag.
    helpers.raise_bplib_event("bplib-extract", {
      entities = { [1] = parent },
      blueprint = blueprint,
    })
    local blueprint_tags = helpers.blueprint_tags(blueprint, 1)
    runner.assert(blueprint_tags.unrelated == "keep", "extraction dropped an unrelated blueprint tag")
    runner.assert(type(blueprint_tags.muluna_compound) == "table", "extraction did not add the compound tag")

    -- Simulate stamping the blueprint over the existing parent.
    reactor_red.disconnect_all()
    helpers.raise_bplib_event("bplib-overlaps", {
      overlaps = { [1] = parent },
      blueprint = blueprint,
      orientation_info = { direction = defines.direction.north },
      surface_index = surface.index,
    })

    local restored_red = data.reactor.get_wire_connector(RED, false)
    local restored_combinator_red = combinator.get_wire_connector(RED, false)
    runner.assert(
      restored_red and restored_combinator_red and restored_red.is_connected_to(restored_combinator_red),
      "overlap did not restore the subentity wire"
    )
  end)
end)

runner.test("compound blueprint: telescope extract handlers merge tags", function()
  with_clean_areas(function()
    local surface = helpers.get_muluna()
    local center = helpers.center(helpers.muluna_area())
    local telescope = helpers.entity_at(surface, "muluna-telescope", center)
    local data = get_compound_data("telescopes", telescope.unit_number)
    runner.assert(data and data["constant-combinator"] and data["constant-combinator"].valid, "telescope has no combinator")

    local blueprint = helpers.blueprint_with_entities({
      { entity_number = 1, name = "muluna-telescope", position = { x = 0, y = 0 } },
    }, {
      [1] = { unrelated = "keep" },
    })

    helpers.raise_bplib_event("bplib-extract", {
      entities = { [1] = telescope },
      blueprint = blueprint,
    })

    local tags = helpers.blueprint_tags(blueprint, 1)
    runner.assert(tags.unrelated == "keep", "telescope extraction dropped an unrelated blueprint tag")
    runner.assert(type(tags.muluna_compound) == "table", "compound handler did not add its tags")
    runner.assert(type(tags.output_asteroid_signals) == "boolean", "telescope handler did not add output_asteroid_signals")
    runner.assert(type(tags.combinator_enabled) == "boolean", "telescope handler did not add combinator_enabled")
  end)
end)

runner.test("compound blueprint: placement orientation rotates external wire targets", function()
  with_clean_areas(function()
    local surface = helpers.get_muluna()
    local machine = first_entry(get_constants().heat_assembling_machines)
    local center = helpers.center(helpers.muluna_area())

    local parent = helpers.entity_at(surface, machine["assembling-machine"], center)
    local data = get_compound_data("heat_assembling_machines", parent.unit_number)
    runner.assert(data and data.reactor and data.reactor.valid, "heat machine has no reactor")
    local parent_position = parent.position

    -- Extracted wire points 8 tiles east of the parent.
    local original_target = helpers.entity_at(surface, "constant-combinator", { x = parent_position.x + 8, y = parent_position.y })
    local reactor_red = data.reactor.get_wire_connector(RED, true)
    local original_red = original_target.get_wire_connector(RED, true)
    runner.assert(reactor_red.connect_to(original_red), "could not wire the reactor to the original target")

    local tags = get_tags(parent)
    parent.destroy({ raise_destroy = true })
    original_target.destroy({ raise_destroy = true })

    -- Rotating the blueprint east turns the +8,0 offset into 0,+8.
    local rotated_target = helpers.entity_at(surface, "constant-combinator", { x = parent_position.x, y = parent_position.y + 8 })
    runner.assert(rotated_target and rotated_target.valid, "could not create the rotated wire target")
    helpers.raise_bplib_event("bplib-positions", {
      positions = { [1] = { parent_position.x, parent_position.y } },
      orientation_info = { direction = defines.direction.east },
      surface_index = surface.index,
    })

    local rebuilt = build_parent_from_tags(surface, machine["assembling-machine"], center, tags)
    local rebuilt_data = get_compound_data("heat_assembling_machines", rebuilt.unit_number)
    runner.assert(rebuilt_data and rebuilt_data.reactor and rebuilt_data.reactor.valid, "rebuilt heat machine has no reactor")

    local rebuilt_red = rebuilt_data.reactor.get_wire_connector(RED, false)
    local rotated_red = rotated_target.get_wire_connector(RED, false)
    runner.assert(
      rebuilt_red and rotated_red and rebuilt_red.is_connected_to(rotated_red),
      "external wire target was not rotated with the blueprint"
    )
  end)
end)

runner.test("compound blueprint: unresolved subentity wires retry after the target is built", function()
  clean_areas()
  local surface = helpers.get_muluna()
  local machine = first_entry(get_constants().heat_assembling_machines)
  local center = helpers.center(helpers.muluna_area())
  local combinator_position = { x = center.x - 8, y = center.y }

  local parent = helpers.entity_at(surface, machine["assembling-machine"], center)
  local data = get_compound_data("heat_assembling_machines", parent.unit_number)
  runner.assert(data and data.reactor and data.reactor.valid, "heat machine has no reactor")

  local original_target = helpers.entity_at(surface, "constant-combinator", combinator_position)
  local reactor_red = data.reactor.get_wire_connector(RED, true)
  local target_red = original_target.get_wire_connector(RED, true)
  runner.assert(reactor_red.connect_to(target_red), "could not wire the reactor to the combinator")

  local tags = get_tags(parent)
  parent.destroy({ raise_destroy = true })
  original_target.destroy({ raise_destroy = true })

  local rebuilt = build_parent_from_tags(surface, machine["assembling-machine"], center, tags)
  local rebuilt_data = get_compound_data("heat_assembling_machines", rebuilt.unit_number)
  runner.assert(rebuilt_data and rebuilt_data.reactor and rebuilt_data.reactor.valid, "rebuilt heat machine has no reactor")

  local early_connection = rebuilt_data.reactor.get_wire_connector(RED, false)
  runner.assert(
    early_connection == nil or early_connection.connection_count == 0,
    "wire was restored before its target existed"
  )

  -- Construction robots can finish the target much later than the parent.
  runner.after_n_ticks_do(15, function()
    local ok, err = pcall(function()
      local late_target = helpers.entity_at(surface, "constant-combinator", combinator_position)
      runner.assert(late_target and late_target.valid, "could not create the late wire target")
      helpers.wait_until(runner, function()
        local source = rebuilt_data.reactor.get_wire_connector(RED, false)
        local target = late_target.get_wire_connector(RED, false)
        return source and target and source.is_connected_to(target)
      end, {
        timeout = 180,
        interval = 30,
        message = "unresolved subentity wire was not retried after the target was built",
        on_success = clean_areas,
        on_failure = clean_areas,
      })
    end)
    if not ok then
      clean_areas()
      error(err, 0)
    end
  end)
end)

runner.test("compound blueprint: malformed tags do not break compound entity builds", function()
  with_clean_areas(function()
    local surface = helpers.get_muluna()
    local machine = first_entry(get_constants().heat_assembling_machines)
    local center = helpers.center(helpers.muluna_area())

    local malformed = {
      version = 1,
      direction = "not-a-direction",
      subentities = {
        {
          name = "junk",
          control = { enabled = "not-a-boolean" },
          connectors = {
            { id = 999, links = { { id = 999, x = "x", y = {} }, "junk", { parent = true } } },
            "junk",
          },
        },
        "junk",
      },
    }

    local rebuilt = build_parent_from_tags(surface, machine["assembling-machine"], center, malformed)
    runner.assert(rebuilt and rebuilt.valid, "malformed tags prevented the parent from being built")
    local data = get_compound_data("heat_assembling_machines", rebuilt.unit_number)
    runner.assert(data and data.reactor and data.reactor.valid, "malformed tags prevented the subentity from being created")
  end)
end)

runner.test("compound blueprint: bplib positions accepts vector-style coordinates", function()
  local surface = helpers.get_muluna()
  local position = { -12345.5, -12345.5 }
  helpers.raise_bplib_event("bplib-positions", {
    positions = { [1] = position },
    orientation_info = { direction = defines.direction.north },
    surface_index = surface.index,
  })

  local key = string.format("%d:%.2f,%.2f", surface.index, position[1], position[2])
  local orientations = helpers.storage().compound_placement_orientations or {}
  runner.assert(orientations[key], "bplib vector-style position was not stored")
end)

runner.test("compound blueprint: wire offsets follow blueprint rotation and flips", function()
  -- Mirrors bplib's blueprint position transform: flips happen first, then the
  -- blueprint is rotated counter-clockwise by direction/4 quarter turns.
  local x, y = helpers.funit_call(
    "transform_compound_offset",
    { x = 2, y = 0 },
    defines.direction.east,
    false,
    false
  )
  runner.assert(x == 0 and y == 2, "east rotation should turn (2,0) into (0,2), got (" .. x .. "," .. y .. ")")

  x, y = helpers.funit_call(
    "transform_compound_offset",
    { x = 2, y = 1 },
    defines.direction.south,
    true,
    false
  )
  runner.assert(x == 2 and y == -1, "south rotation with a horizontal flip should give (2,-1), got (" .. x .. "," .. y .. ")")
end)
