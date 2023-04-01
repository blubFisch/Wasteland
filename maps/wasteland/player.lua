local Public = {}

local ScenarioTable = require 'maps.wasteland.table'
local Team = require 'maps.wasteland.team'
local Event = require 'utils.event'
local Spawn = require 'maps.wasteland.spawn'
local Info = require 'maps.wasteland.info'
local Tutorial = require 'maps.wasteland.tutorial'
local Score = require 'maps.wasteland.score'
local ResearchBalance = require 'maps.wasteland.research_balance'
local CombatBalance = require 'maps.wasteland.combat_balance'

-- how long in ticks between spawn and death will be considered spawn kill (10 seconds)
local max_ticks_between_spawns = 60 * 10

-- how many players must login before teams are teams_enabled
local min_players_for_enabling_towns = 0

function Public.initialize(player)
    player.teleport({0, 0}, game.surfaces['limbo'])
    Team.set_player_to_outlander(player)
    Team.give_player_items(player)
    Team.give_key(player.index)
    local this = ScenarioTable.get()
    if (this.testing_mode == true) then
        player.cheat_mode = true
        player.force.research_all_technologies()
        player.insert {name = 'coin', count = '9900'}
    end
end

function Public.spawn(player)
    -- first time spawn point
    local surface = game.surfaces['nauvis']
    local spawn_point = Spawn.get_new_spawn_point(player, surface)
    local this = ScenarioTable.get()
    this.strikes[player.name] = 0
    Spawn.clear_spawn_point(spawn_point, surface)
    -- reset cooldown
    this.cooldowns_town_placement[player.index] = 0
    this.last_respawn[player.name] = 0
    player.teleport(spawn_point, surface)
end

function Public.load_buffs(player)
    if player.force.name ~= 'player' and player.force.name ~= 'rogue' then
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

            player.print("Your town has fallen since you last played. Good luck next time!", {r = 1, g = 0, b = 0})
            player.character.die()
        end
        this.requests[player.index] = nil
    end
end

function Public.increment()
    local this = ScenarioTable.get()
    local count = this.players + 1
    this.players = count
    if this.testing_mode then
        this.towns_enabled = true
    else
        if this.players >= min_players_for_enabling_towns then
            this.towns_enabled = true
        end
    end
end

local function init_position_frame(player)
    if player.gui.top['towny_map_position'] then
        player.gui.top['towny_map_position'].destroy()
    end
    local b = player.gui.top.add({type = 'label', caption = "Position",
                                  name = 'towny_map_position'})
    b.style.font_color = {r = 255, g = 255, b = 255}
    b.style.top_padding = 10
    b.style.left_padding = 10
    b.style.right_padding = 10
    b.style.bottom_padding = 10
end

local function init_map_hint_frame(player)
    if player.gui.screen['towny_map_hint'] then
        player.gui.screen['towny_map_hint'].destroy()
    end
    local b = player.gui.screen.add({type = 'label', caption = "To activate map, build a town (stone furnace)",
                                     name = 'towny_map_hint'})
    b.location = {x = 2200, y = 100}
    b.style.font_color = {r = 255, g = 255, b = 255}
    b.style.top_padding = 10
    b.style.left_padding = 10
    b.style.right_padding = 10
    b.style.bottom_padding = 10
end

local function update_player_positions()
    for _, player in pairs(game.connected_players) do
        player.gui.top['towny_map_position'].caption = "Position: "
                .. string.format('%.0f, %.0f', player.position.x,  player.position.y)
    end
end

local function on_player_joined_game(event)
    local player = game.players[event.player_index]
    Score.add_score_button(player)
    ResearchBalance.add_balance_ui(player)
    CombatBalance.add_balance_ui(player)
    Info.toggle_button(player)
    Team.set_player_color(player)
    if player.online_time == 0 then
        Public.increment()
        Public.initialize(player)
        Public.spawn(player)
        Info.show(player)
        Tutorial.register_for_tutorial(player)
        init_position_frame(player)
        init_map_hint_frame(player)
    end
    Public.load_buffs(player)
    Public.requests(player)
end

local function on_player_respawned(event)
    local this = ScenarioTable.get()
    local player = game.players[event.player_index]
    local surface = player.surface
    Team.give_player_items(player)
    if player.force == game.forces['rogue'] then
        Team.set_player_to_outlander(player)
    end
    if player.force == game.forces['player'] then
        Team.give_key(player.index)
    end

    -- get_spawn_point will always return a valid spawn
    local spawn_point = Spawn.get_spawn_point(player, surface)

    -- reset cooldown
    this.last_respawn[player.name] = game.tick
    player.teleport(spawn_point, surface)
    Public.load_buffs(player)
end

local function on_player_died(event)
    local this = ScenarioTable.get()
    local player = game.players[event.player_index]
    if this.strikes[player.name] == nil then
        this.strikes[player.name] = 0
    end

    local ticks_elapsed = game.tick - this.last_respawn[player.name]
    if ticks_elapsed < max_ticks_between_spawns then
        this.strikes[player.name] = this.strikes[player.name] + 1
    else
        this.strikes[player.name] = 0
    end
end

Event.on_nth_tick(60, update_player_positions)
Event.add(defines.events.on_player_joined_game, on_player_joined_game)
Event.add(defines.events.on_player_respawned, on_player_respawned)
Event.add(defines.events.on_player_died, on_player_died)

return Public
