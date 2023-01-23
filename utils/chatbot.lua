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

local brain = {
    [1] = {'Our Discord server is at: tinyurl.com/4ua874n4'},
    [2] = {
        'Need an admin? Join our discord at: https://getcomfy.eu/discord,',
        'and report it in #i-need-halp',
        'If you have played for more than 5h in our maps then,',
        'you are eligible to run the command /jail and /free'
    },
    [3] = {'Scenario repository for download:', 'https://github.com/ComfyFactory/ComfyFactorio'},
    [4] = {
        'If you feel like the server is lagging, run the following command:',
        '/server-ups',
        'This will display the server UPS on your top right screen.'
    },
    [5] = {
        "If you're not trusted - ask an admin to trust you."
    }
}

local links = {
    ['admin'] = brain[2],
    ['administrator'] = brain[2],
    ['discord'] = brain[1],
    ['download'] = brain[3],
    ['github'] = brain[3],
    ['greifer'] = brain[2],
    ['grief'] = brain[2],
    ['griefer'] = brain[2],
    ['griefing'] = brain[2],
    ['mod'] = brain[2],
    ['moderator'] = brain[2],
    ['scenario'] = brain[3],
    ['stealing'] = brain[2],
    ['stole'] = brain[2],
    ['troll'] = brain[2],
    ['stutter'] = brain[4],
    ['freeze'] = brain[4],
    ['lag'] = brain[4],
    ['lagging'] = brain[4],
    ['trust'] = brain[5],
    ['trusted'] = brain[5],
    ['untrusted'] = brain[5]
}

local function on_player_joined_game(event)
    local player = game.get_player(event.player_index)
    if this.settings.enable_classic_print then
        player.print('[font=default-game]' .. 'Join the comfy discord >> tinyurl.com/4ua874n4 <<' .. '[/font]', {r = 150, g = 100, b = 255, a = 255})
    else
        player.print(
            '[font=heading-1]' ..
                '[color=#E99696]J[/color][color=#E9A296]o[/color][color=#E9AF96]i[/color][color=#E9BB96]n[/color] [color=#E9C896]t[/color][color=#E9D496]h[/color][color=#E9E096]e[/color] [color=#A6E996]d[/color][color=#9AE996]i[/color][color=#96E99E]s[/color][color=#96E9AB]c[/color][color=#96E9B7]o[/color][color=#96E9C3]r[/color][color=#96E9D0]d[/color] [color=#96E9DC]>[/color][color=#96E9E9]>[/color] [color=#96DCE9]tinyurl.com/4ua874n4[/color]' ..
                    '[/font]'
        )
    end
end

local function process_bot_answers(event)
    local player = game.get_player(event.player_index)
    if player.admin then
        return
    end
    local message = event.message
    message = string.lower(message)
    for word in string.gmatch(message, '%g+') do
        if links[word] then
            for _, bot_answer in pairs(links[word]) do
                player.print('[font=heading-1]' .. bot_answer .. '[/font]', Color.warning)
            end
            return
        end
    end
end

local function on_console_chat(event)
    if not event.player_index then
        return
    end
    local secs = Server.get_current_time()
    if not secs then
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
