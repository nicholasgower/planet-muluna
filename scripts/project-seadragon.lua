local Public = {}
function Public.on_built_rocket_silo(event)
    local entity = event.entity
    if not entity.valid then return end
    
    local prototype = entity.name == "entity-ghost" and entity.ghost_prototype or entity.prototype
    
    if prototype.type ~= "rocket-silo" then return end
    if not prototype.crafting_categories["rocket-building"] then return end

    local rocket_part_recipe_data = prototypes.mod_data["Planetslib-rocket-part-recipe"]
    local recipe
    if rocket_part_recipe_data[entity.surface.name] then
        recipe = rocket_part_recipe_data[entity.surface.name]
    else 
        recipe = rocket_part_recipe_data["default"]
    end
    

    if recipe == {} then return end

    entity.set_recipe(recipe)
    --if entity.get_recipe() or mods["maraxsis"] then return end
    -- if entity.surface.name == "maraxsis" then return end

    -- if entity.surface.name == "muluna" then
    --     entity.recipe_locked = false
    --     entity.set_recipe("rocket-part-muluna")
    --     entity.recipe_locked = true
    -- else
    --     entity.recipe_locked = false
    --     entity.set_recipe("rocket-part")
    --     entity.recipe_locked = true
    -- end

end


--Based on code from Maraxsis, but altered to be more general using 2.0.58's mod-data prototype 

return Public

