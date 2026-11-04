-- Registered so the FUnit re-add test can replay this migration with an empty
-- storage table, the way Factorio does when a mod is added back to a save.
local function migrate()
local rro = Muluna.rro
if rro.deep_equals(storage.telescopes, {}) then
       for _,surface in pairs(game.surfaces) do
        print("searching for telescopes on " .. surface.name)
        local telescopes = surface.find_entities_filtered{name = "muluna-telescope"}
            for _,telescope in pairs(telescopes) do
                local position = telescope.position
                if telescope.unit_number and not storage.telescopes[telescope.unit_number] then
                    local combinators = surface.find_entities_filtered{position = {position.x,position.y }, name = "muluna-telescope-combinator"}
                    local combinator = combinators[1]
                    storage.telescopes[telescope.unit_number] = {
                        ["assembling-machine"] = telescope,
                        ["constant-combinator"] = combinator,
                        ["constant-combinator-control-behavior"] = combinator.get_control_behavior()
                    }
                    -- Adding the mod back rebuilds storage.telescopes from the
                    -- map, so the per-surface update index has to be rebuilt
                    -- here as well or existing telescopes stop updating.
                    if not storage.telescopes_on_surface then storage.telescopes_on_surface = {} end
                    if not storage.telescopes_on_surface[surface.name] then
                        storage.telescopes_on_surface[surface.name] = {}
                    end
                    storage.telescopes_on_surface[surface.name][telescope.unit_number] = true
                end
            end
        end 
    end

end

Muluna.migrations = Muluna.migrations or {}
Muluna.migrations["fix_broken_telescopes"] = migrate
if game then migrate() end
