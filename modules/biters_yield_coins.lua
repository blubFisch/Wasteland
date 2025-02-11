-- biters yield coins -- by mewmew

local Event = require 'utils.event'
local math_floor = math.floor
local DamageUtils = require 'utils.damage_utils'

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

local function get_coin_count(entity)
    local coin_count = coin_yield[entity.name]
    if not coin_count then
        return
    end
    if not storage.biter_health_boost_units then
        return coin_count
    end
    local unit_number = entity.unit_number
    if not unit_number then
        return coin_count
    end
    if not storage.biter_health_boost_units[unit_number] then
        return coin_count
    end
    if not storage.biter_health_boost_units[unit_number][3] then
        return coin_count
    end
    local m = 1 / storage.biter_health_boost_units[unit_number][2]
    coin_count = math_floor(coin_count * m)
    if coin_count < 1 then
        return 1
    end
    return coin_count
end


local __coin_stack = {name = "coin", count = 1}
local __spill_item_stack_param = {
    position = nil, stack = __coin_stack,
    enable_looted = true, allow_belts = true
}
local function on_entity_died(event)
    local entity = event.entity
    if not entity.valid then
        return
    end
    if entity.force.index ~= 2 then -- 2 is enemy
        return
    end

    local coin_count = get_coin_count(entity)
    if not coin_count then
        return
    end
    __coin_stack.count = coin_count

    local cause = event.cause
    if not (cause and cause.valid) then return end

    if entities_that_earn_coins[cause.name] then
        __spill_item_stack_param.position = cause.position
        event.entity.surface.spill_item_stack(__spill_item_stack_param)
    else
        local players_to_reward = DamageUtils.get_players_from_cause(event.cause)
        for _, player in pairs(players_to_reward) do
            player.insert(__coin_stack)
        end
    end
end

Event.add(defines.events.on_entity_died, on_entity_died)
