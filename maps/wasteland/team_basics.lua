local Public = {}

function Public.is_town_force(force)
    return string.sub(force.name, 1, 2) == "t_"
end

function Public.is_outlander_force(force)
    return string.sub(force.name, 1, 2) == "o_"
end

function Public.non_town_display_name(force)
    assert(not Public.is_town_force(force))
    if Public.is_outlander_force(force) then
        return string.sub(force.name, 3)
    elseif force == game.forces.enemy then
        return "the biters"
    else
        return force.name
    end
end

function Public.is_friendly_towards(my_force, other_force)
    return my_force == other_force or my_force.get_friend(other_force) or my_force.get_cease_fire(other_force)
end

return Public
