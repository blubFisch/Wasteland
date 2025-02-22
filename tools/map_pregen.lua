local Event = require 'utils.event'

local function on_tick()
    if storage.map_pregeneration_is_active then
        if game.tick % 600 == 0 then
            local r = 1
            for x = 1, storage.chunk_radius, 1 do
                if game.forces.map_pregen.is_chunk_charted(game.players[1].surface, {x, x}) then
                    r = x
                end
            end
            game.print('Map chunks are generating... current radius ' .. r, {r = 0.22, g = 0.99, b = 0.99})
            if game.forces.map_pregen.is_chunk_charted(game.players[1].surface, {storage.chunk_radius, storage.chunk_radius}) then
                game.print('Map generation done!', {r = 0.22, g = 0.99, b = 0.99})

                game.players[1].force = game.forces['player']
                storage.map_pregeneration_is_active = nil
            end
        end
    end
end

local function map_pregen(chunk_radius)
    if chunk_radius then
        storage.chunk_radius = chunk_radius
    else
        storage.chunk_radius = 32
    end
    local radius = storage.chunk_radius * 32
    if not game.forces.map_pregen then
        game.create_force('map_pregen')
    end
    game.players[1].force = game.forces['map_pregen']
    game.forces.map_pregen.chart(game.players[1].surface, {{x = -1 * radius, y = -1 * radius}, {x = radius, y = radius}})
    storage.map_pregeneration_is_active = true
end

Event.add(defines.events.on_tick, on_tick)

return map_pregen
