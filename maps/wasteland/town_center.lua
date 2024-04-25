local Public = {}

local math_random = math.random
local table_insert = table.insert
local math_floor = math.floor
local table_shuffle = table.shuffle_table
local table_size = table.size
local math_max = math.max
local math_min = math.min
local math_abs = math.abs
local math_rad = math.rad
local math_sin = math.sin
local math_cos = math.cos

local Event = require 'utils.event'
local Server = require 'utils.server'
local ScenarioTable = require 'maps.wasteland.table'
local Team = require 'maps.wasteland.team'
local Building = require 'maps.wasteland.building'
local Colors = require 'maps.wasteland.colors'
local Color = require 'utils.color_presets'
local Utils = require 'maps.wasteland.utils'
local MapLayout = require 'maps.wasteland.map_layout'
local Evolution = require 'maps.wasteland.evolution'
local PvPTownShield = require 'maps.wasteland.pvp_town_shield'
local PvPShield = require 'maps.wasteland.pvp_shield'
local TeamBasics = require 'maps.wasteland.team_basics'


local town_radius = 20

local starter_ore_amounts = { 0.25, 0.5, 1.0 }
local starter_ore_amount = 1200 * starter_ore_amounts[global.game_mode]

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
                    surface.create_entity({name = ore_type, position = p, amount = starter_ore_amount })
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

    -- create walls and gates
    for _, vector in pairs(gate_vectors_horizontal) do
        local p = {position.x + vector[1], position.y + vector[2]}
        surface.create_entity({name = 'gate', position = p, force = player_name, direction = 2})
    end
    for _, vector in pairs(gate_vectors_vertical) do
        local p = {position.x + vector[1], position.y + vector[2]}
        surface.create_entity({name = 'gate', position = p, force = player_name, direction = 0})
    end
    for _, vector in pairs(town_wall_vectors) do
        local p = {position.x + vector[1], position.y + vector[2]}
        surface.create_entity({name = 'stone-wall', position = p, force = player_name})
    end

    PvPTownShield.draw_shield_floor_markers(surface, position)

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
        else
            log("ERROR: could not find starter chest position")
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
        return false, 'Position is obstructed - no room for market!'
    end

    if MapLayout.town_too_close_to_map_end(position) then
        return false, 'Too close to map edge!'
    end

    if table_size(this.town_centers) > 64 - 4 - Team.max_player_slots then
        return false, 'Too many towns on the map!'
    end

    local too_close, _, distance = Building.near_another_town(force_name, position, surface, MapLayout.min_distance_between_towns)

    if too_close then
        local text = 'Town location is too close to others!'
        if distance then
            text = text .. ' (' .. math.ceil(distance) .. ' tiles)'
        end
        return false, text
    end

    local distance_center = math.sqrt(position.x ^ 2 + position.y ^ 2)
    if distance_center < MapLayout.central_ores_town_nobuild then
        return false, string.format("%.0f", MapLayout.central_ores_town_nobuild - distance_center) .. ' tiles too close to the treasure!'
    end

    local distance_uranium = math.sqrt((this.uranium_patch_location.x - position.x) ^ 2 + (this.uranium_patch_location.y - position.y) ^ 2)
    if distance_uranium < MapLayout.uranium_patch_nobuild then
        return false, string.format("%.0f", MapLayout.uranium_patch_nobuild - distance_uranium) .. ' tiles too close to the deep uranium patch!'
    end

    return true
end

