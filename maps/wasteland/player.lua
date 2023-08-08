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

local map_pos_frame_id = 'towny_map_position'
local evo_frame_id = 'towny_evo_display'

-- how long in ticks between spawn and death will be considered spawn kill (10 seconds)
local max_ticks_between_spawns = 60 * 10

function Public.initialize(player)
    player.teleport({0, 0}, game.surfaces['limbo'])
    Team.set_player_to_outlander(player)
    Team.give_player_items(player)
    local this = ScenarioTable.get()
    if (this.testing_mode == true) then
        player.cheat_mode = true
        player.force.research_all_technologies()
        player.insert {name = 'coin', count = '9900'}
    end
end

function Public.spawn_initially(player)
    local this = ScenarioTable.get()
    local surface = game.surfaces['nauvis']
    local spawn_point = Spawn.set_new_spawn_point(player, surface)
    this.strikes[player.name] = 0

    -- reset cooldown
    this.cooldowns_town_placement[player.index] = 0
    this.last_respawn[player.name] = 0
    local new_pos = surface.find_non_colliding_position('character', spawn_point, 50, 0.5)
    player.teleport(new_pos or spawn_point, surface)
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

            if this.killer_name[player.index] then
                player.print("Your town has fallen to " .. this.killer_name[player.index] .. " since you last played!", {r = 1, g = 0, b = 0})
                this.killer_name[player.index] = nil
            else
                player.print("Your town has fallen since you last played!", {r = 1, g = 0, b = 0})
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

local function init_map_hint_frame(player)
    if player.gui.screen['towny_map_hint'] then
        player.gui.screen['towny_map_hint'].destroy()
    end
    local b = player.gui.screen.add({type = 'label', caption = "To activate map, build a town (white chest)",
                                     name = 'towny_map_hint'})
    b.location = {x = 2200, y = 100}
    b.style.font_color = {r = 255, g = 255, b = 255}
    b.style.top_padding = 10
    b.style.left_padding = 10
    b.style.right_padding = 10
    b.style.bottom_padding = 10
end

local function update_player_position_displays()
    for _, player in pairs(game.connected_players) do
        player.gui.top[map_pos_frame_id].caption = "Position: "
                .. string.format('%.0f, %.0f', player.position.x,  player.position.y)
    end
end

local function update_player_evo_displays()
    for _, player in pairs(game.connected_players) do
        local e = Evolution.get_evolution(player.position, true)
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
                        position = player.position,
                        text = 'You hear rumors about a huge treasure at the center of the map',
                        color = {r = 0.4, g = 0.6, b = 0.8},
                        time_to_live = 160
                    }
                )
            end
            if math.sqrt(player.position.x ^ 2 + player.position.y ^ 2) < 150 then
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
        init_map_hint_frame(player)
        init_evo_frame(player)
        GameMode.add_mode_button(player)

        Public.initialize(player)
        Public.spawn_initially(player)
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

Event.on_nth_tick(60, update_player_position_displays)
Event.on_nth_tick(60, update_player_evo_displays)
Event.on_nth_tick(60, hint_treasure)

Event.add(defines.events.on_player_joined_game, on_player_joined_game)
Event.add(defines.events.on_player_respawned, on_player_respawned)
Event.add(defines.events.on_player_died, on_player_died)

return Public
