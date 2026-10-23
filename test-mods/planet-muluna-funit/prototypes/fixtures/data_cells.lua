-- Data-final-fixes checks for Muluna's data-port fluidbox handling.
--
-- A machine with a data port must not let a regular fluid recipe use that port.
-- Recipes get a fluidbox_index that avoids the data port. A mod that rewrites
-- a recipe after Muluna's data-final-fixes can call the public recipe-index
-- pass again to restore it.
local results = require("lib.results")

local SUITE = "data_cells"

-- Added after planet-muluna's data-final-fixes, like a recipe rewritten by a
-- later mod. It deliberately has no fluidbox_index and is fixed by calling the
-- public pass below.
local late_recipe_name = "planet-muluna-funit-late-fluid-recipe"
data:extend({
  {
    type = "recipe",
    name = late_recipe_name,
    categories = { "crafting-with-fluid" },
    hidden = true,
    enabled = true,
    energy_required = 1,
    ingredients = {
      { type = "fluid", name = "water", amount = 10 },
    },
    results = {
      { type = "item", name = "iron-gear-wheel", amount = 1 },
    },
  },
})

---Connection categories can be a string or a list of strings. Muluna sets
---"data", but another mod may append its pipe categories to the same list.
---@param value string|string[]|nil
---@return boolean
local function has_data_category(value)
  if value == "data" then
    return true
  end
  if type(value) == "table" then
    for _, category in pairs(value) do
      if category == "data" then
        return true
      end
    end
  end
  return false
end

