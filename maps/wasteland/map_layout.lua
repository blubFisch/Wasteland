local table_insert = table.insert
local math_random = math.random
local math_floor = math.floor
local math_abs = math.abs
local math_sqrt = math.sqrt

local Public = {}

local get_noise = require 'utils.get_noise'
local Scrap = require 'maps.wasteland.scrap'
local Spaceship = require 'maps.wasteland.spaceship'
local GameMode = require 'maps.wasteland.game_mode'


Public.central_ores_radius = 15
Public.central_ores_town_nobuild = 350
Public.central_oil_radius_inner = 20
Public.central_oil_radius_outer = 25

local league_sizes_by_game_mode = {101, 141, 141}
Public.league_balance_shield_size =  league_sizes_by_game_mode[GameMode.mode]
Public.higher_league_activation_range = Public.league_balance_shield_size + 50
Public.min_distance_between_towns = Public.higher_league_activation_range + 2 + 50    -- plus some buffer for players moving for activations

Public.map_size = {2048, 2048}
Public.uranium_patch_nobuild = 180

function Public.town_too_close_to_map_end(position)
    return Public.map_size[1] / 2 - math_abs(position.x) < Public.league_balance_shield_size / 2
            or Public.map_size[2] / 2 - math_abs(position.y) < Public.league_balance_shield_size / 2
end

function Public.reveal_strategic_resources(force)
    -- We do this to even the battle field with players who just check out the map in SP

    local this = global.tokens.maps_wasteland_table
    local surface = game.surfaces.nauvis
    force.chart(surface, {{-1, -1}, {1, 1}})
    force.chart(surface, {this.uranium_patch_location, this.uranium_patch_location})
end

local function gen_uranium_location()
    local east = (math.random(2) == 1) and -1 or 1
    local top = (math.random(2) == 1) and -1 or 1
    return {x=east * (Public.map_size[1] / 2 - 50), y=top * (Public.map_size[2] / 2  - 50) }
end

local function init()
    local this = global.tokens.maps_wasteland_table
    this.uranium_patch_location = gen_uranium_location()
end
Public.init = init

local scrap_entities = {
    -- simple entity with owner
    {name = 'crash-site-spaceship-wreck-small-1'}, -- these do not have mining animation
    {name = 'crash-site-spaceship-wreck-small-1'}, -- these do not have mining animation
    {name = 'crash-site-spaceship-wreck-small-2'}, -- these do not have mining animation
    {name = 'crash-site-spaceship-wreck-small-3'}, -- these do not have mining animation
    {name = 'crash-site-spaceship-wreck-small-4'}, -- these do not have mining animation
    {name = 'crash-site-spaceship-wreck-small-5'}, -- these do not have mining animation
    {name = 'crash-site-spaceship-wreck-small-6'} -- these do not have mining animation
}

local scrap_entities_index = table.size(scrap_entities)

