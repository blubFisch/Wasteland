local Public = {}
local math_random = math.random
local math_floor = math.floor
local math_sqrt = math.sqrt
local math_round = math.round
local table_size = table.size
local table_insert = table.insert
local table_remove = table.remove
local table_shuffle = table.shuffle_table

local Event = require 'utils.event'
local Global = require 'utils.global'
local BiterHealthBooster = require 'modules.biter_health_booster_v2'

local tick_schedule = {}
Global.register(
    tick_schedule,
    function(t)
        tick_schedule = t
    end
)

local ScenarioTable = require 'maps.wasteland.table'
local Evolution = require 'maps.wasteland.evolution'

local function get_commmands(target, group)
    local commands = {}
    local group_position = {x = group.position.x, y = group.position.y}
    local step_length = 128

    local target_position = target.position
    local distance_to_target = math_floor(math_sqrt((target_position.x - group_position.x) ^ 2 + (target_position.y - group_position.y) ^ 2))
    local steps = math_floor((distance_to_target - 27) / step_length) + 1
    local vector = {math_round((target_position.x - group_position.x) / steps, 3), math_round((target_position.y - group_position.y) / steps, 3)}

    for _ = 1, steps, 1 do
        group_position.x = group_position.x + vector[1]
        group_position.y = group_position.y + vector[2]
        local position = group.surface.find_non_colliding_position('small-biter', group_position, step_length, 2)
        if position then
            commands[#commands + 1] = {
                type = defines.command.go_to_location,
                destination = {x = position.x, y = position.y},
                radius = 16,
                distraction = defines.distraction.by_damage
            }
        end
    end

    commands[#commands + 1] = {
        type = defines.command.attack,
        target = target,
        distraction = defines.distraction.by_damage
    }
    commands[#commands + 1] = {
        type = defines.command.attack_area,
        destination = target.position,
        radius = 27,
        distraction = defines.distraction.by_anything
    }
    commands[#commands + 1] = {
        type = defines.command.build_base,
        destination = target.position,
        distraction = defines.distraction.by_damage
    }

    return commands
end

local function swarm_eligible_town(town_center)
    return #town_center.market.force.connected_players > 0
            and town_center.evolution.biters > 0.2
            and game.tick - town_center.last_swarm >= 20 * 60 * 60
            and not town_center.marked_afk
end

