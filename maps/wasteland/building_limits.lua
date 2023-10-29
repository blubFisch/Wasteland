require 'utils.table'

local ScenarioTable = require 'maps.wasteland.table'
local TeamBasics = require 'maps.wasteland.team_basics'


local function process_slots(actor, event)
    local entity = event.created_entity
    if not entity.valid then return end

    local force = actor.force
    local surface = entity.surface

    -- Outlanders can't build laser turrets
    if entity.name == 'laser-turret' and not TeamBasics.is_town_force(force) then
        surface.create_entity(
                {
                    name = 'flying-text',
                    position = entity.position,
                    text = "Can't build this as outlander!",
                    color = {r = 0.77, g = 0.0, b = 0.0}
                }
        )
        actor.insert({name = entity.name, count = 1})
        entity.destroy()
        return
    end

    local this = ScenarioTable.get_table()
    local town_center = this.town_centers[force.name]
    if not town_center then return end

    if entity.name == 'laser-turret' then

        local slots = town_center.upgrades.laser_turret.slots
        local locations = town_center.upgrades.laser_turret.locations + 1
        local disallowed_info_text = "You do not have enough slots! Buy more at the market"

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

        local key = script.register_on_entity_destroyed(entity)
        this.laser_turrets[key] = force.index
        town_center.upgrades.laser_turret.locations = locations

        surface.create_entity(
                {
                    name = 'flying-text',
                    position = entity.position,
                    text = 'Using ' .. locations .. '/' .. slots .. ' laser slots',
                    color = {r = 1.0, g = 1.0, b = 1.0}
                }
        )
    elseif entity.name == 'lab' then
        -- Prevent researching extremely fast from stockpiled science
        local nearby_beacons = surface.find_entities_filtered({area = {{entity.position.x - 4, entity.position.y - 4},
                                                                       {entity.position.x + 4, entity.position.y + 4}},
                                                               name = 'beacon'})
        if #nearby_beacons > 0 then
            surface.create_entity(
                    {
                        name = 'flying-text',
                        position = entity.position,
                        text = "Beacons can't affect labs!",
                        color = {r = 0.77, g = 0.0, b = 0.0}
                    }
            )
            actor.insert({name = 'lab', count = 1})
            entity.destroy()
            return
        end

        local slots_max = 10
        local labs = town_center.labs or 0
        if labs >= slots_max then
            surface.create_entity(
                    {
                        name = 'flying-text',
                        position = entity.position,
                        text = "You can't have more than 8 labs!",
                        color = {r = 0.77, g = 0.0, b = 0.0}
                    }
            )
            actor.insert({name = 'lab', count = 1})
            entity.destroy()
            return
        end
        town_center.labs = labs + 1
        local key = script.register_on_entity_destroyed(entity)
        this.labs[key] = force.index

        surface.create_entity(
                {
                    name = 'flying-text',
                    position = entity.position,
                    text = 'Using ' .. town_center.labs .. '/' .. slots_max .. ' lab slots',
                    color = {r = 1.0, g = 1.0, b = 1.0}
                }
        )
    elseif entity.name == 'beacon' then
        -- Prevent researching extremely fast from stockpiled science
        local nearby_entities = surface.find_entities_filtered({area = {{entity.position.x - 4, entity.position.y - 4},
                                                                        {entity.position.x + 4, entity.position.y + 4}},
                                                                name = 'lab'})
        if #nearby_entities > 0 then
            surface.create_entity(
                    {
                        name = 'flying-text',
                        position = entity.position,
                        text = "Beacons can't affect labs!",
                        color = {r = 0.77, g = 0.0, b = 0.0}
                    }
            )
            actor.insert({name = 'beacon', count = 1})
            entity.destroy()
        end
    end
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
                town_center.upgrades.laser_turret.locations = town_center.upgrades.laser_turret.locations - 1
            end
        end
    end
    if this.labs[key] then
        local index = this.labs[key]
        local force = game.forces[index]
        if force ~= nil then
            local town_center = this.town_centers[force.name]
            if town_center ~= nil then
                town_center.labs = town_center.labs - 1
            end
        end
    end
end

local Event = require 'utils.event'
Event.add(defines.events.on_built_entity, on_player_built_entity)
Event.add(defines.events.on_robot_built_entity, on_robot_built_entity)
Event.add(defines.events.on_entity_destroyed, on_entity_destroyed)
