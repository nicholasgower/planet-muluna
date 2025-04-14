--[[
  This script handles populating the "Muluna" surface (presumably from a Factorio mod like Space Exploration)
  with starting items, resources, and structures placed randomly upon its creation.

  Enhanced for robustness, error handling, and deterministic placement.
--]]

-- Use serpent for detailed logging if available (optional dependency)
local serpent = serpent or require("serpent") -- Fallback require

local Public = {}

-- =============================================================================
-- Configuration (Validation Recommended during on_init/on_configuration_changed)
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
        ["tungsten-plate"] = {1, 1, 4, 10},
        ["holmium-plate"] = {2, 2, 4, 10},
        ["superconductor"] = {2, 2, 4, 10},
        ["carbon-fiber"] = {1, 1, 4, 10},
        ["spoilage"] = {3, 7, 40, 100},
        ["tree-seed"] = {4, 4, 5, 13},
        ["wood"] = {1, 1, 10, 25},
        -- Potential invalid item for testing validation: ["invalid-item-test"] = {1,1,1,1},
    },

    -- Entities placed directly on the ground (Entity Name -> {min_count, max_count})
    DIRECT_ENTITIES = {
        ["lunar-rock"] = {10, 10},
        -- Potential invalid entity for testing validation: ["invalid-entity-test"] = {1,1},
    },

    -- Items placed based on active mods (Mod Name -> {item_name, min_count, max_count, probability (0-1)})
    MOD_SPECIFIC_ITEMS = {
        ["moshine"] = {"moshine-tech-magnet", 4, 10, 0.7},
        ["maraxsis"] = {"maraxsis-wyrm-specimen", 4, 10, 0.7},
        ["corrundum"] = {"platinum-plate", 4, 10, 0.7},
        ["secretas"] = {"gold-plate", 4, 10, 0.7},
        ["tenebris"] = {"quartz-crystal", 4, 10, 0.7},
        ["tenebris-prime"] = {"quartz-crystal", 4, 10, 0.7},
        ["janus"] = {"janus-shiftite-alpha", 4, 10, 0.7},
        ["castra"] = {"nickel-plate", 4, 10, 0.7},
        ["dea-dia-system"] = {"fossil", 4, 10, 0.7},
        ["terrapalus"] = {"palusium-plate", 4, 10, 0.7},
    },

    -- Rare items placed in containers, selected via weighted roll (Item Name -> {weight, min_count, max_count})
    RARE_ITEMS = {
        {"foundry", 2, 1, 1},
        {"electromagnetic-plant", 4, 1, 1},
        {"big-mining-drill", 6, 2, 6},
        {"cryogenic-plant", 7, 1, 1},
        -- Mod specific rare items added dynamically below
    },
    RARE_ITEM_ROLL_MAX = 200,
}

-- Add mod-specific rare item dynamically (Safeguard check)
if script and script.active_mods and script.active_mods["maraxsis"] then
    -- Check if already added to prevent duplicates if config changes/reloads
    local already_added = false
    for _, item_data in ipairs(CONFIG.RARE_ITEMS) do
        if item_data[1] == "maraxsis-hydro-plant" then
            already_added = true
            break
        end
    end
    if not already_added then
        table.insert(CONFIG.RARE_ITEMS, {"maraxsis-hydro-plant", 8, 1, 1})
    end
end


-- =============================================================================
-- Helper Functions
-- =============================================================================

--- Generates a random position within the configured radius around {0,0}.
-- @return table {x = number, y = number}
local function get_random_initial_position()
    local angle = math.random() * 2 * math.pi
    local radius = math.sqrt(math.random()) * CONFIG.PLACEMENT_RADIUS
    return {
        x = radius * math.cos(angle),
        y = radius * math.sin(angle)
    }
end

