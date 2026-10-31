-- Data-stage checks for the seedless Gleba crop greenhouse recipes.
--
-- Seedless fruit spoils, so a growth recipe that does not reset freshness makes
-- the result inherit the nutrients' freshness and every generation comes out
-- more spoiled than the last.
local results = require("lib.results")

local SUITE = "greenhouse_seedless"

local FRUITS = {"yumako", "jellynut"}
local RECIPE_SUFFIXES = {"muluna-greenhouse-growth-", "muluna-greenhouse-growth-water-saving-"}

local function find_item_result(recipe, item_name)
  local found = {}
  for _, product in pairs(recipe.results or {}) do
    if product.type == "item" and product.name == item_name then
      table.insert(found, product)
    end
  end
  return found
end

for _, fruit in pairs(FRUITS) do
  local seedless_item = data.raw["item"][fruit .. "-seedless"] or data.raw["capsule"][fruit .. "-seedless"]

  results.check(SUITE, fruit .. "-seedless-item-spoils", function()
    assert(seedless_item, fruit .. "-seedless item is missing")
    assert(seedless_item.spoil_ticks, fruit .. "-seedless item should spoil")
    assert(seedless_item.spoil_result, fruit .. "-seedless item should have a spoil result")
  end)

  results.check(SUITE, fruit .. "-processing-seedless-exists", function()
    local recipe = data.raw["recipe"][fruit .. "-processing-seedless"]
    assert(recipe, fruit .. "-processing-seedless recipe is missing")
    local inputs = recipe.ingredients or {}
    assert(
      inputs[1] and inputs[1].name == fruit .. "-seedless",
      fruit .. "-processing-seedless does not consume " .. fruit .. "-seedless"
    )
  end)

  for _, suffix in pairs(RECIPE_SUFFIXES) do
    local recipe_name = suffix .. fruit

    results.check(SUITE, recipe_name .. "-produces-fresh-seedless", function()
      local recipe = data.raw["recipe"][recipe_name]
      assert(recipe, recipe_name .. " recipe is missing")
      local products = find_item_result(recipe, fruit .. "-seedless")
      assert(#products == 1, recipe_name .. " should have exactly one " .. fruit .. "-seedless result")
      assert(
        products[1].reset_freshness_on_craft == true,
        recipe_name .. " does not reset freshness on craft, so seedless fruit inherits the nutrients' spoilage"
      )
    end)
  end
end
