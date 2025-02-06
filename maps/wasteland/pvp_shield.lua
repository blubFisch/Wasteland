local Public = {}

local math_sqrt = math.sqrt

local Event = require 'utils.event'
local ScenarioTable = require 'maps.wasteland.table'
local CommonFunctions = require 'utils.common'

local beam_type = 'electric-beam-no-sound'

Public.SHIELD_TYPE = { OFFLINE = 1, OFFLINE_POST = 2, LEAGUE_BALANCE = 3}

local function is_allowed_in_shield(shield, other_force)
    return shield.force == other_force or shield.force.get_friend(other_force) or shield.force.get_cease_fire(other_force)
end

local function draw_borders(shield)
    local surface = shield.surface
    local right = shield.box.right_bottom.x
    local left = shield.box.left_top.x
    local top = shield.box.left_top.y
    local bottom = shield.box.right_bottom.y

    surface.create_entity({name = beam_type, position = {right, top},
                           source = {right, top}, target = {right, bottom + 0.5}})    -- intentional offset here to correct visual appearance
    surface.create_entity({name = beam_type, position = {right, bottom},
                           source = {right, bottom}, target = {left, bottom + 0.5}})
    surface.create_entity({name = beam_type, position = {left, bottom},
                           source = {left, bottom}, target = {left, top}})
    surface.create_entity({name = beam_type, position = {left, top - 0.5},
                           source = {left, top - 0.5}, target = {right, top}})
end

local function enlarge_bounding_box(bb, size)
    return {left_top = {x = bb.left_top.x - size, y = bb.left_top.y - size},
            right_bottom = {x = bb.right_bottom.x + size, y = bb.right_bottom.y + size}}
end

local function remove_drawn_borders(shield)
    for _, e in pairs(shield.surface.find_entities_filtered({area = enlarge_bounding_box(shield.box, 1), name = beam_type})) do
        if e.valid then
            e.destroy()
        end
    end
end

local function visualise_entity_deactivated(entity)
    local this = ScenarioTable.get_table()

    local entity_label = rendering.draw_text{
        text = "Inactive",
        surface = entity.surface,
        target = entity,
        target_offset = {0, -1},
        color = {r = 1, g = 0.0, b = 0.0},
        alignment = "center",
        scale = 1.0
    }
    this.entity_labels[entity.unit_number] = entity_label
end

local shield_inactive_types = { 'assembling-machine', 'furnace', 'lab', 'roboport', 'mining-drill',
                                'ammo-turret', 'electric-turret', 'fluid-turret', 'radar', 'beacon'}
local function control_buildings_inside(surface, box, active)
    local this = ScenarioTable.get_table()
    for _, e in pairs(surface.find_entities_filtered({ type = shield_inactive_types, area=box})) do
        if e.valid and not e.active == active then
            e.active = active
            if not active then
                visualise_entity_deactivated(e)
            else
                local entity_label = this.entity_labels[e.unit_number]
                if entity_label and rendering.is_valid(entity_label) then
                    rendering.destroy(entity_label)
                    this.entity_labels[e.unit_number] = nil
                end
            end
        end
    end
end

local function resize_shield(shield, scaled_size)
    local center = shield.center
    return {left_top = { x = center.x - scaled_size / 2, y = center.y - scaled_size / 2},
            right_bottom = { x = center.x + scaled_size / 2, y = center.y + scaled_size / 2}}
end

local function scale_size_by_lifetime(shield)
    local time_scale = math.min(1, (game.tick - shield.lifetime_start) / shield.time_to_full_size_ticks)
    shield.size = time_scale * shield.max_size
    shield.box = resize_shield(shield, shield.size)
end

function Public.add_shield(surface, force, center, max_size, expiry_time, time_to_full_size_ticks, shield_type)
    local this = ScenarioTable.get_table()

    local shield = {surface = surface, force = force, center = center, max_size = max_size, expiry_time = expiry_time,
                  time_to_full_size_ticks = time_to_full_size_ticks, lifetime_start = game.tick, shield_type = shield_type}

    scale_size_by_lifetime(shield)
    this.pvp_shields[force.name] = shield
end

function Public.swap_shield_type(shield, new_type)
    shield.shield_type = new_type

    local machines_active
    if new_type == Public.SHIELD_TYPE.LEAGUE_BALANCE then
        machines_active = true
    else
        machines_active = false
    end
    control_buildings_inside(shield.surface, resize_shield(shield, shield.max_size), machines_active)
end

function Public.remove_shield(shield)
    local this = ScenarioTable.get_table()
    remove_drawn_borders(shield)
    control_buildings_inside(shield.surface, resize_shield(shield, shield.max_size), true)

    this.pvp_shields[shield.force.name] = nil
    shield.force.print("Your PvP Shield has expired", {r = 1, g = 0, b = 0})
end

function Public.remaining_lifetime(shield)
    if shield.expiry_time then
        return shield.expiry_time - game.tick
    else
        return nil
    end
end

function Public.format_lifetime_str(lifetime_ticks)
    if lifetime_ticks == nil then
        return "unknown"
    elseif lifetime_ticks > 10 * 60 * 60 * 60 then
        return string.format('%.0fh', lifetime_ticks / 60 / 60 / 60)
    elseif lifetime_ticks > 60 * 60 * 60 then
        return string.format('%.1fh', lifetime_ticks / 60 / 60 / 60)
    elseif lifetime_ticks > 60 * 60 then
        return string.format('%.0f mins', math.ceil(lifetime_ticks / 60 / 60))
    else
        return string.format('%.0f sec', math.ceil(lifetime_ticks / 60))
    end
