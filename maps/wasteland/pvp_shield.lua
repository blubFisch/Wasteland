local Public = {}

local math_sqrt = math.sqrt

local Event = require 'utils.event'
local ScenarioTable = require 'maps.wasteland.table'
local CommonFunctions = require 'utils.common'

local beam_type = 'electric-beam-no-sound'

Public.SHIELD_TYPE = { OFFLINE = 1, OFFLINE_POST = 2, LEAGUE_BALANCE = 3}

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

local function scale_size_by_lifetime(shield)
    local time_scale = math.min(1, (game.tick - shield.lifetime_start) / shield.time_to_full_size_ticks)
    local scaled_size = time_scale * shield.max_size

    local center = shield.center
    local box = {left_top = { x = center.x - scaled_size / 2, y = center.y - scaled_size / 2},
                 right_bottom = { x = center.x + scaled_size / 2, y = center.y + scaled_size / 2}}
    shield.box = box
    shield.size = scaled_size
end

function Public.add_shield(surface, force, center, max_size, lifetime_ticks, time_to_full_size_ticks, shield_type)
    local this = ScenarioTable.get_table()

    local shield = {surface = surface, force = force, center = center, max_size = max_size, max_lifetime_ticks = lifetime_ticks,
                  time_to_full_size_ticks = time_to_full_size_ticks, lifetime_start = game.tick, shield_type = shield_type}

    scale_size_by_lifetime(shield)
    this.pvp_shields[force.name] = shield
end

function Public.remove_shield(shield)
    local this = ScenarioTable.get_table()
    remove_drawn_borders(shield)

    this.pvp_shields[shield.force.name] = nil
    shield.force.print("Your PvP Shield has expired", {r = 1, g = 0, b = 0})
end

function Public.remaining_lifetime(shield)
    if shield.max_lifetime_ticks then
        return shield.max_lifetime_ticks - (game.tick - shield.lifetime_start)
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
    else
        return string.format('%.0f mins', math.ceil(lifetime_ticks / 60 / 60))
    end
end

local function update_shield_lifetime()
    local this = ScenarioTable.get_table()
    for _, shield in pairs(this.pvp_shields) do
        if shield.max_lifetime_ticks == nil or Public.remaining_lifetime(shield) > 0 then
            if shield.size < shield.max_size then
                remove_drawn_borders(shield)
                scale_size_by_lifetime(shield)
                draw_borders(shield)

                -- Push everyone out as we grow (even if they're just standing)
                for _, player in pairs(game.connected_players) do
                    Public.push_enemies_out(player)
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
        if not (shield.force == player.force or shield.force.get_friend(player.force) or player.surface ~= shield.surface) then
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
                if shield.force ~= cause_force and not shield.force.get_friend(cause_force) then
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
    local idx = 0
    local update_limit = 10
    for _, shield in pairs(this.pvp_shields) do
        if game.tick % update_limit == idx % update_limit then  -- Keep runtime low

            -- Protect against rolling tanks where player hops out before impact - this cannot be handled with damage event
            local tank_box = enlarge_bounding_box(shield.box, 3)
            for _, e in pairs(shield.surface.find_entities_filtered({name = shield_disallowed_vehicles, area = tank_box })) do
                if shield.force ~= e.force and not shield.force.get_friend(e.force) then
                    e.speed = 0
                end
            end

            -- Protect against big biters that are lured in/glitched in
            local biters_box = enlarge_bounding_box(shield.box, 17) -- catch spitters in their range
            for _, e in pairs(shield.surface.find_entities_filtered({ type = "unit", area = biters_box, force = "enemy"})) do
                e.die()
            end
        end
        idx = idx + 1
    end
end

Event.add(defines.events.on_player_changed_position, on_player_changed_position)
Event.on_nth_tick(3, update_shield_lifetime)
Event.add(defines.events.on_tick, scan_protect_shield_area)

return Public
