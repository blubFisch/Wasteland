require 'utils.table'

local ScenarioTable = require 'maps.wasteland.table'
local CommonFunctions = require 'utils.common'

local center_limited_types = { 'assembling-machine', 'furnace'}
local center_forbidden_types = { 'lab'}

local function process_slots(actor, event)
    local entity = event.created_entity
    if not entity.valid then
        return
    end

    local force = actor.force
    local this = ScenarioTable.get_table()
    local town_center = this.town_centers[force.name]
    if not town_center then     -- only for town owners
        return
    end

    if not (entity.name == 'laser-turret' or (
            (table.array_contains(center_limited_types, entity.type) or table.array_contains(center_forbidden_types, entity.type))
                    and CommonFunctions.point_in_bounding_box(entity.position, town_center.center_box)
            )
    ) then
        return
    end

    local surface = entity.surface

    if force.index == game.forces['player'].index or force.index == game.forces['rogue'].index or town_center == nil then
        surface.create_entity(
            {
                name = 'flying-text',
                position = entity.position,
                text = 'You are not acclimated to this technology!',
                color = {r = 0.77, g = 0.0, b = 0.0}
            }
        )
        actor.insert({name = 'laser-turret', count = 1})
        entity.destroy()
        return
    end

    local slots
    local locations
    local disallowed_info_text
    if entity.name == 'laser-turret' then
        slots = town_center.upgrades.laser_turret.slots
        locations = town_center.upgrades.laser_turret.locations + 1
        disallowed_info_text = "You do not have enough slots! Buy more at the market"
    elseif table.array_contains(center_limited_types, entity.type) then
        slots = 5
        locations = surface.count_entities_filtered({ force = force, type = center_limited_types, area=town_center.center_box})
        disallowed_info_text = "Too many production machines in center, build outside!"
    elseif table.array_contains(center_forbidden_types, entity.type) then
        slots = 0
        locations = 1
        disallowed_info_text = "Can't build this in the town center, build outside!"
    else
        assert(false, "Unhandled case")
    end

    if locations > slots then
        surface.create_entity(
            {
                name = 'flying-text',
                position = entity.position,
                text = disallowed_info_text,
                color = {r = 0.77, g = 0.0, b = 0.0}
            }
        )

        local inventory
        if event.player_index then
            inventory = actor
        else
            inventory = event.robot.get_inventory(defines.inventory.robot_cargo)
        end
        inventory.insert({name = entity.name, count = 1})

        entity.destroy()
        return
    end

    if entity.name == 'laser-turret' then
        local key = script.register_on_entity_destroyed(entity)
        this.laser_turrets[key] = force.index
        town_center.upgrades.laser_turret.locations = locations
    end

    surface.create_entity(
        {
            name = 'flying-text',
            position = entity.position,
            text = 'Using ' .. locations .. '/' .. slots .. ' ' .. (entity.name == 'laser-turret' and "laser" or "center production") ..' slots',
            color = {r = 1.0, g = 1.0, b = 1.0}
        }
    )
end

local function on_player_built_entity(event)
    process_slots(game.get_player(event.player_index), event)
end

local function on_robot_built_entity(event)
    process_slots(event.robot, event)
end

local function on_entity_destroyed(event)
    local key = event.registration_number
    local this = ScenarioTable.get_table()
    if this.laser_turrets[key] then
        local index = this.laser_turrets[key]
        local force = game.forces[index]
        if force ~= nil then
            local town_center = this.town_centers[force.name]
            if town_center ~= nil then
                if force.index == game.forces['player'].index or force.index == game.forces['rogue'].index or town_center == nil then
                    return
                end
                local locations = town_center.upgrades.laser_turret.locations
                locations = locations - 1
                if (locations < 0) then
                    locations = 0
                end
                town_center.upgrades.laser_turret.locations = locations
            end
        end
    end
end

local Event = require 'utils.event'
Event.add(defines.events.on_built_entity, on_player_built_entity)
Event.add(defines.events.on_robot_built_entity, on_robot_built_entity)
Event.add(defines.events.on_entity_destroyed, on_entity_destroyed)
