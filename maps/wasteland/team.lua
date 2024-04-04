local Public = {}

local math_random = math.random
local string_match = string.match
local string_lower = string.lower

local Server = require 'utils.server'
local ScenarioTable = require 'maps.wasteland.table'
local PvPShield = require 'maps.wasteland.pvp_shield'
local CombatBalance = require 'maps.wasteland.combat_balance'
local Utils = require 'maps.wasteland.utils'
local ResearchBalance = require 'maps.wasteland.research_balance'
local PvPTownShield = require 'maps.wasteland.pvp_town_shield'
local TeamBasics = require 'maps.wasteland.team_basics'
local MapLayout = require 'maps.wasteland.map_layout'

local outlander_color = {150, 150, 150}
local outlander_chat_color = {170, 170, 170}
local item_drop_radius = 1.65
Public.max_player_slots = 30
local town_serial_no = 1

local destroy_wall_types = {
    ['gate'] = true,
    ['wall'] = true
}

local destroy_military_types = {
    ['ammo-turret'] = true,
    ['electric-turret'] = true,
    ['fluid-turret'] = true,
    ['artillery-turret'] = true,
    ['artillery-wagon'] = true,
    ['land-mine'] = true,
    ['radar'] = true
}

local destroy_robot_types = {
    ['combat-robot'] = true,
    ['construction-robot'] = true,
    ['logistic-robot'] = true
}

local dont_destroy_types = {
    ['container'] = true,
    ['logistic-container'] = true,
    ['storage-tank'] = true,
    ['reactor'] = true
}

local outlander_force_disabled_recipes = {
    'lab',
    'automation-science-pack',
    'radar'
}
local all_force_enabled_recipes = {
    'submachine-gun',
    'shotgun',
    'shotgun-shell',
}

function Public.force_display_name(force)
    local this = ScenarioTable.get_table()
    if TeamBasics.is_town_force(force) then
        local town_center = this.town_centers[force.name]
        return town_center.town_name
    else
        return TeamBasics.non_town_display_name(force)
    end
end

local function can_force_accept_member(force)
    if not force or not force.valid then
        log('force nil or not valid!')
        return
    end

    return true
end

function Public.set_player_color(player)
    if not player or not player.valid then
        log('player nil or not valid!')
        return
    end
    local this = ScenarioTable.get_table()
    if not TeamBasics.is_town_force(player.force) then
        player.color = outlander_color
        player.chat_color = outlander_chat_color
        return
    else
        local town_center = this.town_centers[player.force.name]
        player.color = town_center.color
        player.chat_color = town_center.color
    end
end

local function set_town_color(event)
    local this = ScenarioTable.get_table()
    if event.command ~= 'color' then
        return
    end
    local player = game.players[event.player_index]
    local force = player.force
    local town_center = this.town_centers[force.name]
    if not town_center then
        Public.set_player_color(player)
        return
    end
    town_center.color = {player.color.r, player.color.g, player.color.b}
    rendering.set_color(town_center.town_caption, town_center.color)
    for _, p in pairs(force.players) do
        Public.set_player_color(p)
    end
end

function Public.set_all_player_colors()
    for _, p in pairs(game.connected_players) do
        Public.set_player_color(p)
    end
end

local function reset_player(player)
    if not player or not player.valid then
        log('player nil or not valid!')
        return
    end
    if player.character ~= nil then
        local character = player.character
        character.character_crafting_speed_modifier = 0.0
        character.character_mining_speed_modifier = 0.0
        character.character_inventory_slots_bonus = 0
    end
end

function Public.add_player_to_town(player, town_center)
    if not player or not player.valid then
        log('player nil or not valid!')
        return
    end
    if not town_center then
        log('town_center nil!')
        return
    end
    local this = ScenarioTable.get_table()
    local market = town_center.market
    local force = market.force
    local surface = market.surface

    reset_player(player)

    if TeamBasics.is_outlander_force(player.force) then
        game.merge_forces(player.force, market.force)
    end
    player.force = market.force -- This should happen in same tick as merge_forces is delayed

    this.spawn_point[player.index] = force.get_spawn_position(surface)
    this.strikes[player.name] = 0
    game.permissions.get_group(force.name).add_player(player)
    player.tag = ''

    Public.set_player_color(player)

    ResearchBalance.player_changes_town_status(player, true)
    CombatBalance.player_changes_town_status(player, true)
end

