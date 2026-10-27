-- Data-stage setup for the Mini/Micro Machines compatibility fixture.
--
-- Mini and Micro Machines create resized assembling machines that are shrunk
-- again by their shared data-final-fixes pass. Muluna must not add its data
-- fluidbox to those machines: the vanilla-sized pipe connection positions do
-- not fit inside the resized collision box.
--
-- The fixture mirrors that lifecycle. The machines are created at their
-- original size here and shrunk in resized_assembler_compat.lua, which runs
-- after planet-muluna's data-final-fixes.

local fixture_names = {
  "mini-assembler-3",
  "micro-assembler-3",
}

for _, name in ipairs(fixture_names) do
  local template = data.raw["assembling-machine"]["assembling-machine-3"]
  assert(template, "assembling-machine-3 is missing from the test fixtures")

  local machine = table.deepcopy(template)
  machine.name = name
  machine.localised_name = { "entity-name.assembling-machine-3" }
  machine.minable = { mining_time = 0.1, result = "assembling-machine-3" }
  data:extend({ machine })
end
