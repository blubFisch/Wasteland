local TeamBasics = require 'maps.wasteland.team_basics'
local Utils = require 'maps.wasteland.utils'

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
    ['gate'] = true,
    -- Spaceship market entries
    ['car'] = true,
    ['heavy-armor'] = true,
    ['modular-armor'] = true,
    ['solar-panel-equipment'] = true,
    ['battery-equipment'] = true,
    ['personal-roboport-equipment'] = true,
    ['night-vision-equipment'] = true,
}

local allowed_for_towns = {
    ['laser-turret'] = true
}

local function error_floaty(surface, position)
    surface.create_entity({
        name = 'flying-text',
        position = position,
        text = "Technology not available!",
        color = {r = 0.77, g = 0.0, b = 0.0}
    })
end

-- Prevent exploits of players in lower leagues gaining access to high league items
local function process_armor(player)
    local armor_inventory = player.get_inventory(defines.inventory.character_armor)
    if not armor_inventory.valid then
        log("error: not armor_inventory.valid")
        return
    end
    local armor = armor_inventory[1]
    if not armor.valid_for_read then
        return
    end

    local player_force_name = player.force.name
    if not global.force_available_recipe_cache[player_force_name] then
        update_recipes(player.force)
    end

    if not global.force_available_recipe_cache[player_force_name][armor.name] and not allowed_for_all[armor.name] then
        armor_inventory.clear() -- Note this doesn't refund the armor, but doesn't matter much at this point
        player.print("Technology not available for your armor", Utils.scenario_color_warning)
    end

    local grid = armor.grid
    if not grid or not grid.valid then
        return
    end
    local equip = grid.equipment
    for _, piece in pairs(equip) do
        if piece.valid then
            game.print(piece.name)
            if not global.force_available_recipe_cache[player_force_name][piece.name] and not allowed_for_all[piece.name] then
                armor_inventory.clear() -- Note this doesn't refund the armor, but doesn't matter much at this point
                player.print("Technology not available for your armor", Utils.scenario_color_warning)
            end
        end
    end
end

local function on_player_placed_equipment(event)
    process_armor(game.get_player(event.player_index))
end

local function on_player_armor_inventory_changed(event)
    process_armor(game.get_player(event.player_index))
end

-- Prevent exploits of players in lower leagues gaining access to high league buildings
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
        error_floaty(entity.surface, entity.position)
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
Event.add(defines.events.on_player_armor_inventory_changed, on_player_armor_inventory_changed)
Event.add(defines.events.on_player_placed_equipment, on_player_placed_equipment)
