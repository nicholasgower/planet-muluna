-- Runtime tests for burner/vacuum roboports.
--
-- A burner roboport is a refueler assembling machine with a hidden roboport at
-- the same position. The refueler burns `muluna-roboport-propellant` and the
-- crafting event transfers energy into the hidden roboport. These tests cover
-- registration, the locked refuel recipe, energy transfer, full/empty statuses,
-- destruction cleanup, and the missing-storage guard.
local runner = require("__funit__.test_runner")
local helpers = require("__planet-muluna-funit__.tests.helpers")

local PROPELLANT = "muluna-roboport-propellant"
local REFUEL_RECIPE = "burner-roboport-refuel-muluna"
local STATUS_REFUELING = "custom-status.muluna-burner-roboport-refueling"
local STATUS_FULL = "custom-status.muluna-burner-roboport-full"
local STATUS_EMPTY = "custom-status.muluna-burner-roboport-empty"

local function get_constants()
  return prototypes.mod_data["muluna-constants"].data
end

local function get_roboport_config()
  local roboports = get_constants().vacuum_roboports
  runner.assert(type(roboports) == "table", "vacuum_roboports constants are missing")
  for _, machine in pairs(roboports) do
    runner.assert(machine.refueler, "vacuum roboport entry has no refueler")
    runner.assert(machine.roboport, "vacuum roboport entry has no roboport")
    return machine
  end
  error("vacuum_roboports constants are empty")
end

local function status_name(entity)
  local status = entity.custom_status
  return status and status.label and status.label[1] or nil
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

local function build_roboport(surface, machine, position)
  local refueler = helpers.entity_at(surface, machine.refueler, position)
  runner.assert(
    refueler and refueler.valid,
    "could not create " .. machine.refueler .. " at ("
      .. tostring(position.x) .. ", " .. tostring(position.y) .. ")"
  )
  local data = helpers.funit_call("get_burner_roboport_data", refueler.unit_number)
  runner.assert(data ~= nil, "burner roboport was not registered in storage")
  runner.assert(data.refueler == refueler, "storage entry points at the wrong refueler")
  runner.assert(data.roboport and data.roboport.valid, "burner roboport has no valid hidden roboport")
  runner.assert(data.roboport.name == machine.roboport, "hidden roboport has the wrong prototype name")
  runner.assert(
    math.abs(data.roboport.position.x - refueler.position.x) < 0.1
      and math.abs(data.roboport.position.y - refueler.position.y) < 0.1,
    "hidden roboport is not at the refueler position"
  )
  return refueler, data
end

runner.test("burner roboport: build links a roboport and locks the refuel recipe", function()
  with_clean_areas(function()
    local surface = helpers.get_muluna()
    local machine = get_roboport_config()
    local center = helpers.center(helpers.muluna_area())
    local refueler, data = build_roboport(surface, machine, center)

    runner.assert(data.roboport.force == refueler.force, "roboport force does not match the refueler")
    local recipe = refueler.get_recipe()
    runner.assert(recipe ~= nil, "refueler has no recipe")
    runner.assert(
      recipe.name == REFUEL_RECIPE,
      "refueler recipe should be " .. REFUEL_RECIPE .. ", got " .. tostring(recipe.name)
    )
    runner.assert(refueler.recipe_locked == true, "refueler recipe is not locked")
    runner.assert(refueler.get_fluid_count(PROPELLANT) == 0, "new refueler starts with propellant")
    runner.assert(refueler.disabled_by_script == false, "new refueler starts disabled")
    runner.assert(status_name(refueler) == STATUS_EMPTY, "new refueler is not marked empty")
    runner.assert(status_name(data.roboport) == STATUS_EMPTY, "new roboport is not marked empty")
  end)
end)

runner.test("burner roboport: propellant crafting transfers energy into the roboport", function()
  with_clean_areas(function()
    local surface = helpers.get_muluna()
    local machine = get_roboport_config()
    local center = helpers.center(helpers.muluna_area())
    local refueler, data = build_roboport(surface, machine, center)

    local inserted = refueler.insert_fluid({ name = PROPELLANT, amount = 500 })
    runner.assert(inserted > 0, "could not insert propellant into the refueler")
    runner.assert(refueler.get_fluid_count(PROPELLANT) > 0, "refueler has no propellant after insert")

    data.roboport.energy = 0
    local ok, err = pcall(helpers.funit_call, "short_update_roboport", refueler.unit_number)
    runner.assert(ok, "short_update_roboport errored: " .. tostring(err))
    runner.assert(data.roboport.energy > 0, "short_update_roboport did not add energy")
    runner.assert(refueler.disabled_by_script == false, "refueler disabled before reaching full energy")
    runner.assert(status_name(refueler) == STATUS_REFUELING, "refueler status is not refueling")
    runner.assert(status_name(data.roboport) == STATUS_REFUELING, "roboport status is not refueling")
  end)
end)

runner.test("burner roboport: reaching the high-energy cutoff disables the refueler", function()
  with_clean_areas(function()
    local surface = helpers.get_muluna()
    local machine = get_roboport_config()
    local center = helpers.center(helpers.muluna_area())
    local refueler, data = build_roboport(surface, machine, center)

    refueler.insert_fluid({ name = PROPELLANT, amount = 500 })
    data.roboport.energy = 1e15

    local ok, err = pcall(helpers.funit_call, "short_update_roboport", refueler.unit_number)
    runner.assert(ok, "short_update_roboport errored at full energy: " .. tostring(err))
    runner.assert(refueler.disabled_by_script == true, "refueler is not disabled at full energy")
    runner.assert(status_name(refueler) == STATUS_FULL, "refueler status is not full")
    runner.assert(status_name(data.roboport) == STATUS_FULL, "roboport status is not full")
  end)
end)

