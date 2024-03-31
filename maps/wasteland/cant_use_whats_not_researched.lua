local TeamBasics = require 'maps.wasteland.team_basics'
local Utils = require 'maps.wasteland.utils'

global.force_available_recipe_cache = global.force_available_recipe_cache or {}

local function update_recipes(force)
    global.force_available_recipe_cache[force.name] = {}

    for _, rec in pairs(force.recipes) do
        if rec.enabled then
            for _, prod in pairs(rec.products) do
                global.force_available_recipe_cache[force.name][prod.name] = true
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
    ['curved-rail'] = true,
    ['straight-rail'] = true,
    ['loader'] = true,
    ['fast-loader'] = true,
    ['express-loader'] = true
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

local function force_unequip_armor(player, armor_inventory, armor)
    local armor_stack = armor_inventory.find_item_stack(armor.name)
    local player_inventory = player.get_main_inventory()
    if player_inventory.can_insert(armor_stack) then
        player_inventory.insert(armor_stack)
        armor_inventory.remove(armor_stack)
    else
        player.surface.spill_item_stack(player.position, armor_stack, true, player.force, false)
        armor_inventory.remove(armor_stack)
    end
    player.print("Technology not available for your armor or one of its modules", Utils.scenario_color_warning)
end

-- Prevent exploits of players using higher league items via tricks like suiciding own town
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
        force_unequip_armor(player, armor_inventory, armor)
    end

    local grid = armor.grid
    if not grid or not grid.valid then
        return
    end
    local equip = grid.equipment
    for _, piece in pairs(equip) do
        if piece.valid then
            if not global.force_available_recipe_cache[player_force_name][piece.name] and not allowed_for_all[piece.name] then
                force_unequip_armor(player, armor_inventory, armor)
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

-- Prevent exploits of players using higher league buildings via tricks like suiciding own town
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
        local entity_to_refund = entity.name
        entity.destroy()
        actor.insert({name = entity_to_refund, count = 1})
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
