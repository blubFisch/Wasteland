local Public = {}

local ScenarioTable = require 'maps.wasteland.table'
local Team = require 'maps.wasteland.team'
local Event = require 'utils.event'
local Spawn = require 'maps.wasteland.spawn'
local Info = require 'maps.wasteland.info'
local Tutorial = require 'maps.wasteland.tutorial'
local ScoreBoard = require 'maps.wasteland.score_board'
local ResearchBalance = require 'maps.wasteland.research_balance'
local CombatBalance = require 'maps.wasteland.combat_balance'
local Evolution = require 'maps.wasteland.evolution'
local GameMode = require 'maps.wasteland.game_mode'
local TeamBasics = require 'maps.wasteland.team_basics'
local Utils = require 'maps.wasteland.utils'

local map_pos_frame_id = 'wasteland_map_position'
local evo_frame_id = 'wasteland_evo_display'

local spawn_kill_time = 60 * 30
local minimum_respawn_time = 30 * 60
local reckless_death_increment = 30 * 60
local reckless_death_limit = 5 * 3600

function Public.initialize(player)
    player.teleport({0, 0}, game.surfaces['limbo'])
    Team.set_player_to_outlander(player)
    Team.set_player_starter_inventory(player)
    local this = ScenarioTable.get()
    if (this.testing_mode) then
        player.cheat_mode = true
        player.insert {name = 'coin', count = '9900'}
    end
end

function Public.spawn_initially(player)
    local this = ScenarioTable.get()
    local surface = game.surfaces['nauvis']
    local spawn_point = Spawn.set_new_spawn_point(player, surface)
    local new_pos = surface.find_non_colliding_position('character', spawn_point, 50, 0.5)
    player.teleport(new_pos or spawn_point, surface)

    this.strikes[player.name] = 0
    this.cooldowns_town_placement[player.index] = 0
    this.respawn_time[player.name] = minimum_respawn_time
end

function Public.load_buffs(player)
    if TeamBasics.is_town_force(player.force) then
        return
    end
    local this = ScenarioTable.get()
    local player_index = player.index
    if player.character == nil then
        return
    end
    if this.buffs[player_index] == nil then
        this.buffs[player_index] = {}
    end
    if this.buffs[player_index].character_inventory_slots_bonus ~= nil then
        player.character.character_inventory_slots_bonus = this.buffs[player_index].character_inventory_slots_bonus
    end
    if this.buffs[player_index].character_mining_speed_modifier ~= nil then
        player.character.character_mining_speed_modifier = this.buffs[player_index].character_mining_speed_modifier
    end
    if this.buffs[player_index].character_crafting_speed_modifier ~= nil then
        player.character.character_crafting_speed_modifier = this.buffs[player_index].character_crafting_speed_modifier
    end
end

function Public.requests(player)
    local this = ScenarioTable.get()
    if this.requests[player.index] and this.requests[player.index] == 'kill-character' then
        if player.character and player.character.valid then
            -- Clear inventories to avoid people easily getting back their stuff after a town dies offline
            local inventories = {
                player.get_inventory(defines.inventory.character_main),
                player.get_inventory(defines.inventory.character_guns),
                player.get_inventory(defines.inventory.character_ammo),
                player.get_inventory(defines.inventory.character_armor),
                player.get_inventory(defines.inventory.character_vehicle),
                player.get_inventory(defines.inventory.character_trash)
            }
            for _, i in pairs(inventories) do
                i.clear()
            end

            if this.town_kill_message[player.index] then
                player.print("Your town is no more: " .. this.town_kill_message[player.index], {r = 1, g = 0, b = 0})
                this.town_kill_message[player.index] = nil
            end

            player.character.die()
        end
        this.requests[player.index] = nil
    end
end

local function init_position_frame(player)
    if player.gui.top[map_pos_frame_id] then
        player.gui.top[map_pos_frame_id].destroy()
    end
    local button = player.gui.top.add({ type = 'label', caption = "Position",
                                        name = map_pos_frame_id})
    button.tooltip = "Your player position"
    button.style.font_color = { r = 255, g = 255, b = 255}
    button.style.top_padding = 10
    button.style.left_padding = 10
    button.style.right_padding = 10
    button.style.bottom_padding = 10
end

local function init_evo_frame(player)
    if player.gui.top[evo_frame_id] then
        player.gui.top[evo_frame_id].destroy()
    end
    local button = player.gui.top.add({ type = 'label', caption = "Evolution",
                                        name = evo_frame_id})
    button.tooltip = "Biter evolution level at your position. In this scenario, evolution depends on the research of nearby towns"
    button.style.font_color = { r = 255, g = 255, b = 255}
    button.style.top_padding = 10
    button.style.left_padding = 10
    button.style.right_padding = 10
    button.style.bottom_padding = 10
end

local function update_player_position_displays()
    for _, player in pairs(game.connected_players) do
        player.gui.top[map_pos_frame_id].caption = "Position: "
                .. string.format('%.0f, %.0f', player.physical_position.x,  player.physical_position.y)
    end
end

