local Public = {}

local math_random = math.random
local table_insert = table.insert
local math_floor = math.floor
local table_shuffle = table.shuffle_table
local table_size = table.size

local Event = require 'utils.event'
local Server = require 'utils.server'
local ScenarioTable = require 'maps.wasteland.table'
local Team = require 'maps.wasteland.team'
local Building = require 'maps.wasteland.building'
local Colors = require 'maps.wasteland.colors'
local Enemy = require 'maps.wasteland.enemy'
local Color = require 'utils.color_presets'
local Utils = require 'maps.wasteland.utils'
local MapLayout = require 'maps.wasteland.map_layout'
local Evolution = require 'maps.wasteland.evolution'
local PvPTownShield = require 'maps.wasteland.pvp_town_shield'
local PvPShield = require 'maps.wasteland.pvp_shield'

local town_radius = 20
local radius_between_towns = PvPTownShield.league_balance_shield_size * 1.3 + 2 + 40

local ore_amount = 1200

local colors = {}
local c1 = 250
local c2 = 210
local c3 = -40
for v = c1, c2, c3 do
    table_insert(colors, {0, 0, v})
end
for v = c1, c2, c3 do
    table_insert(colors, {0, v, 0})
end
for v = c1, c2, c3 do
    table_insert(colors, {v, 0, 0})
end
for v = c1, c2, c3 do
    table_insert(colors, {0, v, v})
end
for v = c1, c2, c3 do
    table_insert(colors, {v, v, 0})
end
for v = c1, c2, c3 do
    table_insert(colors, {v, 0, v})
end

local town_wall_vectors = Utils.make_border_vectors(town_radius, 2)

local gate_vectors_horizontal = {}
for x = -1, 1, 1 do
    table_insert(gate_vectors_horizontal, {x, town_radius})
    table_insert(gate_vectors_horizontal, {x, town_radius * -1})
end
local gate_vectors_vertical = {}
for y = -1, 1, 1 do
    table_insert(gate_vectors_vertical, {town_radius, y})
    table_insert(gate_vectors_vertical, {town_radius * -1, y})
end

local resource_vectors = {}
resource_vectors[1] = {}
for x = 8, 14, 1 do
    for y = 6, 12, 1 do
        table_insert(resource_vectors[1], {x, y})
    end
end
resource_vectors[2] = {}
for _, vector in pairs(resource_vectors[1]) do
    table_insert(resource_vectors[2], {vector[1] * -1, vector[2]})
end
resource_vectors[3] = {}
for _, vector in pairs(resource_vectors[1]) do
    table_insert(resource_vectors[3], {vector[1] * -1, vector[2] * -1})
end
resource_vectors[4] = {}
for _, vector in pairs(resource_vectors[1]) do
    table_insert(resource_vectors[4], {vector[1], vector[2] * -1})
end

local resource_vectors_out = {}
resource_vectors_out[1] = {}
for x = 24, 30, 1 do
    for y = 6, 17, 1 do
        table_insert(resource_vectors_out[1], {x, y})
    end
end
resource_vectors_out[2] = {}
for _, vector in pairs(resource_vectors_out[1]) do
    table_insert(resource_vectors_out[2], {vector[1] * -1, vector[2]})
end
resource_vectors_out[3] = {}
for _, vector in pairs(resource_vectors_out[1]) do
    table_insert(resource_vectors_out[3], {vector[1] * -1, vector[2] * -1})
end
resource_vectors_out[4] = {}
for _, vector in pairs(resource_vectors_out[1]) do
    table_insert(resource_vectors_out[4], {vector[1], vector[2] * -1})
end

local additional_resource_vectors = {}
additional_resource_vectors[1] = {}
for x = 7, 14, 1 do
    for y = -3, 3, 1 do
        table_insert(additional_resource_vectors[1], {x, y})
    end
end
additional_resource_vectors[2] = {}
for _, vector in pairs(additional_resource_vectors[1]) do
    table_insert(additional_resource_vectors[2], {vector[1] * -1, vector[2]})
end
additional_resource_vectors[3] = {}
for _, vector in pairs(additional_resource_vectors[1]) do
    table_insert(additional_resource_vectors[3], {vector[1] * -1, vector[2] * -1})
