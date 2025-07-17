Muluna = {}

Muluna.get_stage = require("lib.get-stage").get_stage
Muluna.stage = Muluna.get_stage()
Muluna.rro = require("lib.remove-replace-object")
Muluna.img = require("lib.images")
Muluna.vectors=require("lib.vectors")





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