local scrap_containers = {
    -- containers
    {name = 'big-ship-wreck-1', size = 3}, -- these are not mineable normally
    {name = 'big-ship-wreck-1', size = 3}, -- these are not mineable normally
    {name = 'big-ship-wreck-1', size = 3}, -- these are not mineable normally
    {name = 'big-ship-wreck-2', size = 3}, -- these are not mineable normally
    {name = 'big-ship-wreck-2', size = 3}, -- these are not mineable normally
    {name = 'big-ship-wreck-2', size = 3}, -- these are not mineable normally
    {name = 'big-ship-wreck-3', size = 3}, -- these are not mineable normally
    {name = 'big-ship-wreck-3', size = 3}, -- these are not mineable normally
    {name = 'big-ship-wreck-3', size = 3}, -- these are not mineable normally
    {name = 'crash-site-chest-1', size = 8}, -- these do not have mining animation
    {name = 'crash-site-chest-2', size = 8}, -- these do not have mining animation
    {name = 'crash-site-spaceship-wreck-medium-1', size = 1}, -- these do not have mining animation
    {name = 'crash-site-spaceship-wreck-medium-1', size = 1}, -- these do not have mining animation
    {name = 'crash-site-spaceship-wreck-medium-1', size = 1}, -- these do not have mining animation
    {name = 'crash-site-spaceship-wreck-medium-1', size = 1}, -- these do not have mining animation
    {name = 'crash-site-spaceship-wreck-medium-2', size = 1}, -- these do not have mining animation
    {name = 'crash-site-spaceship-wreck-medium-2', size = 1}, -- these do not have mining animation
    {name = 'crash-site-spaceship-wreck-medium-2', size = 1}, -- these do not have mining animation
    {name = 'crash-site-spaceship-wreck-medium-2', size = 1}, -- these do not have mining animation
    {name = 'crash-site-spaceship-wreck-medium-3', size = 1}, -- these do not have mining animation
    {name = 'crash-site-spaceship-wreck-medium-3', size = 1}, -- these do not have mining animation
    {name = 'crash-site-spaceship-wreck-medium-3', size = 1}, -- these do not have mining animation
    {name = 'crash-site-spaceship-wreck-medium-3', size = 1}, -- these do not have mining animation
    {name = 'crash-site-spaceship-wreck-big-1', size = 2}, -- these do not have mining animation
    {name = 'crash-site-spaceship-wreck-big-1', size = 2}, -- these do not have mining animation
    {name = 'crash-site-spaceship-wreck-big-1', size = 2}, -- these do not have mining animation
    {name = 'crash-site-spaceship-wreck-big-2', size = 2}, -- these do not have mining animation
    {name = 'crash-site-spaceship-wreck-big-2', size = 2}, -- these do not have mining animation
    {name = 'crash-site-spaceship-wreck-big-2', size = 2} -- these do not have mining animation
}
local scrap_containers_index = table.size(scrap_containers)

-- loot chances and amounts for scrap containers

local container_loot_chance = {
    {name = 'advanced-circuit', chance = 15},
    --{name = "artillery-shell", chance = 1},
    {name = 'battery', chance = 15},
    {name = 'cannon-shell', chance = 4},
    --{name = "cluster-grenade", chance = 2},
    {name = 'construction-robot', chance = 1},
    {name = 'copper-cable', chance = 250},
    {name = 'copper-plate', chance = 250},
    {name = 'crude-oil-barrel', chance = 30},
    {name = 'defender-capsule', chance = 5},
    {name = 'destroyer-capsule', chance = 1},
    {name = 'distractor-capsule', chance = 2},
    {name = 'electric-engine-unit', chance = 2},
    {name = 'electronic-circuit', chance = 150},
    {name = 'empty-barrel', chance = 10},
    {name = 'engine-unit', chance = 5},
    {name = 'explosive-cannon-shell', chance = 2},
    --{name = "explosive-rocket", chance = 3},
    --{name = "explosive-uranium-cannon-shell", chance = 1},
    {name = 'explosives', chance = 5},
    {name = 'grenade', chance = 10},
    {name = 'heavy-oil-barrel', chance = 20},
    {name = 'iron-gear-wheel', chance = 500},
    {name = 'iron-plate', chance = 500},
    {name = 'iron-stick', chance = 50},
    {name = 'land-mine', chance = 3},
    {name = 'light-oil-barrel', chance = 20},
    {name = 'logistic-robot', chance = 1},
    {name = 'low-density-structure', chance = 1},
    {name = 'lubricant-barrel', chance = 20},
    --{name = "nuclear-fuel", chance = 1},
    {name = 'petroleum-gas-barrel', chance = 30},
    {name = 'pipe', chance = 100},
    {name = 'pipe-to-ground', chance = 10},
    {name = 'plastic-bar', chance = 5},
    {name = 'processing-unit', chance = 2},
    --{name = "rocket", chance = 3},
    --{name = "rocket-control-unit", chance = 1},
    {name = "rocket-fuel", chance = 3},
    {name = 'solid-fuel', chance = 100},
    {name = 'steel-plate', chance = 150},
    {name = 'sulfuric-acid-barrel', chance = 15},
    --{name = "uranium-cannon-shell", chance = 1},
    {name = "uranium-fuel-cell", chance = 1},
    --{name = "used-up-uranium-fuel-cell", chance = 1},
    {name = 'water-barrel', chance = 10}
}