--- Attempts to find a clear spot and create an entity.
-- Enhanced with prototype existence check.
-- @param surface The LuaSurface to place the entity on.
-- @param entity_definition Table containing entity properties (name, position, force, etc.).
-- @return The created LuaEntity, or nil if placement failed.
local function find_and_create_entity(surface, entity_definition)
    -- Crash Fix: Check if game and prototypes table exist
    if not game or not game.entity_prototypes then
        log("Error: game.entity_prototypes not available while trying to place entity: " .. entity_definition.name)
        return nil
    end
    if not surface or not surface.valid then return nil end

    -- Check prototype *after* confirming game.entity_prototypes exists
    if not game.entity_prototypes[entity_definition.name] then
        log("Error: Entity prototype not found: " .. entity_definition.name)
        return nil
    end

    local initial_pos = entity_definition.position or get_random_initial_position()
    local found_pos = nil

    for _ = 1, CONFIG.MAX_PLACEMENT_ATTEMPTS do
        found_pos = surface.find_non_colliding_position(
            entity_definition.name,
            initial_pos,
            CONFIG.PLACEMENT_SEARCH_RADIUS,
            0.5, -- Precision
            false -- Force build
        )
        if found_pos then break end
        initial_pos = get_random_initial_position()
    end

    if not found_pos then
        log("Warning: Could not find non-colliding position for " .. entity_definition.name .. " near " .. serpent.block(initial_pos))
        return nil
    end

    entity_definition.position = found_pos
    entity_definition.force = entity_definition.force or CONFIG.ENTITY_FORCE
    entity_definition.raise_built = true

    -- Use pcall for added safety during entity creation itself
    local ok, placed_entity = pcall(surface.create_entity, surface, entity_definition)
    if not ok then
        log("Error creating entity '" .. entity_definition.name .. "' at " .. serpent.block(found_pos) .. ": " .. tostring(placed_entity)) -- placed_entity contains error message on failure
        return nil
    end
    if not placed_entity then
        log("Error: Failed to create entity (returned nil) " .. entity_definition.name .. " at " .. serpent.block(found_pos))
        return nil -- Handle case where create_entity might return nil without erroring
    end

    return placed_entity
end


--- Places a container and inserts items into it.
-- Enhanced with prototype existence check.
-- @param surface The LuaSurface.
-- @param item_name The name of the item to insert.
-- @param item_count The number of items to insert.
-- @return The created container LuaEntity, or nil on failure.
local function place_item_in_container(surface, item_name, item_count)
    -- Crash Fix: Check if game and prototypes table exist BEFORE accessing game.item_prototypes
    if not game or not game.item_prototypes then
        log("CRITICAL Error: game.item_prototypes not available while trying to place item: " .. item_name .. ". Skipping placement.")
        -- Returning nil here prevents the crash at the original error line (154 in original paste)
        return nil
    end

    -- Check prototype *after* confirming game.item_prototypes exists
    if not game.item_prototypes[item_name] then
        log("Error: Item prototype not found: " .. item_name .. ". Skipping placement.")
        return nil
    end

    item_count = item_count or 1
    if item_count <= 0 then return nil end

    local container_def = { name = CONFIG.CONTAINER_ENTITY_NAME }
    local container = find_and_create_entity(surface, container_def)

    if container and container.valid then
        -- Use pcall for added safety when accessing inventory and inserting
        local ok, inventory = pcall(container.get_inventory, container, defines.inventory.chest)
        if not ok then
             log("Error accessing inventory for container '" .. container.name .. "': " .. tostring(inventory))
             pcall(container.destroy, container) -- Try to clean up
             return nil
        end

        if inventory then
            local ok_insert, inserted_count = pcall(inventory.insert, inventory, { name = item_name, count = item_count })
            if not ok_insert then
                log("Error inserting item '" .. item_name .. "' into container '" .. container.name .. "': " .. tostring(inserted_count))
                 -- Don't destroy container, maybe partially filled or error was temporary
                 return container -- Return container anyway, maybe partially successful
            elseif inserted_count < item_count then
                log("Warning: Could not insert full amount of " .. item_name .. " into container. Requested: " .. item_count .. ", Inserted: " .. (inserted_count or 0))
            end
            return container
        else
            log("Error: Container " .. container.name .. " does not have a standard chest inventory (defines.inventory.chest).")
            pcall(container.destroy, container) -- Try to clean up
            return nil
        end
    end
    -- Log container placement failure if find_and_create_entity didn't already
    if not container then
        log("Error: Failed to place container entity '".. CONFIG.CONTAINER_ENTITY_NAME .."' for item '"..item_name.."'")
    end
    return nil
end

-- =============================================================================
-- Configuration Validation (Call this during on_init or on_configuration_changed)
-- =============================================================================

