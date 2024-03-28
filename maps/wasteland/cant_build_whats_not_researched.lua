local TeamBasics = require 'maps.wasteland.team_basics'

global.force_available_recipe_cache = global.force_available_recipe_cache or {}

local function update_recipes(force)
    global.force_available_recipe_cache[force.name] = {}

    for _, rx in pairs(force.recipes) do
        if rx.enabled then
            for _, ef in pairs(rx.products) do
                global.force_available_recipe_cache[force.name][ef.name] = true
            end
        end
    end
end

local function research_finished(event)
    update_recipes(event.research.force)
end

local allowed_for_all = {
    ['car'] = true,
    ['gate'] = true,
}

local allowed_for_towns = {
    ['laser-turret'] = true
}

local function process_building_limit(actor, event)
    local entity = event.created_entity
    if not entity.valid then return end

    local force = actor.force
    local force_name = force.name

    if not global.force_available_recipe_cache[force_name] then
        update_recipes(force)
    end

    if not global.force_available_recipe_cache[force_name][entity.name] and not allowed_for_all[entity.name]
            and not (allowed_for_towns[entity.name] and TeamBasics.is_town_force(force)) then
        entity.surface.create_entity(
                {
                    name = 'flying-text',
                    position = entity.position,
                    text = "Technology not available!",
                    color = {r = 0.77, g = 0.0, b = 0.0}
                }
        )
        actor.insert({name = entity.name, count = 1})
        entity.destroy()
    end
end

local function on_player_built_entity(event)
    process_building_limit(game.get_player(event.player_index), event)
end

local function on_robot_built_entity(event)
    process_building_limit(event.robot, event)
end


local Event = require 'utils.event'
Event.add(defines.events.on_research_finished, research_finished)
Event.add(defines.events.on_built_entity, on_player_built_entity)
Event.add(defines.events.on_robot_built_entity, on_robot_built_entity)