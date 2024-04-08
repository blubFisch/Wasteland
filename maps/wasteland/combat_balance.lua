local Public = {}

local ScenarioTable = require 'maps.wasteland.table'
local TeamBasics = require 'maps.wasteland.team_basics'
local Building = require 'maps.wasteland.building'
local PvPTownShield = require 'maps.wasteland.pvp_town_shield'
local Utils = require 'maps.wasteland.utils'


local player_ammo_damage_starting_modifiers = {
    --['artillery-shell'] = -0.75,
    --['biological'] = -0.5,
    ['bullet'] = 0,
    ['cannon-shell'] = -0.4,
    ['capsule'] = 0,
    ['beam'] = -0.5,
    ['laser'] = -0.5,
    ['electric'] = -0.5,
    ['flamethrower'] = 0,
    ['grenade'] = -0.5,
    ['landmine'] = -0.75,
    --['melee'] = 2,
    --['rocket'] = -0.75,
    ['shotgun-shell'] = 0
}

local player_ammo_speed_starting_modifiers = {
    --['artillery-shell'] = -0.75,
    --['biological'] = -0.5,
    ['bullet'] = 0,
    ['cannon-shell'] = -0.4,
    ['capsule'] = 0,
    ['beam'] = -0.5,
    ['laser'] = -0.7,
    ['electric'] = -0.5,
    ['flamethrower'] = 0,
    ['grenade'] = -0.5,
    ['landmine'] = -0.75,
    --['melee'] = 2,
    --['rocket'] = -0.75,
    ['shotgun-shell'] = 0
}

local player_ammo_damage_upgrade_modifiers = {
    --['artillery-shell'] = -0.75,
    --['biological'] = -0.5,
    ['bullet'] = 0,
    ['cannon-shell'] = -0.75,
    ['capsule'] = 0,
    ['beam'] = -0.5,
    ['laser'] = -0.75,
    ['electric'] = -0.5,
    ['flamethrower'] = 0,
    ['grenade'] = -0.5,
    ['landmine'] = -0.5,
    --['melee'] = 0,
    --['rocket'] = -0.5,
    ['shotgun-shell'] = 0
}
local player_ammo_speed_upgrade_modifiers = {
    --['artillery-shell'] = -0.75,
    --['biological'] = -0.5,
    ['bullet'] = 0,
    ['cannon-shell'] = -0.35,
    ['capsule'] = -0.5,
    ['beam'] = -0.5,
    ['laser'] = 0,
    ['electric'] = -0.5,
    ['flamethrower'] = 0,
    ['grenade'] = -0.5,
    ['landmine'] = 0,
    --['melee'] = 1,
    --['rocket'] = -0.75,
    ['shotgun-shell'] = 0
}

--local player_turrets_research_modifiers = {
--    ['gun-turret'] = 0,
--    ['laser-turret'] = 1.5,
--    ['flamethrower-turret'] = 0
--}

function Public.init_player_weapon_damage(force)
    for k, v in pairs(player_ammo_damage_starting_modifiers) do
        force.set_ammo_damage_modifier(k, v)
    end

    for k, v in pairs(player_ammo_speed_starting_modifiers) do
        force.set_gun_speed_modifier(k, v)
    end

    force.set_turret_attack_modifier('laser-turret', 8)
end

-- After a research is finished and the game applied the modifier, we reduce modifiers to achieve the reduction
local function research_finished(event)
    local r = event.research
    local p_force = r.force

    p_force.recipes["slowdown-capsule"].enabled = false -- Note: Disabled because the effect is too strong & can't modify it

    for _, e in ipairs(r.effects) do
        local t = e.type

        if t == 'ammo-damage' then
            local category = e.ammo_category
            local factor = player_ammo_damage_upgrade_modifiers[category]

            if factor then
                local current_m = p_force.get_ammo_damage_modifier(category)
                p_force.set_ammo_damage_modifier(category, current_m + factor * e.modifier)
            end
        --elseif t == 'turret-attack' then  -- NOTE: this doesn't trigger for laser turrets :-(
        --    local category = e.turret_id
        --    local factor = player_turrets_research_modifiers[category]
        --    game.print("XDB cat " .. category)
        --    if factor then
        --        local current_m = p_force.get_turret_attack_modifier(category)
        --        game.print("XDB mod " .. current_m .. " -> " .. current_m + factor * e.modifier)
        --        p_force.set_turret_attack_modifier(category, current_m + factor * e.modifier)
        --    end
        elseif t == 'gun-speed' then
            local category = e.ammo_category
            local factor = player_ammo_speed_upgrade_modifiers[category]

            if factor then
                local current_m = p_force.get_gun_speed_modifier(category)
                p_force.set_gun_speed_modifier(category, current_m + factor * e.modifier)
            end
        end
    end
