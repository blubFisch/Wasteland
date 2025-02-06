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
local TeamBasics = require 'maps.wasteland.team_basics'

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
    for k, swarm in pairs(this.swarms) do
        if not is_swarm_valid(swarm) then
            table_remove(this.swarms, k)
        end
    end
end

function Public.unit_groups_start_moving()
    local this = ScenarioTable.get_table()
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

storage.last_chatter_time = storage.last_chatter_time or {}
local function biter_chatter()
    local current_tick = game.tick
    for _, player in pairs(game.connected_players) do
        if TeamBasics.is_outlander_force(player.force) and game.forces.enemy.get_cease_fire(player.force) and player.character then
            if not storage.last_chatter_time[player.index] or current_tick - storage.last_chatter_time[player.index] >= 600 then
                local position = player.position
                local surface = player.surface
                local biters = surface.find_entities_filtered({
                    type = "unit",
                    area = {{position.x - 10, position.y - 10}, {position.x + 10, position.y + 10}},
                    force = "enemy"
                })
                if #biters > 0 then
                    local messages = {
                        "Hey outlander, let's raid a town together!",
                        "I'm friendly towards you... for now.",
                        "Nice gear, mind if I take a closer look?",
                        "Just passing by, don't mind me...",
                        "Ever wonder what we biters talk about?",
                        "Outlanders like yourself and us biters should work together!",
                        "You look delicious, I mean... delightful!",
                        "Got any snacks? We ran out.",
                        "Don't mind the teeth, I'm actually quite friendly... to you",
                        "If you see a big red button, do NOT press it.",
                        "I swear, we were just about to leave.",
                        "It's time to raid a town!",
                        "I want to eat a construction bot.",
                        "We've been thinking of starting a town too. Got any tips?",
                        "Careful where you step, we just had the place cleaned.",
                        "Our last encounter with a town member didn't go so well. For them.",
                        "I want to attack a town but my friends are shy.",
                        "Stay away, we are preparing a raid on a town.",
                        "We like you. Just don't hurt anyone of us.",
                        "I hate towns, they smell bad. But I like you."
                    }
                    local message = messages[math.random(#messages)]
                    surface.create_entity({
                        name = "flying-text",
                        position = biters[1].position, -- Only show one message per player to limit spam
                        text = message,
                        color = {r=1, g=0.5, b=0.25}
                    })
                    storage.last_chatter_time[player.index] = current_tick
                end
            end
        end
    end
end

Event.on_init(on_init)
Event.add(defines.events.on_tick, on_tick)
Event.add(defines.events.on_unit_group_finished_gathering, on_unit_group_finished_gathering)
Event.on_nth_tick(60, biter_chatter)

return Public
