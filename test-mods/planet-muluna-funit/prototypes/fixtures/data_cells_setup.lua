-- Data-stage setup for the data-port fluidbox fixtures.
--
-- The recipe below uses a custom fluid crafting category, like the modded
-- categories (for example Castra's "castra-crafting-with-fluid") that caused
-- regular fluids to show up in Muluna's data port. It also has an unrelated
-- second category: recipe categories are alternatives, so the machine still
-- crafts it through the matching category. This mirrors electric-engine-unit,
-- which has crafting-with-fluid plus mechanics and maraxsis-hydro-plant.
-- It is added before planet-muluna's data-final-fixes so the recipe indexing
-- pass must handle it.

local category = "planet-muluna-funit-crafting-with-fluid"
local unrelated_category = "planet-muluna-funit-unrelated-category"
local recipe_name = "planet-muluna-funit-fluid-recipe"

data:extend({
  {
    type = "recipe-category",
    name = category,
    hidden = true,
  },
  {
    type = "recipe-category",
    name = unrelated_category,
    hidden = true,
  },
  {
    type = "recipe",
    name = recipe_name,
    categories = { category, unrelated_category },
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

local machine = data.raw["assembling-machine"]["assembling-machine-3"]
assert(machine, "assembling-machine-3 is missing from the test fixtures")

machine.crafting_categories = machine.crafting_categories or {}
table.insert(machine.crafting_categories, category)

-- Some mods assign one fluid_boxes array to several assembling machines
-- (Bob's assembling machines 4, 5 and 6 do this). Muluna must detach a shared
-- array before adding a data port: otherwise the first machine processed grows
-- the shared array and the remaining machines fail the "#fluid_boxes == 2"
-- check, leaving them without the data crafting category.
local shared_fluid_box_names = {
  "planet-muluna-funit-shared-fluid-boxes-1",
  "planet-muluna-funit-shared-fluid-boxes-2",
  "planet-muluna-funit-shared-fluid-boxes-3",
}

local shared_fluid_boxes = table.deepcopy(machine.fluid_boxes)
assert(#shared_fluid_boxes == 2, "assembling-machine-3 must start with two fluid boxes")

for _, name in ipairs(shared_fluid_box_names) do
  local fixture = table.deepcopy(machine)
  fixture.name = name
  fixture.localised_name = { "entity-name.assembling-machine-3" }
  fixture.minable = { mining_time = 0.1, result = "assembling-machine-3" }
  fixture.fluid_boxes = shared_fluid_boxes
  data:extend({ fixture })
end