end
additional_resource_vectors[4] = {}
for _, vector in pairs(additional_resource_vectors[1]) do
    table_insert(additional_resource_vectors[4], {vector[1], vector[2] * -1})
end

--local clear_whitelist_types = {
--    ['character'] = true,
--    ['market'] = true,
--    ['simple-entity'] = true,
--    ['simple-entity-with-owner'] = true,
--    ['container'] = true,
--    ['car'] = true,
--    ['resource'] = true,
--    ['cliff'] = true,
--    ['tree'] = true
--}

local starter_supplies = {
    {name = 'raw-fish', count = 20},
    {name = 'grenade', count = 5},
    {name = 'stone', count = 100},
    {name = 'land-mine', count = 4},
    {name = 'wood', count = 100},
    {name = 'iron-plate', count = 200},
    {name = 'shotgun', count = 1},
    {name = 'shotgun-shell', count = 8},
    {name = 'firearm-magazine', count = 20},
    {name = 'gun-turret', count = 4}
}

local function count_nearby_ore(surface, position, ore_name)
    local count = 0
    local r = town_radius + 8
    for _, e in pairs(surface.find_entities_filtered({area = {{position.x - r, position.y - r}, {position.x + r, position.y + r}}, force = 'neutral', name = ore_name})) do
        count = count + e.amount
    end
    return count
end

local function draw_ore_patches(surface, position, ore_types, resource_vectors)
    for i = 1, #ore_types do
        local ore_type = ore_types[i]
        if count_nearby_ore(surface, position, ore_type) < 150000 then
            for _, vector in pairs(resource_vectors[i]) do
                local p = {position.x + vector[1], position.y + vector[2]}
                p = surface.find_non_colliding_position(ore_type, p, 64, 1)
                if p then
                    surface.create_entity({name = ore_type, position = p, amount = ore_amount})
                end
            end
        end
    end
end

local function draw_town_spawn(player_name)
    local this = ScenarioTable.get_table()
    local market = this.town_centers[player_name].market
    local position = market.position
    local surface = market.surface

    -- create walls
    for _, vector in pairs(gate_vectors_horizontal) do
        local p = {position.x + vector[1], position.y + vector[2]}
        surface.create_entity({name = 'gate', position = p, force = player_name, direction = 2})
        surface.set_tiles({{name = 'blue-refined-concrete', position = p}}, true)
    end
    for _, vector in pairs(gate_vectors_vertical) do
        local p = {position.x + vector[1], position.y + vector[2]}
        surface.create_entity({name = 'gate', position = p, force = player_name, direction = 0})
        surface.set_tiles({{name = 'blue-refined-concrete', position = p}}, true)
    end

    for _, vector in pairs(town_wall_vectors) do
        local p = {position.x + vector[1], position.y + vector[2]}
        surface.create_entity({name = 'stone-wall', position = p, force = player_name})
    end

    PvPTownShield.draw_all_shield_markers(surface, position, town_wall_vectors)

    -- ore patches
    local ores_in = {'coal'}
    table_shuffle(ores_in)
    draw_ore_patches(surface, position, ores_in, resource_vectors)

    local ores_out = {'iron-ore', 'copper-ore', 'stone', 'coal'}
    table_shuffle(ores_out)
    draw_ore_patches(surface, position, ores_out, resource_vectors_out)

    -- starter chests
    for _, item_stack in pairs(starter_supplies) do
        local m1 = -8 + math_random(0, 16)
        local m2 = -8 + math_random(0, 16)
        local p = {position.x + m1, position.y + m2}
        p = surface.find_non_colliding_position('iron-chest', p, 64, 1)
        if p then
            local e = surface.create_entity({name = 'iron-chest', position = p, force = player_name})
            local inventory = e.get_inventory(defines.inventory.chest)
            inventory.insert(item_stack)
        end
    end

    local vector_indexes = {1, 2, 3, 4}
    table_shuffle(vector_indexes)

    -- pond
    for _, vector in pairs(additional_resource_vectors[vector_indexes[2]]) do
        local x = position.x + vector[1]
        local y = position.y + vector[2]
        local p = {x = x, y = y}
        if surface.get_tile(p).name ~= 'out-of-map' then
            surface.set_tiles({{name = 'water-shallow', position = p}})
        end
    end

    -- fish
    for _, vector in pairs(additional_resource_vectors[vector_indexes[2]]) do
        local x = position.x + vector[1] + 0.5
        local y = position.y + vector[2] + 0.5
        local p = {x = x, y = y}
        if math_random(1, 2) == 1 then
            if surface.can_place_entity({name = 'fish', position = p}) then
                surface.create_entity({name = 'fish', position = p})
            end
        end
    end
