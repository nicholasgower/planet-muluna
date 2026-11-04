-- Registered so the FUnit re-add test can replay this migration with an empty
-- storage table, the way Factorio does when a mod is added back to a save.
local function migrate()
-- The old placement handler only assigned the regolith digging recipe to diggers it
-- created directly. Diggers built from ghosts (for example, by construction robots) were
-- left without a recipe. PlanetsLib now assigns the recipe on every build, so give
-- existing diggers the same recipe.
local recipe = "muluna-regolith-digging"
local digger_suffix = "-ground-digger"

for _, surface in pairs(game.surfaces) do
    if surface.planet and surface.planet.name == "muluna" then
        for _, entity in pairs(surface.find_entities_filtered{type = "assembling-machine"}) do
            if string.find(entity.name, digger_suffix, 1, true) and not entity.get_recipe() then
                entity.set_recipe(recipe, "normal")
                entity.recipe_locked = true
            end
        end
    end
end

end

Muluna.migrations = Muluna.migrations or {}
Muluna.migrations["ground-digger-recipe"] = migrate
if game then migrate() end