-- given to player upon respawn
function Public.give_player_items(player)
    if not player or not player.valid then
        log('player nil or not valid!')
        return
    end
    player.clear_items_inside()
    player.insert({name = 'raw-fish', count = 3})
    if not TeamBasics.is_town_force(player.force) then
        player.insert {name = 'linked-chest', count = '1'}
    end
end

function Public.set_biter_peace(force, peace)
    game.forces.enemy.set_cease_fire(force, peace)
    force.set_cease_fire(game.forces.enemy, peace)
end

local function ally_outlander(player, target)
    if not player or not player.valid then
        log('player nil or not valid!')
        return
    end
    if not target or not target.valid then
        log('target nil or not valid!')
        return
    end
    local this = ScenarioTable.get_table()
    local requesting_force = player.force
    local target_force = target.force
    local target_town_center = this.town_centers[target_force.name]

    -- don't handle request if target is not a town
    if not TeamBasics.is_town_force(requesting_force) and not TeamBasics.is_town_force(target_force) then
        return false
    end

    -- don't handle request to  another town if already in a town
    if TeamBasics.is_town_force(requesting_force) and TeamBasics.is_town_force(target_force) then
        return false
    end

    -- handle the request
    if not TeamBasics.is_town_force(requesting_force) and TeamBasics.is_town_force(target_force) then
        this.requests[player.index] = target_force.name

        local target_player
        if target.type == 'character' then
            target_player = target.player
        else
            target_player = game.players[target_force.name]
        end

        if target_player then
            if this.requests[target_player.index] then
                if this.requests[target_player.index] == player.name then
                    if not can_force_accept_member(target_force) then
                        return true
                    end
                    game.print('>> ' .. player.name .. ' has settled in ' .. target_town_center.town_name, Utils.scenario_color)
                    Public.add_player_to_town(player, target_town_center)
                    return true
                end
            end
        end

        game.print('>> ' .. player.name .. ' wants to settle in ' .. target_town_center.town_name, Utils.scenario_color)
        return true
    end

    -- handle the approval
    if TeamBasics.is_town_force(requesting_force) and TeamBasics.is_outlander_force(target_force) then
        if target.type ~= 'character' then
            return true
        end
        local target_player = target.player
        if not target_player then
            return true
        end
        this.requests[player.index] = target_player.name

        if this.requests[target_player.index] then
            if this.requests[target_player.index] == player.force.name then
                if target_town_center then
                    if not can_force_accept_member(player.force) then
                        return true
                    end
                    game.print('>> ' .. player.name .. ' has accepted ' .. target_player.name .. ' into' .. target_town_center.town_name, Utils.scenario_color)
                    Public.add_player_to_town(target_player, this.town_centers[player.force.name])
                    return true
                end
            end
        end

        local target_town_center_player = this.town_centers[player.force.name]
        game.print('>> ' .. player.name .. ' is inviting ' .. target_player.name .. ' into ' .. target_town_center_player.town_name, Utils.scenario_color)
        return true
    end
end

local function ally_neighbour_towns(player, target)
    if not player or not player.valid then
        log('player nil or not valid!')
        return
    end
    if not target or not target.valid then
        log('target nil or not valid!')
        return
    end
    local requesting_force = player.force
    local target_force = target.force

    if target_force.get_friend(requesting_force) and requesting_force.get_friend(target_force) then
        return
    end

    requesting_force.set_friend(target_force, true)
    game.print('>> ' .. Public.force_display_name(requesting_force) .. ' has declared ' .. Public.force_display_name(target_force) .. ' their friend!', Utils.scenario_color)

    if target_force.get_friend(requesting_force) then
        game.print('>> ' .. Public.force_display_name(requesting_force) .. ' and ' .. Public.force_display_name(target_force) .. ' have formed an alliance!', Utils.scenario_color)
    end
end

local function ally_town(player, item)
    if not player or not player.valid then
        log('player nil or not valid!')
        return
    end
    local position = item.position
    local surface = player.surface
    local area = {{position.x - item_drop_radius, position.y - item_drop_radius}, {position.x + item_drop_radius, position.y + item_drop_radius}}
    local requesting_force = player.force
    local target = false

    for _, e in pairs(surface.find_entities_filtered({type = {'character', 'market'}, area = area})) do
        if e.force.name ~= requesting_force.name then
            target = e
            break
        end
    end

    if not target then
        return
    end
    if target.force == game.forces['enemy'] or target.force == game.forces['neutral'] then
        return
    end

    if ally_outlander(player, target) then
        return
    end
    ally_neighbour_towns(player, target)