--- Checks if item/entity names in CONFIG exist in game prototypes.
function Public.validate_config_prototypes()
    local all_valid = true
    local function check(prototype_type, name)
        if not game[prototype_type] or not game[prototype_type][name] then
            log("Configuration Error: ".. prototype_type .." '" .. name .. "' not found!")
            all_valid = false
        end
    end

    log("Validating Muluna surface population configuration...")

    -- Check container entity
    check("entity_prototypes", CONFIG.CONTAINER_ENTITY_NAME)

    -- Check standard items
    for item_name, _ in pairs(CONFIG.CONTAINER_ITEMS) do
        check("item_prototypes", item_name)
    end

    -- Check direct entities
    for entity_name, _ in pairs(CONFIG.DIRECT_ENTITIES) do
        check("entity_prototypes", entity_name)
    end

    -- Check mod-specific items (only check item name, mod activation checked at runtime)
    for mod_name, item_data in pairs(CONFIG.MOD_SPECIFIC_ITEMS) do
        check("item_prototypes", item_data[1])
    end

    -- Check rare items
    for _, item_data in ipairs(CONFIG.RARE_ITEMS) do
         -- Check if the first element is indeed the item name (string)
         if type(item_data[1]) == "string" then
             check("item_prototypes", item_data[1])
         else
             log("Configuration Error: Invalid format in RARE_ITEMS table entry: " .. serpent.block(item_data))
             all_valid = false
         end
    end

    if all_valid then
        log("Muluna configuration validation successful.")
    else
        log("Muluna configuration validation FAILED. Please check item/entity names.")
        -- Optional: game.print errors directly to player chat on config change?
    end
    return all_valid
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
        return
    end

    local surface = target_planet.surface
    log("Populating surface '" .. CONFIG.TARGET_SURFACE_NAME .. "' (Index: " .. surface_index .. ", Seed: " .. surface.seed .. ")")

    -- Seed randomness for deterministic placement per map seed
    math.randomseed(surface.seed)

    local function place_item_safely(item_name, spawn_data)
        local num_pods = math.random(spawn_data[1], spawn_data[2])
        for _ = 1, num_pods do
            local count_per_pod = math.random(spawn_data[3], spawn_data[4])
            -- Use pcall to catch errors during placement of this specific item type
            local ok, result = pcall(place_item_in_container, surface, item_name, count_per_pod)
            if not ok then
                log("Error caught placing item '" .. item_name .. "': " .. tostring(result))
            end
        end
    end

    local function place_entity_safely(entity_name, spawn_data)
         local num_entities = math.random(spawn_data[1], spawn_data[2])
         for _ = 1, num_entities do
             -- Use pcall to catch errors during placement of this specific entity type
             local ok, result = pcall(find_and_create_entity, surface, { name = entity_name })
             if not ok then
                 log("Error caught placing entity '" .. entity_name .. "': " .. tostring(result))
             end
         end
    end

    -- 1. Place standard items in containers
    log("Placing standard items...")
    for item_name, spawn_data in pairs(CONFIG.CONTAINER_ITEMS) do
        place_item_safely(item_name, spawn_data)
    end

    -- 2. Place direct entities
    log("Placing direct entities...")
    for entity_name, spawn_data in pairs(CONFIG.DIRECT_ENTITIES) do
        place_entity_safely(entity_name, spawn_data)
    end

    -- 3. Place mod-specific items
    log("Checking for mod-specific items...")
    local active_mods = script.active_mods or {} -- Safeguard if script.active_mods is nil
    local placed_mod_items = {}
    for mod_name, item_data in pairs(CONFIG.MOD_SPECIFIC_ITEMS) do
        -- Ensure item_data is structured correctly before accessing indices
        if type(item_data) == "table" and #item_data >= 4 then
             local item_name = item_data[1]
             if active_mods[mod_name] and not placed_mod_items[item_name] then
                 local probability = item_data[4]
                 if math.random() <= probability then
                     local count = math.random(item_data[2], item_data[3])
                     log("Attempting to place mod item: " .. item_name .. " (from mod: " .. mod_name .. ")")
                     -- Use pcall for safety here too
                     local ok, result = pcall(place_item_in_container, surface, item_name, count)
                     if not ok then
                         log("Error caught placing mod item '" .. item_name .. "': " .. tostring(result))
                     end
                     placed_mod_items[item_name] = true
                 end
             end
        else
             log("Warning: Invalid structure for MOD_SPECIFIC_ITEMS entry for mod '"..mod_name.."': "..serpent.block(item_data))
        end
    end

    -- 4. Place one rare item based on weighted roll
    log("Rolling for rare item...")
    local dice_roll = math.random(1, CONFIG.RARE_ITEM_ROLL_MAX)
    local cumulative_weight = 0
    for _, item_data in ipairs(CONFIG.RARE_ITEMS) do
        -- Ensure item_data is structured correctly
        if type(item_data) == "table" and #item_data >= 4 then
             local item_name = item_data[1]
             local weight = item_data[2]
             if type(item_name) == "string" and type(weight) == "number" then
                 cumulative_weight = cumulative_weight + weight
                 if dice_roll <= cumulative_weight then
                     local count = math.random(item_data[3], item_data[4])
                     log("Attempting to place rare item: " .. item_name .. " (Rolled " .. dice_roll .. ", Needed <= " .. cumulative_weight .. ")")
                     -- Use pcall for safety
                     local ok, result = pcall(place_item_in_container, surface, item_name, count)
                     if not ok then
                         log("Error caught placing rare item '" .. item_name .. "': " .. tostring(result))
                     end
                     break
                 end
             else
                 log("Warning: Invalid data types in RARE_ITEMS entry: "..serpent.block(item_data))
             end
        else
            log("Warning: Invalid structure for RARE_ITEMS entry: "..serpent.block(item_data))
        end
    end

    log("Surface population attempt complete for '" .. CONFIG.TARGET_SURFACE_NAME .. "'. Check log for any errors.")
end

return Public
