local ScenarioTable = require 'maps.wasteland.table'

local function process_slots(actor, event)
    local entity = event.created_entity
    if not entity.valid then
        return
    end
    if entity.name ~= 'laser-turret' then
        return
    end
    local this = ScenarioTable.get_table()
    local force = actor.force
    local town_center = this.town_centers[force.name]
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
    local slots = town_center.upgrades.laser_turret.slots
    local locations = town_center.upgrades.laser_turret.locations

    if locations >= slots then
        surface.create_entity(
            {
                name = 'flying-text',
                position = entity.position,
                text = 'You do not have enough slots!',
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

    local key = script.register_on_entity_destroyed(entity)
    if (this.laser_turrets == nil) then
        this.laser_turrets = {}
    end
    this.laser_turrets[key] = force.index
    locations = locations + 1
    town_center.upgrades.laser_turret.locations = locations

    surface.create_entity(
        {
            name = 'flying-text',
            position = entity.position,
            text = 'Using ' .. locations .. '/' .. slots .. ' slots',
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
    if (this.laser_turrets == nil) then
        return
    end
    if (this.laser_turrets[key] ~= nil) then
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
