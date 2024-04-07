local Public = {}

local table_insert = table.insert

Public.scenario_color = { r = 255, g = 255, b = 0 }
Public.scenario_color_warning = { r = 255, g = 0, b = 0 }

global.build_error_rate_limit = global.build_error_rate_limit or {}


function Public.make_border_vectors(radius, center_gap)
    if not center_gap then center_gap = 0 end

    local vectors = {}
    for x = center_gap, radius, 1 do
        table_insert(vectors, { x, radius })
        table_insert(vectors, { x * -1, radius })
        table_insert(vectors, { x, radius * -1})
        table_insert(vectors, { x * -1, radius * -1})
    end
    for y = center_gap, radius - 1, 1 do
        table_insert(vectors, { radius, y})
        table_insert(vectors, { radius, y * -1})
        table_insert(vectors, { radius * -1, y})
        table_insert(vectors, { radius * -1, y * -1})
    end
    return vectors
end

function Public.build_rate_limit_check(force)
    local force_name = force.name
    local force_limit = global.build_error_rate_limit[force_name]

    if not force_limit or game.tick - force_limit > 30 then
        global.build_error_rate_limit[force_name] = game.tick
        return true
    else
        return false
    end
end

function Public.build_error_notification(force_or_player, surface, position, msg, player_sound)
    if not force_or_player or Public.build_rate_limit_check(force_or_player) then
        surface.create_entity({
            name = 'flying-text',
            position = position,
            text = msg,
            color = {r = 0.77, g = 0.0, b = 0.0}
        })
    end
    if player_sound then
        player_sound.play_sound({path = 'utility/cannot_build', position = player_sound.position, volume_modifier = 0.75})
    end
end

return Public