end

local function is_valid_location(force_name, surface, position)
    local this = ScenarioTable.get_table()
    if not surface.can_place_entity({name = 'market', position = position}) then
        surface.create_entity(
            {
                name = 'flying-text',
                position = position,
                text = 'Position is obstructed - no room for market!',
                color = {r = 0.77, g = 0.0, b = 0.0}
            }
        )
        return false
    end

    for _, vector in pairs(town_wall_vectors) do
        local p = {x = math_floor(position.x + vector[1]), y = math_floor(position.y + vector[2])}
        if Building.in_restricted_zone(surface, p) then
            surface.create_entity(
                {
                    name = 'flying-text',
                    position = position,
                    text = 'Can not build in restricted zone!',
                    color = {r = 0.77, g = 0.0, b = 0.0}
                }
            )
            return false
        end
    end

    if table_size(this.town_centers) > 48 then
        surface.create_entity(
            {
                name = 'flying-text',
                position = position,
                text = 'Too many towns on the map!',
                color = {r = 0.77, g = 0.0, b = 0.0}
            }
        )
        return false
    end

    if Building.near_another_town(force_name, position, surface, radius_between_towns) or PvPTownShield.in_extended_control_range(position) then
        surface.create_entity(
            {
                name = 'flying-text',
                position = position,
                text = 'Town location is too close to others!',
                color = {r = 0.77, g = 0.0, b = 0.0}
            }
        )
        return false
    end

    local distance_center = math.sqrt(position.x ^ 2 + position.y ^ 2)
    if not this.testing_mode and distance_center < MapLayout.central_ores_town_nobuild then
        surface.create_entity(
                {
                    name = 'flying-text',
                    position = position,
                    text = string.format("%.0f", MapLayout.central_ores_town_nobuild - distance_center) .. ' tiles too close to the treasure!',
                    color = {r = 0.77, g = 0.0, b = 0.0}
                }
        )
        return false
    end

    return true
end

function Public.in_any_town(position)
    local this = ScenarioTable.get_table()
    local town_centers = this.town_centers
    for _, town_center in pairs(town_centers) do
        local market = town_center.market
        if market ~= nil then
            if Building.in_area(position, market.position, town_radius) == true then
                return true
            end
        end
    end
    return false
end

function Public.update_town_name(force)
    local this = ScenarioTable.get_table()
    local town_center = this.town_centers[force.name]
    rendering.set_text(town_center.town_caption, town_center.town_name)
end

function Public.set_market_health(entity, final_damage_amount)
    local this = ScenarioTable.get_table()
    local town_center = this.town_centers[entity.force.name]
    if not town_center then
        return
    end
    town_center.health = math_floor(town_center.health - final_damage_amount)
    if town_center.health > town_center.max_health then
        town_center.health = town_center.max_health
    end
    local m = town_center.health / town_center.max_health
    entity.health = 150 * m
    rendering.set_text(town_center.health_text, 'HP: ' .. town_center.health .. ' / ' .. town_center.max_health)
end

function Public.update_coin_balance(force)
    local this = ScenarioTable.get_table()
    local town_center = this.town_centers[force.name]
    local coin_balance = town_center.coin_balance
    if town_center.prev_coin_balance ~= coin_balance then
        rendering.set_text(town_center.coins_text, 'Coins: ' .. coin_balance)
        town_center.prev_coin_balance = coin_balance
    end
end

