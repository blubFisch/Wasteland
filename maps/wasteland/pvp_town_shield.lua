local Public = {}

local table_size = table.size
local math_floor = math.floor
local math_sqrt = math.sqrt

local Score = require 'maps.wasteland.score'
local ScenarioTable = require 'maps.wasteland.table'
local PvPShield = require 'maps.wasteland.pvp_shield'
local Utils = require 'maps.wasteland.utils'
local Event = require 'utils.event'

Public.starter_shield_size = 101

function Public.in_extended_control_range(position)
    local this = ScenarioTable.get_table()
    for _, town_center in pairs(this.town_centers) do
        local town_position = town_center.market.position

        local distance = math_floor(math_sqrt((position.x - town_position.x) ^ 2 + (position.y - town_position.y) ^ 2))
        if distance < Public.get_town_control_range(town_center) * 1.5 + Public.starter_shield_size / 2 then   -- Account for growing control range
            return true
        end
    end
    return false
end

function Public.get_town_control_range(town_center)
    return 50 + town_center.evolution.worms * 200
end

function Public.enemy_players_nearby(town_center, max_distance)
    local own_force = town_center.market.force
    local town_position = town_center.market.position

    for _, player in pairs(game.connected_players) do
        if player.surface == town_center.market.surface then
            local distance = math_floor(math_sqrt((player.position.x - town_position.x) ^ 2 + (player.position.y - town_position.y) ^ 2))
            if distance < max_distance and player.force ~= own_force and not player.force.get_friend(own_force) then
                if player.character or player.driving then
                    return true
                end
            end
        end
    end
    return false
end

local function update_pvp_shields_display()
    local this = ScenarioTable.get_table()
    for _, town_center in pairs(this.town_centers) do
        local shield = this.pvp_shields[town_center.market.force.name]
        local info
        if shield then
            info = 'PvP Shield: '
            local lifetime_str = PvPShield.format_lifetime_str(PvPShield.remaining_lifetime(shield))
            if shield.shield_type == PvPShield.SHIELD_TYPE.OFFLINE then
                info = info .. 'While offline, max ' .. lifetime_str
            elseif shield.shield_type == PvPShield.SHIELD_TYPE.AFK then
                info = info .. 'AFK ' .. lifetime_str
            elseif shield.shield_type == PvPShield.SHIELD_TYPE.STARTER then
                local score = Score.total_score(town_center)
                info = info .. 'Until ' .. string.format('%.1f / %.1f', score, this.pvp_shield_starter_limit) .. ' score'
            end
        else
            info = ''
        end
        rendering.set_text(town_center.shield_text, info)

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
    local size = PvPShield.default_size
    local offset_to_max_evo = 10

    this.pvp_shield_starter_limit = math.max(this.pvp_shield_starter_limit, Score.highest_total_score() - offset_to_max_evo, 0)

    for _, town_center in pairs(this.town_centers) do
        local market = town_center.market
        local force = market.force
        local shield = this.pvp_shields[force.name]
        local score = Score.total_score(town_center)
        local offline_shield_eligible = Score.research_score(town_center) > 1

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
                    PvPShield.add_shield(market.surface, market.force, market.position, size,
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
            if offline_shield_eligible and not this.pvp_shields_displayed_offline_hint[force.name] then
                force.print("Your town is now advanced enough to deploy an offline shield."
                        .. " Once all of your members leave, the area marked by the blue floor tiles"
                        .. " will be protected from enemy players for " .. PvPShield.format_lifetime_str(offline_shield_duration_ticks) .. "."
                        .. " However, biters will always be able to attack your town!", Utils.scenario_color)
                this.pvp_shields_displayed_offline_hint[force.name] = true
            end
            this.pvp_shield_offline_activations[force.index] = nil

            -- Add starter shield
            if not shield and score < this.pvp_shield_starter_limit then
                force.print("Your town deploys a PvP shield because there are more advanced towns on the map", Utils.scenario_color)
                PvPShield.add_shield(market.surface, market.force, market.position, Public.starter_shield_size, nil, 60 * 60, PvPShield.SHIELD_TYPE.STARTER)
                update_pvp_shields_display()
            end

            -- Remove starter shield
            if shield and shield.shield_type == PvPShield.SHIELD_TYPE.STARTER and score > this.pvp_shield_starter_limit then
                force.print("Your town's PvP starter shield has been deactivated as you have reached a higher level of advancement.", Utils.scenario_color)
                PvPShield.remove_shield(shield)
            end
        end
    end
end

Event.on_nth_tick(60, update_pvp_shields_display)
Event.on_nth_tick(60, manage_pvp_shields)

return Public
