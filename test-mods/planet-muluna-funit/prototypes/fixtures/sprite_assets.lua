-- Sprite-definition checks that the data stage can verify even though the
-- headless server does not load the actual textures.
--
-- #530: muluna-lunar-regolith defines four random item pictures with
-- mipmap_count = 4, but the matching files in muluna-graphics are plain 64x64
-- images. Factorio therefore warns that mipmap level 1 belongs at
-- {64, 0; 32x32}, outside the source image. A 64x64 image carries one mipmap
-- level; four levels require a 120x64 sheet (64 + 32 + 16 + 8).
local results = require("lib.results")

local SUITE = "sprite_assets"
local ITEM_NAME = "muluna-lunar-regolith"
local EXPECTED_PICTURE_COUNT = 4

results.check(SUITE, "lunar-regolith-pictures-have-supported-mipmap-count", function()
  local item = data.raw["item"] and data.raw["item"][ITEM_NAME]
  assert(item, ITEM_NAME .. " item is missing")

  local pictures = item.pictures
  assert(type(pictures) == "table", ITEM_NAME .. ".pictures is missing")
  assert(#pictures == EXPECTED_PICTURE_COUNT,
    string.format("%s.pictures must have %d entries, got %d", ITEM_NAME, EXPECTED_PICTURE_COUNT, #pictures))

  for index, picture in ipairs(pictures) do
    assert(type(picture) == "table", string.format("%s.pictures[%d] is not a table", ITEM_NAME, index))
    assert(type(picture.filename) == "string" and picture.filename:find("lunar-regolith", 1, true),
      string.format("%s.pictures[%d] does not reference a lunar-regolith image", ITEM_NAME, index))

    local mipmap_count = picture.mipmap_count
    assert(mipmap_count == nil or mipmap_count <= 1,
      string.format(
        "%s.pictures[%d] (%s) declares %s mipmap levels, but the muluna-graphics file is a plain 64x64 image; use no mipmap_count or a 120x64 mipmapped asset",
        ITEM_NAME, index, picture.filename, tostring(mipmap_count)))
  end
end)
