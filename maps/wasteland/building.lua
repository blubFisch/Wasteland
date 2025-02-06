local Public = {}

local math_floor = math.floor
local table_insert = table.insert
local ScenarioTable = require 'maps.wasteland.table'
local PvPShield = require 'maps.wasteland.pvp_shield'
local TeamBasics = require 'maps.wasteland.team_basics'
local MapLayout = require 'maps.wasteland.map_layout'
local Utils = require 'maps.wasteland.utils'

local town_zoning_entity_types = {"ammo-turret", "electric-turret", "fluid-turret"}
local default_protected_radius = 30
local turret_protected_radius = 42
local base_town_protected_size = (MapLayout.league_balance_shield_size - 1) / 2 + turret_protected_radius

local ghost_time_after_destruction = 168 * 60 * 60 * 60 -- Note: After unlocking construction bots tech. This might not be stable after engine changes
local ghost_age_to_prevent_building = 60 * 60

local NEAR_TOWN_CENTER = 1
local NEAR_TOWN_TURRET = 2
local NEAR_TOWN_TURRET_GHOST = 3
local NEAR_TOWN_SHIELD = 4

local REASON_TEXTS = {
    [NEAR_TOWN_CENTER] = "town center",
    [NEAR_TOWN_TURRET] = "turret",
    [NEAR_TOWN_TURRET_GHOST] = "recently destroyed turret blueprint (max " .. ghost_age_to_prevent_building / 60 .. " sec)",
    [NEAR_TOWN_SHIELD] = "PvP shield"
}

-- these should be allowed to place inside any base by anyone as neutral
local allowed_entities_neutral = {
    ['burner-inserter'] = true,
    ['coin'] = true,
    ['express-loader'] = true,
    ['fast-inserter'] = true,
    ['fast-loader'] = true,
    ['inserter'] = true,
    ['iron-chest'] = true,
    ['loader'] = true,
    ['long-handed-inserter'] = true,
    ['raw-fish'] = true,
    ['bulk-inserter'] = true,
    ['steel-chest'] = true,
    ['wooden-chest'] = true,
    ['transport-belt'] = true,
    ['fast-transport-belt'] = true,
    ['express-transport-belt'] = true,
    ['underground-belt'] = true,
    ['fast-underground-belt'] = true,
    ['express-underground-belt'] = true,
    ['splitter'] = true,
    ['fast-splitter'] = true,
    ['express-splitter'] = true,
    ['straight-rail'] = true,
    ['curved-rail'] = true,
    ['rail-signal'] = true,
    ['rail-chain-signal'] = true
}

local allowed_entities_keep_force = {
    ['car'] = true,
    ['tank'] = true,
    ['locomotive'] = true,
    ['cargo-wagon'] = true,
    ['fluid-wagon'] = true,
    ['train-stop'] = true,  -- This needs to be here so automatic routes work
}

local ignore_neutral_build_feature = {
    ["entity-ghost"] = true,
    ["roboport"] = true,
    ["electric-pole"] = true
}

local function refund_item(event, item_name)
    if item_name == 'blueprint' then
        return
    end

    if event.player_index ~= nil then
        game.players[event.player_index].insert({name = item_name, count = 1})
        return
    end

    -- return item to robot, but don't replace ghost (otherwise might loop)
    if event.robot ~= nil then
        local inventory = event.robot.get_inventory(defines.inventory.robot_cargo)
        inventory.insert({name = item_name, count = 1})
        return
    end
end

function Public.in_range(pos1, pos2, radius)
    local dx = pos1.x - pos2.x
    local dy = pos1.y - pos2.y
    if dx ^ 2 + dy ^ 2 < radius ^ 2 then
        return true
    end
    return false
end

function Public.in_area(position, area_center, area_radius)
    local dist_east = position.x - (area_center.x + area_radius)
    local dist_west = (area_center.x - area_radius) - position.x
    if dist_east < 0 and dist_west < 0 then
        local dist_north = (area_center.y - area_radius) - position.y
        local dist_south = position.y - (area_center.y + area_radius)
        if dist_south < 0 and dist_north < 0 then
            return true, -math.max(dist_east, dist_west, dist_north, dist_south)
        end
    end
    return false
end

function Public.near_outlander_town(my_force, position, surface, radius)
    local entities = surface.find_entities_filtered({ position = position, radius = radius, type=town_zoning_entity_types})
    for _, entity in pairs(entities) do
        if not TeamBasics.is_friendly_towards(my_force, entity.force) then
            return true
        end
    end
    return false
end

