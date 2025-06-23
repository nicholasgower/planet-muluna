local rro = require("lib.remove-replace-object")

require("wood-gasification.data")
require("prototypes.tips-and-tricks")
require("prototypes.technology.index")
require("prototypes.planet.planet")
require("prototypes.entity.index")
require("prototypes.water-treatment")
require("prototypes.item.index")
require("vanilla-changes.asteroid-chunk-icons")
require("prototypes.sound.index")
require("prototypes.atmosphere")
require("prototypes.recipe.index")
require("prototypes.tiles.tiles")
require("prototypes.tiles.artificial-tiles")
require("prototypes.radiation")
require("prototypes.entity.oxidized-boiler")
--null change
require("prototypes.subgroups")
require("prototypes.lunar-science-pack")
require("prototypes.technology.interstellar-technologies") --Also runs during data-updates
require("prototypes.nav-beacon")
require("prototypes.decoratives.muluna-decoratives")
require("prototypes.mod-data")


require("compat.maraxsis")
require("compat.solar-productivity")
--if mods["MT-lib"] then require("compat.MT-lib") end
if mods["any-planet-start"] then
    APS.add_planet{name = "muluna" , filename = "__planet-muluna__/compat/any-planet-start", technology = "planet-discovery-muluna"}
end

for _,lab in pairs(data.raw["lab"]) do
    if lab.name ~= "cerys-lab" then
        rro.soft_insert(lab.inputs,"interstellar-science-pack")
    end
end
