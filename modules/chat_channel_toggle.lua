storage.chat_modes = {}

local CHAT_MODES = {GLOBAL = 1, TEAM = 2, ALLIANCE = 3}
local BUTTON_PROPERTIES = {
    [CHAT_MODES.GLOBAL] = {'Global Chat', 'Chat messages are sent to everyone.', {r = 0.0, g = 0.77, b = 0.0}},
    [CHAT_MODES.TEAM] = {'Team Chat', 'Chat messages are only sent to your team.', {r = 0.77, g = 0.77, b = 0.0}},
    [CHAT_MODES.ALLIANCE] = {'Alliance Chat', 'Chat messages are only sent to your alliance.', {r = 0.5, g = 0.6, b = 0.9}}
}

local function setChatMode(player, mode)
    storage.chat_modes[player.index] = mode

    local button = player.gui.screen['global_chat_toggle']
    local properties = BUTTON_PROPERTIES[mode]
    button.caption = properties[1]
    button.tooltip = properties[2]
    button.style.font_color = properties[3]
end

local function toggle(player)
    local button = player.gui.screen['global_chat_toggle']
    if not button then return end

    local current_mode = storage.chat_modes[player.index] or CHAT_MODES.GLOBAL

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

local function on_player_joined_game(event)
    local player = game.players[event.player_index]

    if player.gui.screen['global_chat_toggle'] then
        return
    end

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

local function on_gui_click(event)
    if not event or not event.element or not event.element.valid then return end

    local player = game.players[event.element.player_index]
    if event.element.name == 'global_chat_toggle' then
        toggle(player)
    end
end

local function get_recipients(currentMode, sender)
    if currentMode == CHAT_MODES.GLOBAL then
        return game.connected_players
    elseif currentMode == CHAT_MODES.TEAM then
        return sender.force.connected_players
    elseif currentMode == CHAT_MODES.ALLIANCE then
        local recipients = {}
        for _, force in pairs(game.forces) do
            if force == sender.force or force.get_friend(sender.force) then
                for _, player in pairs(force.connected_players) do
                    table.insert(recipients, player)
                end
            end
        end
        return recipients
    end
end

local function on_console_chat(event)
    if not event.message or not event.player_index then return end

    local sender = game.players[event.player_index]
    local button = sender.gui.screen['global_chat_toggle']
    if not button then return end

    local currentMode = storage.chat_modes[sender.index] or CHAT_MODES.GLOBAL
    local prefix_color = BUTTON_PROPERTIES[currentMode][3]
    local color_string = string.format("#%02X%02X%02X", prefix_color.r*255, prefix_color.g*255, prefix_color.b*255)
    local mode_prefixes = { [CHAT_MODES.GLOBAL] = 'Global', [CHAT_MODES.TEAM] = 'Team', [CHAT_MODES.ALLIANCE] = 'Alliance' }
    local prefix = '[color=' .. color_string .. ']' .. mode_prefixes[currentMode] .. '[/color]'
    local recipients = get_recipients(currentMode, sender)

    local message = prefix .. ' ' .. sender.name .. ' ' .. sender.tag .. ': ' .. event.message
    for _, player in pairs(recipients) do
        player.print(message, sender.chat_color)
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
