require("prototypes.planet.planet")
require("prototypes.entity.index")
require("prototypes.technology.index")
require("prototypes.water-treatment")
require("prototypes.item.index")
require("prototypes.sound.index")
require("prototypes.atmosphere")
require("prototypes.recipe.index")
require("prototypes.tiles.tiles")
require("prototypes.tiles.artificial-tiles")
require("prototypes.radiation")
require("prototypes.entity.oxidized-boiler")

require("prototypes.subgroups")
require("prototypes.lunar-science-pack")
require("prototypes.technology.interstellar-technologies") --Also runs during data-updates
require("prototypes.nav-beacon")

require("compat.maraxsis")
--if mods["MT-lib"] then require("compat.MT-lib") end
if mods["any-planet-start"] then
    APS.add_planet{name = "muluna" , filename = "__planet-muluna__/compat/any-planet-start", technology = "planet-discovery-muluna"}
end
