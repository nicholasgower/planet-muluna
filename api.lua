Muluna = {}

Muluna.get_stage = require("lib.get-stage").get_stage
Muluna.stage = Muluna.get_stage()
Muluna.rro = require("lib.remove-replace-object")
Muluna.img = require("lib.images")
Muluna.vectors=require("lib.vectors")
Muluna.multiply_energy = require("lib.energy-multiply").multiply_energy
Muluna.pipe_pictures = require("lib.pipe-pictures")

--flib imports
Muluna.flib_bounding_box = require("__flib__.bounding-box")


if Muluna.stage == "data" then
    data:extend{{
        type = "mod-data",
        name = "muluna-constants",
        data = {

        }
    }}
    Muluna.constants = data.raw["mod-data"]["muluna-constants"].data

    -- Resource generation libraries forked from vanilla 
    Muluna.resource = require("lib.resources").resource
    Muluna.resource_autoplace = require("lib.resource-autoplace")

elseif Muluna.stage == "control" then
    Muluna.constants = prototypes.mod_data["muluna-constants"].data
    Muluna.events = require("lib.events")
end 

require("prototypes.mod-data.constants")