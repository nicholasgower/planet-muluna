--[[
  This script handles populating the "Muluna" surface (presumably from a Factorio mod like Space Exploration)
  with starting items, resources, and structures placed randomly upon its creation.
--]]

-- No longer needed based on the provided code snippet
-- local rro = require("lib.remove-replace-object")

local Public = {}

-- =============================================================================
-- Configuration
-- =============================================================================

local CONFIG = {
    -- The internal name of the surface to populate
    TARGET_SURFACE_NAME = "muluna",

    -- The name of the container entity to spawn items in
    CONTAINER_ENTITY_NAME = "fulgoran-cargo-pod-container", -- Or "steel-chest", "cargo-pod", etc.

    -- The force to assign created entities/containers to
    ENTITY_FORCE = "player",

    -- How far from the center (0,0) entities can be placed initially (radius)
    PLACEMENT_RADIUS = 128,

    -- How far to search outwards from the initial random spot to find a clear location
    PLACEMENT_SEARCH_RADIUS = 16,

    -- Maximum attempts to find a non-colliding position
    MAX_PLACEMENT_ATTEMPTS = 10,

    -- Items placed in containers (Item Name -> {min_pods, max_pods, min_count_per_pod, max_count_per_pod})
    CONTAINER_ITEMS = {
        ["crusher"] = {4, 8, 1, 1},
        ["electric-furnace"] = {4, 8, 1, 1},
        ["solar-panel"] = {3, 10, 1, 3},
        ["medium-electric-pole"] = {3, 10, 1, 3},
        ["tungsten-plate"] = {1, 1, 4, 10}, -- math.random(2,5)+math.random(2,5) -> math.random(4,10)
        ["holmium-plate"] = {2, 2, 4, 10},
        ["superconductor"] = {2, 2, 4, 10},
        ["carbon-fiber"] = {1, 1, 4, 10},
        ["spoilage"] = {3, 7, 40, 100}, -- math.random(20,50)+math.random(20,50) -> math.random(40,100)
        ["tree-seed"] = {4, 4, 5, 13}, -- math.random(2,6)+math.random(3,7) -> math.random(5,13)
        ["wood"] = {1, 1, 10, 25}, -- math.random(5,12)+math.random(5,13) -> math.random(10,25)
    },

    -- Entities placed directly on the ground (Entity Name -> {min_count, max_count})
    DIRECT_ENTITIES = {
        ["lunar-rock"] = {10, 10},
    },

    -- Items placed based on active mods (Mod Name -> {item_name, min_count, max_count, probability (0-1)})
    -- Note: Probability is checked *once* per active mod in this list
    MOD_SPECIFIC_ITEMS = {
        ["moshine"] = {"moshine-tech-magnet", 4, 10, 0.7},
        ["maraxsis"] = {"maraxsis-wyrm-specimen", 4, 10, 0.7},
        ["corrundum"] = {"platinum-plate", 4, 10, 0.7},
        ["secretas"] = {"gold-plate", 4, 10, 0.7},
        ["tenebris"] = {"quartz-crystal", 4, 10, 0.7},
        ["tenebris-prime"] = {"quartz-crystal", 4, 10, 0.7}, -- Duplicate handled below if both active
        ["janus"] = {"janus-shiftite-alpha", 4, 10, 0.7},
        ["castra"] = {"nickel-plate", 4, 10, 0.7},
        ["dea-dia-system"] = {"fossil", 4, 10, 0.7},
        ["terrapalus"] = {"palusium-plate", 4, 10, 0.7},
    },

    -- Rare items placed in containers, selected via weighted roll (Item Name -> {weight, min_count, max_count})
    RARE_ITEMS = {
        {"foundry", 2, 1, 1},
        {"electromagnetic-plant", 4, 1, 1}, -- Weight 4 means needs <= 4 (total weight 2+4=6)
        {"big-mining-drill", 6, 2, 6},      -- Weight 6 means needs <= 6 (total weight 6+6=12)
        {"cryogenic-plant", 7, 1, 1},       -- Weight 7 means needs <= 7 (total weight 12+7=19)
        -- Mod specific rare items added dynamically below
    },
    RARE_ITEM_ROLL_MAX = 200, -- The max value for the weighted roll dice
}

-- Add mod-specific rare item dynamically
if script.active_mods["maraxsis"] then
    table.insert(CONFIG.RARE_ITEMS, {"maraxsis-hydro-plant", 8, 1, 1}) -- Weight 8 means <= 8 (total weight 19+8=27)
end


-- =============================================================================
-- Helper Functions
-- =============================================================================

--- Generates a random position within the configured radius around {0,0}.
-- @return table {x = number, y = number}
local function get_random_initial_position()
    local angle = math.random() * 2 * math.pi
    local radius = math.sqrt(math.random()) * CONFIG.PLACEMENT_RADIUS -- Square root for uniform distribution
    return {
        x = radius * math.cos(angle),
        y = radius * math.sin(angle)
    }
end