local function found_town(event)
    local entity = event.created_entity
    -- is a valid entity placed?
    if entity == nil or not entity.valid then
        return
    end

    local player = game.players[event.player_index]

    -- is player not a character?
    local character = player.character
    if character == nil then
        return
    end

    -- is it a stone-furnace?
    if entity.name ~= 'stone-furnace' then
        return
    end

    -- is player in a town already?
    if player.force.index ~= game.forces.player.index and player.force.index ~= game.forces['rogue'].index then
        return
    end

    -- try to place the town

    local force_name = tostring(player.name)
    local surface = entity.surface
    local position = entity.position

    entity.destroy()

    -- are towns enabled?
    local this = ScenarioTable.get_table()

    -- is player mayor of town that still exists?
    if Team.is_towny(player.force) then
        player.insert({name = 'stone-furnace', count = 1})
        return
    end

    -- is town placement on cooldown?
    if this.cooldowns_town_placement[player.index] then
        if game.tick < this.cooldowns_town_placement[player.index] then
            surface.create_entity(
                {
                    name = 'flying-text',
                    position = position,
                    text = 'Town founding is on cooldown for ' .. math.ceil((this.cooldowns_town_placement[player.index] - game.tick) / 3600) .. ' minutes.',
                    color = {r = 0.77, g = 0.0, b = 0.0}
                }
            )
            player.insert({name = 'stone-furnace', count = 1})
            return
        end
    end

    -- is it a valid location to place a town?
    if not is_valid_location(force_name, surface, position) then
        player.insert({name = 'stone-furnace', count = 1})
        return
    end

    if Evolution.get_evolution(position, true) >= 0.2 then
        if this.town_evo_warned[player.index] == nil or this.town_evo_warned[player.index] < game.tick - 60 * 10 then
            surface.create_entity(
                    {
                        name = 'flying-text',
                        position = position,
                        text = 'Evolution is high on this position. Are you sure?',
                        color = {r = 0.77, g = 0.0, b = 0.0}
                    }
            )
            player.print("Hint: Big towns nearby cause evolution. Check the evolution number at the top of the screen.", Utils.scenario_color)

            this.town_evo_warned[player.index] = game.tick

            player.insert({name = 'stone-furnace', count = 1})
            return
        end
    end

    local force = Team.add_new_force(force_name)

    this.town_centers[force_name] = {}
    local town_center = this.town_centers[force_name]
    town_center.town_name = player.name .. "'s Town"
    town_center.market = surface.create_entity({name = 'market', position = position, force = force_name})
    town_center.chunk_position = {math.floor(town_center.market.position.x / 32), math.floor(town_center.market.position.y / 32)}
    town_center.max_health = 100
    town_center.coin_balance = 0
    town_center.prev_coin_balance = 0
    town_center.input_buffer = {}
    town_center.output_buffer = {}
    town_center.output_market_entities = {}
    town_center.input_market_entities = {}
    town_center.health = town_center.max_health
    local crayola = Colors.get_random_color()
    town_center.color = crayola.color
    town_center.upgrades = {}
    town_center.upgrades.mining_prod = 0
    town_center.upgrades.mining_speed = 0
    town_center.upgrades.crafting_speed = 0
    town_center.upgrades.laser_turret = {}
    town_center.upgrades.laser_turret.slots = 8
    town_center.upgrades.laser_turret.locations = 0
    town_center.evolution = {}
    town_center.evolution.biters = 0
    town_center.evolution.spitters = 0
    town_center.evolution.worms = 0
    town_center.creation_tick = game.tick
    town_center.last_swarm = 0
    town_center.research_balance = {current_modifier = 1}
    town_center.laser_turrets = {}
    local market_pos = town_center.market.position
    town_center.center_box = {left_top = {x = market_pos.x - town_radius, y = market_pos.y - town_radius},
                              right_bottom = {x = market_pos.x + town_radius, y = market_pos.y + town_radius}}

    town_center.town_caption =
        rendering.draw_text {
        text = town_center.town_name,
        surface = surface,
        forces = {force_name, game.forces.player, game.forces.rogue},
        target = town_center.market,
        target_offset = {0, -4.25},
        color = town_center.color,
        scale = 1.30,
        font = 'default-game',
        alignment = 'center',
        scale_with_zoom = false
    }

    town_center.health_text =
        rendering.draw_text {
        text = 'HP: ' .. town_center.health .. ' / ' .. town_center.max_health,
        surface = surface,
        forces = {force_name, game.forces.player, game.forces.rogue},
        target = town_center.market,
        target_offset = {0, -3.25},
        color = {200, 200, 200},
        scale = 1.00,
        font = 'default-game',
        alignment = 'center',
        scale_with_zoom = false
    }

    town_center.coins_text =
        rendering.draw_text {
        text = 'Coins: ' .. town_center.coin_balance,
        surface = surface,
        forces = {force_name},
        target = town_center.market,
        target_offset = {0, -2.75},
        color = {200, 200, 200},
        scale = 1.00,
        font = 'default-game',
        alignment = 'center',
        scale_with_zoom = false
    }

    town_center.enemies_text = rendering.draw_text {
        text = '',
        surface = surface,
        forces = {force_name, game.forces.player, game.forces.rogue},
        target = town_center.market,
        target_offset = {0, -2.25},
        color = {0, 0, 0},
        scale = 1.00,
        font = 'default-game',
        alignment = 'center',
        scale_with_zoom = false
    }

    town_center.shield_text = rendering.draw_text {
        text = '',
        surface = surface,
        forces = {force_name, game.forces.player, game.forces.rogue},
        target = town_center.market,
        target_offset = {0, -1.5},
        color = {200, 200, 200},
        scale = 1.00,
        font = 'default-game',
        alignment = 'center',
        scale_with_zoom = false
    }

    Enemy.clear_enemies(position, surface, town_radius * 5)
    draw_town_spawn(force_name)

    -- set the spawn point
    local pos = {x = town_center.market.position.x, y = town_center.market.position.y + 4}
    --log("setting spawn point = {" .. spawn_point.x .. "," .. spawn_point.y .. "}")
    force.set_spawn_position(pos, surface)

    Team.add_player_to_town(player, town_center)
    Team.add_chart_tag(town_center)

    force.chart(surface, {{-1, -1}, {1, 1}})    -- Uncover center treasure

    PvPTownShield.init_town(town_center)

    game.print(player.name .. ' has founded a new town!', {255, 255, 0})
    Server.to_discord_embed(player.name .. ' has founded a new town!')
