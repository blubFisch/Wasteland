local Public = {}

local table_size = table.size
local math_floor = math.floor
local math_sqrt = math.sqrt
local math_max = math.max

local Score = require 'maps.wasteland.score'
local ScenarioTable = require 'maps.wasteland.table'
local PvPShield = require 'maps.wasteland.pvp_shield'
local Utils = require 'maps.wasteland.utils'
local Event = require 'utils.event'

Public.league_balance_shield_size = 111
Public.offline_shield_size = 41

function Public.in_extended_control_range(position)
    local this = ScenarioTable.get_table()
    for _, town_center in pairs(this.town_centers) do
        local town_position = town_center.market.position

        local distance = math_floor(math_sqrt((position.x - town_position.x) ^ 2 + (position.y - town_position.y) ^ 2))
        if distance < Public.get_town_control_range(town_center) * 1.5 + Public.league_balance_shield_size / 2 then   -- Account for growing control range
            return true
        end
    end
    return false
end

function Public.get_town_control_range(town_center)
    return 50 + town_center.evolution.worms * 150
end

function Public.get_town_league(town_center)
    local score = Score.total_score(town_center)
    local tank_researched = town_center.market.force.technologies['tank'].researched

    if score >= 80 then return 6 end
    if score >= 60 then return 5 end
    if score >= 45 then return 4 end
    if score >= 30 then return 3 end
    if score >= 15 or tank_researched then return 2 end
    return 1
end

local function get_league_by_items(player)
    if player.character and player.character.vehicle and player.character.vehicle.name == "tank" then
        return 2
    else
        return 1
    end
end

function Public.get_player_league(player)
    local this = ScenarioTable.get_table()
    local town_center = this.town_centers[player.force.name]

    local league = get_league_by_items(player)
    if town_center then
        local town_league = Public.get_town_league(town_center)
        league = math_max(town_league, league)
    end

    return league
end

function Public.enemy_players_nearby(town_center, max_distance, min_league)
    local market = town_center.market
    local town_force = market.force
    local town_position = market.position

    for _, player in pairs(game.connected_players) do
        if player.surface == market.surface then
            local distance = math_floor(math_sqrt((player.position.x - town_position.x) ^ 2 + (player.position.y - town_position.y) ^ 2))
            if distance < max_distance and player.force ~= town_force and not player.force.get_friend(town_force) then
                if (not min_league or Public.get_player_league(player) > min_league) and (player.character or player.driving) then
                    return true
                end
            end
        end
    end
    return false
end

function Public.shield_info_text(town_center)
    local this = ScenarioTable.get_table()
    local shield = this.pvp_shields[town_center.market.force.name]
    local info = 'League ' .. Public.get_town_league(town_center)
    if shield then
        info = info .. ', PvP Shield: '
        local lifetime_str = PvPShield.format_lifetime_str(PvPShield.remaining_lifetime(shield))
        if shield.shield_type == PvPShield.SHIELD_TYPE.OFFLINE then
            info = info .. 'While offline, max ' .. lifetime_str
        elseif shield.shield_type == PvPShield.SHIELD_TYPE.AFK then
            info = info .. 'AFK ' .. lifetime_str
        elseif shield.shield_type == PvPShield.SHIELD_TYPE.LEAGUE_BALANCE then
            info = info .. 'League balance'
        end
    end
    return info
end

local function update_pvp_shields_display()
    local this = ScenarioTable.get_table()
    for _, town_center in pairs(this.town_centers) do

        rendering.set_text(town_center.shield_text, Public.shield_info_text(town_center))

        -- Update enemy nearby display
        local town_control_range = Public.get_town_control_range(town_center)
        local info_enemies
        local color
        if Public.enemy_players_nearby(town_center, town_control_range) then
            info_enemies = "Enemies"
            color = {255, 0, 0}

            if not town_center.enemies_warning_status then
                town_center.market.force.print("Enemies have been spotted near your town. Your offline PvP shield can not activate now.", {r = 1, g = 0, b = 0})
                town_center.enemies_warning_status = 1
            end
        elseif Public.enemy_players_nearby(town_center, town_control_range + 10) then
            info_enemies = "Enemies"
            color = {255, 255, 0}
        else
            info_enemies = "No enemies"
            color = {0, 255, 0}
            town_center.enemies_warning_status = nil
        end
        info_enemies = info_enemies .. " (" .. string.format('%.0f',  town_control_range) .. " tiles)"
        rendering.set_text(town_center.enemies_text, info_enemies)
        rendering.set_color(town_center.enemies_text, color)
    end
end