---Return the input and output data-port positions of a machine.
---The fluidbox_index on recipes counts input and output boxes separately.
---@param machine table
---@return table
local function data_ports(machine)
  local ports = { input = {}, output = {} }
  local input_index, output_index = 0, 0
  for _, box in pairs(machine.fluid_boxes or {}) do
    local production_type = box.production_type
    if production_type == "input" then
      input_index = input_index + 1
    elseif production_type == "output" then
      output_index = output_index + 1
    end

    local is_data = has_data_category(box.connection_category)
    for _, connection in pairs(box.pipe_connections or {}) do
      if has_data_category(connection.connection_category) then
        is_data = true
        break
      end
    end

    if is_data then
      local list = ports[production_type]
      if list then
        list[#list + 1] = production_type == "input" and input_index or output_index
      end
    end
  end
  return ports
end

---Whether a recipe can be crafted in a machine with the given categories.
---Recipe categories are alternatives, not all-required flags.
---@param machine table
---@param recipe table
---@return boolean
local function is_craftable(machine, recipe)
  local recipe_categories = recipe.categories or { "crafting" }
  local available = machine.crafting_categories or {}
  for _, needed in pairs(recipe_categories) do
    for _, category in pairs(available) do
      if category == needed then
        return true
      end
    end
  end
  return false
end

---Whether a fluid entry may use this fluidbox index.
---A missing index means automatic assignment, which can use any box.
---@param entry table
---@param index number
---@return boolean
local function may_use_index(entry, index)
  local primary = entry.fluidbox_index
  if primary == nil or primary == 0 then
    return true
  end
  if primary == index then
    return true
  end
  for _, optional in pairs(entry.optional_fluidbox_indexes or {}) do
    if optional == index then
      return true
    end
  end
  return false
end

---The issue is about general/advanced assembling machines. Specialized data
---machines (data processors, scanners, and so on) use their own data fluids.
---@param machine table
---@return boolean
local function is_advanced_assembling_machine(machine)
  for _, category in pairs(machine.crafting_categories or {}) do
    if category == "crafting-with-fluid" or category == "crafting-with-fluid-and-data" then
      return true
    end
  end
  return false
end

local function data_port_machines()
  local machines = {}
  for _, machine in pairs(data.raw["assembling-machine"] or {}) do
    local ports = data_ports(machine)
    if (#ports.input > 0 or #ports.output > 0) and is_advanced_assembling_machine(machine) then
      machines[#machines + 1] = {
        name = machine.name,
        machine = machine,
        ports = ports,
      }
    end
  end
  return machines
end

results.check(SUITE, "data-port-machines-exist", function()
  local machines = data_port_machines()
  assert(#machines > 0, "no assembling machine has a data port")
end)

results.check(SUITE, "modded-fluid-category-recipe-indexed", function()
  local recipe = data.raw["recipe"]["planet-muluna-funit-fluid-recipe"]
  assert(recipe, "planet-muluna-funit-fluid-recipe is missing")

  local ingredient
  for _, entry in pairs(recipe.ingredients or {}) do
    if entry.type == "fluid" then
      ingredient = entry
      break
    end
  end
  assert(ingredient, "the modded-category test recipe has no fluid ingredient")
  assert(ingredient.fluidbox_index and ingredient.fluidbox_index ~= 0,
    "the modded-category test recipe was not given a fluidbox_index")
  assert(ingredient.optional_fluidbox_indexes,
    "the modded-category test recipe was not given optional_fluidbox_indexes")

  local machine = data.raw["assembling-machine"]["assembling-machine-3"]
  assert(machine, "assembling-machine-3 is missing")
  local ports = data_ports(machine)
  assert(#ports.input > 0, "assembling-machine-3 has no input data port")
  for _, port in pairs(ports.input) do
    assert(not may_use_index(ingredient, port),
      "the modded-category test recipe can use the data port")
  end
end)

results.check(SUITE, "late-recipe-can-be-reindexed", function()
  local recipe = data.raw["recipe"][late_recipe_name]
  assert(recipe, "the late fluid test recipe is missing")

  Muluna.data_fluids.apply_recipe_fluidbox_indexes()

  local ingredient
  for _, entry in pairs(recipe.ingredients or {}) do
    if entry.type == "fluid" then
      ingredient = entry
      break
    end
  end
  assert(ingredient, "the late fluid test recipe has no fluid ingredient")
  assert(ingredient.fluidbox_index and ingredient.fluidbox_index ~= 0,
    "the late fluid test recipe was not given a fluidbox_index")
  assert(ingredient.optional_fluidbox_indexes,
    "the late fluid test recipe was not given optional_fluidbox_indexes")

  local machine = data.raw["assembling-machine"]["assembling-machine-3"]
  assert(machine, "assembling-machine-3 is missing")
  local ports = data_ports(machine)
  assert(#ports.input > 0, "assembling-machine-3 has no input data port")
  for _, port in pairs(ports.input) do
    assert(not may_use_index(ingredient, port),
      "the late fluid test recipe can use the data port")
  end
end)

results.check(SUITE, "no-regular-fluid-can-reach-a-data-port", function()
  local machines = data_port_machines()
  assert(#machines > 0, "no assembling machine has a data port")

  local violations = {}
  for recipe_name, recipe in pairs(data.raw["recipe"] or {}) do
    for _, machine in pairs(machines) do
      if is_craftable(machine.machine, recipe) then
        local lists = {
          { "ingredient", recipe.ingredients, machine.ports.input },
          { "product", recipe.results, machine.ports.output },
        }
        for _, list in pairs(lists) do
          local kind, entries, ports = list[1], list[2], list[3]
          for _, entry in pairs(entries or {}) do
            if entry.type == "fluid" then
              for _, port in pairs(ports) do
                -- A fluid may use the data port only when it explicitly says
                -- so. Any other fluid must be pinned elsewhere.
                if may_use_index(entry, port) and entry.fluidbox_index ~= port then
                  violations[#violations + 1] = string.format(
                    "%s (%s %s) can use the data port on %s",
                    recipe_name, kind, tostring(entry.name), machine.name
                  )
                end
              end
            end
          end
        end
      end
    end
  end

  assert(#violations == 0, table.concat(violations, "; "))
end)