local container_loot_amounts = {
    ['advanced-circuit'] = 6,
    --["artillery-shell"] = 0.3,
    ['battery'] = 2,
    ['cannon-shell'] = 4,
    --["cluster-grenade"] = 0.3,
    ['construction-robot'] = 0.3,
    ['copper-cable'] = 24,
    ['copper-plate'] = 16,
    ['crude-oil-barrel'] = 3,
    ['defender-capsule'] = 2,
    ['destroyer-capsule'] = 0.3,
    ['distractor-capsule'] = 0.3,
    ['electric-engine-unit'] = 2,
    ['electronic-circuit'] = 8,
    ['empty-barrel'] = 3,
    ['engine-unit'] = 2,
    ['explosive-cannon-shell'] = 2,
    --["explosive-rocket"] = 2,
    --["explosive-uranium-cannon-shell"] = 2,
    ['explosives'] = 4,
    ['green-wire'] = 8,
    ['grenade'] = 6,
    ['heat-pipe'] = 1,
    ['heavy-oil-barrel'] = 3,
    ['iron-gear-wheel'] = 8,
    ['iron-plate'] = 16,
    ['iron-stick'] = 16,
    ['land-mine'] = 6,
    ['light-oil-barrel'] = 3,
    ['logistic-robot'] = 0.3,
    ['low-density-structure'] = 0.3,
    ['lubricant-barrel'] = 3,
    --["nuclear-fuel"] = 0.1,
    ['petroleum-gas-barrel'] = 3,
    ['pipe'] = 8,
    ['pipe-to-ground'] = 1,
    ['plastic-bar'] = 4,
    ['processing-unit'] = 2,
    ['red-wire'] = 8,
    --["rocket"] = 2,
    --["rocket-control-unit"] = 0.3,
    ["rocket-fuel"] = 0.3,
    ['solid-fuel'] = 4,
    ['steel-plate'] = 4,
    ['sulfuric-acid-barrel'] = 3,
    --["uranium-cannon-shell"] = 2,
    ["uranium-fuel-cell"] = 0.3,
    --["used-up-uranium-fuel-cell"] = 1,
    ['water-barrel'] = 3,
}

local scrap_raffle = {}
for _, t in pairs(container_loot_chance) do
    for _ = 1, t.chance, 1 do
        table_insert(scrap_raffle, t.name)
    end
end

local size_of_scrap_raffle = #scrap_raffle

local function place_scrap(surface, position)
    
    -- place turrets
    if math_random(1, 700) == 1 then
        if position.x ^ 2 + position.x ^ 2 > 4096 then
            local e = surface.create_entity({name = 'gun-turret', position = position, force = 'enemy'})
            e.minable = false
            e.operable = false
            e.insert({name = 'piercing-rounds-magazine', count = 100})
            return
        end
    end

    -- place market spaceship
    if math_random(1, 1000) == 1 then
        Spaceship.place(surface, position)
        return
    end

    -- place scrap containers with loot
    if math_random(1, 128) == 1 then
        local scrap = scrap_containers[math_random(1, scrap_containers_index)]
        local e = surface.create_entity({name = scrap.name, position = position, force = 'neutral'})
        e.minable = true
        local i = e.get_inventory(defines.inventory.chest)
        if i then
            local size = scrap.size
            for _ = 1, math_random(1, size), 1 do
                local loot = scrap_raffle[math_random(1, size_of_scrap_raffle)]
                local amount = container_loot_amounts[loot]
                local count = math_floor(amount * math_random(5, 35) * 0.1) + 1
                i.insert({name = loot, count = count})
            end
        end
        return
    end

    -- place scrap entities with loot
    local scrap = scrap_entities[math_random(1, scrap_entities_index)]
    local e = surface.create_entity({name = scrap.name, position = position, force = 'neutral'})
    e.minable = true
end

local function is_scrap_area(n)
    if n > 0.6 then
        return true
    end
    if n < -0.6 then
        return true
    end
end

local function move_away_biteys(surface, area)
    for _, e in pairs(surface.find_entities_filtered({type = {'unit-spawner', 'turret', 'unit'}, area = area})) do
        local position = surface.find_non_colliding_position(e.name, e.position, 96, 4)
        if position then
            surface.create_entity({name = e.name, position = position, force = 'enemy'})
            e.destroy()
        end
    end