local function manage_pvp_shields()
    local this = ScenarioTable.get_table()
    local offline_shield_duration_ticks = 24 * 60 * 60 * 60

    for _, town_center in pairs(this.town_centers) do
        local market = town_center.market
        local force = market.force
        local shield = this.pvp_shields[force.name]
        local offline_shield_eligible = Score.research_score(town_center) > 1
        local town_league = Public.get_town_league(town_center)

        if table_size(force.connected_players) == 0 and offline_shield_eligible then
            if not shield then
                -- Activations:
                -- nil means waiting for players to go offline
                -- -1 it is not meant to renew until players join again
                local activation = this.pvp_shield_offline_activations[force.index]
                local town_control_range = Public.get_town_control_range(town_center)
                if not activation and not Public.enemy_players_nearby(town_center, town_control_range) then
                    local time_to_full = 0.5 * 60 * 60
                    game.print("The offline PvP Shield of " .. town_center.town_name .. " is activating now." ..
                            " It will last up to " .. PvPShield.format_lifetime_str(offline_shield_duration_ticks), Utils.scenario_color)
                    PvPShield.add_shield(market.surface, market.force, market.position, Public.offline_shield_size,
                            offline_shield_duration_ticks, time_to_full, PvPShield.SHIELD_TYPE.OFFLINE)
                    this.pvp_shield_offline_activations[force.index] = -1
                end
            end
        elseif table_size(force.connected_players) > 0 then

            -- Leave offline shield online for a short time for the town's players "warm up" and also to understand it better
            if shield and shield.shield_type == PvPShield.SHIELD_TYPE.OFFLINE then
                local delay_mins = 3
                force.print("Welcome back. Your offline protection will expire in " .. delay_mins .. " minutes."
                        .. " After everyone in your town leaves, you will get a new shield for "
                        .. PvPShield.format_lifetime_str(offline_shield_duration_ticks), Utils.scenario_color)
                shield.shield_type = PvPShield.SHIELD_TYPE.OTHER
                shield.max_lifetime_ticks = game.tick - shield.lifetime_start + delay_mins * 60 * 60
            end

            -- Show hint
            if not this.pvp_shields_displayed_offline_hint[force.name] and offline_shield_eligible then
                force.print("Your town is now advanced enough to deploy an offline shield."
                        .. " Once all of your members leave, the area marked by the blue floor tiles"
                        .. " will be protected from enemy players for " .. PvPShield.format_lifetime_str(offline_shield_duration_ticks) .. "."
                        .. " However, biters will always be able to attack your town!", Utils.scenario_color)
                this.pvp_shields_displayed_offline_hint[force.name] = true
            end
            this.pvp_shield_offline_activations[force.index] = nil
        end

        -- Balancing shield
        local league_shield_activation_range = Public.league_balance_shield_size * 1.0
        local higher_league_nearby = Public.enemy_players_nearby(town_center, league_shield_activation_range, town_league)
        if higher_league_nearby then
            town_center.last_higher_league_nearby = game.tick
        end

        if not shield and higher_league_nearby then
            force.print("Your town deploys a Balancing PvP Shield because there are players of a higher league nearby", Utils.scenario_color)
            PvPShield.add_shield(market.surface, market.force, market.position, Public.league_balance_shield_size, nil, 13 * 60, PvPShield.SHIELD_TYPE.LEAGUE_BALANCE)
            update_pvp_shields_display()
        end

        local protect_time_after_nearby = 3 * 60 * 60
        if shield and shield.shield_type == PvPShield.SHIELD_TYPE.LEAGUE_BALANCE and not higher_league_nearby and game.tick - town_center.last_higher_league_nearby > protect_time_after_nearby then
            force.print("Your town's Balancing PvP Shield has been deactivated as there are no more higher league players nearby.", Utils.scenario_color)
            PvPShield.remove_shield(shield)
        end
    end
end

local function init_league_label(player)
    local this = ScenarioTable.get_table()

    local league_label = rendering.draw_text{
        text = "[League]",
        surface = player.surface,
        target = player.character,
        target_offset = {0, 0},
        color = {r = 1, g = 1, b = 1},
        alignment = "center",
        scale = 1.0
    }
    this.league_labels[player.index] = league_label
end

local function update_leagues()
    if game.tick == 0 then return end

    local this = ScenarioTable.get_table()
    for _, player in pairs(game.connected_players) do
        if player.character then
            local league_label = this.league_labels[player.index]
            if not league_label or not rendering.is_valid(league_label) then
                init_league_label(player)
            end

            local league = Public.get_player_league(player)

            rendering.set_text(this.league_labels[player.index], "League " .. league)

            if this.previous_leagues[player.index] ~= nil and league ~= this.previous_leagues[player.index] then
                player.print("You are now in League " .. league, Utils.scenario_color)
            end
            this.previous_leagues[player.index] = league
        end
    end
end

Event.on_nth_tick(60, update_pvp_shields_display)
Event.on_nth_tick(60, manage_pvp_shields)
Event.on_nth_tick(60, update_leagues)

return Public
