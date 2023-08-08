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
local MapLayout = require 'maps.wasteland.map_layout'

Public.offline_shield_size = 41

local league_shield_radius = (MapLayout.league_balance_shield_size - 1) / 2
local league_shield_vectors = Utils.make_border_vectors(league_shield_radius)

function Public.in_extended_control_range(position)
    local this = ScenarioTable.get_table()
    for _, town_center in pairs(this.town_centers) do
        local town_position = town_center.market.position

        local distance = math_floor(math_sqrt((position.x - town_position.x) ^ 2 + (position.y - town_position.y) ^ 2))
        if distance < Public.get_town_control_range(town_center) * 1.5 + MapLayout.league_balance_shield_size / 2 then   -- Account for growing control range
            return true
        end
    end
    return false
end

function Public.get_town_control_range(town_center)
    return 70 + town_center.evolution.worms * 80
end

function Public.get_town_league(town_center)
    local score = Score.total_score(town_center)
    local tank_researched = town_center.market.force.technologies['tank'].researched

    if score >= 60 then return 4 end      -- Note: referenced in info.lua
    if score >= 35 then return 3 end
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

local function update_pvp_shields_display()
    local this = ScenarioTable.get_table()
    for _, town_center in pairs(this.town_centers) do

        rendering.set_text(town_center.shield_text, town_center.pvp_shield_mgmt.shield_info)

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

local function town_shields_researched(force)
    return force.technologies["automation"].researched
end

function Public.town_is_afk(force)
    local this = ScenarioTable.get_table()
    return this.pvp_shield_mark_afk[force.name] == true
end

local function update_pvp_shields()
    local this = ScenarioTable.get_table()
    local offline_shield_duration_ticks = 24 * 60 * 60 * 60
    local league_shield_activation_range = MapLayout.league_balance_shield_size + 60

    for _, town_center in pairs(this.town_centers) do
        local market = town_center.market
        local force = market.force
        local shield = this.pvp_shields[force.name]
        local shields_researched = town_shields_researched(force)
        local town_league = Public.get_town_league(town_center)
        local town_offline_or_afk = table_size(force.connected_players) == 0 or this.pvp_shield_mark_afk[force.name]
        local abandoned = false
        local high_score = Score.total_score(town_center) > 70  -- Note: referenced in info.lua

        local higher_league_nearby = Public.enemy_players_nearby(town_center, league_shield_activation_range, town_league)
        if higher_league_nearby then
            town_center.last_higher_league_nearby = game.tick
        end

        if town_offline_or_afk then
            if shields_researched and not high_score then
                if this.pvp_shield_offline_eligible_since[force.index] == nil then
                    this.pvp_shield_offline_eligible_since[force.index] = game.tick
                end
                local remaining_offline_shield_time = offline_shield_duration_ticks - (game.tick - this.pvp_shield_offline_eligible_since[force.index])
                abandoned = remaining_offline_shield_time <= 0

                if not shield and not abandoned then
                    -- Activations:
                    -- nil means waiting for players to go offline
                    -- -1 it is not meant to renew until players join again
                    if not Public.enemy_players_nearby(town_center, Public.get_town_control_range(town_center)) then
                        if this.pvp_shield_offline_eligible_since[force.index] == game.tick then
                            game.print("The offline/afk PvP Shield of " .. town_center.town_name .. " is activating now." ..
                                    " It will last up to " .. PvPShield.format_lifetime_str(remaining_offline_shield_time), Utils.scenario_color)
                        end
                        PvPShield.add_shield(market.surface, market.force, market.position, Public.offline_shield_size,
                                remaining_offline_shield_time, 0.5 * 60 * 60, PvPShield.SHIELD_TYPE.OFFLINE)
                    end
                end
            end
        else    -- Online
            this.pvp_shield_offline_eligible_since[force.index] = nil

            -- Leave offline shield online for a short time for the town's players "warm up" and also to understand it better
            if shield and shield.shield_type == PvPShield.SHIELD_TYPE.OFFLINE then
                local delay_mins = 3
                force.print("Welcome back. Your offline protection will expire in " .. delay_mins .. " minutes."
                        .. " After everyone in your town leaves, you will get a new shield for "
                        .. PvPShield.format_lifetime_str(offline_shield_duration_ticks), Utils.scenario_color)
                shield.shield_type = PvPShield.SHIELD_TYPE.OFFLINE_POST
                shield.max_lifetime_ticks = game.tick - shield.lifetime_start + delay_mins * 60 * 60
            end

            -- Show hint
            if not this.pvp_shields_displayed_offline_hint[force.name] and shields_researched then
                force.print("Your town is now advanced enough to deploy PvP shields."
                        .. " Once all of your town members leave, your town will be protected from enemy players"
                        .. " for up to " .. PvPShield.format_lifetime_str(offline_shield_duration_ticks) .. "."
                        .. " However, biters will always be able to attack your town! See Help for more details.", Utils.scenario_color)
                this.pvp_shields_displayed_offline_hint[force.name] = true
            end
        end

        -- Balancing shield
        if higher_league_nearby and not abandoned and not high_score then
            if shields_researched then
                -- If we have any type of shield ongoing, swap it for a league shield
                if shield and shield.shield_type ~= PvPShield.SHIELD_TYPE.LEAGUE_BALANCE then
                    PvPShield.remove_shield(shield)
                    shield = nil
                end

                if not shield then
                    force.print("Your town deploys a Balancing PvP Shield because there are players of a higher league nearby", Utils.scenario_color)
                    PvPShield.add_shield(market.surface, market.force, market.position, MapLayout.league_balance_shield_size, nil, 13 * 60, PvPShield.SHIELD_TYPE.LEAGUE_BALANCE)
                    update_pvp_shields_display()
                end
            else
                force.print("There are enemy players of a higher league, but your town can't deploy a shield without automation research", Utils.scenario_color)
            end
        end

        local protect_time_after_nearby = 3 * 60 * 60
        if shield and shield.shield_type == PvPShield.SHIELD_TYPE.LEAGUE_BALANCE and not higher_league_nearby and game.tick - town_center.last_higher_league_nearby > protect_time_after_nearby then
            force.print("Your town's Balancing PvP Shield has been deactivated as there are no more higher league players nearby.", Utils.scenario_color)
            PvPShield.remove_shield(shield)
        end

        -- Construct shield info text
        local shield_info = 'League ' .. town_league
        if shield then
            shield_info = shield_info .. ', PvP Shield: '
            local lifetime_str = PvPShield.format_lifetime_str(PvPShield.remaining_lifetime(shield))
            if shield.shield_type == PvPShield.SHIELD_TYPE.OFFLINE or shield.shield_type == PvPShield.SHIELD_TYPE.OFFLINE_POST then
                shield_info = shield_info .. 'While offline/afk, max ' .. lifetime_str
            elseif shield.shield_type == PvPShield.SHIELD_TYPE.LEAGUE_BALANCE then
                shield_info = shield_info .. 'League balance'
            end
        else
            if abandoned then
                shield_info = shield_info .. ', Abandoned town'
            elseif high_score then
                shield_info = shield_info .. ', No shield (High score)'
            elseif not shields_researched then
                shield_info = shield_info .. ', Shields not researched'
            else
                shield_info = shield_info .. ', Shields ready'
            end
        end
        town_center.pvp_shield_mgmt.shield_info = shield_info
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