function Public.near_another_town(my_force_name, position, surface, radius, radius_center, include_ghosts)
    local this = ScenarioTable.get_table()
    local enemy_force_names = {}

    if not radius_center then radius_center = radius end

    -- Nearby town centers
    for _, town_center in pairs(this.town_centers) do
        local market_force_name = town_center.market.force.name
        if my_force_name ~= market_force_name then
            local in_area, distance = Public.in_area(position, town_center.market.position, radius_center)
            if in_area then
                return true, NEAR_TOWN_CENTER, distance
            end
            table_insert(enemy_force_names, market_force_name)
        end
    end

    if table.size(enemy_force_names) > 0 then
        -- Nearby town zoning entities
        if surface.count_entities_filtered({ position = position, radius = radius,
                                             force = enemy_force_names, type=town_zoning_entity_types, limit = 1}) > 0 then
            return true, NEAR_TOWN_TURRET
        end

        -- Prevent placing turrets to block an enemy base from rebuilding itself (turret creep)
        if include_ghosts then
            local ghosts = surface.find_entities_filtered({ position = position, radius = radius,
                                                            force = enemy_force_names, type='entity-ghost',
                                                            ghost_type=town_zoning_entity_types})
            for _, ghost in pairs(ghosts) do
                local ghost_age = ghost_time_after_destruction - ghost.time_to_live
                --game.print("XDB " .. ghost.type .. " " .. ghost_age)
                if ghost_age > 0 and ghost_age < ghost_age_to_prevent_building then
                    return true, NEAR_TOWN_TURRET_GHOST
                end
            end
        end
    end
    return false
end

function Public.is_out_of_map(surface, position)
    if surface.name ~= 'nauvis' then
        return false
    end
    local chunk_position = {}
    chunk_position.x = math_floor(position.x / 32)
    chunk_position.y = math_floor(position.y / 32)
    if chunk_position.x <= -33 or chunk_position.x >= 32 or chunk_position.y <= -33 or chunk_position.y >= 32 then
        return true
    end
    return false
end

local function prevent_entity_in_restricted_zone(event)
    local player_index = event.player_index or nil
    local entity = event.entity
    if entity == nil or not entity.valid then
        return
    end
    local name = entity.name
    local surface = entity.surface
    local position = entity.position
    local error = false
    if Public.is_out_of_map(surface, position) then
        error = true
        entity.destroy()
        local item = event.item
        if name ~= 'entity-ghost' and name ~= 'tile-ghost' and item ~= nil then
            refund_item(event, item.name)
        end
    end
    if error == true then
        local player
        if player_index then player = game.players[player_index] end
        Utils.build_error_notification(player, surface, position, 'Can not build out of map!', player)
    end
end

local function prevent_landfill_in_restricted_zone(event)
    local player_index = event.player_index or nil
    local tile = event.tile
    if tile == nil or not tile.valid then
        return
    end
    local surface = game.surfaces[event.surface_index]
    local fail = false
    local position
    for _, t in pairs(event.tiles) do
        local old_tile = t.old_tile
        position = t.position
        if Public.is_out_of_map(surface, position) then
            fail = true
            surface.set_tiles({{name = old_tile.name, position = position}}, true)
            refund_item(event, event.item.name)
        end
    end
    if fail == true then
        local player
        if player_index ~= nil then player = game.players[player_index] end
        Utils.build_error_notification(player, surface, position, 'Can not build out of map!', player)
    end
    return fail
end

local function process_built_entities(event)
    local player_index = event.player_index or nil
    local entity = event.entity
    if entity == nil or not entity.valid then
        return
    end
    if entity.name == 'linked-chest' then
        return  -- let town_center logic handle it
    end

    local name = entity.name
    local surface = entity.surface
    local position = entity.position
    local force
    local force_name
    local player
    if player_index ~= nil then
        player = game.players[player_index]
        force = player.force
        force_name = force.name
    else
        local robot = event.robot
        force = robot.force
        force_name = force.name
    end

    -- Handle entities placed within protected areas
    if not allowed_entities_keep_force[name] then  -- Some entities like vehicles are always ok to place
        local radius = default_protected_radius
        local prevented_by_ghosts = false

        if table.array_contains(town_zoning_entity_types, entity.type) then
            radius = turret_protected_radius -- Prevent using these entities offensively to stop a base from replacing entities of itself
            prevented_by_ghosts = true
        end

        local in_protected_zone = false
        local reason

        in_protected_zone, reason = Public.near_another_town(force_name, position, surface, radius, radius + base_town_protected_size, prevented_by_ghosts)

        if not in_protected_zone and PvPShield.protected_by_shields(surface, position, force, radius) then
            in_protected_zone = true
            reason = NEAR_TOWN_SHIELD
        end

        if in_protected_zone then
            -- Logistics are okay to place wherever you can access (=outside of shield)
            if allowed_entities_neutral[name] and not (PvPShield.protected_by_shields(surface, position, force, 0)
                    or Public.near_another_town(force_name, position, surface, 10, 0)) then
                entity.force = game.forces['neutral']   -- Place as neutral to make sure they can interact with everything
                surface.create_entity({name = 'flying-text', position = position,
                                       text = "Neutral", color = {r = 0, g = 1, b = 0}})
            else
                -- Prevent building
                entity.destroy()
                Utils.build_error_notification(player or force, surface, position, "Can't build near " .. REASON_TEXTS[reason], player)
                if name ~= 'entity-ghost' then
                    if event.stack.valid_for_read then
                        refund_item(event, event.stack.name)
                    end
                end
                return
            end
        end
    end

    -- Feature to build neutral = all players can access + robots will ignore
    local players_prefs = ScenarioTable.get().players[player_index]
    if entity.force ~= game.forces['neutral'] and players_prefs and players_prefs.neutral_building
        and not allowed_entities_keep_force[name] then
        if not ignore_neutral_build_feature[entity.type] and not table.array_contains(town_zoning_entity_types, entity.type) then
            entity.force = game.forces['neutral']
            surface.create_entity({name = 'flying-text', position = position,
                                   text = "Neutral (setting)", color = {r = 0, g = 1, b = 0}})
        else
            surface.create_entity({name = 'flying-text', position = position,
                                   text = "Can't build neutral (Setting)", color = {r = 0, g = 1, b = 1}})
        end
    end

    -- Prevent power poles of different forces from connecting to each other
    if entity.type == 'electric-pole' then
        for _, other_pole in pairs(entity.neighbours["copper"]) do
            if other_pole.force ~= force then
                entity.disconnect_neighbour(other_pole)
                Utils.build_error_notification(player or force, surface, position, "Can't connect to other town", player)
            end
        end
    end