end

local function set_cease_fire(player, entity)
    if not player or not player.valid then
        log('player nil or not valid!')
        return
    end
    local position = entity.position
    local surface = player.surface
    local area = {{position.x - item_drop_radius, position.y - item_drop_radius}, {position.x + item_drop_radius, position.y + item_drop_radius}}
    local requesting_force = player.force
    local target = false

    for _, e in pairs(surface.find_entities_filtered({type = {'character', 'market'}, area = area})) do
        if e.force.name ~= requesting_force.name then
            target = e
            break
        end
    end

    if not target then
        return
    end
    local target_force = target.force
    if target_force == game.forces['enemy'] or target_force == game.forces['neutral'] then
        return
    end

    if requesting_force.get_cease_fire(target_force) then
        player.print("You already have a cease fire agreement with " .. Public.force_display_name(target_force), Utils.scenario_color)
        return
    end

    requesting_force.set_cease_fire(target_force, true)

    local pm_tag = "[Private message] "
    if target_force.get_cease_fire(requesting_force) then
        requesting_force.print(pm_tag .. "You have agreed on a mutual cease-fire with " .. Public.force_display_name(target_force), Utils.scenario_color)
        target_force.print(pm_tag ..  Public.force_display_name(requesting_force) .. " has agreed on a mutual cease-fire with you", Utils.scenario_color)
    else
        requesting_force.print(pm_tag .. "You have set a one-sided cease-fire with " .. Public.force_display_name(target_force), Utils.scenario_color)
        target_force.print(pm_tag .. Public.force_display_name(requesting_force) .. " has set one-sided cease-fire with you", Utils.scenario_color)
    end
end

local function declare_war(player, item)
    if not player or not player.valid then
        log('player nil or not valid!')
        return
    end
    local this = ScenarioTable.get_table()
    local position = item.position
    local surface = player.surface
    local area = {{position.x - item_drop_radius, position.y - item_drop_radius}, {position.x + item_drop_radius, position.y + item_drop_radius}}

    local requesting_force = player.force
    local target = surface.find_entities_filtered({type = {'character', 'market'}, area = area})[1]

    if not target then
        return
    end
    if target.name == "character" and target.player == player then
        return
    end
    local target_force = target.force
    if not TeamBasics.is_town_force(target_force) then
        return
    end

    if requesting_force.name == target_force.name then
        if #target.force.players > 1 then
            Public.set_player_to_outlander(player)
            local town_center = this.town_centers[target_force.name]
            game.print('>> ' .. player.name .. ' has abandoned ' .. town_center.town_name, Utils.scenario_color)
            this.requests[player.index] = nil
        else
            player.print(">> The town's last player can't abandon the town.", Utils.scenario_color)
        end
        if player.name == target.force.name then
            if target.type ~= 'character' then
                return
            end
            local target_player = target.player
            if not target_player then
                return
            end
            if target_player.index == player.index then
                return
            end
            Public.set_player_to_outlander(target_player)
            local town_center = this.town_centers[requesting_force.name]
            game.print('>> ' .. player.name .. ' has banished ' .. target_player.name .. ' from ' .. town_center.town_name, Utils.scenario_color)
            this.requests[player.index] = nil
        end
        return
    end

    if not TeamBasics.is_town_force(requesting_force) then
        return
    end

    requesting_force.set_friend(target_force, false)
    target_force.set_friend(requesting_force, false)

    game.print('>> ' .. player.name .. ' has dropped the coal! Town ' .. target_force.name .. ' and ' .. requesting_force.name .. ' are now at war!', Utils.scenario_color)
end

local function delete_chart_tag_for_all_forces(market)
    if not market or not market.valid then
        log('market nil or not valid!')
        return
    end
    local forces = game.forces
    local position = market.position
    local surface = market.surface
    for _, force in pairs(forces) do
        local tags = force.find_chart_tags(surface, {{position.x - 0.1, position.y - 0.1}, {position.x + 0.1, position.y + 0.1}})
        local tag = tags[1]
        if tag then
            if tag.icon.name == 'signal-dot' then
                tag.destroy()
            end
        end
    end
end