end

local function update_shield_lifetime()
    local this = ScenarioTable.get_table()
    for _, shield in pairs(this.pvp_shields) do
        if shield.expiry_time == nil or Public.remaining_lifetime(shield) > 0 then
            if shield.size < shield.max_size then
                remove_drawn_borders(shield)
                scale_size_by_lifetime(shield)
                draw_borders(shield)

                -- Push players out as shield grows
                for _, player in pairs(game.connected_players) do
                    Public.push_enemies_out(player)
                end

                -- Deactivate buildings as shield grows
                if shield.shield_type ~= Public.SHIELD_TYPE.LEAGUE_BALANCE then
                    control_buildings_inside(shield.surface, shield.box, false)
                end
            end
        else
            Public.remove_shield(shield)
        end
    end
end

local function vector_norm(vector)
    return math_sqrt(vector.x ^ 2 + vector.y ^ 2)
end

function Public.protected_by_shields(surface, position, force, distance)
    local this = ScenarioTable.get_table()
    for _, shield in pairs(this.pvp_shields) do
        if not (shield.force == force or surface ~= shield.surface) then
            if CommonFunctions.point_in_bounding_box(position, enlarge_bounding_box(shield.box, distance)) then
                return true
            end
        end
    end
    return false
end

function Public.push_enemies_out(player)
    local this = ScenarioTable.get_table()
    for _, shield in pairs(this.pvp_shields) do
        if not is_allowed_in_shield(shield, player.force) or player.surface ~= shield.surface then
            if CommonFunctions.point_in_bounding_box(player.position, shield.box) then
                if player.character then
                    -- Push player away from center
                    local center_diff = { x = player.position.x - shield.center.x, y = player.position.y - shield.center.y}
                    center_diff.x = center_diff.x / vector_norm(center_diff)
                    center_diff.y = center_diff.y / vector_norm(center_diff)
                    player.teleport({ player.position.x + center_diff.x, player.position.y + center_diff.y}, player.surface)

                    -- Kick players out of vehicles if needed
                    if player.character and player.character.driving then
                        player.character.driving = false
                    end

                    -- Punish player
                    if player.character then
                        player.character.health = player.character.health - 25
                        player.character.surface.create_entity({name = 'water-splash', position = player.position})
                        if player.character.health <= 0 then
                            player.character.die('enemy')
                        end
                    end
                end
            end
        end
    end
end

local function on_player_changed_position(event)
    local player = game.get_player(event.player_index)
    local surface = player.surface
    if not surface or not surface.valid then
        return
    end

    Public.push_enemies_out(player)
end

function Public.entity_is_protected(entity, cause_force)
    if not (cause_force and cause_force.valid) then
        return true
    end

    local this = ScenarioTable.get_table()
    for _, shield in pairs(this.pvp_shields) do
        if entity.surface == shield.surface and CommonFunctions.point_in_bounding_box(entity.position, shield.box) then
            if (entity.force == shield.force or entity.force.name == "neutral") and cause_force.name ~= "enemy" then
                if not is_allowed_in_shield(shield, cause_force) then
                    return true
                end
            end
        end
    end
    return false
end

function Public.protect_if_needed(event)
    local entity = event.entity
    if not entity.valid then
        return false
    end

    if Public.entity_is_protected(entity, event.force) then
        -- Undo all damage
        entity.health = entity.health + event.final_damage_amount
        return true
    else
        return false
    end
end

local shield_disallowed_vehicles = {'tank', 'car'}
local function scan_protect_shield_area()
    -- Handle edge case damage situations

    local this = ScenarioTable.get_table()
    local limit_idx = 0
    local update_limit = 10
    for _, shield in pairs(this.pvp_shields) do
        if game.tick % update_limit == limit_idx % update_limit then  -- Keep runtime low

            -- Protect against rolling tanks where player hops out before impact - this cannot be handled with damage event
            local tank_box = enlarge_bounding_box(shield.box, 3)
            for _, e in pairs(shield.surface.find_entities_filtered({name = shield_disallowed_vehicles, area = tank_box })) do
                if not is_allowed_in_shield(shield, e.force) then
                    e.speed = 0
                end
            end

            -- Remove nearby biters
            local biters_box = enlarge_bounding_box(shield.box, 17) -- catch spitters in their range
            for _, e in pairs(shield.surface.find_entities_filtered({ type = "unit", area = biters_box, force = "enemy"})) do
                e.die()
            end
        end
        limit_idx = limit_idx + 1
    end
end

local function on_built_entity(event)
    local entity = event.entity

    if not entity.valid or not table.array_contains(shield_inactive_types, entity.type) then
        return
    end

    local this = ScenarioTable.get_table()
    for _, shield in pairs(this.pvp_shields) do
        if shield.shield_type ~= Public.SHIELD_TYPE.LEAGUE_BALANCE then
            if CommonFunctions.point_in_bounding_box(entity.position, shield.box) then
                entity.active = false
                visualise_entity_deactivated(entity)
            end
        end
    end
end

Event.add(defines.events.on_player_changed_position, on_player_changed_position)
Event.on_nth_tick(3, update_shield_lifetime)
Event.add(defines.events.on_tick, scan_protect_shield_area)
Event.add(defines.events.on_built_entity, on_built_entity)
Event.add(defines.events.on_robot_built_entity, on_built_entity)

return Public
