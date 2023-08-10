local Public = {}

function Public.is_town_force(force)
    return string.sub(force.name, 1, 2) == "t_"
end

return Public