end

local function prevent_tiles_near_towns(event)
    local player_index = event.player_index or nil
    local tile = event.tile
    if tile == nil or not tile.valid then
        return
    end
    local surface = game.surfaces[event.surface_index]
    local force_name
    if player_index ~= nil then
        local player = game.players[player_index]
        if player ~= nil then
            local force = player.force
            if force ~= nil then
                force_name = force.name
            end
        end
    else
        local robot = event.robot
        if robot ~= nil then
            local force = robot.force
            if force ~= nil then
                force_name = force.name
            end
        end
    end
    local fail = false
    local position
    for _, t in pairs(event.tiles) do
        local old_tile = t.old_tile
        position = t.position
        if Public.near_another_town(force_name, position, surface, 32) then
            fail = true
            surface.set_tiles({{name = old_tile.name, position = position}}, true)
            refund_item(event, event.item.name)
        end
    end
    if fail == true then
        local player
        if player_index ~= nil then player = game.players[player_index] end
        Utils.build_error_notification(player or force, surface, position, "Can't build near town!", player)
    end
    return fail
end

local function on_built_entity(event)
    if prevent_entity_in_restricted_zone(event) then
        return
    end
    if process_built_entities(event) then
        return
    end
end

local function on_robot_built_entity(event)
    if prevent_entity_in_restricted_zone(event) then
        return
    end
    if process_built_entities(event) then
        return
    end
end

local function on_player_built_tile(event)
    if prevent_landfill_in_restricted_zone(event) then
        return
    end
    if process_built_entities(event) then
        return
    end
    if prevent_tiles_near_towns(event) then
        return
    end
end

local function on_robot_built_tile(event)
    if prevent_landfill_in_restricted_zone(event) then
        return
    end
    if prevent_tiles_near_towns(event) then
        return
    end
end

local function on_pre_build(event)
    local p = event.position
    local surface = game.surfaces.nauvis

    -- Prevent deleting other players ghosts to breach their defenses
    local player = game.players[event.player_index]
    if surface.count_entities_filtered({position=p, radius=3, name='entity-ghost'}) > 0 -- some radius to account for bigger entities being placed
            and Public.near_another_town(player.force.name, p, surface, default_protected_radius) then
        player.clear_cursor()
        Utils.build_error_notification(player, surface, p, "Can't override enemy blueprint near town or turret", player)
    end
end

local disabled_for_outlander_deconstruction = {
    ['fish'] = true,
    ['huge-rock'] = true,
    ['big-rock'] = true,
    ['big-sand-rock'] = true,
    ['cliff'] = true
}

local function on_marked_for_deconstruction(event)
    if not event.player_index then return end

    local player = game.get_player(event.player_index)
    if TeamBasics.is_outlander_force(player.force)
            and (disabled_for_outlander_deconstruction[event.entity.name] or event.entity.type == 'tree') then
        event.entity.cancel_deconstruction(player.force.name)
        player.create_local_flying_text(
                {
                    position = event.entity.position,
                    text = "Not possible as outlander",
                    color = {r = 1, g = 0.0, b = 0.0},
                    time_to_live = 160
                }
        )
    end
end


local Event = require 'utils.event'
Event.add(defines.events.on_pre_build, on_pre_build)
Event.add(defines.events.on_built_entity, on_built_entity)
Event.add(defines.events.on_player_built_tile, on_player_built_tile)
Event.add(defines.events.on_robot_built_entity, on_robot_built_entity)
Event.add(defines.events.on_robot_built_tile, on_robot_built_tile)
Event.add(defines.events.on_marked_for_deconstruction, on_marked_for_deconstruction)

return Public
