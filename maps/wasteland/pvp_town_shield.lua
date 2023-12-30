local Public = {}

local math_floor = math.floor
local math_sqrt = math.sqrt
local math_max = math.max

local Score = require 'maps.wasteland.score'
local ScenarioTable = require 'maps.wasteland.table'
local PvPShield = require 'maps.wasteland.pvp_shield'
local Utils = require 'maps.wasteland.utils'
local Event = require 'utils.event'
local MapLayout = require 'maps.wasteland.map_layout'
local TeamBasics = require 'maps.wasteland.team_basics'


Public.offline_shield_size = (MapLayout.league_balance_shield_size - 1)

local league_shield_radius = (MapLayout.league_balance_shield_size - 1) / 2
local league_shield_vectors = Utils.make_border_vectors(league_shield_radius)

function Public.get_town_control_range(town_center)
    return math.min(130 + town_center.evolution.worms * 130,
            MapLayout.radius_between_towns - MapLayout.league_balance_shield_size / 2 - 5)  -- don't overlap with other towns
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

function Public.enemy_players_near_town(town_center, max_distance, min_league)
    local market = town_center.market
    return Public.enemy_players_nearby(market.position, market.surface, market.force, max_distance, min_league)
end

function Public.enemy_players_nearby(position, surface, force, max_distance, min_league)
    for _, player in pairs(game.connected_players) do
        if player.surface == surface then
            local distance = math_floor(math_sqrt((player.position.x - position.x) ^ 2 + (player.position.y - position.y) ^ 2))
            if distance < max_distance and not TeamBasics.is_friendly_towards(player.force, force) then
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
        if Public.enemy_players_near_town(town_center, town_control_range) then
            info_enemies = "Enemies"
            color = {255, 0, 0}

            if not town_center.enemies_warning_status then
                town_center.market.force.print("Enemies have been spotted near your town. Your offline PvP shield can not activate now.", {r = 1, g = 0, b = 0})
                town_center.enemies_warning_status = 1
            end
        elseif Public.enemy_players_near_town(town_center, town_control_range + 10) then
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