function Public.in_any_town(position)
    local this = ScenarioTable.get_table()
    for _, town_center in pairs(this.town_centers) do
        local market = town_center.market
        if market ~= nil then
            local in_area, _ = Building.in_area(position, market.position, town_radius)
            if in_area then
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

    if entity.name ~= 'linked-chest' then
        return
    end

    if event.robot then
        entity.destroy()
        local inventory = event.robot.get_inventory(defines.inventory.robot_cargo)
        inventory.insert({name = 'linked-chest', count = 1})
        return
    end

    local player = game.players[event.player_index]
    if not player.character then
        return
    end

    -- is player in a town already?
    if TeamBasics.is_town_force(player.force) then
        entity.destroy()    -- Can't allow placing the special item for this
        return
    end

    -- try to place the town
    local surface = entity.surface
    local position = entity.position

    entity.destroy()

    -- are towns enabled?
    local this = ScenarioTable.get_table()

    -- is player mayor of town that still exists?
    if TeamBasics.is_town_force(player.force) then
        player.insert({name = 'linked-chest', count = 1})
        return
    end

    -- is town placement on cooldown?
    if this.cooldowns_town_placement[player.index] then
        if game.tick < this.cooldowns_town_placement[player.index] then
            Utils.build_error_notification(player, surface, position, 'Town founding is on cooldown for '
                    .. math.ceil((this.cooldowns_town_placement[player.index] - game.tick) / 3600) .. ' minutes.', player)
            player.insert({name = 'linked-chest', count = 1})
            return
        end
    end

    -- is it a valid location to place a town?
    local is_valid, reason = is_valid_location(player.force.name, surface, position)
    if not is_valid then
        player.insert({name = 'linked-chest', count = 1})
        Utils.build_error_notification(player, surface, position, reason .. " Type /good-spot in chat to get a nearby good location", player)
        return
    end

    if Evolution.get_evolution(position, true) >= 0.2 then
        if this.town_evo_warned[player.index] == nil or this.town_evo_warned[player.index] < game.tick - 60 * 10 then
            surface.create_entity({
                name = 'flying-text',
                position = position,
                text = 'Evolution is high on this position. Are you sure?',
                color = {r = 0.77, g = 0.0, b = 0.0}
            })
            player.print("Hint: Towns nearby increase evolution. Check the evolution number at the top of the screen.", Utils.scenario_color)

            this.town_evo_warned[player.index] = game.tick

            player.insert({name = 'linked-chest', count = 1})
            return
        end
    end


    local force = Team.create_town_force(player)
    local force_name = force.name

    this.town_centers[force_name] = {}
    local town_center = this.town_centers[force_name]
    town_center.town_name = player.name .. "'s Town"
    town_center.market = surface.create_entity({name = 'market', position = position, force = force_name})
    town_center.chunk_position = {math.floor(town_center.market.position.x / 32), math.floor(town_center.market.position.y / 32)}
    town_center.max_health = 500
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
    town_center.evolution = {}
    town_center.evolution.biters = 0
    town_center.evolution.spitters = 0
    town_center.evolution.worms = 0
    town_center.survival_time_ticks = 0
    town_center.last_swarm = 0
    town_center.laser_turrets = 0
    local market_pos = town_center.market.position
    town_center.center_box = {left_top = {x = market_pos.x - town_radius, y = market_pos.y - town_radius},
                              right_bottom = {x = market_pos.x + town_radius, y = market_pos.y + town_radius}}
    town_center.pvp_shield_mgmt = {}
    town_center.marked_afk = false
    town_center.town_rest = {}
    town_center.town_rest.last_online = game.tick
    town_center.town_rest.current_modifier = 0
    town_center.town_rest.previous_modifier = 0
    town_center.town_rest.mining_prod_bonus = 0

    town_center.town_caption =
        rendering.draw_text {
        text = town_center.town_name,
        surface = surface,
        forces = {force_name},
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
        forces = {force_name},
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
        forces = {force_name},
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
        forces = {force_name},
        target = town_center.market,
        target_offset = {0, -1.5},
        color = {200, 200, 200},
        scale = 1.00,
        font = 'default-game',
        alignment = 'center',
        scale_with_zoom = false
    }

    -- Clear enemies around spawn
    for _, e in pairs(surface.find_entities_filtered({force = 'enemy', type = {'unit-spawner', 'unit', 'turret', 'gun-turret'},
                                                      position = position, radius = town_radius * 5})) do
        e.destroy()
    end

    draw_town_spawn(force_name)

    -- set the spawn point
    local pos = {x = town_center.market.position.x, y = town_center.market.position.y + 4}
    --log("setting spawn point = {" .. spawn_point.x .. "," .. spawn_point.y .. "}")
    force.set_spawn_position(pos, surface)

    Team.add_player_to_town(player, town_center)
    Team.add_chart_tag(town_center)

    PvPTownShield.init_town(town_center)

    game.print(player.name .. ' has founded a new town!', {255, 255, 0})
    Server.to_discord_embed(player.name .. ' has founded a new town!')
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
    if not TeamBasics.is_town_force(force) then
        player.print('You are not member of a town!', Color.fail)
        return
    end
    local name = cmd.parameter
    if name == nil then
        player.print('Must specify new town name!', Color.fail)
        return
    end
    if string.len(name) > 25 then
        player.print('Name too long', Color.fail)
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

commands.add_command(
        'suicide-town',
        'Kill your own town instantly',
        function(cmd)
            local player = game.players[cmd.player_index]

            if not player or not player.valid then
                return
            end

            local this = ScenarioTable.get_table()
            local min_strikes_needed = 3
            if TeamBasics.is_town_force(player.force) then
                if this.strikes[player.name] >= min_strikes_needed then
                    local town_center = this.town_centers[player.force.name]
                    game.print(player.name .. " has triggered a town suicide on " ..  town_center.town_name, Utils.scenario_color)
                    town_center.market.die(player.force)
                else
                    player.print("You can use this command after you have been spawnkilled " .. min_strikes_needed .. " times", Utils.scenario_color)
                end
            else
                player.print("You are not member of a town", Utils.scenario_color)
            end
        end
)

local function format_boost_modifier(modifier)
    return string.format('+%.0f%%', 100 * modifier)
end
Public.format_boost_modifier = format_boost_modifier
local format_rest_modifier = format_boost_modifier
Public.format_rest_modifier = format_rest_modifier