runner.test("burner roboport: short update is safe without a registered refueler", function()
  with_clean_areas(function()
    local surface = helpers.get_muluna()
    local machine = get_roboport_config()
    local center = helpers.center(helpers.muluna_area())
    local refueler = helpers.entity_at(
      surface,
      machine.refueler,
      { x = center.x - 25, y = center.y },
      { raise_built = false }
    )
    runner.assert(refueler and refueler.valid, "could not create an unregistered refueler")
    runner.assert(
      helpers.funit_call("get_burner_roboport_data", refueler.unit_number) == nil,
      "unbuilt refueler was registered in storage"
    )

    local ok, err = pcall(helpers.funit_call, "short_update_roboport", refueler.unit_number)
    runner.assert(ok, "short_update_roboport errored without storage: " .. tostring(err))
  end)
end)

runner.test("burner roboport: destroying the refueler removes the roboport", function()
  with_clean_areas(function()
    local surface = helpers.get_muluna()
    local machine = get_roboport_config()
    local center = helpers.center(helpers.muluna_area())
    local refueler, data = build_roboport(surface, machine, center)
    local unit_number = refueler.unit_number

    local ok, err = pcall(function()
      refueler.destroy({ raise_destroy = true })
    end)
    runner.assert(ok, "destroying the refueler errored: " .. tostring(err))
    runner.assert(not refueler.valid, "refueler is still valid after destroy")
    runner.assert(not data.roboport.valid, "hidden roboport survived the refueler")
    runner.assert(
      helpers.funit_call("get_burner_roboport_data", unit_number) == nil,
      "storage entry survived the refueler"
    )
    runner.assert(
      helpers.storage().active_burner_roboports[unit_number] == nil,
      "refueler survived in active_burner_roboports"
    )
  end)
end)

runner.test("burner roboport: destroying the roboport removes the refueler", function()
  with_clean_areas(function()
    local surface = helpers.get_muluna()
    local machine = get_roboport_config()
    local center = helpers.center(helpers.muluna_area())
    local refueler, data = build_roboport(surface, machine, center)
    local unit_number = refueler.unit_number

    local ok, err = pcall(function()
      data.roboport.destroy({ raise_destroy = true })
    end)
    runner.assert(ok, "destroying the hidden roboport errored: " .. tostring(err))
    runner.assert(not data.roboport.valid, "roboport is still valid after destroy")
    runner.assert(not refueler.valid, "refueler survived its hidden roboport")
    runner.assert(
      helpers.funit_call("get_burner_roboport_data", unit_number) == nil,
      "storage entry survived the hidden roboport"
    )
  end)
end)

runner.test("burner roboport: multiple roboports are tracked independently", function()
  with_clean_areas(function()
    local surface = helpers.get_muluna()
    local machine = get_roboport_config()
    local center = helpers.center(helpers.muluna_area())
    local first, first_data = build_roboport(surface, machine, { x = center.x - 25, y = center.y })
    local second, second_data = build_roboport(surface, machine, { x = center.x + 25, y = center.y })

    first.destroy({ raise_destroy = true })
    runner.assert(not first_data.roboport.valid, "first roboport survived its refueler")
    runner.assert(second.valid, "destroying the first refueler invalidated the second")
    runner.assert(second_data.roboport.valid, "destroying the first refueler invalidated the second roboport")
    runner.assert(
      helpers.funit_call("get_burner_roboport_data", second.unit_number) ~= nil,
      "destroying the first refueler removed the second storage entry"
    )
  end)
end)

runner.test("burner roboport: raise_on_crafted refuels without a remote call", function()
  clean_areas()
  local surface = helpers.get_muluna()
  local machine = get_roboport_config()
  local center = helpers.center(helpers.muluna_area())
  local refueler, data = build_roboport(surface, machine, center)
  local constants = get_constants()
  local expected_energy = constants.burner_roboport_fluid_per_craft * 0.1 * 1000000

  local recipe_prototype = prototypes.recipe[REFUEL_RECIPE]
  runner.assert(
    recipe_prototype and recipe_prototype.on_crafted_event ~= nil,
    REFUEL_RECIPE .. " has no on_crafted_event"
  )

  local inserted = refueler.insert_fluid({ name = PROPELLANT, amount = 1000 })
  runner.assert(inserted == 1000, "could not insert roboport propellant, inserted " .. tostring(inserted))
  data.roboport.energy = 0
  refueler.crafting_progress = 0.999

  runner.after_n_ticks_do(3, function()
    runner.assert(
      data.roboport.energy >= expected_energy,
      "raise_on_crafted did not refuel the roboport, energy=" .. tostring(data.roboport.energy)
        .. " expected at least " .. tostring(expected_energy)
    )
    runner.assert(
      refueler.get_fluid_count(PROPELLANT) < 1000,
      "refueler did not consume propellant while crafting"
    )
    runner.assert(
      status_name(refueler) == STATUS_REFUELING,
      "refueler status after raise_on_crafted is " .. tostring(status_name(refueler))
    )
    clean_areas()
  end)
end)