end

local vectors = {{0, 0}, {1, 0}, {-1, 0}, {0, 1}, {0, -1}}

local function landfill_under(entity)
    -- landfill the area under the entity
    local surface = entity.surface
    for _, v in pairs(vectors) do
        local position = {entity.position.x + v[1], entity.position.y + v[2]}
        local tile = surface.get_tile(position)
        if tile.name ~= "blue-refined-concrete" and not tile.collides_with('resource-layer') then
            surface.set_tiles({{name = 'landfill', position = position}}, true)
        end
    end
end

local function on_player_mined_entity(event)
    local entity = event.entity
    if not entity.valid then
        return
    end
    if Scrap.is_scrap(entity) then
        landfill_under(entity)
    end
end

local function on_entity_died(event)
    local entity = event.entity
    if not entity.valid then
        return
    end
    if Scrap.is_scrap(entity) then
        landfill_under(entity)
    end
end

local function on_chunk_generated(event)
    --log("wasteland::on_chunk_generated")
    local surface = event.surface
    if (surface.name ~= 'nauvis') then
        return
    end
    local this = global.tokens.maps_wasteland_table
    local seed = surface.map_gen_settings.seed
    local left_top_x = event.area.left_top.x
    local left_top_y = event.area.left_top.y

    local position
    local noise

    local chunk_position = event.position
    --log('chunk_position = {' .. chunk_position.x .. ',' .. chunk_position.y .. '}')
    if chunk_position.x >= -33 and chunk_position.x <= 32 and chunk_position.y >= -33 and chunk_position.y <= 32 then
        if chunk_position.x == -33 or chunk_position.x == 32 or chunk_position.y == -33 or chunk_position.y == 32 then
            local area = {{x = left_top_x, y = left_top_y}, {x = left_top_x + 31, y = left_top_y + 31}}
            local entities = surface.find_entities(area)
            for _, e in pairs(entities) do
                e.destroy()
            end
            for x = 0, 31, 1 do
                for y = 0, 31, 1 do
                    position = {x = left_top_x + x, y = left_top_y + y}
                    surface.set_tiles({{name = 'water-shallow', position = position}}, true)
                end
            end
            return
        end
    end
    if chunk_position.x < -33 or chunk_position.x > 32 or chunk_position.y < -33 or chunk_position.y > 32 then
        local area = {{x = left_top_x, y = left_top_y}, {x = left_top_x + 31, y = left_top_y + 31}}
        local entities = surface.find_entities(area)
        for _, e in pairs(entities) do
            e.destroy()
        end
        for x = 0, 31, 1 do
            for y = 0, 31, 1 do
                position = {x = left_top_x + x, y = left_top_y + y}
                surface.set_tiles({{name = 'deepwater', position = position}}, true)
            end
        end
        return
    end

    for x = 0, 31, 1 do
        for y = 0, 31, 1 do
            position = {x = left_top_x + x, y = left_top_y + y}
            if math.sqrt(position.x^2 + position.y^2) > Public.central_oil_radius_outer + 10 then
                if math_random(1, 3) > 1 then
                    if not surface.get_tile(position).collides_with('resource-layer') then
                        noise = get_noise('wasteland', position, seed)
                        if is_scrap_area(noise) then
                            surface.set_tiles({{name = 'dirt-' .. math_floor(math_abs(noise) * 6) % 6 + 2, position = position}}, true)
                            place_scrap(surface, position)
                        end
                    end
                end
            end
        end
    end

    -- central ore patch
    if chunk_position.x >= -2 and chunk_position.x <= 2 and chunk_position.y >= -2 and chunk_position.y <=2 then
        local ores = {'iron-ore', 'copper-ore', 'stone', 'coal'}
        local amount = 50000
        local oil_amount = 1000000

        for x = 0, 31, 1 do
            for y = 0, 31, 1 do
                position = {x = left_top_x + x, y = left_top_y + y}
                local distance_to_center = math.sqrt(position.x^2 + position.y^2)
                if distance_to_center < Public.central_ores_radius then
                    noise = get_noise('wasteland', position, seed)
                    surface.set_tiles({{name = 'dirt-' .. math_floor(math_abs(noise) * 6) % 6 + 2, position = position}}, true)
                    surface.create_entity({name = ores[math.random(1, 4)], position = position, amount = amount})
                elseif distance_to_center > Public.central_oil_radius_inner and distance_to_center < Public.central_oil_radius_outer then
                    if math_random(1, 50) == 1 then
                        local position_nc = surface.find_non_colliding_position("crude-oil", position, 3, 1)
                        if position_nc then
                            surface.create_entity({name = 'crude-oil', position = position_nc, amount = oil_amount})
                        end
                    end
                end
            end
        end
    end

    -- deep uranium patch
    local uranium_patch_radius = 3
    local uranium_amount = 100000
    local uranium_patch_location = this.uranium_patch_location
    if math.abs(chunk_position.x - math.floor(uranium_patch_location.x / 32)) <= 1 and math.abs(chunk_position.y - math.floor(uranium_patch_location.y / 32)) <= 1 then
        for x = 0, 31, 1 do
            for y = 0, 31, 1 do
                position = {x = left_top_x + x, y = left_top_y + y}
                local distance_to_uranium_patch_center = math_sqrt((position.x - uranium_patch_location.x)^2 + (position.y - uranium_patch_location.y)^2)
                if distance_to_uranium_patch_center <= uranium_patch_radius then
                    surface.set_tiles({{name = 'dirt-' .. math_floor(math_abs(noise) * 6) % 6 + 2, position = position}}, true)
                    surface.create_entity({name = 'uranium-ore', position = position, amount = uranium_amount})
                end
            end
        end
    end

    -- random mixed patches, mostly to show beginners that there's ores on the map
    if math_random(1,80) == 1 then
        local ores = {'iron-ore', 'copper-ore', 'stone', 'coal'}
        local amount = 500
        local max_radius = 8
        local offset_x = math_random(max_radius, 32-max_radius)
        local offset_y = math_random(max_radius, 32-max_radius)

        for x = -max_radius, max_radius, 1 do
            for y = -max_radius, max_radius, 1 do
                position = { x = left_top_x + x + offset_x, y = left_top_y + y + offset_y}
                local distance_to_center = math_abs(math_sqrt(x^2 + y^2))
                if distance_to_center < max_radius then
                    noise = get_noise('wasteland', position, seed)
                    local ore_type = ores[math_random(1, 4)]
                    if surface.can_place_entity({name = ore_type, position = position}) then
                        surface.create_entity({name = ore_type, position = position, amount = amount})
                    end
                end
            end
        end
    end

    move_away_biteys(surface, event.area)
