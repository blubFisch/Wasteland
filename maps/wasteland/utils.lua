local Public = {}

local table_insert = table.insert

Public.scenario_color = { r = 255, g = 255, b = 0 }

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

return Public
