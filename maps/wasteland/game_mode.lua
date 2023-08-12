local Public = {}

local button_id = "wl_game_mode"
Public.mode = 2
Public.mode_names = {
    {'wasteland.gui_gamemode_mode_1'},    -- Target: 10 hours game
    {'wasteland.gui_gamemode_mode_2'},   -- Target: 2 days game
    {'wasteland.gui_gamemode_mode_3'}      -- Target: 7 days game
}

function Public.add_mode_button(player)
    if player.gui.top[button_id] then
        player.gui.top[button_id].destroy()
    end
    local button = player.gui.top.add {
        type = 'sprite-button',
        caption = {'wasteland.gui_gamemode', Public.mode_names[Public.mode]},
        name = button_id
    }
    button.tooltip = {'wasteland.gui_gamemode_tooltip'}
    button.style.font_color = {r = 1, g = 1, b = 1}
    button.style.minimal_height = 38
    button.style.minimal_width = 150
    button.style.top_padding = 2
    button.style.left_padding = 4
    button.style.right_padding = 4
    button.style.bottom_padding = 2
end

return Public