local function roll_market()
    local this = ScenarioTable.get_table()
    local keyset = {}
    for town_name, town_center in pairs(this.town_centers) do
        if swarm_eligible_town(town_center) then
            -- Lottery system to assign higher chances to higher evo
            local tries = math_floor(town_center.evolution.biters * 20)
            for _ = 1, tries, 1 do
                table_insert(keyset, town_name)
            end
        end
    end
    if #keyset == 0 then
        return nil
    end
    local tc = math_random(1, #keyset)
    return this.town_centers[keyset[tc]]
end

local function get_random_close_spawner(surface, market, radius)
    local units = surface.find_enemy_units(market.position, radius, market.force)
    if units ~= nil and #units > 0 then
        -- found units, shuffle the list
        table_shuffle(units)
        while units[1] do
            local unit = units[1]
            if unit.spawner then
                return unit.spawner
            end
            table_remove(units, 1)
        end
    end
end

local function is_swarm_valid(swarm)
    local group = swarm.group
    if not group then
        return
    end
    if not group.valid then
        return
    end
    if game.tick >= swarm.timeout then
        group.destroy()
        return
    end
    return true
end

function Public.validate_swarms()
    local this = ScenarioTable.get_table()
    if this.testing_mode then
        return
    end
    for k, swarm in pairs(this.swarms) do
        if not is_swarm_valid(swarm) then
            table_remove(this.swarms, k)
        end
    end
end

function Public.unit_groups_start_moving()
    local this = ScenarioTable.get_table()
    if this.testing_mode then
        return
    end
    for _, swarm in pairs(this.swarms) do
        if swarm.group then
            if swarm.group.valid then
                swarm.group.start_moving()
            end
        end
    end
end

function Public.swarm(town_center, radius)
    local this = ScenarioTable.get_table()
    if this.testing_mode then
        return
    end
    local r = radius or 32
    local tc = town_center or roll_market()
    if not tc or r > 512 then
        return
    end

    -- skip if we have to many swarms already
    local count = table_size(this.swarms)
    local towns = table_size(this.town_centers)
    if count > 3 * towns then
        log("too many active swarms!")
        return
    end

    local market = tc.market
    local surface = market.surface

    -- find a spawner
    local spawner = get_random_close_spawner(surface, market, r)
    if not spawner then
        r = r + 16
        local future = game.tick + 1
        -- schedule to run this method again with a higher radius on next tick
        if not tick_schedule[future] then
            tick_schedule[future] = {}
        end
        tick_schedule[future][#tick_schedule[future] + 1] = {
            callback = 'swarm',
            params = {tc, r}
        }
        return
    end

    -- get our evolution at the spawner location
    local evolution
    if spawner.name == 'spitter-spawner' then
        evolution = Evolution.get_biter_evolution(spawner)
    else
        evolution = Evolution.get_spitter_evolution(spawner)
    end

    -- get our target amount of enemies based on relative evolution
    local count2 = (evolution * 150) + 10

    local units = spawner.surface.find_enemy_units(spawner.position, 16, market.force)
    if #units < count2 then
        units = spawner.surface.find_enemy_units(spawner.position, 32, market.force)
    end
    if #units < count2 then
        units = spawner.surface.find_enemy_units(spawner.position, 64, market.force)
    end
    if #units < count2 then
        units = spawner.surface.find_enemy_units(spawner.position, 128, market.force)
    end
    if not units[1] then
        return
    end

    -- Turn strongest unit into a boss
    local max_health = 0
    local max_unit
    for _, unit in pairs(units) do
        if unit.health > max_health then
            max_health = unit.health
            max_unit = unit
        end
    end
    BiterHealthBooster.add_boss_unit(max_unit, 4)

    local unit_group_position = surface.find_non_colliding_position('biter-spawner', units[1].position, 256, 1)
    if not unit_group_position then
        return
    end
    local unit_group = surface.create_unit_group({position = unit_group_position, force = units[1].force})

    for key, unit in pairs(units) do
        if key > count2 then
            break
        end
        unit_group.add_member(unit)
    end

    unit_group.set_command(
        {
            type = defines.command.compound,
            structure_type = defines.compound_command.return_last,
            commands = get_commmands(market, unit_group)
        }
    )
    town_center.last_swarm = game.tick
    --game.print("XDB Swarm go " .. town_center.town_name)
    table_insert(this.swarms, {group = unit_group, timeout = game.tick + 36000})
end

local cost_per_biter_config = {
    [1] = 1,
    [2] = 3,
    [3] = 10
}

local function on_player_dropped_item(event)
    local player = game.players[event.player_index]
    local dropped_item = event.entity

    if dropped_item.stack.name == "coin" then
        local surface = player.surface
        local coin_position = dropped_item.position
        local this = ScenarioTable.get_table()

        -- Find closest spawner
        local spawners = surface.find_entities_filtered{type = "unit-spawner", position = coin_position, radius = 10}
        if #spawners == 0 then return end
        table.sort(spawners, function(a, b)
            return ((a.position.x - coin_position.x)^2 + (a.position.y - coin_position.y)^2) < ((b.position.x - coin_position.x)^2 + (b.position.y - coin_position.y)^2)
        end)
        local closest_spawner = spawners[1]

        -- Rate limit check for the closest spawner
        local current_time = game.tick
        local last_spawn_time = this.last_spawn_time_per_spawner[closest_spawner.unit_number] or 0
        if current_time - last_spawn_time < 10 then
            return
        end

        local unit_size = math.min(Evolution.get_unit_size(coin_position), 3)
        local cost_per_biter = cost_per_biter_config[unit_size]
        local total_coins = 0

        -- Count coins from dropped items
        local coin_stacks = surface.find_entities_filtered{type = "item-entity", position = coin_position, radius = 10, name = "item-on-ground"}
        for _, coin_stack in pairs(coin_stacks) do
            if coin_stack.stack.name == "coin" then
                total_coins = total_coins + coin_stack.stack.count
            end
        end

        -- Check if there are enough coins to cover the cost
        if total_coins >= cost_per_biter then
            local coins_to_use = cost_per_biter

            -- Deduct coins from dropped items first
            for _, coin_stack in ipairs(coin_stacks) do
                if coin_stack.stack.name == "coin" then
                    if coin_stack.stack.count <= coins_to_use then
                        coins_to_use = coins_to_use - coin_stack.stack.count
                        coin_stack.destroy()
                    else
                        coin_stack.stack.count = coin_stack.stack.count - coins_to_use
                        coins_to_use = 0
                        break
                    end
                end
            end

            -- Proceed with spawn if coins were deducted successfully
            if coins_to_use == 0 then
                this.last_spawn_time_per_spawner[closest_spawner.unit_number] = current_time
                local unit_type_id = math.random(0,1)
                local unit_name = unit_type_id == 1 and Evolution.get_biter_by_size(unit_size) or Evolution.get_spitter_by_size(unit_size)
                local biter_position = surface.find_non_colliding_position(unit_name, coin_position, 32, 2)
                if biter_position then
                    local biter = surface.create_entity{name = unit_name, position = biter_position}

                    -- Find the closest town center to the coin drop
                    local closest_town_center
                    local closest_distance = math.huge
                    for _, town_center in pairs(this.town_centers) do
                        local distance_squared = (coin_position.x - town_center.market.position.x)^2 + (coin_position.y - town_center.market.position.y)^2
                        if distance_squared < 300^2 and distance_squared < closest_distance then
                            closest_distance = distance_squared
                            closest_town_center = town_center
                        end
                    end

                    if closest_town_center then
                        biter.set_command({
                            type = defines.command.attack,
                            target = closest_town_center.market,
                            distraction = defines.distraction.by_damage
                        })
                    end
                end
            end
        end
    end
end

local function on_unit_group_finished_gathering(event)
    local unit_group = event.group
    local position = unit_group.position
    local entities = unit_group.surface.find_entities_filtered({position = position, radius = 256, name = 'market'})
    local target = entities[1]
    if target ~= nil then
        local force = target.force
        local this = ScenarioTable.get_table()
        local town_center = this.town_centers[force.name]
        if not town_center or not swarm_eligible_town(town_center) then
            return
        end
        unit_group.set_command(
            {
                type = defines.command.compound,
                structure_type = defines.compound_command.return_last,
                commands = get_commmands(target, unit_group)
            }
        )
    end
end

local function on_tick()
    if not tick_schedule[game.tick] then
        return
    end
    for _, token in pairs(tick_schedule[game.tick]) do
        local callback = token.callback
        local params = token.params
        if callback == 'swarm' then
            Public.swarm(params[1], params[2])
        end
    end
    tick_schedule[game.tick] = nil
end

local on_init = function()
    BiterHealthBooster.acid_nova(true)
    BiterHealthBooster.check_on_entity_died(true)
end

Event.on_init(on_init)
Event.add(defines.events.on_tick, on_tick)
Event.add(defines.events.on_unit_group_finished_gathering, on_unit_group_finished_gathering)
Event.add(defines.events.on_player_dropped_item, on_player_dropped_item)


return Public
