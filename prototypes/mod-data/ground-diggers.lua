--data.raw["mod-data"]["ground-diggers"]

-- data:extend{{
--     type = "mod-data",
--     name = "ground-diggers",
--     data = {
--         drills = {
--             ["electric-mining-drill"] = {
--                 name = "electric-mining-drill"
--             }
            
--         }
--     }
-- }}

Muluna.constants.regolith_drills = {
            ["electric-mining-drill"] = {
                name = "electric-mining-drill",
            },
            ["big-mining-drill"] = {
                name = "big-mining-drill",
            }
        }

if data.raw["mining-drill"]["Schall-uranium-mining-drill"] then
    Muluna.constants.regolith_drills["Schall-uranium-mining-drill"] = table.deepcopy(Muluna.constants.regolith_drills["electric-mining-drill"])
    Muluna.constants.regolith_drills["Schall-uranium-mining-drill"].name = "Schall-uranium-mining-drill"
end

Muluna.constants.regolith_drills_blacklist = { --Blacklisted drills go here
    ["seafloor-drill"] = true
}