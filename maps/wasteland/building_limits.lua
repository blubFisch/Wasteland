require 'utils.table'

local ScenarioTable = require 'maps.wasteland.table'
local TeamBasics = require 'maps.wasteland.team_basics'
local Utils = require 'maps.wasteland.utils'


global.tracked_labs = global.tracked_labs or {}

local function process_building_limit(actor, event)
    local entity = event.created_entity
    if not entity.valid then return end

    local force = actor.force
    if not TeamBasics.is_town_force(force) then
        return
    end

    local this = ScenarioTable.get_table()
    local surface = entity.surface
    local town_center = this.town_centers[force.name]

    if entity.type == 'electric-turret' then
        if surface.count_entities_filtered({position = entity.position, type = 'electric-turret', radius = 9, limit = 2}) == 2 then
            local position = entity.position
            local inventory
            local msg_entity
            if event.player_index then
                inventory = actor
                msg_entity = actor
            else
                inventory = event.robot.get_inventory(defines.inventory.robot_cargo)
                msg_entity = actor.force
            end
            inventory.insert({name = entity.name, count = 1})
            entity.destroy()

            Utils.build_error_notification(force, surface, position, "Too close to other turrets of this type!", event.player_index and actor or nil)
        end
    elseif entity.name == 'lab' then
        table.insert(global.tracked_labs, entity)

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
    process_building_limit(game.get_player(event.player_index), event)
end

local function on_robot_built_entity(event)
    process_building_limit(event.robot, event)
end

local function labs_cant_have_speed_modules()
    for i = #global.tracked_labs, 1, -1 do
        local lab = global.tracked_labs[i]
        if lab.valid then
            local inventory = lab.get_module_inventory()
            if not inventory.is_empty() then
                for ii = #inventory, 1, -1 do
                    if inventory[ii].valid_for_read then
                        if string.find(inventory[ii].name,"speed") then
                            inventory[ii].count = 0
                            lab.surface.create_entity(
                                {
                                    name = 'flying-text',
                                    position = lab.position,
                                    text = "Labs can't have speed modules!",
                                    color = {r = 0.77, g = 0.0, b = 0.0}
                                }
                            )
                        end
                    end
                end
            end
        else
            table.remove(global.tracked_labs, i)
        end
    end
end

local function on_entity_destroyed(event)
    local key = event.registration_number
    local this = ScenarioTable.get_table()
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
Event.on_nth_tick(18, labs_cant_have_speed_modules)
