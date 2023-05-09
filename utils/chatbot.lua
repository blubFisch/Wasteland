local Event = require 'utils.event'
local Server = require 'utils.server'
local Color = require 'utils.color_presets'
local Global = require 'utils.global'

local this = {
    settings = {
        enable_classic_print = false
    }
}

Global.register(
    this,
    function(tbl)
        this = tbl
    end
)

local Public = {}

local discord_url = "wasteland-discord.fun"
local discord_url_styled = "[color=red]" .. discord_url .. "[/color]"


local brain = {
    [1] = {"Our Discord server is at >> " .. discord_url_styled .. " >> Enter that URL into your web browser to join"},
    [2] = {
        'Need an admin? Message in our discord at ' .. discord_url_styled
    }
}

local links = {
    ['admin'] = brain[2],
    ['administrator'] = brain[2],
    ['discord'] = brain[1],
    ['dc'] = brain[1],
    ['greifer'] = brain[2],
    ['grief'] = brain[2],
    ['griefer'] = brain[2],
    ['griefing'] = brain[2],
    ['moderator'] = brain[2],
    ['troll'] = brain[2],
}

local function on_player_joined_game(event)
    local player = game.get_player(event.player_index)
    if this.settings.enable_classic_print then
        player.print('[font=default-game]' .. 'Join the discord >> ' .. discord_url .. ' <<' .. '[/font]', {r = 150, g = 100, b = 255, a = 255})
    else
        player.print(
            '[font=heading-1]' ..
            'Join the discord >> [color=red]' .. discord_url .. '[/color]' ..
            '[/font]' ..
            ' >> Server reset info, map updates, bugs/ideas, ..'
        )
    end
end

local function process_bot_answers(event)
    local message = event.message
    message = string.lower(message)
    for word in string.gmatch(message, '%g+') do
        if links[word] then
            for _, bot_answer in pairs(links[word]) do
                game.print('Wasteland bot: ' .. bot_answer)
            end
            return
        end
    end
end

local function on_console_chat(event)
    if not event.player_index then
        return
    end
    process_bot_answers(event)
end

--- Enables the classic print when a player is created.
---@param boolean any
function Public.enable_classic_print(boolean)
    this.settings.enable_classic_print = boolean or false
end

Event.add(defines.events.on_player_joined_game, on_player_joined_game)
Event.add(defines.events.on_console_chat, on_console_chat)

return Public