local function update_pvp_shields()
    local this = ScenarioTable.get_table()
    local offline_shield_duration_ticks = 24 * 60 * 60 * 60
    local league_shield_activation_range = MapLayout.higher_league_activation_range

    for _, town_center in pairs(this.town_centers) do
        local market = town_center.market
        local force = market.force
        local shield = this.pvp_shields[force.name]
        local shields_researched = town_shields_researched(force)
        local town_league = Public.get_town_league(town_center)
        local town_offline_or_afk = #force.connected_players == 0 or town_center.marked_afk
        local abandoned = false
        local high_league_no_shield = town_league >= 4

        local higher_league_nearby = Public.enemy_players_near_town(town_center, league_shield_activation_range, town_league)
        if higher_league_nearby then
            town_center.last_higher_league_nearby = game.tick
        end

        if town_offline_or_afk then     -- Offline shields
            if shields_researched and not high_league_no_shield then
                local is_init_now = false
                if town_center.pvp_shield_mgmt.offline_shield_eligible_until == nil then
                    is_init_now = true
                    town_center.pvp_shield_mgmt.offline_shield_eligible_until = game.tick + offline_shield_duration_ticks
                end
                local remaining_offline_shield_time = town_center.pvp_shield_mgmt.offline_shield_eligible_until - game.tick
                abandoned = remaining_offline_shield_time <= 0

                -- Town can get a offline shield?
                -- Treat the OFFLINE_POST shield as a temporary shield to be replaced with a "proper" one
                if (not shield or (shield and shield.shield_type == PvPShield.SHIELD_TYPE.OFFLINE_POST)) and not abandoned then
                    if not Public.enemy_players_near_town(town_center, Public.get_town_control_range(town_center)) then
                        if is_init_now and not town_center.marked_afk then
                            -- Show this to remind other players of this feature
                            game.print("The offline PvP Shield of " .. town_center.town_name .. " is activating now." ..
                                    " It will last up to " .. PvPShield.format_lifetime_str(remaining_offline_shield_time), Utils.scenario_color)
                        end
                        if not shield then
                            PvPShield.add_shield(market.surface, market.force, market.position, Public.offline_shield_size,
                                    game.tick + remaining_offline_shield_time, 0.5 * 60 * 60, PvPShield.SHIELD_TYPE.OFFLINE)
                        else
                            shield.shield_type = PvPShield.SHIELD_TYPE.OFFLINE
                            shield.expiry_time = game.tick + remaining_offline_shield_time
                        end
                    end
                end
            end
        else    -- Online
            town_center.pvp_shield_mgmt.offline_shield_eligible_until = nil

            -- Leave offline shield online for a short time for the town's players "warm up" and also to understand it better
            if shield and shield.shield_type == PvPShield.SHIELD_TYPE.OFFLINE then
                local delay_mins = 1
                force.print("Welcome back. Your offline protection will expire in " .. delay_mins .. " minute."
                        .. " After everyone in your town leaves, you will get a new shield for "
                        .. PvPShield.format_lifetime_str(offline_shield_duration_ticks), Utils.scenario_color)
                shield.shield_type = PvPShield.SHIELD_TYPE.OFFLINE_POST
                shield.expiry_time = game.tick + delay_mins * 60 * 60
            end

            -- Show hint
            if not town_center.pvp_shield_mgmt.displayed_offline_hint and shields_researched then
                force.print("Your town is now advanced enough to deploy PvP shields."
                        .. " Once all of your town members leave, your town will be protected from enemy players"
                        .. " for up to " .. PvPShield.format_lifetime_str(offline_shield_duration_ticks) .. "."
                        .. " However, biters will always be able to attack your town! See Help for more details.", Utils.scenario_color)
                town_center.pvp_shield_mgmt.displayed_offline_hint = true
            end
        end

        -- Online or Offline: Balancing shield
        if higher_league_nearby and not abandoned and not high_league_no_shield then
            if shields_researched then
                -- If we have any type of shield ongoing, swap it for a league shield
                if not shield or (shield and shield.shield_type ~= PvPShield.SHIELD_TYPE.LEAGUE_BALANCE) then
                    force.print("Your town deploys a Balancing PvP Shield because there are players of a higher league nearby", Utils.scenario_color)
                    if not shield then
                        PvPShield.add_shield(market.surface, market.force, market.position, MapLayout.league_balance_shield_size, nil, 13 * 60, PvPShield.SHIELD_TYPE.LEAGUE_BALANCE)
                    else
                        shield.shield_type = PvPShield.SHIELD_TYPE.LEAGUE_BALANCE
                        shield.expiry_time = nil
                    end
                    update_pvp_shields_display()
                end
            else
                if town_center.last_higher_league_nearby_hint == nil or game.tick - town_center.last_higher_league_nearby_hint > 60 * 60 then
                    force.print("There are enemy players of a higher league, but your town can't deploy a shield without automation research", Utils.scenario_color_warning)
                    town_center.last_higher_league_nearby_hint = game.tick
                end
            end
        end

        if high_league_no_shield and shield then -- A shield is still active after moving into high score
            PvPShield.remove_shield(shield)
            shield = nil
        end

        -- Stop a league balance shield
        local protect_time_after_nearby = 3 * 60 * 60
        if shield and shield.shield_type == PvPShield.SHIELD_TYPE.LEAGUE_BALANCE and not higher_league_nearby and game.tick - town_center.last_higher_league_nearby > protect_time_after_nearby then
            if town_offline_or_afk then -- change to an offline shield
                shield.shield_type = PvPShield.SHIELD_TYPE.OFFLINE
                shield.expiry_time = town_center.pvp_shield_mgmt.offline_shield_eligible_until
            else
                PvPShield.remove_shield(shield)
                shield = nil
            end
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
            elseif high_league_no_shield then
                shield_info = shield_info .. ', No shield (League 4)'
            elseif not shields_researched then
                shield_info = shield_info .. ', Shields not researched'
            else
                shield_info = shield_info .. ', Shields ready'
            end
        end
        town_center.pvp_shield_mgmt.shield_info = shield_info
    end
end

local function update_leagues()
    if game.tick == 0 then return end

    local this = ScenarioTable.get_table()
    for _, player in pairs(game.connected_players) do
        if player.character then
            local league = Public.get_player_league(player)

            if this.previous_leagues[player.index] ~= nil and league ~= this.previous_leagues[player.index] then
                player.print("You are now in League " .. league, Utils.scenario_color)
                if league == 4 and this.previous_leagues[player.index] < 4 then
                    player.print("From now on, your town can not deploy offline PvP shields anymore", Utils.scenario_color_warning)
                end
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

function Public.draw_all_shield_markers(surface, position)
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
        if math.sqrt((pp.x - mp.x) ^ 2 +  (pp.y - mp.y) ^ 2) > 10 then
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
        if not Public.enemy_players_near_town(town_center, town_control_range) then
            if town_shields_researched(force) then
                town_center.marked_afk = true
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
        if town_center.marked_afk then
            local players_online = #force.connected_players > 0
            if players_online and not all_players_near_center(town_center) then
                town_center.marked_afk = false
                force.print("AFK mode has ended because players moved", Utils.scenario_color)
                local shield = this.pvp_shields[force.name]
                if shield then
                    PvPShield.remove_shield(shield)
                end
            elseif not players_online then
                town_center.marked_afk = false
            end
        end
    end
end

local function on_player_left_game(player)
    update_pvp_shields()    -- prevent shields from activating when the last player of the server logs out next to them?
end

function Public.init_town()
    update_pvp_shields()
end

Event.on_nth_tick(31, update_pvp_shields_display)   -- Tiny time offset to even out load
Event.on_nth_tick(31, update_pvp_shields)
Event.on_nth_tick(31, update_leagues)
Event.on_nth_tick(13, update_afk_shields)
Event.add(defines.events.on_player_left_game, on_player_left_game)

return Public