end

local function on_built_entity(event)
    found_town(event)
end

local function on_player_repaired_entity(event)
    local entity = event.entity
    if entity.name == 'market' then
        Public.set_market_health(entity, -4)
    end
end

local function on_entity_damaged(event)
    local entity = event.entity
    if not entity.valid then
        return
    end
    if entity.name == 'market' and not PvPShield.entity_is_protected(entity, event.force) then
        Public.set_market_health(entity, event.final_damage_amount)
    end
end

local function rename_town(cmd)
    local player = game.players[cmd.player_index]
    if not player or not player.valid then
        return
    end
    local force = player.force
    if force.name == 'player' or force.name == 'rogue' then
        player.print('You are not member of a town!', Color.fail)
        return
    end
    local name = cmd.parameter
    if name == nil then
        player.print('Must specify new town name!', Color.fail)
        return
    end
    local this = ScenarioTable.get_table()
    local town_center = this.town_centers[force.name]
    local old_name = town_center.town_name
    town_center.town_name = name
    Public.update_town_name(force)

    for _, p in pairs(force.players) do
        if p == player then
            player.print('Your town name is now ' .. name, town_center.color)
        else
            player.print(player.name .. ' has renamed the town to ' .. name, town_center.color)
        end
        Team.set_player_color(p)
    end

    game.print('>> ' .. old_name .. ' is now known as ' .. '"' .. name .. '"', {255, 255, 0})
    Server.to_discord_embed(old_name .. ' is now known as ' .. '"' .. name .. '"')
end

commands.add_command(
    'rename-town',
    'Renames your town..',
    function(cmd)
        rename_town(cmd)
    end
)

Event.add(defines.events.on_built_entity, on_built_entity)
Event.add(defines.events.on_player_repaired_entity, on_player_repaired_entity)
Event.add(defines.events.on_entity_damaged, on_entity_damaged)

return Public