--- Attempts to find a clear spot and create an entity.
-- @param surface The LuaSurface to place the entity on.
-- @param entity_definition Table containing entity properties (name, position, force, etc.).
-- @return The created LuaEntity, or nil if placement failed.
local function find_and_create_entity(surface, entity_definition)
    if not surface or not surface.valid then return nil end
    if not game.entity_prototypes[entity_definition.name] then
        log("Error: Entity prototype not found: " .. entity_definition.name)
        return nil
    end

    local initial_pos = entity_definition.position or get_random_initial_position()
    local found_pos = nil

    for _ = 1, CONFIG.MAX_PLACEMENT_ATTEMPTS do
        -- find_non_colliding_position searches in a radius
        found_pos = surface.find_non_colliding_position(
            entity_definition.name,
            initial_pos,
            CONFIG.PLACEMENT_SEARCH_RADIUS,
            0.5, -- Precision
            false -- Force build
        )
        if found_pos then break end
        -- If not found, try a slightly different initial spot for the next search
        initial_pos = get_random_initial_position()
    end

    if not found_pos then
        log("Warning: Could not find non-colliding position for " .. entity_definition.name .. " near " .. serpent.line(initial_pos))
        return nil -- Failed to find a spot
    end

    entity_definition.position = found_pos
    entity_definition.force = entity_definition.force or CONFIG.ENTITY_FORCE
    entity_definition.raise_built = true -- Trigger on_built events if needed

    local placed_entity = surface.create_entity(entity_definition)

    if not placed_entity then
        log("Error: Failed to create entity " .. entity_definition.name .. " at " .. serpent.line(found_pos))
    end

    return placed_entity
end


--- Places a container and inserts items into it.
-- @param surface The LuaSurface.
-- @param item_name The name of the item to insert.
-- @param item_count The number of items to insert.
-- @return The created container LuaEntity, or nil on failure.
local function place_item_in_container(surface, item_name, item_count)
    if not game.item_prototypes[item_name] then
        log("Error: Item prototype not found: " .. item_name)
        return nil
    end

    item_count = item_count or 1
    if item_count <= 0 then return nil end -- Don't place empty containers

    local container_def = { name = CONFIG.CONTAINER_ENTITY_NAME }
    local container = find_and_create_entity(surface, container_def)

    if container and container.valid then
        local inventory = container.get_inventory(defines.inventory.chest) -- Use standard chest inventory
        if inventory then
            local inserted_count = inventory.insert({ name = item_name, count = item_count })
            if inserted_count < item_count then
                log("Warning: Could not insert full amount of " .. item_name .. " into container. Requested: " .. item_count .. ", Inserted: " .. inserted_count)
            end
            return container
        else
            log("Error: Container " .. container.name .. " does not have a standard chest inventory.")
            container.destroy() -- Clean up useless container
            return nil
        end
    end
    return nil -- Container placement failed
end

-- =============================================================================
-- Main Logic
-- =============================================================================

--- Called when a new surface is potentially created, populates it if it's the target surface.
-- @param surface_index The index of the newly created surface.
function Public.on_new_surface(surface_index)
    -- Check if the target planet/surface exists and matches the index
    local target_planet = game.planets and game.planets[CONFIG.TARGET_SURFACE_NAME]
    if not target_planet or not target_planet.surface or target_planet.surface.index ~= surface_index then
        return -- Not the surface we are looking for
    end

    local surface = target_planet.surface
    log("Populating surface '" .. CONFIG.TARGET_SURFACE_NAME .. "' (Index: " .. surface_index .. ")")

    -- 1. Place standard items in containers
    log("Placing standard items...")
    for item_name, spawn_data in pairs(CONFIG.CONTAINER_ITEMS) do
        local num_pods = math.random(spawn_data[1], spawn_data[2])
        for _ = 1, num_pods do
            local count_per_pod = math.random(spawn_data[3], spawn_data[4])
            place_item_in_container(surface, item_name, count_per_pod)
        end
    end

    -- 2. Place direct entities
    log("Placing direct entities...")
    for entity_name, spawn_data in pairs(CONFIG.DIRECT_ENTITIES) do
        local num_entities = math.random(spawn_data[1], spawn_data[2])
        for _ = 1, num_entities do
            find_and_create_entity(surface, { name = entity_name })
        end
    end

    -- 3. Place mod-specific items
    log("Checking for mod-specific items...")
    local active_mods = script.active_mods
    local placed_mod_items = {} -- Avoid placing duplicates if multiple mods provide the same item
    for mod_name, item_data in pairs(CONFIG.MOD_SPECIFIC_ITEMS) do
        if active_mods[mod_name] and not placed_mod_items[item_data[1]] then
            local probability = item_data[4]
            if math.random() <= probability then -- Check probability once per mod
                local item_name = item_data[1]
                local count = math.random(item_data[2], item_data[3])
                log("Placing mod item: " .. item_name .. " (from mod: " .. mod_name .. ")")
                place_item_in_container(surface, item_name, count)
                placed_mod_items[item_name] = true -- Mark as placed
            end
        end
    end

    -- 4. Place one rare item based on weighted roll
    log("Rolling for rare item...")
    local dice_roll = math.random(1, CONFIG.RARE_ITEM_ROLL_MAX)
    local cumulative_weight = 0
    for _, item_data in pairs(CONFIG.RARE_ITEMS) do
        cumulative_weight = cumulative_weight + item_data[2] -- Add the item's weight
        if dice_roll <= cumulative_weight then
            local item_name = item_data[1]
            local count = math.random(item_data[3], item_data[4])
            log("Placing rare item: " .. item_name .. " (Rolled " .. dice_roll .. ", Needed <= " .. cumulative_weight .. ")")
            place_item_in_container(surface, item_name, count)
            break -- Place only the first item whose threshold is met
        end
    end

    log("Surface population complete for '" .. CONFIG.TARGET_SURFACE_NAME .. "'.")
end

return Public