end

local button_id = "wasteland_damage_balance"

local force_damage_modifier_excluded = {
    ['laser-turret'] = true,
    ['flamethrower-turret'] = true,
    ['gun-turret'] = true
}

function Public.add_balance_ui(player)
    if player.gui.top[button_id] then
        player.gui.top[button_id].destroy()
    end
    local button = player.gui.top.add {
        type = 'sprite-button',
        caption = 'Damage',
        name = button_id
    }
    button.visible = false
    button.tooltip = "Multiplier on the attack damage for your town members. Doesn't apply to your turrets. Depends on the number of online town members."
    button.style.font = 'default'
    button.style.font_color = {r = 255, g = 255, b = 255}
    button.style.minimal_height = 38
    button.style.minimal_width = 130
    button.style.top_padding = 2
    button.style.left_padding = 4
    button.style.right_padding = 4
    button.style.bottom_padding = 2
end

local function format_dmg_modifier(modifier)
    return string.format('%.0f%%', 100 * modifier)
end
Public.format_dmg_modifier = format_dmg_modifier

local function calculate_modifier_for_town(town_center)
    local force = town_center.market.force
    if TeamBasics.is_town_force(force) then
        return math.min(1 / #force.connected_players + 0.2, 1) + town_center.town_rest.current_modifier / 2
    else
        return 1
    end
end

local function update_modifiers()
    local this = ScenarioTable.get_table()
    for _, town_center in pairs(this.town_centers) do
        if not town_center.combat_balance then
            town_center.combat_balance = {}
            town_center.combat_balance.previous_modifier = 1
        end
        town_center.combat_balance.current_modifier = calculate_modifier_for_town(town_center)

        -- Update UIs of all town players
        for _, player in pairs(town_center.market.force.connected_players) do
            player.gui.top[button_id].caption = "Damage: " .. format_dmg_modifier(town_center.combat_balance.current_modifier)
        end

        -- Notify about the change
        if math.abs(town_center.combat_balance.current_modifier - town_center.combat_balance.previous_modifier) >= 0.1 then
            town_center.market.force.print("Your town members attack damage is now "
                    .. format_dmg_modifier(town_center.combat_balance.current_modifier)
                    .. " (previously " .. format_dmg_modifier(town_center.combat_balance.previous_modifier) .. ")", Utils.scenario_color)
            town_center.combat_balance.previous_modifier = town_center.combat_balance.current_modifier
        end
    end
end

function Public.player_changes_town_status(player, in_town)
    update_modifiers()
    player.gui.top[button_id].visible = in_town
end


local non_bulldozable_entities = {
    ['car'] = true,
    ['tank'] = true,
    ['locomotive'] = true,
    ['cargo-wagon'] = true,
    ['fluid-wagon'] = true,
}

-- Extra modifiers based on player numbers
function Public.on_entity_damaged(event)
    local entity = event.entity
    if not entity.valid then
        return
    end
    local cause_force = event.force
    if cause_force == game.forces.enemy then
        return
    end
    local event_cause = event.cause

    -- Extra debug info
    --local cause_name = "n/a"
    --if event_cause then
    --    cause_name = event_cause.name
    --end
    --game.print("DMG_XDB entity " .. entity.name .. " damage_type " .. event.damage_type.name .. " cause " .. cause_name
    --        .. " original_damage_amount " .. event.original_damage_amount .. " final_damage_amount " .. event.final_damage_amount
    --        .. " entity.health(before) " .. entity.health)

    local is_vehicle_damage = false
    local vehicle_modifier = 1

    -- Bulldozer mode
    if event.damage_type.name == "explosion" and event_cause then
        local min_clear_distance = 30
        local position = entity.position
        if not Building.near_another_town(cause_force.name, position, entity.surface, min_clear_distance)
                and not Building.near_outlander_town(cause_force, position, entity.surface, min_clear_distance)
                and not PvPTownShield.enemy_players_nearby(position, entity.surface, cause_force, min_clear_distance)
                and not TeamBasics.is_friendly_towards(cause_force, entity.force)
                and not non_bulldozable_entities[entity.type]
                and entity.force ~= game.forces.enemy
        then
            entity.surface.create_entity(
                {
                    name = 'flying-text',
                    position = position,
                    text = 'Bulldozed!',
                    color = {r = 0.8, g = 0.7, b = 0.0}
                }
            )
            entity.health = 0
            return
        end
    end

    -- Adjust damage resistances of tanks
    if entity.name == "tank" then
        local damage_type_name = event.damage_type.name
        if (damage_type_name == "physical" or damage_type_name == "fire" or damage_type_name == "laser") then
            is_vehicle_damage = true
            if damage_type_name == "laser" then
                vehicle_modifier = 5
            else
                vehicle_modifier = 0.5
            end
            if event_cause and (event_cause.name == "tank" or event_cause.name == "car") then
                -- Boost player vs player vehicle battles
                vehicle_modifier = vehicle_modifier * 3
            end
            --if event.damage_type.name == "fire" then
            --    vehicle_modifier = vehicle_modifier * 1
            --end
        end
    end

    local force_modifier = 1
    -- Force modifier compensates for unbalanced teams
    -- This evens it out so that 2 shots from a 2 player team do same damage as 1 shot from a 1 player team
    -- Need to consider damage after damage resistances
    if not event_cause or force_damage_modifier_excluded[event_cause.name] then
        force_modifier = 1
    else
        local town_center = global.tokens.maps_wasteland_table.town_centers[cause_force.name]
        if town_center then
            force_modifier = town_center.combat_balance.current_modifier

            -- UX
            local last_shown = global.tokens.maps_wasteland_table.last_damage_multiplier_shown[cause_force.index]
            if (not last_shown or game.tick - last_shown > 60 * 60) and event_cause
                    and entity.force ~= game.forces.neutral and entity.force ~= game.forces.enemy then
                entity.surface.create_entity({
                    name = 'flying-text',
                    position = event_cause.position,
                    text = 'Damage: '.. format_dmg_modifier(force_modifier),
                    color = {r =1, g = 1, b = 1}
                })
                global.tokens.maps_wasteland_table.last_damage_multiplier_shown[cause_force.index] = game.tick
            end
        else
            force_modifier = 1
        end
    end

    local would_be_killed = entity.health == 0

    -- Undo original damage and apply modified damage
    if is_vehicle_damage then
        --game.print("DMG_XDB applying vehicle damage force_modifier " .. force_modifier .. " vehicle_modifier " .. vehicle_modifier
        --        .. " calc_dmg " .. event.original_damage_amount * vehicle_modifier * force_modifier)
        entity.health = entity.health + event.final_damage_amount - event.original_damage_amount * vehicle_modifier * force_modifier
    else
        if force_modifier == 1 then
            return
        else
            --game.print("DMG_XDB applying force_modifier " .. force_modifier)
            if event.final_damage_amount * force_modifier >= entity.health then
                entity.health = 0  -- Note: This is not fully correct, it can skip the last damage modification
            else
                entity.health = math.max(0, entity.health - event.final_damage_amount * (force_modifier - 1))
            end
        end
    end

    -- Handle the engine limitation that we can't know the applied damage if the originally resulting damage would be 0
    if would_be_killed and entity.health < entity.prototype.max_health * 0.05 then
        entity.health = 0
    end

    --game.print("DMG_XDB entity.health(after) " .. entity.health)
end

local Event = require 'utils.event'
Event.add(defines.events.on_research_finished, research_finished)
Event.on_nth_tick(63, update_modifiers)

return Public
