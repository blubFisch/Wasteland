require 'modules.custom_death_messages'
require 'modules.flashlight_toggle_button'
require 'modules.global_chat_toggle'
require 'modules.biters_yield_coins'
require 'maps.scrap_towny_ffa.reset'
require 'maps.scrap_towny_ffa.mining'
require 'maps.scrap_towny_ffa.building'
require 'maps.scrap_towny_ffa.spaceship'
require 'maps.scrap_towny_ffa.town_center'
require 'maps.scrap_towny_ffa.market'
require 'maps.scrap_towny_ffa.slots'
require 'maps.scrap_towny_ffa.wreckage_yields_scrap'
require 'maps.scrap_towny_ffa.rocks_yield_ore_veins'
require 'maps.scrap_towny_ffa.worms_create_oil_patches'
require 'maps.scrap_towny_ffa.spawners_contain_biters'
require 'maps.scrap_towny_ffa.explosives_are_explosive'
require 'maps.scrap_towny_ffa.fluids_are_explosive'
require 'maps.scrap_towny_ffa.trap'
require 'maps.scrap_towny_ffa.turrets_drop_ammo'
require 'maps.scrap_towny_ffa.vehicles'
require 'maps.scrap_towny_ffa.suicide'
require 'maps.scrap_towny_ffa.score'

local Event = require 'utils.event'
local Autostash = require 'modules.autostash'
local MapDefaults = require 'maps.scrap_towny_ffa.map_defaults'
local BottomFrame = require 'utils.gui.bottom_frame'
local Nauvis = require 'maps.scrap_towny_ffa.nauvis'
local Biters = require 'maps.scrap_towny_ffa.biters'
local Pollution = require 'maps.scrap_towny_ffa.pollution'
local Fish = require 'maps.scrap_towny_ffa.fish_reproduction'
local Team = require 'maps.scrap_towny_ffa.team'
local Radar = require 'maps.scrap_towny_ffa.limited_radar'
local Limbo = require 'maps.scrap_towny_ffa.limbo'
local Evolution = require 'maps.scrap_towny_ffa.evolution'
local Gui = require 'utils.gui'
local Color = require 'utils.color_presets'
local Where = require 'utils.commands.where'
local Inventory = require 'modules.show_inventory'
local AntiGrief = require 'utils.antigrief'

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

require 'maps.scrap_towny_ffa.scrap_towny_ffa_layout'