function Public.add_chart_tag(town_center)
    if not town_center then
        log('town_center nil or not valid!')
        return
    end
    local market = town_center.market
    local force = market.force
    local position = market.position
    local tags = force.find_chart_tags(market.surface, {{position.x - 0.1, position.y - 0.1}, {position.x + 0.1, position.y + 0.1}})
    if tags[1] then
        return
    end
    force.add_chart_tag(market.surface, {icon = {type = 'virtual', name = 'signal-dot'}, position = position, text = town_center.town_name})
end

function Public.update_town_chart_tags()
    local this = ScenarioTable.get_table()
    local forces = game.forces
    for _, town_center in pairs(this.town_centers) do
        local market = town_center.market
        for _, force in pairs(forces) do
            if force.is_chunk_visible(market.surface, town_center.chunk_position) then
                Public.add_chart_tag(town_center)
            end
        end
    end
end

local function reset_permissions(permission_group)
    for action_name, _ in pairs(defines.input_action) do
        permission_group.set_allows_action(defines.input_action[action_name], true)
    end
end

local function set_full_blueprint_functions(permission_group, enabled)
    local defs = {
        defines.input_action.alt_select_blueprint_entities,
        defines.input_action.cancel_new_blueprint,
        defines.input_action.change_blueprint_record_label,
        defines.input_action.clear_selected_blueprint,
        defines.input_action.create_blueprint_like,
        defines.input_action.cycle_blueprint_backwards,
        defines.input_action.cycle_blueprint_forwards,
        defines.input_action.delete_blueprint_library,
        defines.input_action.delete_blueprint_record,
        defines.input_action.drop_blueprint_record,
        defines.input_action.drop_to_blueprint_book,
        defines.input_action.export_blueprint,
        defines.input_action.grab_blueprint_record,
        defines.input_action.import_blueprint,
        defines.input_action.import_blueprint_string,
        defines.input_action.open_blueprint_library_gui,
        defines.input_action.open_blueprint_record,
        defines.input_action.select_blueprint_entities,
        defines.input_action.setup_blueprint,
        defines.input_action.setup_single_blueprint_record,
        defines.input_action.upgrade_open_blueprint
    }
    for _, d in pairs(defs) do
        permission_group.set_allows_action(d, enabled)
    end
end

function Public.enable_artillery(force, permission_group)
    permission_group.set_allows_action(defines.input_action.use_artillery_remote, true)
    force.technologies['artillery'].enabled = true
    force.technologies['artillery-shell-range-1'].enabled = true
    force.technologies['artillery-shell-speed-1'].enabled = true
    force.recipes['artillery-turret'].enabled = false
    force.recipes['artillery-wagon'].enabled = false
    force.recipes['artillery-targeting-remote'].enabled = false
    force.recipes['artillery-shell'].enabled = false
end

local function disable_artillery(force, permission_group)
    permission_group.set_allows_action(defines.input_action.use_artillery_remote, false)
    force.technologies['artillery'].enabled = false
    force.technologies['artillery-shell-range-1'].enabled = false
    force.technologies['artillery-shell-speed-1'].enabled = false
    force.recipes['artillery-turret'].enabled = false
    force.recipes['artillery-wagon'].enabled = false
    force.recipes['artillery-targeting-remote'].enabled = false
    force.recipes['artillery-shell'].enabled = false
end

local function disable_spidertron(force, permission_group)
    permission_group.set_allows_action(defines.input_action.send_spidertron, false)
    force.technologies['spidertron'].enabled = false
    force.recipes['spidertron'].enabled = false
    force.recipes['spidertron-remote'].enabled = false
end

local function disable_rockets(force)
    force.technologies['rocketry'].enabled = false
    force.technologies['explosive-rocketry'].enabled = false
    force.recipes['rocket-launcher'].enabled = false
    force.recipes['rocket'].enabled = false
    force.recipes['explosive-rocket'].enabled = false
end

local function disable_nukes(force)
    force.technologies['atomic-bomb'].enabled = false
    force.recipes['atomic-bomb'].enabled = false
end

local function disable_cluster_grenades(force)
    force.recipes['cluster-grenade'].enabled = false
end

local function disable_high_lab_speed_research(force)
    -- Prevent researching extremely fast from stockpiled science
    force.technologies['research-speed-4'].enabled = false
    force.technologies['research-speed-5'].enabled = false
    force.technologies['research-speed-6'].enabled = false
end