local function update_player_evo_displays()
    for _, player in pairs(game.connected_players) do
        local e = Evolution.get_evolution(player.physical_position, true)
        local color
        if e < 0.2 then
            color = {r = 0, g = 255, b = 0}
        elseif e < 0.6 then
            color = {r = 255, g = 255, b = 0}
        else
            color = {r = 255, g = 0, b = 0}
        end
        player.gui.top[evo_frame_id].caption = "Evolution: " .. string.format('%.0f%%', e * 100)
        player.gui.top[evo_frame_id].style.font_color = color
    end
end

local function hint_treasure()
    local this = ScenarioTable.get()
    for _, player in pairs(game.connected_players) do
        if this.treasure_hint[player.index] == nil then
            if player.online_time % (30 * 60 * 60) < 60 then
                player.create_local_flying_text(
                    {
                        position = player.physical_position,
                        text = 'You hear rumors about a huge treasure at the center of the map',
                        color = {r = 0.4, g = 0.6, b = 0.8},
                        time_to_live = 160
                    }
                )
            end
            if math.sqrt(player.physical_position.x ^ 2 + player.physical_position.y ^ 2) < 150 then
                this.treasure_hint[player.index] = false
            end
        end
    end
end

local function on_player_joined_game(event)
    local player = game.players[event.player_index]
    Team.set_player_color(player)
    if player.online_time == 0 then
        Info.toggle_button(player)
        Info.show(player)
        ScoreBoard.add_score_button(player)
        Tutorial.register_for_tutorial(player)
        ResearchBalance.add_balance_ui(player)
        CombatBalance.add_balance_ui(player)
        init_position_frame(player)
        init_evo_frame(player)
        GameMode.add_mode_button(player)
        Info.add_last_winner_button(player)

        Public.initialize(player)
        Public.spawn_initially(player)
    else
        if player.force == game.forces.neutral then -- Existing player joins after map reset
            Public.initialize(player)
            Public.spawn_initially(player)
        end
    end
    Team.player_joined(player)
    Public.load_buffs(player)
    Public.requests(player)
end

local function on_player_respawned(event)
    local this = ScenarioTable.get()
    local player = game.players[event.player_index]
    local surface = player.physical_surface

    Team.set_player_starter_inventory(player)

    if TeamBasics.is_outlander_force(player.force) then
        Team.set_biter_peace(player.force, true)
    end

    local spawn_point = Spawn.get_spawn_point(player, surface)

    -- reset cooldown
    this.last_respawn[player.name] = game.tick
    local new_pos = surface.find_non_colliding_position('character', spawn_point, 50, 0.5)
    player.teleport(new_pos or spawn_point, surface)

    Public.load_buffs(player)
end

local function on_player_died(event)
    local this = ScenarioTable.get()
    local player = game.players[event.player_index]

    if this.last_respawn[player.name] and game.tick - this.last_respawn[player.name] < spawn_kill_time then
        this.strikes[player.name] = this.strikes[player.name] + 1
        if this.strikes[player.name] >= 3 and TeamBasics.is_town_force(player.force) then
            player.print("You have been spawn killed multiple times. Use the chat command /suicide-town to kill your town", Utils.scenario_color)
        end
    else
        this.strikes[player.name] = 0
    end

    -- Discourage reckless gameplay like suicide-running tanks into other players bases
    if this.last_respawn[player.name] and game.tick - this.last_respawn[player.name] < reckless_death_limit then
        player.print("You have already died within the last " .. reckless_death_limit / 3600 .. " minutes -> Higher spawn time", Utils.scenario_color)
        this.respawn_time[player.name] = this.respawn_time[player.name] + reckless_death_increment
        this.next_respawn_time_update[player.index] = game.tick + reckless_death_limit
    end
    player.ticks_to_respawn = this.respawn_time[player.name]
end

local function update_respawn_times()
    local this = ScenarioTable.get()
    for _, player in pairs(game.connected_players) do
        if this.next_respawn_time_update[player.index] and game.tick > this.next_respawn_time_update[player.index] then
            if this.respawn_time[player.name] > minimum_respawn_time then
                this.respawn_time[player.name] = math.min(this.respawn_time[player.name] - reckless_death_increment, minimum_respawn_time)
                this.next_respawn_time_update[player.index] = game.tick + reckless_death_limit
                player.print("Your respawn time has been lowered to " .. this.respawn_time[player.name] / 60 .. " sec")
            else
                this.next_respawn_time_update[player.index] = nil
            end
        end
    end
end

local stats_update_frequency_secs = 60
local function update_players_stats()
    local this = ScenarioTable.get()
    local current_online_players = #game.connected_players
    if current_online_players > this.player_online_max then
        this.player_online_max = current_online_players
    end
    if game.tick ~= 0 then
        this.player_online_time_sec = this.player_online_time_sec + current_online_players * 60
        log("Players stats: cur " .. current_online_players .. " max " .. this.player_online_max ..
            " avg ".. tonumber(string.format("%.1f", this.player_online_time_sec / (game.tick / stats_update_frequency_secs))))
    end
end

Event.on_nth_tick(60, update_player_position_displays)
Event.on_nth_tick(60, update_player_evo_displays)
Event.on_nth_tick(60, hint_treasure)
Event.on_nth_tick(60 * stats_update_frequency_secs, update_players_stats)
Event.on_nth_tick(121, update_respawn_times)

Event.add(defines.events.on_player_joined_game, on_player_joined_game)
Event.add(defines.events.on_player_respawned, on_player_respawned)
Event.add(defines.events.on_player_died, on_player_died)

return Public
