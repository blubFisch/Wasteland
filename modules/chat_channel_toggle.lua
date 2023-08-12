global.chat_modes = {}

local CHAT_MODES = {GLOBAL = 1, TEAM = 2, ALLIANCE = 3}
local BUTTON_PROPERTIES = {
    [CHAT_MODES.GLOBAL] = {{'wasteland.gui_chat_mode_global'}, {'wasteland.gui_chat_mode_global_tooltip'}, {r = 0.0, g = 0.77, b = 0.0}},
    [CHAT_MODES.TEAM] = {{'wasteland.gui_chat_mode_team'}, {'wasteland.gui_chat_mode_team_tooltip'}, {r = 0.77, g = 0.77, b = 0.0}},
    [CHAT_MODES.ALLIANCE] = {{'wasteland.gui_chat_mode_alliance'}, {'wasteland.gui_chat_mode_alliance_tooltip'}, {r = 0.5, g = 0.6, b = 0.9}}
}

local function setChatMode(player, mode)
    global.chat_modes[player.index] = mode

    local button = player.gui.screen['global_chat_toggle']
    local properties = BUTTON_PROPERTIES[mode]
    button.caption = properties[1]
    button.tooltip = properties[2]
    button.style.font_color = properties[3]
end

local function toggle(player)
    local button = player.gui.screen['global_chat_toggle']
    if not button then return end

    local current_mode = global.chat_modes[player.index] or CHAT_MODES.GLOBAL

    if current_mode == CHAT_MODES.GLOBAL then
        setChatMode(player, CHAT_MODES.TEAM)
    elseif current_mode == CHAT_MODES.TEAM then
        setChatMode(player, CHAT_MODES.ALLIANCE)
    else
        setChatMode(player, CHAT_MODES.GLOBAL)
    end
end

local function set_location(player)
    local button = player.gui.screen['global_chat_toggle']
    if button then
        local resolution = player.display_resolution
        local scale = player.display_scale
        button.location = {
            x = 6 * scale,
            y = resolution.height -128 * scale
        }
    end
end

local function create_gui_button(player)
    local button = player.gui.screen.add({type = 'sprite-button', name = 'global_chat_toggle', caption = ''})
    button.style.font = 'default'
    button.style.minimal_width = 85
    button.style.minimal_height = 30
    button.style.maximal_height = 30
    button.style.padding = 1
    button.style.margin = 0

    set_location(player)

    setChatMode(player, CHAT_MODES.GLOBAL)
end

local function on_player_joined_game(event)
    local player = game.players[event.player_index]
    create_gui_button(player)
end

local function on_gui_click(event)
    if not event or not event.element or not event.element.valid then return end

    local player = game.players[event.element.player_index]
    if event.element.name == 'global_chat_toggle' then
        toggle(player)
    end
end

local function on_console_chat(event)
    if not event.message or not event.player_index then return end

    local sender = game.players[event.player_index]
    local button = sender.gui.screen['global_chat_toggle']
    if not button then return end

    local message = sender.name .. ' ' .. sender.tag .. ': ' .. event.message
    local currentMode = global.chat_modes[sender.index]

    -- Note:
    -- The engine already displays messages to
    -- 1. the sending player
    -- 2. the team of the sending player

    if currentMode == CHAT_MODES.GLOBAL then
        for _, force in pairs(game.forces) do
            if force ~= sender.force then
                for _, player in pairs(force.players) do
                    player.print(message, sender.chat_color)
                end
            end
        end
    elseif currentMode == CHAT_MODES.ALLIANCE then
        for _, force in pairs(game.forces) do
            if force.get_friend(sender.force) and force ~= sender.force then
                for _, player in pairs(force.players) do
                    player.print(message, sender.chat_color)
                end
            end
        end
    end
end

local function on_display_changed(event)
    local player = game.get_player(event.player_index)
    set_location(player)
end

local Event = require 'utils.event'
Event.add(defines.events.on_console_chat, on_console_chat)
Event.add(defines.events.on_player_joined_game, on_player_joined_game)
Event.add(defines.events.on_gui_click, on_gui_click)
Event.add(defines.events.on_player_display_resolution_changed, on_display_changed)
Event.add(defines.events.on_player_display_scale_changed, on_display_changed)