local function disable_high_weapon_research(force)
    -- Limit the difference between small/big towns so that new towns have a chance
    -- and prevent pvp encounters that last less than 1s

    force.technologies['uranium-ammo'].enabled = false
    force.technologies['power-armor-mk2'].enabled = false

    force.technologies['laser-shooting-speed-6'].enabled = false
    force.technologies['laser-shooting-speed-7'].enabled = false
    force.technologies['energy-weapons-damage-6'].enabled = false
    force.technologies['energy-weapons-damage-7'].enabled = false

    force.technologies['refined-flammables-6'].enabled = false
    force.technologies['refined-flammables-7'].enabled = false

    force.technologies['stronger-explosives-6'].enabled = false
    force.technologies['stronger-explosives-7'].enabled = false

    force.technologies['follower-robot-count-4'].enabled = false
    force.technologies['follower-robot-count-5'].enabled = false
    force.technologies['follower-robot-count-6'].enabled = false
    force.technologies['follower-robot-count-7'].enabled = false

    force.technologies['weapon-shooting-speed-6'].enabled = false
    force.technologies['physical-projectile-damage-6'].enabled = false
    force.technologies['physical-projectile-damage-7'].enabled = false
end

local function disable_achievements(permission_group)
    permission_group.set_allows_action(defines.input_action.open_achievements_gui, false)
end

local function disable_tips_and_tricks(permission_group)
    permission_group.set_allows_action(defines.input_action.open_tips_and_tricks_gui, false)
end

local function set_initial_combat_bot_slots(force)
    force.maximum_following_robot_count = 6
end

local function set_default_tech(force)
    for _, recipe_name in pairs(all_force_enabled_recipes) do
        force.recipes[recipe_name].enabled = true
    end
    force.technologies['gun-turret'].researched = true
    force.technologies['stone-wall'].researched = true
end

local function setup_outlander_permissions()
    game.permissions.create_group('outlander')
end

local function assign_outlander_permissions(force)
    local permission_group = game.permissions.get_group('outlander')
    reset_permissions(permission_group)
    set_full_blueprint_functions(permission_group, false)
    disable_artillery(force, permission_group)
    disable_spidertron(force, permission_group)
    disable_rockets(force)
    disable_nukes(force)
    disable_cluster_grenades(force)
    disable_achievements(permission_group)
    disable_tips_and_tricks(permission_group)
end

function Public.create_town_force(player)
    local this = ScenarioTable.get_table()
    local force = game.create_force("t_" .. town_serial_no .. "_" .. player.name)
    town_serial_no = town_serial_no + 1

    -- diplomacy
    force.friendly_fire = true
    force.share_chart = true

    -- permissions
    local permission_group = game.permissions.create_group(force.name)
    reset_permissions(permission_group)
    set_full_blueprint_functions(permission_group, true)
    disable_artillery(force, permission_group)
    disable_spidertron(force, permission_group)
    disable_high_weapon_research(force)
    disable_high_lab_speed_research(force)
    disable_rockets(force)
    disable_nukes(force)
    disable_cluster_grenades(force)
    disable_achievements(permission_group)
    disable_tips_and_tricks(permission_group)

    -- research
    set_default_tech(force)
    force.research_queue_enabled = true
    set_initial_combat_bot_slots(force)

    CombatBalance.init_player_weapon_damage(force)
    MapLayout.reveal_strategic_resources(force)

    if this.testing_mode then
        Public.set_biter_peace(force, true)
        force.enable_all_prototypes()
        force.research_all_technologies()
    end

    return force
end

local function create_outlander_force(player)
    local this = ScenarioTable.get_table()
    local force = game.create_force("o_" .. player.name)

    -- diplomacy
    Public.set_biter_peace(force, true)
    force.share_chart = true
    force.friendly_fire = true

    assign_outlander_permissions(force)

    -- research
    set_default_tech(force)
    force.disable_research()
    set_initial_combat_bot_slots(force)

    -- recipes
    for _, recipe_name in pairs(outlander_force_disabled_recipes) do
        force.recipes[recipe_name].enabled = false
    end

    CombatBalance.init_player_weapon_damage(force)
    MapLayout.reveal_strategic_resources(force)

    if this.testing_mode then
        force.enable_all_prototypes()
    end

    return force
end

local function setup_enemy_force()
    game.forces.enemy.evolution_factor = 1
end

