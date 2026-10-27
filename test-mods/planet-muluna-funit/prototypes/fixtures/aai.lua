-- Data-stage checks for the aai-industry compatibility patch.
--
-- Muluna restricts AAI's burner entities to surfaces with oxygen >= 1 so they
-- cannot be used on Muluna, which has no breathable atmosphere. This fixture is
-- registered only when aai-industry is active; the other FUnit mod sets require
-- this file without recording any results.
local results = require("lib.results")

local SUITE = "aai"

if not mods["aai-industry"] then
  return
end

local BURNER_ENTITIES = {
  { type = "assembling-machine", name = "burner-assembling-machine" },
  { type = "lab", name = "burner-lab" },
  { type = "generator", name = "burner-turbine" },
  { type = "mining-drill", name = "burner-mining-drill" },
  { type = "inserter", name = "burner-inserter" },
}

results.check(SUITE, "aai-industry-loaded", function()
  assert(mods["aai-industry"], "aai-industry is not active in the AAI FUnit mod set")
end)

results.check(SUITE, "burner-entities-restricted-to-oxygen", function()
  local muluna = data.raw["planet"]["muluna"]
  assert(muluna, "planet muluna is missing")
  local oxygen = muluna.surface_properties and muluna.surface_properties["oxygen"]
  assert(
    oxygen == nil or oxygen < 1,
    "Muluna has oxygen >= 1, so the AAI burner restriction would not keep them off the surface"
  )

  local checked = 0
  for _, entry in ipairs(BURNER_ENTITIES) do
    local prototype = data.raw[entry.type] and data.raw[entry.type][entry.name]
    if prototype then
      checked = checked + 1
      local oxygen_condition
      for _, condition in ipairs(prototype.surface_conditions or {}) do
        if condition.property == "oxygen" then
          oxygen_condition = condition
          break
        end
      end
      assert(oxygen_condition, entry.type .. "/" .. entry.name .. " has no oxygen surface condition")
      assert(
        oxygen_condition.min == 1,
        entry.type .. "/" .. entry.name .. " oxygen condition min is "
          .. tostring(oxygen_condition.min)
          .. ", expected 1"
      )
    end
  end
  assert(checked > 0, "none of the AAI burner entities exist")
end)

results.check(SUITE, "electric-engine-unit-from-carbon-icon", function()
  local recipe = data.raw["recipe"]["electric-engine-unit-from-carbon"]
  assert(recipe, "electric-engine-unit-from-carbon recipe is missing")
  assert(recipe.icons, "electric-engine-unit-from-carbon has no icons")
  assert(
    #recipe.icons >= 2,
    "electric-engine-unit-from-carbon should have a dual icon, got " .. #recipe.icons .. " layer(s)"
  )
end)
