require 'modules.custom_death_messages'
require 'modules.flashlight_toggle_button'
require 'modules.global_chat_toggle'
require 'modules.biters_yield_coins'
require 'maps.wasteland.reset'
require 'maps.wasteland.mining'
require 'maps.wasteland.building'
require 'maps.wasteland.spaceship'
require 'maps.wasteland.town_center'
require 'maps.wasteland.market'
require 'maps.wasteland.slots'
require 'maps.wasteland.wreckage_yields_scrap'
require 'maps.wasteland.rocks_yield_ore_veins'
require 'maps.wasteland.worms_create_oil_patches'
require 'maps.wasteland.spawners_contain_biters'
require 'maps.wasteland.explosives_are_explosive'
require 'maps.wasteland.fluids_are_explosive'
require 'maps.wasteland.trap'
require 'maps.wasteland.turrets_drop_ammo'
require 'maps.wasteland.vehicles'
require 'maps.wasteland.suicide'
require 'maps.wasteland.score'
require 'maps.wasteland.research_balance'

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
local Evolution = require 'maps.wasteland.evolution'
local Gui = require 'utils.gui'
local Color = require 'utils.color_presets'
local Where = require 'utils.commands.where'
local Inventory = require 'modules.show_inventory'
local AntiGrief = require 'utils.antigrief'
local Utils = require 'maps.wasteland.utils'


local function on_init()
    Autostash.insert_into_furnace(true)
    Autostash.insert_into_wagon(true)
    Autostash.bottom_button(true)
    BottomFrame.reset()
    BottomFrame.activate_custom_buttons(true)
    Where.module_disabled(true)
    Inventory.module_disabled(true)

    -- Disable AntiGrief as it has too many side effects and is not so useful for this mode
    local AG = AntiGrief.get()
    AG.enabled = false

    game.enemy_has_vision_on_land_mines = false
    game.draw_resource_selection = true
    game.disable_tutorial_triggers()

    MapDefaults.initialize()
    Limbo.initialize()
    Nauvis.initialize()
    Team.initialize()
end

local tick_actions = {
    [60 * 0] = Radar.reset, -- each minute, at 00 seconds
    [60 * 5] = Team.update_town_chart_tags, -- each minute, at 05 seconds
    [60 * 10] = Team.set_all_player_colors, -- each minute, at 10 seconds
    [60 * 15] = Fish.reproduce, -- each minute, at 15 seconds
    [60 * 25] = Biters.unit_groups_start_moving, -- each minute, at 25 seconds
    [60 * 30] = Radar.reset, -- each minute, at 30 seconds
    [60 * 45] = Biters.validate_swarms, -- each minute, at 45 seconds
    [60 * 50] = Biters.swarm, -- each minute, at 50 seconds
    [60 * 55] = Pollution.market_scent -- each minute, at 55 seconds
}

local function on_nth_tick(event)
    -- run each second
    local tick = event.tick
    local seconds = tick % 3600 -- tick will recycle minute
    if not tick_actions[seconds] then
        return
    end
    --game.surfaces['nauvis'].play_sound({path = 'utility/alert_destroyed', volume_modifier = 1})
    --log('seconds = ' .. seconds)
    tick_actions[seconds]()
end

local function ui_smell_evolution()
    for _, player in pairs(game.connected_players) do
        -- Only for non-townies
        if player.force.index == game.forces.player.index or player.force.index == game.forces['rogue'].index then
            local e = Evolution.get_evolution(player.position)
            local extra
            if e < 0.1 then
                extra = 'Could be a good place to found a town.'
            else
                extra = 'Not a safe place to start a new town. Maybe somewhere else?'
            end
            player.create_local_flying_text(
                {
                    position = {x = player.position.x, y = player.position.y},
                    text = 'You smell the evolution around here: ' .. string.format('%.0f', e * 100) .. '%. ' .. extra,
                    color = {r = 1, g = 1, b = 1}
                }
            )
        end
    end
end

Event.on_init(on_init)
Event.on_nth_tick(60, on_nth_tick) -- once every second
Event.on_nth_tick(60 * 30, ui_smell_evolution)

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

require 'maps.wasteland.map_layout'
