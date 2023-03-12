local Public = {}

local ScenarioTable = require 'maps.scrap_towny_ffa.table'
local Event = require 'utils.event'

local button_id = "towny_research_balance"

function Public.add_balance_ui(player)
    if player.gui.top[button_id] then
        player.gui.top[button_id].destroy()
    end
    local button = player.gui.top.add {
        type = 'sprite-button',
        caption = 'Research modifier',
        name = button_id
    }
    button.style.font = 'default'
    button.style.font_color = {r = 255, g = 255, b = 255}
    button.style.minimal_height = 38
    button.style.minimal_width = 180
    button.style.top_padding = 2
    button.style.left_padding = 4
    button.style.right_padding = 4
    button.style.bottom_padding = 2
end

local function update_uis()
    local this = ScenarioTable.get_table()
    for _, town_center in pairs(this.town_centers) do
        local force = town_center.market.force
        for _, player in pairs(force.connected_players) do
            player.gui.top[button_id].caption = "Research modifier: " .. Public.format_modifier(town_center)
        end
    end
end

function Public.format_modifier(town_center)
    return string.format('%.0f%%', 100 * Public.modifier_for_town(town_center))
end

-- Relative speed modifier, 1=no change
function Public.modifier_for_town(town_center)
    local this = ScenarioTable.get_table()
    local max_res = 0
    for _, town_center in pairs(this.town_centers) do
        max_res = math.max(town_center.evolution.worms, max_res)
    end
    --game.print("max_res:" .. max_res)
    local research_modifier = math.min(math.max(max_res, 0.01) / math.max(town_center.evolution.worms, 0.01), 10)

    local player_modifier = 1 / #town_center.market.force.players
    --game.print(town_center.market.force.name .. " " .. player_modifier .. " " .. research_modifier .. " " .. player_modifier * research_modifier)

    return player_modifier * research_modifier
end

local function tick()
    local this = ScenarioTable.get_table()

     for _, town_center in pairs(this.town_centers) do
         local force = town_center.market.force
         if force.current_research then
             if not town_center.research_balance then
                 town_center.research_balance = {}
             end
             --game.print("cur:" .. force.research_progress)

             if town_center.research_balance.last_progress
                     and town_center.research_balance.last_progress < force.research_progress   -- don't skip to next research
             then
                 local diff = force.research_progress - town_center.research_balance.last_progress
                 --game.print("diff:" .. diff)
                 force.research_progress = math.min(force.research_progress + diff * (Public.modifier_for_town(town_center) - 1), 1)
             end
             town_center.research_balance.last_progress = force.research_progress
             --game.print("last: " .. town_center.research_balance.last_progress)
         end
    end
end

Event.on_nth_tick(1, tick)
Event.on_nth_tick(60, update_uis)

return Public