function Public.player_joined(player)
    if #game.connected_players > Public.max_player_slots then
        game.print("WARNING: Too many players connected. Things might start going wrong")
        return
    end

    if player.force.name == 'player' then
        if player.online_time > 0 then
            player.print("Welcome back, outlander! After you left, your buildings have become neutral and your map and diplomacy has reset", Utils.scenario_color)
        end
        player.force = create_outlander_force(player)
    end

    local this = ScenarioTable.get_table()
    if this.winner then
        player.print(this.winner .. " has won the game! The server will be reset by an admin soon.", Utils.scenario_color)
    end
end

function Public.player_left(player)
    if not TeamBasics.is_town_force(player.force) then
        local prev_force = player.force
        player.force = 'player' -- Note: Reassign the player first to avoid a race where merge_forces doesn't delete the force. TODO: validate
        game.merge_forces(prev_force, 'neutral')  -- All of their buildings become common property
    end
end

function Public.set_player_to_outlander(player)
    if not player or not player.valid then
        log('player nil or not valid!')
        return
    end

    player.force = create_outlander_force(player)

    game.permissions.get_group('outlander').add_player(player)
    player.tag = '[Outlander]'
    Public.set_player_color(player)

    ResearchBalance.player_changes_town_status(player, false)
    CombatBalance.player_changes_town_status(player, false)
end

local function reset_forces()
    local players = game.players
    local forces = game.forces
    for i = 1, #players do
        local player = players[i]
        local force = forces[player.name]
        if force then
            game.merge_forces(force, 'player')
        end
    end
end

function Public.reset_all_forces()
    for _, force in pairs(game.forces) do
        if force and force.valid then
            if force.name ~= 'enemy' and force.name ~= 'player' and force.name ~= 'neutral' then
                game.merge_forces(force.name, 'player')
            end
        end
    end
    game.forces['enemy'].reset()
    game.forces['neutral'].reset()
    game.forces['player'].reset()
end

local function display_player_name(player)
    if player.tag ~= '' then
        return player.name .. " " .. player.tag
    else
        return player.name
    end
end

local function kill_force(killed_force, cause_force, cause_entity)
    local this = ScenarioTable.get_table()
    local killed_force_name = killed_force.name
    local town_center = this.town_centers[killed_force_name]
    if not town_center then
        return
    end
    local market = town_center.market
    local position = market.position
    local surface = market.surface
    local town_name = town_center.town_name
    surface.create_entity({name = 'big-artillery-explosion', position = position})

    local is_suicide = cause_force and killed_force == cause_force

    local kill_message
    if is_suicide then
        kill_message = town_name .. ' has given up'
    elseif cause_entity == nil or not cause_entity.valid or cause_entity.force == nil then
        kill_message = town_name .. ' has fallen!'
    else
        local player_name_printable
        if cause_entity.type == 'car' or cause_entity.type == 'tank' then
            local driver = cause_entity.get_driver()
            if driver and driver.player then
                player_name_printable = display_player_name(driver.player)
            end
        elseif cause_entity.name == 'character' then
            player_name_printable = display_player_name(cause_entity.player)
        end

        if TeamBasics.is_town_force(cause_entity.force) then
            local killer_town_center = this.town_centers[cause_entity.force.name]
            if player_name_printable then
                kill_message = town_name .. ' has fallen to ' .. player_name_printable .. ' from '  .. killer_town_center.town_name .. '!'
            else
                kill_message = town_name .. ' has fallen to ' .. killer_town_center.town_name .. '!'
            end
        elseif cause_entity.force.name ~= 'enemy' then
            if player_name_printable then
                kill_message = town_name .. ' has fallen to ' .. player_name_printable .. '!'
            else
                kill_message = town_name .. ' has fallen!'
            end
        else
            kill_message = town_name .. ' has fallen to the biters!'
        end
    end

    for _, player in pairs(killed_force.players) do
        this.spawn_point[player.index] = nil
        this.cooldowns_town_placement[player.index] = game.tick + 3600 * 5
        this.buffs[player.index] = {}
        if player.character then
            player.character.die()
        elseif not player.connected then
            this.town_kill_message[player.index] = kill_message
            this.requests[player.index] = 'kill-character'
        end
        Public.set_player_to_outlander(player)
    end
    for _, e in pairs(surface.find_entities_filtered({force = killed_force})) do
        if e.valid then
            if destroy_military_types[e.type] then
                surface.create_entity({name = 'big-artillery-explosion', position = position})
                e.die()
            elseif destroy_robot_types[e.type] then
                surface.create_entity({name = 'explosion', position = position})
                e.die()
            elseif destroy_wall_types[e.type] then
                e.die()
            elseif not dont_destroy_types[e.type] then
                local random = math_random()
                if random > 0.5 or e.health == nil then
                    e.die()
                elseif random < 0.25 then
                    e.health = e.health * math_random()
                end
            end
            if e.valid and e.type == "assembling-machine" and e.get_recipe() then
                e.set_recipe(nil)   -- Stop exploits of players gaining access to higher league recipes
            end
        end
    end
    local r = 30
    for _, e in pairs(surface.find_entities_filtered({area = {{position.x - r, position.y - r}, {position.x + r, position.y + r}}, force = 'neutral', type = 'resource'})) do
        if e.name ~= 'crude-oil' then
            e.destroy()
        end
    end

    PvPTownShield.remove_shield_floor_markers(surface, position)

    if this.pvp_shields[killed_force_name] then
        PvPShield.remove_shield(this.pvp_shields[killed_force_name])
    end

    game.merge_forces(killed_force, 'neutral')
    this.town_centers[killed_force_name] = nil
    delete_chart_tag_for_all_forces(market)

    -- place the loot coins from town center
    local loot_balance = town_center.coin_balance
    if loot_balance > 0 then
        local chest = surface.create_entity({name = 'steel-chest', position = position, force = 'neutral'})
        chest.insert({name = 'coin', count = loot_balance })
    end

    local town_count = 0
    for _, _ in pairs(this.town_centers) do
        town_count = town_count + 1
    end
    if town_count == 0 then
        game.reset_time_played()
    end

    log("kill_force: " .. kill_message)
    Server.to_discord_embed(kill_message)
    game.print('>> ' .. kill_message, Utils.scenario_color)
