require 'modules.flashlight_toggle_button'
require 'modules.chat_channel_toggle'
require 'modules.biters_yield_coins'
require 'maps.wasteland.game_settings'
require 'maps.wasteland.reset'
require 'maps.wasteland.mining'
require 'maps.wasteland.building'
require 'maps.wasteland.score'
require 'maps.wasteland.spaceship'
require 'maps.wasteland.town_center'
require 'maps.wasteland.market'
require 'maps.wasteland.building_limits'
require 'maps.wasteland.wreckage_yields_scrap'
require 'maps.wasteland.rocks_yield_ore_veins'
require 'maps.wasteland.worms_create_oil_patches'
require 'maps.wasteland.spawners_contain_biters'
require 'maps.wasteland.trap'
require 'maps.wasteland.turrets_drop_ammo'
require 'maps.wasteland.suicide'
require 'maps.wasteland.score_board'
require 'maps.wasteland.research_balance'
require 'maps.wasteland.map_layout'
require 'maps.wasteland.evolution'
require 'maps.wasteland.custom_death_messages'
require 'maps.wasteland.pvp_guardian'
require 'maps.wasteland.cant_use_whats_not_researched'

local Event = require 'utils.event'
local Autostash = require 'modules.autostash'
local MapDefaults = require 'maps.wasteland.map_defaults'
local BottomFrame = require 'utils.gui.bottom_frame'
local Nauvis = require 'maps.wasteland.nauvis'
local Biters = require 'maps.wasteland.biters'
local Pollution = require 'maps.wasteland.pollution'
local Fish = require 'maps.wasteland.fish_reproduction'
local Team = require 'maps.wasteland.team'
local Radar = require 'maps.wasteland.limited_radar'
local Limbo = require 'maps.wasteland.limbo'
local PvPShield = require 'maps.wasteland.pvp_shield'
local Gui = require 'utils.gui'
local Color = require 'utils.color_presets'
local Where = require 'utils.commands.where'
local CombatBalance = require 'maps.wasteland.combat_balance'


local function on_init()
    Autostash.insert_into_furnace(true)
    Autostash.insert_into_wagon(true)
    Autostash.bottom_button(true)
    BottomFrame.reset()
    BottomFrame.activate_custom_buttons(true)
    Where.module_disabled(true)

    game.enemy_has_vision_on_land_mines = false
    game.draw_resource_selection = true
    game.disable_tutorial_triggers()

    MapDefaults.initialize()
    Limbo.initialize()
    Nauvis.initialize()
    Team.initialize()
end

local tick_actions = {
    [60 * 0] = Radar.reset,
    [60 * 5] = Team.update_town_chart_tags,
    [60 * 10] = Team.set_all_player_colors,
    [60 * 15] = Fish.reproduce,
    [60 * 25] = Biters.unit_groups_start_moving,
    [60 * 30] = Radar.reset,
    [60 * 45] = Biters.validate_swarms,
    [60 * 50] = Biters.swarm,
    [60 * 55] = Pollution.market_scent
}

local function run_tick_actions(event)
    -- run each second
    local tick = event.tick
    local seconds = tick % 3600 -- tick will recycle minute
    if not tick_actions[seconds] then
        return
    end
    tick_actions[seconds]()
end

local is_entity_protected = PvPShield.entity_is_protected
-- Central damage routing to avoid overlaps and races
local function on_entity_damaged(event)
    local entity = event.entity
    if not entity.valid then
        return
    end

    local force = event.force
    if not (force and force.valid) or (force.index ~= 2 and is_entity_protected(entity, force)) then  -- enemy's force index is 2
        CombatBalance.on_entity_damaged(event)
        Team.on_entity_damaged(event)
        Pollution.on_entity_damaged(event)
    else
        -- Undo all damage
        entity.health = entity.health + event.final_damage_amount
    end
end

Event.add(defines.events.on_entity_damaged, on_entity_damaged)
Event.on_init(on_init)
Event.on_nth_tick(60, run_tick_actions)

--Disable the comfy main gui since we good too many goodies there.
Event.add(
    defines.events.on_gui_click,
    function(event)
        local element = event.element
        if not element or not element.valid then
            return
        end
        local fish_button = Gui.top_main_gui_button
        local main_frame_name = Gui.main_frame_name
        local player = game.get_player(event.player_index)
        if not player or not player.valid then
            return
        end
        if element.name == fish_button then
            if not player.admin then
                if player.gui.left[main_frame_name] and player.gui.left[main_frame_name].valid then
                    player.gui.left[main_frame_name].destroy()
                end
                return player.print('Comfy panel is disabled in this scenario.', Color.fail)
            end
        end
    end
)
