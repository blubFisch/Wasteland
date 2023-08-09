-- biters yield coins -- by mewmew

local Event = require 'utils.event'
local insert = table.insert
local math_floor = math.floor

local coin_yield = {
    ['behemoth-biter'] = 5,
    ['behemoth-spitter'] = 5,
    ['behemoth-worm-turret'] = 20,
    ['big-biter'] = 3,
    ['big-spitter'] = 3,
    ['big-worm-turret'] = 16,
    ['biter-spawner'] = 32,
    ['medium-biter'] = 2,
    ['medium-spitter'] = 2,
    ['medium-worm-turret'] = 12,
    ['small-biter'] = 1,
    ['small-spitter'] = 1,
    ['small-worm-turret'] = 8,
    ['spitter-spawner'] = 32
}

local entities_that_earn_coins = {
    ['artillery-turret'] = true,
    ['gun-turret'] = true,
    ['laser-turret'] = true,
    ['flamethrower-turret'] = true
}

--extra coins for "boss" biters from biter_health_booster.lua
local function get_coin_count(entity)
    local coin_count = coin_yield[entity.name]
    if not coin_count then
        return
    end
    if not global.biter_health_boost_units then
        return coin_count
    end
    local unit_number = entity.unit_number
    if not unit_number then
        return coin_count
    end
    if not global.biter_health_boost_units[unit_number] then
        return coin_count
    end
    if not global.biter_health_boost_units[unit_number][3] then
        return coin_count
    end
    local m = 1 / global.biter_health_boost_units[unit_number][2]
    coin_count = math_floor(coin_count * m)
    if coin_count < 1 then
        return 1
    end
    return coin_count
end

local function on_entity_died(event)
    local entity = event.entity
    if not entity.valid then
        return
    end
    if entity.force.index ~= 2 then
        return
    end

    local coin_count = get_coin_count(entity)
    if not coin_count then
        return
    end

    local players_to_reward = {}
    local cause = event.cause

    if cause and cause.valid then
        --game.print("XDB " .. cause.type .. " " .. cause.name)
        if cause.type == 'combat-robot' then
            local owner = cause.combat_robot_owner
            if owner then
                insert(players_to_reward, owner.player)
            end
        elseif cause.name == 'character' then
            insert(players_to_reward, cause)
        elseif cause.type == 'car' then
            local driver = cause.get_driver()
            local passenger = cause.get_passenger()
            if driver then
                insert(players_to_reward, driver.player)
            end
            if passenger then
                insert(players_to_reward, passenger.player)
            end
        elseif cause.type == 'locomotive' then
            local train_passengers = cause.train.passengers
            if train_passengers then
                for _, passenger in pairs(train_passengers) do
                    insert(players_to_reward, passenger)
                end
            end
        elseif entities_that_earn_coins[cause.name] then
            event.entity.surface.spill_item_stack(cause.position, {name = 'coin', count = coin_count}, true)
        end
        for _, player in pairs(players_to_reward) do
            player.insert({name = 'coin', count = coin_count})
        end
    end
end

Event.add(defines.events.on_entity_died, on_entity_died)
