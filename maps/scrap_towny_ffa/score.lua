local mod_gui = require('mod-gui')

local ScenarioTable = require 'maps.scrap_towny_ffa.table'
local Event = require 'utils.event'

local function spairs(t, order)
    local keys = {}
    for k in pairs(t) do
        keys[#keys + 1] = k
    end
    if order then
        table.sort(
                keys,
                function(a, b)
                    return order(t, a, b)
                end
        )
    else
        table.sort(keys)
    end
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

local function init_score_board(player)
    local this = ScenarioTable.get_table()
    local saved_frame = this.score_gui_frame[player.index]
    if saved_frame and saved_frame.valid then
        return
    end

    local flow = mod_gui.get_frame_flow(player)
    local frame = flow.add {type = 'frame', style = mod_gui.frame_style, caption = 'Town leaderboard', direction = 'vertical'}
    frame.style.vertically_stretchable = false
    this.score_gui_frame[player.index] = frame
end

local function update_score()
    local this = ScenarioTable.get_table()
    local score_to_win = 70

    for _, player in pairs(game.connected_players) do
        local frame = this.score_gui_frame[player.index]
        if not (frame and frame.valid) then
            init_score_board(player)
        end
        if frame and frame.valid then
            frame.clear()

            local inner_frame = frame.add {type = 'frame', style = 'inside_shallow_frame', direction = 'vertical'}

            local subheader = inner_frame.add {type = 'frame', style = 'subheader_frame'}
            subheader.style.horizontally_stretchable = true
            subheader.style.vertical_align = 'center'

            subheader.add {type = 'label', style = 'subheader_label', caption = {'', 'Reach ' .. score_to_win .. ' research points to win!'}}

            if not next(subheader.children) then
                subheader.destroy()
            end

            local information_table = inner_frame.add {type = 'table', column_count = 3, style = 'bordered_table'}
            information_table.style.margin = 4
            information_table.style.column_alignments[3] = 'right'

            for _, caption in pairs({'Rank', 'Town (players online/total)', 'Research points'}) do
                local label = information_table.add {type = 'label', caption = caption}
                label.style.font = 'default-bold'
            end

            local town_tech_scores = {}
            for _, town_center in pairs(this.town_centers) do
                if town_center ~= nil then
                    town_tech_scores[town_center] = town_center.evolution.worms * 100
                end
            end

            local rank = 1

            for town_center, tech_score in spairs(
                    town_tech_scores,
                    function(t, a, b)
                        return t[b] < t[a]
                    end
            ) do
                local position = information_table.add {type = 'label', caption = '#' .. rank}
                if town_center == this.town_centers[player.force.name] then
                    position.style.font = 'default-semibold'
                    position.style.font_color = {r = 1, g = 1}
                end
                local label =
                information_table.add {
                    type = 'label',
                    caption = town_center.town_name .. ' (' .. #town_center.market.force.connected_players .. '/' .. #town_center.market.force.players .. ')'
                }
                label.style.font = 'default-semibold'
                label.style.font_color = town_center.color
                information_table.add {type = 'label', caption = string.format('%.1f', tech_score)}

                rank = rank + 1
            end

            -- Outlander section
            information_table.add {type = 'label', caption = '-'}
            local outlander_on = #game.forces['player'].connected_players + #game.forces['rogue'].connected_players
            local outlander_total = #game.forces['player'].players + #game.forces['rogue'].players

            local label =
            information_table.add {
                type = 'label',
                caption = 'Outlanders' .. ' (' .. outlander_on .. '/' .. outlander_total .. ')'
            }
            label.style.font_color = {170, 170, 170}
            information_table.add {type = 'label', caption = '-'}
        end
    end
end

Event.on_nth_tick(60, update_score)