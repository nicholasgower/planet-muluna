require("api")
local rro = Muluna.rro
-- script.on_configuration_changed(function()
--     if debug_mode then
--         log(DT .. "initialized storage")
--         log(serpent.block(storage))
--     end
--     if storage == nil then 
--         storage = {
--             ---@type table<int, LuaEntity>
--             nav_beacons = {}, -- beacon [unit_number] = LuaEntity (nav-beacon)
--             ---@type table<int, LuaSpacePlatform>
--             beacon_platforms = {}, -- beacon [unit_number] = LuaSpacePlatform
--             ---@type table<int, LuaEntity>
--             platform_beacons = {}, -- platform [index] = LuaEntity (nav-beacon)
--             ---@type table<int, LuaSpaceLocationPrototype>
--             nav_surfaces = {}, -- beacon [unit_number] = LuaSpaceLocationPrototype
--             ---@type table<int, LuaEntity>
--             beacon_electric_interfaces = {}, -- beacon [unit_number] = LuaEntity (nav-beacon-electric-interface)
--         }
--     end
-- end)


--_G.maraxsis = require "scripts.constants"
--muluna={}
--require("lib.control-stage")

local ground_digger = require("scripts.sand-extractor")
require("scripts.nav-beacon")
require("scripts.walking_particles")
--local sd = require("scripts.project-seadragon")

--muluna.finalize_events()

-- script.on_nth_tick(60,function(event)
--     local map_gen_settings = game.planets.muluna.surface.map_gen_settings
--     --map_gen_settings.autoplace_settings.entity.settings["anorthite-chunk"] == nil
--     if map_gen_settings.autoplace_settings.entity.settings["anorthite-chunk"] == nil then
--       map_gen_settings.autoplace_controls["anorthite-chunk"] = {}
--       map_gen_settings.autoplace_settings.entity.settings["anorthite-chunk"] = {}
--       game.planets.muluna.surface.map_gen_settings = map_gen_settings
--       game.planets.muluna.surface.regenerate_entity("anorthite-chunk")
--     end
-- end) 

-- script.on_event(defines.events.on_built_entity, function(event)
--     ground_digger.construct_sand_extractor(event)
-- end)

Muluna.events.finalize_events()

local new_surface = require("scripts.new-surface")

script.on_event(defines.events.on_surface_created,function(event)
    -- game.print(tostring(event.surface_index))
    -- game.print(tostring(event.tick))
    --game.print(tostring(tick))
    new_surface.on_new_surface(event.surface_index)

end

)

local interstellar_science_pack = require("scripts.interstellar-science-pack")

local function init_storage() 
    storage.players_on_muluna = {}

end

Muluna.events.on_event(Muluna.events.events.on_init(), function(event)

    init_storage() 


end)

script.on_event(defines.events.on_research_finished, function(event) interstellar_science_pack.update_interstellar_pack(event.research.force) end)
script.on_configuration_changed(function()
    storage.walking_tick_rates = {}
    for _,force in pairs(game.forces) do
        local data = prototypes.mod_data["muluna-interstellar-science-pack-conditions"].data
        local interstellar_pack_name = data.gated_technology
        force.technologies[interstellar_pack_name].researched = false
        interstellar_science_pack.update_interstellar_pack(force,false)
    end
    storage.players_on_muluna = {}
    for i,player in pairs(game.players) do
        if player.surface.name == "muluna" then
            storage.players_on_muluna[i] = player
        end
    end
end
)

if script.active_mods["gvv"] then require("__gvv__.gvv")() end