local Event = require 'utils.event'
local message_color = {r = 0.9, g = 0.9, b = 0.9}
local TeamBasics = require 'maps.wasteland.team_basics'
local Team = require 'maps.wasteland.team'

local messages = {
    ['small-biter'] = {' was nibbled to death', ' should not have played with the biters', ' is biter food'},
    ['medium-biter'] = {' lost their leg to a hungry biter', ' is biter food', ' was a tasty biter treat'},
    ['big-biter'] = {' had their head chomped off', ' is biter food', ' was a tasty biter treat'},
    ['behemoth-biter'] = {' was devoured by a behemoth biter', ' was crushed by a behemoth biter', ' is biter food'},
    ['small-spitter'] = {' melted away by acid spit!', " couldn't dodge the spit in time"},
    ['medium-spitter'] = {' melted away by acid spit!', " couldn't dodge the spit in time"},
    ['big-spitter'] = {' melted away by acid spit!', " couldn't dodge the spit in time", ' got blasted away by a spitter'},
    ['behemoth-spitter'] = {' melted away by acid spit!', " couldn't dodge the spit in time", ' got blasted away by a spitter'},
    ['small-worm-turret'] = {' melted away by acid spit!', " couldn't dodge the spit in time"},
    ['medium-worm-turret'] = {' melted away by acid spit!', " couldn't dodge the spit in time", ' got blasted away by a medium worm turret'},
    ['big-worm-turret'] = {' melted away by acid spit!', " couldn't dodge the spit in time", ' got blasted away by a big worm turret'},
    ['gun-turret'] = {' was mowed down by a gun turret'},
    ['laser-turret'] = {' was fatally enlightened by a laser turret'},
    ['flamethrower-turret'] = {' was barbecued by a flamer turret'},
    ['cargo-wagon'] = {' was flattened', ' was crushed'},
    ['locomotive'] = {' was flattened', ' was crushed'}
}

local function display_player_name(player)
    if player.tag ~= '' then
        return player.name .. " " .. player.tag
    else
        return player.name
    end
end

local function on_player_died(event)
    local player = game.players[event.player_index]

    local player_display = display_player_name(player)

    if event.cause then
        local cause = event.cause
        if not cause.name then
            game.print(player_display .. ' was killed', message_color)
            return
        end
        if messages[cause.name] then
            local extension = ""
            if TeamBasics.is_town_force(cause.force) then
                extension = " of " .. Team.force_display_name(cause.force)
            end
            game.print(player_display .. messages[cause.name][math.random(1, #messages[cause.name])] .. extension, message_color)
            return
        end

        if cause.name == 'character' then
            if not cause.player.name then
                return
            end
            game.print(player_display .. ' was killed by ' .. display_player_name(cause.player), message_color)
            return
        end

        if cause.type == 'car' or cause.type == 'tank' then
            local driver = cause.get_driver()
            if driver and driver.player then
                game.print(player_display .. ' was killed by ' .. display_player_name(driver.player) .. ' with a ' .. cause.name, message_color)
                return
            end
        end

        if cause.type == 'combat-robot' then
            local owner = cause.combat_robot_owner
            game.print(player_display .. ' was killed by ' .. display_player_name(owner.player) .. ' with a ' .. cause.name, message_color)
            return
        end

        game.print(player_display .. ' was killed by ' .. cause.name, message_color)
        return
    end
    for _, p in pairs(game.connected_players) do
        if player.force.name ~= p.force.name then
            p.print(player_display .. ' was killed', message_color)
        end
    end
end

Event.add(defines.events.on_player_died, on_player_died)