function Public.remove_all_shield_markers(surface, position)
    local r = MapLayout.league_balance_shield_size
    for _, e in pairs(surface.find_tiles_filtered({area = {{position.x - r, position.y - r}, {position.x + r, position.y + r}}, name = 'blue-refined-concrete'})) do
        surface.set_tiles({{name = 'landfill', position = e.position}}, true)
    end
end

function Public.draw_all_shield_markers(surface, position, town_wall_vectors)
    for _, vector in pairs(town_wall_vectors) do
        local p = {position.x + vector[1], position.y + vector[2]}
        surface.set_tiles({{name = 'blue-refined-concrete', position = p}}, true)
    end

    for _, vector in pairs(league_shield_vectors) do
        local p = {position.x + vector[1], position.y + vector[2]}
        if not surface.get_tile(p).collides_with("water-tile") then
            surface.set_tiles({{name = 'blue-refined-concrete', position = p}}, true)
        end
    end
end

local function all_players_near_center(town_center)
    local market = town_center.market
    local force = market.force

    for _, player in pairs(force.connected_players) do
        local pp = player.position
        local mp = market.position
        if math.sqrt((pp.x - mp.x) ^ 2 +  (pp.y - mp.y) ^ 2) > 5 then
            return false
        end
    end
    return true
end

function Public.request_afk_shield(town_center, player)
    local market = town_center.market
    local this = global.tokens.maps_wasteland_table
    local force = market.force
    local surface = market.surface
    local town_control_range = Public.get_town_control_range(town_center)

    if all_players_near_center(town_center) then
        if not Public.enemy_players_nearby(town_center, town_control_range) then
            if town_shields_researched(force) then
                this.pvp_shield_mark_afk[force.name] = true
                local shield = this.pvp_shields[force.name]
                if shield then
                    PvPShield.remove_shield(shield)
                end
                surface.play_sound({path = 'utility/scenario_message', position = player.position, volume_modifier = 1})
                force.print("You have enabled AFK mode", Utils.scenario_color)
                update_pvp_shields()
            else
                player.print("You need to research automation to enable shields", Utils.scenario_color)
            end
        else
            player.print("Enemy players are too close, can't enter AFK mode", Utils.scenario_color)
        end
    else
        player.print("To activate AFK mode, all players need to gather near the town center", Utils.scenario_color)
    end
end

local function update_afk_shields()
    local this = global.tokens.maps_wasteland_table

    for _, town_center in pairs(this.town_centers) do
        local force = town_center.market.force
        if this.pvp_shield_mark_afk[force.name] then
            local players_online = #force.connected_players > 0
            if players_online and not all_players_near_center(town_center) then
                this.pvp_shield_mark_afk[force.name] = false
                force.print("AFK mode has ended because players moved", Utils.scenario_color)
                local shield = this.pvp_shields[force.name]
                if shield then
                    PvPShield.remove_shield(shield)
                end
            elseif not players_online then
                this.pvp_shield_mark_afk[force.name] = false
            end
        end
    end
end

function Public.init_town(town_center)
    town_center.pvp_shield_mgmt = {}
    update_pvp_shields()
end

Event.on_nth_tick(30, update_pvp_shields_display)
Event.on_nth_tick(30, update_pvp_shields)
Event.on_nth_tick(30, update_leagues)
Event.on_nth_tick(13, update_afk_shields)

return Public
