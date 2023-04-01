local Scheduler = require 'utils.scheduler'
local ScenarioTable = require 'maps.wasteland.table'
local Event = require 'utils.event'
local Utils = require 'maps.wasteland.utils'

-- Must be at least 1 minute
local minutes_to_die = 10

local one_minute = 60 * 60

local function on_player_died(event)
    local this = ScenarioTable.get_table()
    local player = game.players[event.player_index]
    this.suicides[player.index] = nil
end

Event.add(defines.events.on_player_died, on_player_died)

local suicide_handler = Scheduler.set(function(data)
    for i = 1, #data do
        local this = ScenarioTable.get_table()
        local player_index = data[i].player_index
        local player = game.get_player(player_index)

        if not player or not player.valid or not player.character then
            this.suicides[player_index] = nil
            return
        end

        if not this.suicides[player.index] then
            -- the suicide was cancelled (the character died)
            return
        end

        local minutes_remaining = this.suicides[player.index].minutes_remaining

        if minutes_remaining <= 0 then
            this.suicides[player.index] = nil
            player.character.die(player.force, player.character)
        else
            if minutes_remaining == 1 then
                player.print(minutes_remaining .. " minute remaining until death.", Utils.scenario_color)
            else
                player.print(minutes_remaining .. " minutes remaining until death.", Utils.scenario_color)
            end
            this.suicides[player.index].minutes_remaining = this.suicides[player.index].minutes_remaining - 1
        end
    end

end)

commands.add_command(
        'suicide',
        'Kills the player',
        function(cmd)
            local this = ScenarioTable.get_table()
            local player = game.player

            if not player or not player.valid then
                return
            end

            if this.suicides[player.index] then
                player.print("You are already dying!", Utils.scenario_color)
                return
            end

            this.suicides[player.index] = {minutes_remaining = minutes_to_die - 1}
            for i = 1, 10 do
                Scheduler.timer(game.tick + i * one_minute, suicide_handler, {player_index = player.index})
            end
            player.print("You ate a poison pill. You will die in " .. minutes_to_die .. " minutes.", Utils.scenario_color)
        end
)
