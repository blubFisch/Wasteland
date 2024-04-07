local Public = {}

local GameSettings = require 'game_settings'

local button_id = "wl_game_mode"
Public.mode = GameSettings.game_mode
Public.mode_names = {
    "Short",    -- Target: 10 hours game
    "Normal",   -- Target: 2 days game
    "Long"      -- Target: 7 days game
}

function Public.add_mode_button(player)
    if player.gui.top[button_id] then
        player.gui.top[button_id].destroy()
    end
    local button = player.gui.top.add {
        type = 'sprite-button',
        caption = 'Game Mode: ' .. Public.mode_names[Public.mode],
        name = button_id
    }
    button.tooltip = "Changes game duration, research cost and research score"
    button.style.font_color = {r = 1, g = 1, b = 1}
    button.style.minimal_height = 38
    button.style.minimal_width = 150
    button.style.top_padding = 2
    button.style.left_padding = 4
    button.style.right_padding = 4
    button.style.bottom_padding = 2
end

function Public.disable_game_mode_techs(force)
    if Public.mode == 1 then
        force.technologies['production-science-pack'].enabled = false
        force.technologies['nuclear-fuel-reprocessing'].enabled = false
        force.technologies['effect-transmission'].enabled = false
        force.technologies['automation-3'].enabled = false
        force.technologies['logistics-3'].enabled = false
        force.technologies['coal-liquefaction'].enabled = false
        force.technologies['kovarex-enrichment-process'].enabled = false
        force.technologies['rocket-silo'].enabled = false
        force.technologies['space-science-pack'].enabled = false
        force.technologies['worker-robots-speed-5'].enabled = false
        force.technologies['worker-robots-storage-2'].enabled = false
        force.technologies['braking-force-3'].enabled = false
    end
end

return Public
