local Public = {}

local Event = require 'utils.event'
local Alert = require 'utils.alert'
local ScenarioTable = require 'maps.wasteland.table'
local Nauvis = require 'maps.wasteland.nauvis'
local Team = require 'maps.wasteland.team'
local Player = require 'maps.wasteland.player'
local Color = require 'utils.color_presets'
local MapLayout = require 'maps.wasteland.map_layout'
local Info = require 'maps.wasteland.info'
local Utils = require 'maps.wasteland.utils'

local function init_reset_sequence()
    storage.game_end_sequence_start = game.tick + 1
end
Public.init_reset_sequence = init_reset_sequence

-- Reset is split into parts for performance
local function reset_map_part_1()
    ScenarioTable.reset_table()
    MapLayout.init()
    game.reset_time_played()
    game.reset_game_state()
    for _, player in pairs(game.players) do
        player.teleport({0, 0}, game.surfaces['limbo'])
    end
end

local function reset_map_part_2()
    Nauvis.initialize()
end

local function reset_map_part_3()
    Team.initialize()
    for _, player in pairs(game.players) do
        if player.connected then
            Player.initialize(player)
            Player.spawn_initially(player)
        else
            player.force = game.forces.neutral  -- Mark them to be reinitialised on join
        end
        Team.set_player_color(player)
        Player.load_buffs(player)
        Info.update_last_winner_name(player)
    end
    Alert.alert_all_players(10, 'The world has been reset!', Color.white, 'restart_required', 1.0)
end

local function on_tick()
    if storage.game_end_sequence_start then
        local tick = game.tick
        if tick == storage.game_end_sequence_start then
            Alert.alert_all_players(60, 'The world is about to reset!', Color.white, 'warning-white', 1.0)
        elseif tick == storage.game_end_sequence_start + 60 * 60 then
            game.print("The world will now reset. This can cause the game to hang for a while....", Utils.scenario_color)
            Team.reset_all_forces()
        elseif tick == storage.game_end_sequence_start + 60 * 60 + 1 then
            reset_map_part_1()
        elseif tick == storage.game_end_sequence_start + 60 * 60 + 31 then
            reset_map_part_2()
        elseif tick == storage.game_end_sequence_start + 60 * 60 + 61 then
            reset_map_part_3()
        end
    end
end

commands.add_command(
    'reset',
    'Usable only for admins - controls the scenario!',
    function()
        local p
        local player = game.player

        if not player or not player.valid then
            p = log
        else
            p = player.print
            if not player.admin then
                return
            end
        end
        local this = ScenarioTable.get_table()

        if not this.reset_confirmed or game.tick - this.reset_confirmed > 600 then
            this.reset_confirmed = game.tick
            p('[WARNING] Run this command again if you really want to reset!')
            return
        end

        if player and player.valid then
            game.print(player.name .. ' has reset the game!', {r = 0.98, g = 0.66, b = 0.22})
        else
            game.print('Server has reset the game!', {r = 0.98, g = 0.66, b = 0.22})
        end
        this.reset_confirmed = nil
        init_reset_sequence()
        p('[WARNING] Game has been reset!')
    end
)

Event.add(defines.events.on_tick, on_tick)

return Public