end

local function on_forces_merged()
    -- Remove any ghosts that have been moved into neutral after a town is destroyed
    for _, e in pairs(game.surfaces.nauvis.find_entities_filtered({force = 'neutral', type = "entity-ghost"})) do
        if e.valid then
            e.destroy()
        end
    end
end

local function on_player_dropped_item(event)
    local player = game.players[event.player_index]
    local entity = event.entity
    if entity.stack.name == 'coin' then
        ally_town(player, entity)
        return
    end
    if entity.stack.name == 'raw-fish' then
        set_cease_fire(player, entity)
        return
    end
    if entity.stack.name == 'coal' then
        declare_war(player, entity)
        return
    end
end

function Public.on_entity_damaged(event)
    local entity = event.entity
    if not entity or not entity.valid then
        return
    end
    local damaged_force = entity.force
    local attacker_force = event.force

    if damaged_force.get_cease_fire(attacker_force) or attacker_force.get_cease_fire(damaged_force) then
        if damaged_force == game.forces.enemy then
            attacker_force.print("You have broken the peace with the biters. They will seek revenge!", {r = 1, g = 0, b = 0})
        else
            attacker_force.print("You broke a cease fire agreement with " .. Public.force_display_name(damaged_force), Utils.scenario_color)
        end
        damaged_force.print("A cease fire agreement with you was broken by " .. Public.force_display_name(attacker_force), Utils.scenario_color)

        if attacker_force ~= game.forces.enemy then  -- ignore accidental damage
            damaged_force.set_cease_fire(attacker_force, false)
            attacker_force.set_cease_fire(damaged_force, false)
        end
    end
end

local function on_entity_died(event)
    local entity = event.entity
    if entity and entity.valid and entity.name == 'market' then
        kill_force(entity.force, event.force, event.cause)
    end
end

local function on_console_command(event)
    set_town_color(event)
end

local function on_console_chat(event)
    if not event.player_index then
        return
    end

    local player = game.players[event.player_index]
    if string_match(string_lower(event.message), '%[armor%=') then
        player.clear_console()
        player.print('Viewing player armor is disabled')
    end
end

function Public.initialize()
    reset_forces()
    setup_outlander_permissions()
    setup_enemy_force()
end

local Event = require 'utils.event'
Event.add(defines.events.on_player_dropped_item, on_player_dropped_item)
Event.add(defines.events.on_entity_died, on_entity_died)
Event.add(defines.events.on_console_command, on_console_command)
Event.add(defines.events.on_console_chat, on_console_chat)
Event.add(defines.events.on_forces_merged, on_forces_merged)
return Public