local town_rest_min_period_hours = 2
local town_rest_up_per_hour = 1 / (20 - town_rest_min_period_hours)
local town_rest_down_per_hour = 1 / 4
if false then   -- DEBUG
    town_rest_min_period_hours = town_rest_min_period_hours / 60 / 10
    town_rest_up_per_hour = town_rest_up_per_hour * 60 * 10
    town_rest_down_per_hour = town_rest_down_per_hour * 60 * 10
end
local town_rest_min_period_ticks = town_rest_min_period_hours * 60 * 60 * 60
local town_rest_loop_time = 60
local town_rest_up_per_loop = town_rest_loop_time * town_rest_up_per_hour / (60 * 60 * 60)
local town_rest_down_per_loop = town_rest_loop_time * town_rest_down_per_hour / (60 * 60 * 60)

local function round(num)
    return num >= 0 and math.floor(num + 0.5) or math.ceil(num - 0.5)
end

local function update_town_rest()
    local this = ScenarioTable.get_table()
    for _, town_center in pairs(this.town_centers) do
        local town_force = town_center.market.force
        if #town_force.connected_players > 0 then
            town_center.town_rest.current_modifier = math_max(town_center.town_rest.current_modifier - town_rest_down_per_loop, 0)
            town_center.town_rest.last_online = game.tick
            if math_abs(town_center.town_rest.current_modifier - town_center.town_rest.previous_modifier) >= 0.2
                    or (town_center.town_rest.current_modifier == 0 and town_center.town_rest.previous_modifier > 0) then
                town_force.print("Your town rest bonus is now " .. format_rest_modifier(town_center.town_rest.current_modifier)
                    .. ". Town rest boosts player damage and scrap/mining productivity. It also lowers research cost."
                    .. " You collect town rest bonus while you are offline.", Utils.scenario_color)
                town_center.town_rest.previous_modifier = town_center.town_rest.current_modifier
            end
        else    -- offline
            if game.tick - town_center.town_rest.last_online > town_rest_min_period_ticks then   -- discourage going online quickly to check town
                town_center.town_rest.current_modifier = math_min(town_center.town_rest.current_modifier + town_rest_up_per_loop, 1)
            end
        end
        local target_prod_bonus = town_center.town_rest.current_modifier * 0.5
        if math_abs(town_center.town_rest.mining_prod_bonus - target_prod_bonus) >= 0.01 then
            local diff = target_prod_bonus - town_center.town_rest.mining_prod_bonus
            local combined_bonus_precise = town_center.market.force.mining_drill_productivity_bonus + diff
            local combined_bonus_rounded = round(100 * combined_bonus_precise) / 100
            local rounding_error = combined_bonus_rounded - combined_bonus_precise
            town_center.market.force.mining_drill_productivity_bonus = combined_bonus_rounded
            town_center.town_rest.mining_prod_bonus = town_center.town_rest.mining_prod_bonus + diff + rounding_error
        end

        --game.print("XDB town rest: " ..  town_center.town_rest.current_modifier)
    end
end

local function find_good_town_build_position(initial_position, force, surface)
    local tries = 0
    local radius = 20
    local angle
    local force_name = force.name
    while tries < 100 do
        for _ = 1, 8 do
            -- position on the circle radius
            angle = math_random(0, 360)
            local t = math_rad(angle)
            local x = math_floor(initial_position.x + math_cos(t) * radius)
            local y = math_floor(initial_position.y + math_sin(t) * radius)
            local variation_position = { x = x, y = y}
            --log("testing {" .. variation_position.x .. "," .. variation_position.y .. "}")

            MapLayout.force_gen_chunk(variation_position, surface, 1)
            if is_valid_location(force_name, surface, variation_position) then
                if Evolution.get_evolution(variation_position, true) < 0.1 then
                    return variation_position
                end
            end
        end
        -- near a town, increment the radius and select another angle
        radius = radius + math_random(1, 30)
        tries = tries + 1
    end

    log("ERROR: found no good spot for a town")
    return false
end

commands.add_command(
        'good-spot',
        'Reveals a good location to build a town',
        function(cmd)
            local player = game.players[cmd.player_index]

            if not player or not player.valid then
                return
            end

            log("USAGE_ANALYTICS: player " .. player.name .. " used good-spot")
            local pos = find_good_town_build_position(player.position, player.force, player.surface)
            if pos then
                player.print("A good position for a town is here: [gps=" .. pos.x .. "," .. pos.y .. "]", Utils.scenario_color)
            else
                player.print("Could not find a good spot", Utils.scenario_color_warning)
            end
        end
)

Event.on_nth_tick(town_rest_loop_time, update_town_rest)
Event.add(defines.events.on_built_entity, found_town)
Event.add(defines.events.on_robot_built_entity, found_town)
Event.add(defines.events.on_player_repaired_entity, on_player_repaired_entity)
Event.add(defines.events.on_entity_damaged, on_entity_damaged)

return Public
