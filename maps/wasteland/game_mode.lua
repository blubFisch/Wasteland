local Public = {}

local GameSettings = require 'game_settings'

local button_id = "wl_game_mode"
Public.mode = GameSettings.game_mode
Public.mode_names = {
    "Short",    -- Target: 6 hours game
    "Normal",   -- Target: 2 days game
    "Long"      -- Target: 5 days game
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

local function disable_techs(force, starting_from_list, inputs_to_disable)
    local targets = {}
    for _, name in ipairs(starting_from_list) do
        targets[name] = true
    end

    local function is_prerequisite_or_input(tech)
        if targets[tech.name] then return true end
        for _, ingredient in pairs(tech.research_unit_ingredients) do
            if inputs_to_disable[ingredient.name] then return true end
        end
        if tech.prerequisites then
            for prerequisite_name, _ in pairs(tech.prerequisites) do
                if targets[prerequisite_name] or is_prerequisite_or_input(force.technologies[prerequisite_name]) then
                    return true
                end
            end
        end
        return false
    end

    for _, tech in pairs(force.technologies) do
        if is_prerequisite_or_input(tech) then
            tech.enabled = false
        end
    end
end

function Public.disable_game_mode_techs(force)
    if Public.mode == 1 then
        disable_techs(force, {'production-science-pack', 'utility-science-pack'}, {
            ["production-science-pack"] = true,
            ["utility-science-pack"] = true,
        })
    end
end

return Public
