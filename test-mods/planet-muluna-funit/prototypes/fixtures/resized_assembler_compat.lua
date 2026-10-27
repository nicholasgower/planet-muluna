-- Data-final-fixes checks for Mini/Micro Machines compatibility.
--
-- Mini and Micro Machines resize their assembling machines after Muluna has
-- run. The resizer only fixes up the fluidboxes it created itself, so a data
-- port appended by Muluna would keep the original pipe connection positions
-- and end up outside the resized collision box.
local results = require("lib.results")

local SUITE = "resized_assemblers"

local fixture_names = {
  "mini-assembler-3",
  "micro-assembler-3",
}

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

local function is_data_port(box)
  if has_data_category(box.connection_category) then
    return true
  end
  for _, connection in pairs(box.pipe_connections or {}) do
    if has_data_category(connection.connection_category) then
      return true
    end
  end
  return false
end

local function position_xy(position)
  return position[1] or position.x, position[2] or position.y
end

for _, name in ipairs(fixture_names) do
  local machine = data.raw["assembling-machine"][name]
  assert(machine, name .. " was not created by the fixture setup")

  -- Mimic the resizer's final pass: shrink the entity and the pipe connections
  -- it owns, but do not touch data ports added by another mod.
  machine.collision_box = { { -0.598, -0.598 }, { 0.598, 0.598 } }
  machine.selection_box = { { -0.598, -0.598 }, { 0.598, 0.598 } }
  for _, box in pairs(machine.fluid_boxes or {}) do
    if not is_data_port(box) then
      for _, connection in pairs(box.pipe_connections or {}) do
        if connection.position then
          local x, y = position_xy(connection.position)
          connection.position = { x * 0.5, y * 0.5 }
        end
      end
    end
  end
end

results.check(SUITE, "resized-assemblers-have-no-data-port", function()
  for _, name in ipairs(fixture_names) do
    local machine = data.raw["assembling-machine"][name]
    assert(machine, name .. " is missing")

    for _, category in pairs(machine.crafting_categories or {}) do
      assert(
        category ~= "crafting-with-fluid-and-data",
        name .. " still has the data crafting category"
      )
    end

    for _, box in pairs(machine.fluid_boxes or {}) do
      assert(not is_data_port(box), name .. " still has a data fluidbox")
      for _, connection in pairs(box.pipe_connections or {}) do
        if connection.position then
          local x, y = position_xy(connection.position)
          local left_top = machine.collision_box[1]
          local right_bottom = machine.collision_box[2]
          assert(
            x >= left_top[1] and x <= right_bottom[1]
              and y >= left_top[2] and y <= right_bottom[2],
            string.format(
              "%s pipe connection {%.3f, %.3f} is outside the resized collision box",
              name,
              x,
              y
            )
          )
        end
      end
    end
  end
end)