end

local function add_chart_tag_if_none(force, surface, position, icon, text)
    if #force.find_chart_tags(surface, {{position.x - 0.1, position.y - 0.1}, {position.x + 0.1, position.y + 0.1}}) == 0 then
        force.add_chart_tag(surface, {icon = {type = 'item', name = icon}, position = position, text = text})
    end
end

local function on_chunk_charted(event)
    local force = event.force
    local surface = game.surfaces[event.surface_index]
    local this = global.tokens.maps_wasteland_table
    if force.valid then
        local position = event.position
        if position.x == 0 and position.y == 0 then
            add_chart_tag_if_none(force, surface, position, 'coin', "Treasure")
        end

        local uranium_patch_location = this.uranium_patch_location
        if position.x == math.floor(uranium_patch_location.x / 32) and position.y == math.floor(uranium_patch_location.y / 32) then
            add_chart_tag_if_none(force, surface, uranium_patch_location, 'uranium-ore', "Deep Uranium")
        end
    end
end

function Public.force_gen_chunk(position, surface, radius)
    if not surface.is_chunk_generated(position) then
        surface.request_to_generate_chunks(position, radius)
        surface.force_generate_chunk_requests()
    end
end

local Event = require 'utils.event'
Event.on_init(init)
Event.add(defines.events.on_chunk_generated, on_chunk_generated)
Event.add(defines.events.on_chunk_charted, on_chunk_charted)
Event.add(defines.events.on_player_mined_entity, on_player_mined_entity)
Event.add(defines.events.on_entity_died, on_entity_died)

return Public
