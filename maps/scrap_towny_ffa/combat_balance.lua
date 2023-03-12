local ScenarioTable = require 'maps.scrap_towny_ffa.table'

local Public = {}

local player_ammo_damage_starting_modifiers = {
    --['artillery-shell'] = -0.75,
    --['biological'] = -0.5,
    ['bullet'] = 0,
    ['cannon-shell'] = -0.5,
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
local player_ammo_damage_modifiers = {
    --['artillery-shell'] = -0.75,
    --['biological'] = -0.5,
    ['bullet'] = 0,
    ['cannon-shell'] = -0.5,
    ['capsule'] = 0,
    ['beam'] = -0.5,
    ['laser'] = -0.5,
    ['electric'] = -0.5,
    ['flamethrower'] = 0,
    ['grenade'] = -0.5,
    ['landmine'] = -0.5,
    --['melee'] = 0,
    --['rocket'] = -0.5,
    ['shotgun-shell'] = 0
}
local player_gun_speed_modifiers = {
    --['artillery-shell'] = -0.75,
    --['biological'] = -0.5,
    ['bullet'] = 0,
    ['cannon-shell'] = -0.5,
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

    for k, v in pairs(player_gun_speed_modifiers) do
        force.set_gun_speed_modifier(k, v)
    end

    force.set_turret_attack_modifier('laser-turret', 3)
end

-- After a research is finished and the game applied the modifier, we reduce modifiers to achieve the reduction
local function research_finished(event)
    local r = event.research
    local p_force = r.force

    for _, e in ipairs(r.effects) do
        local t = e.type

        if t == 'ammo-damage' then
            local category = e.ammo_category
            local factor = player_ammo_damage_modifiers[category]

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
            local factor = player_gun_speed_modifiers[category]

            if factor then
                local current_m = p_force.get_gun_speed_modifier(category)
                p_force.set_gun_speed_modifier(category, current_m + factor * e.modifier)
            end
        end
    end
end

local button_id = "towny_damage_balance"

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
        caption = 'Damage modifier',
        name = button_id
    }
    button.style.font = 'default'
    button.style.font_color = {r = 255, g = 255, b = 255}
    button.style.minimal_height = 38
    button.style.minimal_width = 180
    button.style.top_padding = 2
    button.style.left_padding = 4
    button.style.right_padding = 4
    button.style.bottom_padding = 2
end

local function update_uis()
    local this = ScenarioTable.get_table()
    for _, town_center in pairs(this.town_centers) do
        local force = town_center.market.force
        for _, player in pairs(force.connected_players) do
            player.gui.top[button_id].caption = "Damage modifier: " .. Public.format_dmg_modifier(force)
        end
    end
end

function Public.format_dmg_modifier(force)
    return string.format('%.0f%%', 100 * Public.dmg_modifier_for_force(force))
end


function Public.dmg_modifier_for_force(force)
    return 1 / #force.connected_players
end

-- Extra modifiers based on player numbers
local function on_entity_damaged(event)
    local entity = event.entity
    if not entity.valid then
        return
    end

    local cause_force = event.force
    if cause_force == game.forces.enemy or entity.force == game.forces.enemy or entity.force == game.forces.neutral then
        return
    end
    if cause_force == game.forces.player or cause_force == game.forces.rogue then
        return
    end

    if not event.cause or force_damage_modifier_excluded[event.cause.name] then
        return
    end
    --game.print("damage_type " .. event.damage_type.name .. " cause " .. event.cause.name)

    local modifier = Public.dmg_modifier_for_force(cause_force)
    entity.health = entity.health - event.final_damage_amount * (modifier - 1)
end

local Event = require 'utils.event'
Event.add(defines.events.on_research_finished, research_finished)
Event.add(defines.events.on_entity_damaged, on_entity_damaged)
Event.on_nth_tick(60, update_uis)

return Public