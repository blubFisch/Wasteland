local Public = {}

local table_size = table.size
local table_insert = table.insert
local math_random = math.random
local math_rad = math.rad
local math_sin = math.sin
local math_cos = math.cos
local math_floor = math.floor

local ScenarioTable = require 'maps.wasteland.table'
local Building = require 'maps.wasteland.building'
local MapLayout = require 'maps.wasteland.map_layout'
local Utils = require 'maps.wasteland.utils'
local TeamBasics = require 'maps.wasteland.team_basics'

local function force_load(position, surface, radius)
    --log("is_chunk_generated = " .. tostring(surface.is_chunk_generated(position)))
    surface.request_to_generate_chunks(position, radius)
    --log("force load position = {" .. position.x .. "," .. position.y .. "}")
    surface.force_generate_chunk_requests()
end

-- gets an area (might not be even amount)
local function get_area(position, w, h)
    local x1 = math_floor(w / 2)
    local x2 = w - x1
    local y1 = math_floor(h / 2)
    local y2 = h - y1
    return {{position.x - x1, position.y - y1}, {position.x + x2, position.y + y2}}
end

-- is the position already used
local function in_use(position)
    local this = ScenarioTable.get_table()
    local result = false
    for _, v in pairs(this.spawn_point) do
        if v == position then
            result = true
        end
    end
    --log("in_use = " .. tostring(result))
    return result
end

-- is the position empty
local function is_empty(position, surface)
    local chunk_position = {}
    chunk_position.x = math_floor(position.x / 32)
    chunk_position.y = math_floor(position.y / 32)
    if not surface.is_chunk_generated(chunk_position) then
        -- force load the chunk
        surface.request_to_generate_chunks(position, 0)
        surface.force_generate_chunk_requests()
    end
    local entity_radius = 3
    local tile_radius = 2
    local entities = surface.find_entities_filtered({position = position, radius = entity_radius})
    --log("entities = " .. #entities)
    if #entities > 0 then
        return false
    end
    local tiles = surface.count_tiles_filtered({position = position, radius = tile_radius, collision_mask = 'water-tile'})
    --log("water-tiles = " .. tiles)
    if tiles > 0 then
        return false
    end
    local result = surface.can_place_entity({name = 'character', position = position})
    --log("is_empty = " .. tostring(result))
    return result
end

local function find_valid_spawn_point(force_name, surface)
    local this = ScenarioTable.get_table()

    local default_position = { x = MapLayout.central_ores_town_nobuild + 50, y = 0}
    local initial_position

    -- Make an initial rough position pick
    -- Prefer spawns near a town center
    local town_names_keyset = {}
    for town_name, _ in pairs(this.town_centers) do
        table_insert(town_names_keyset, town_name)
    end
    local town_count = table_size(town_names_keyset)
    if town_count > 0 then
        local town_center = this.town_centers[town_names_keyset[math_random(1, town_count)]]
        initial_position = town_center.market.position
        --log("XDB Town center is {" .. initial_position.x .. "," .. initial_position.y .. "}")
    else
        --log("XDB Starting with default_spawn")
        -- Use the default spawn area
        initial_position = default_position
    end

    -- Then start checking around it for a suitable spawn position
    local tries = 0
    local radius
    local min_distance_to_town_center = MapLayout.league_balance_shield_size * 0.75
    if town_count > 0 then
        radius = min_distance_to_town_center
    else
        radius = 5 -- Spawn players next to each other for extra fun
    end
    local angle
    while tries < 100 do
        -- 8 attempts each position
        for _ = 1, 8 do
            -- position on the circle radius
            angle = math_random(0, 360)
            local t = math_rad(angle)
            local x = math_floor(initial_position.x + math_cos(t) * radius)
            local y = math_floor(initial_position.y + math_sin(t) * radius)
            local variation_position = { x = x, y = y}
            --log("testing {" .. variation_position.x .. "," .. variation_position.y .. "}")
            force_load(initial_position, surface, 1)
            if not in_use(variation_position) then
                local distance_center = math.sqrt(variation_position.x ^ 2 + variation_position.y ^ 2)
                if distance_center > MapLayout.central_ores_town_nobuild + 50 then
                    if not Building.near_another_town(force_name, variation_position, surface, 40, min_distance_to_town_center) then
                    --    or PvPTownShield.in_extended_control_range(variation_position) then
                        if is_empty(variation_position, surface) then
                            --log("found valid spawn point at {" .. variation_position.x .. "," .. variation_position.y .. "}")
                            return variation_position
                        end
                    end
                end
            end
        end
        -- near a town, increment the radius and select another angle
        radius = radius + math_random(1, 30)
        tries = tries + 1
    end

    log("ERROR: found no good spawn, using default")
    return default_position
end

function Public.set_new_spawn_point(player, surface)
    local this = ScenarioTable.get_table()
    -- get a new spawn point
    local force = player.force
    local force_name = force.name
    local position = find_valid_spawn_point(force_name, surface)
    this.spawn_point[player.index] = position

    --log("player " .. player.name .. " assigned new spawn point at {" .. position.x .. "," .. position.y .. "}")
    return position
end

-- gets a new or existing spawn point for the player
function Public.get_spawn_point(player, surface)
    local this = ScenarioTable.get_table()
    local position = this.spawn_point[player.index]

    if position ~= nil and this.strikes[player.name] < 3 then
        if surface.can_place_entity({name = 'character', position = position}) then
            --log("player " .. player.name .. " using existing spawn point at {" .. position.x .. "," .. position.y .. "}")
            return position
        else
            position = surface.find_non_colliding_position('character', position, 0, 0.25)
            return position
        end
    elseif not TeamBasics.is_town_force(player.force) then
        player.print("Setting new spawn point after spawn kills", Utils.scenario_color)
        return Public.set_new_spawn_point(player, surface)
    end
end

commands.add_command(
        'new-spawn',
        'Set up a new spawn point for the next spawn',
        function(cmd)
            local player = game.players[cmd.player_index]

            if not player or not player.valid then
                return
            end

            Public.set_new_spawn_point(player, player.surface)
            player.print("New spawn is set up and will be used when you die", Utils.scenario_color)
        end
)

return Public
