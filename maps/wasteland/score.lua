local mod_gui = require('mod-gui')

local ScenarioTable = require 'maps.scrap_towny_ffa.table'
local Event = require 'utils.event'
local ResearchBalance = require 'maps.scrap_towny_ffa.research_balance'

local Public = {}
local button_id = 'towny-score-button'
local evo_score_factor = 50

function Public.score_increment(evo_increase)
    return evo_increase * evo_score_factor
end

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

function Public.add_score_button(player)
    if player.gui.top[button_id] then
        player.gui.top[button_id].destroy()
    end
    local button = player.gui.top.add {
        type = 'sprite-button',
        caption = 'Leaderboard',
        name = button_id
    }
    button.style.font = 'default-bold'
    button.style.font_color = {r = 1, g = 0.7, b = 0.1}
    button.style.minimal_height = 38
    button.style.minimal_width = 100
    button.style.top_padding = 2
    button.style.left_padding = 4
    button.style.right_padding = 4
    button.style.bottom_padding = 2
end

local function on_gui_click(event)
    if not event.element.valid or event.element.name ~= button_id then
        return
    end
    local player = game.players[event.player_index]
    local this = ScenarioTable.get_table()
    local saved_frame = this.score_gui_frame[player.index]
    saved_frame.visible = not saved_frame.visible
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
    local score_to_win = 100

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

            subheader.add {type = 'label', style = 'subheader_label', caption = {'', 'Reach ' .. score_to_win .. ' points to win!'}}

            if not next(subheader.children) then
                subheader.destroy()
            end

            local information_table = inner_frame.add {type = 'table', column_count = 5, style = 'bordered_table'}
            information_table.style.margin = 4

            for _, caption in pairs({'Rank', 'Town', 'Research', 'Survival Time', 'Total'}) do
                local label = information_table.add {type = 'label', caption = caption}
                label.style.font = 'default-bold'
            end

            local town_total_scores = {}
            local town_age_scores = {}
            local town_ages_h = {}
            local town_res_scores = {}
            for _, town_center in pairs(this.town_centers) do
                if town_center ~= nil then
                    town_ages_h[town_center] = (game.tick - town_center.creation_tick) / 60 / 3600
                    town_age_scores[town_center] = math.min(town_ages_h[town_center] * 0.5, 60)
                    town_res_scores[town_center] = math.min(town_center.evolution.worms * evo_score_factor, 70)
                    town_total_scores[town_center] = town_age_scores[town_center] + town_res_scores[town_center]
                end
            end

            local rank = 1

            for town_center, total_score in spairs(
                    town_total_scores,
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
                information_table.add {type = 'label', caption = string.format('%.1f', town_res_scores[town_center]) ..
                        " (" .. ResearchBalance.format_town_modifier(ResearchBalance.modifier_for_town(town_center)) .. ")"}
                information_table.style.column_alignments[3] = 'right'
                information_table.add {type = 'label', caption = string.format('%.1f  (%.1fh)', town_age_scores[town_center], town_ages_h[town_center])}
                information_table.style.column_alignments[4] = 'right'
                information_table.add {type = 'label', caption = string.format('%.1f', town_total_scores[town_center])}
                information_table.style.column_alignments[5] = 'right'

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
            information_table.add {type = 'label', caption = '-'}
            information_table.add {type = 'label', caption = '-'}
        end
    end
end

Event.add(defines.events.on_gui_click, on_gui_click)
Event.on_nth_tick(60, update_score)

return Public
