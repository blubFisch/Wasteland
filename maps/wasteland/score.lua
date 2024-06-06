local Public = {}

local math_max = math.max
local ScenarioTable = require 'maps.wasteland.table'
local Event = require 'utils.event'
local Utils = require 'maps.wasteland.utils'

local age_score_factors = { 10.0, 2.4, 1.2 }
local age_score_factor = age_score_factors[global.game_mode]
local research_evo_score_factors = { 150, 65, 65 }
local research_evo_score_factor = research_evo_score_factors[global.game_mode]
local l4_score_only_offline_settings = { false, true, true }
local l4_score_only_offline = l4_score_only_offline_settings[global.game_mode]
local score_to_win = 100
Public.score_to_win = score_to_win
local max_research_score = 70
local max_survival_time_score = 70

function Public.score_increment_for_research(evo_increase)
    return evo_increase * research_evo_score_factor
end

function Public.research_score(town_center)
    return math.min(town_center.evolution.worms * research_evo_score_factor, max_research_score)
end

function Public.survival_score(town_center)
    return Public.survival_time_h(town_center) * age_score_factor
end

function Public.survival_time_h(town_center)
    return town_center.survival_time_ticks / 60 / 3600
end

function Public.total_score(town_center)
    return Public.research_score(town_center) + Public.survival_score(town_center)
end

function Public.survival_score(town_center)
    return math.min(Public.survival_time_h(town_center) * age_score_factor, max_survival_time_score)
end

local function format_score(score)
    return string.format('%.1f', math.floor(score * 10) / 10)
end
Public.format_score = format_score

function Public.extra_info()
    return "Current game mode settings:"
            .. "\n" .. "Score per hour from survival: " .. string.format('%.1f', age_score_factor)
            .. "\n" .. "Max score from survival time: " .. max_survival_time_score
            .. "\n" .. "Max score from research: " .. max_research_score
end

local function format_town_with_player_names(town_center)
    local player_names = ""
    local player_in_town_name = false
    for _, player in pairs(town_center.market.force.players) do
        if not string.find(town_center.town_name, player.name) then
            if player_names ~= "" then
                player_names = player_names .. ", "
            end
            player_names = player_names .. player.name
        else
            player_in_town_name = true
        end
    end
    if player_names ~= "" then
        if player_in_town_name then
            player_names = "+" .. player_names
        end
        player_names = " (" .. player_names .. ")"
    end
    return town_center.town_name .. player_names
end

function Public.get_town_league(town_center)
    local score = Public.total_score(town_center)
    local tank_researched = town_center.market.force.technologies['tank'].researched

    if score >= 60 then return 4 end      -- Note: referenced in info.lua
    if score >= 35 then return 3 end
    if score >= 15 or tank_researched then return 2 end
    return 1
end

function Public.get_player_league(player)
    local this = ScenarioTable.get_table()
    local town_center = this.town_centers[player.force.name]

    local league
    if player.character and player.character.vehicle and player.character.vehicle.name == "tank" then
        league = 2
    else
        league = 1
    end

    if town_center then
        local town_league = Public.get_town_league(town_center)
        league = math_max(town_league, league)
    end

    return league
end

local score_update_loop_interval = 60
local function update_score()
    local this = ScenarioTable.get_table()

    local town_highest_score = 0
    local town_total_scores = {}
    for _, town_center in pairs(this.town_centers) do
        local market = town_center.market
        local force = market.force
        local shield = this.pvp_shields[force.name]
        if not shield and (not l4_score_only_offline or Public.get_town_league(town_center) < 4 or #force.connected_players == 0) then
            town_center.survival_time_ticks = town_center.survival_time_ticks + score_update_loop_interval
        end

        town_total_scores[town_center] = Public.total_score(town_center)
        if town_total_scores[town_center] > town_highest_score then
            town_highest_score = town_total_scores[town_center]
        end

        if town_total_scores[town_center] >= score_to_win and this.winner == nil then
            this.winner = town_center.town_name
            local town_with_player_names = format_town_with_player_names(town_center)

            game.print(town_with_player_names .. " has won the game!", Utils.scenario_color)

            global.last_winner_name = town_with_player_names
            log("WINNER_STORE=\"" .. town_with_player_names .. "\"")
            if global.auto_reset_enabled then
                global.game_end_sequence_start = game.tick + 600
            else
                game.print("Automatic map restart is disabled, please wait for an admin to start a new game", Utils.scenario_color)
            end
        end
    end

    -- Announce high score towns
    if this.next_high_score_announcement == 0 then  -- init
        this.next_high_score_announcement = 70
    end
    if town_highest_score >= this.next_high_score_announcement then
        game.print("A town has reached " .. format_score(town_highest_score) .. " score." ..
                " The game ends at 100 score", Utils.scenario_color)
        if town_highest_score >= 70 then
            this.next_high_score_announcement = 80
        end
        if town_highest_score >= 80 then
            this.next_high_score_announcement = 90
        end
        if town_highest_score >= 90 then
            this.next_high_score_announcement = 95
        end
        if town_highest_score >= 95 then
            this.next_high_score_announcement = 9999 -- turning it off
        end
    end
end

Event.on_nth_tick(score_update_loop_interval, update_score)

return Public
