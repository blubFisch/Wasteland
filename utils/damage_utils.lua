local table_insert = table.insert

local Public = {}


local function add_players_from_entity_or_player(players, entity_or_player)
    if entity_or_player.object_name == "LuaEntity" then
        table_insert(players, entity_or_player.player)
    else -- "LuaPlayer"
        table_insert(players, entity_or_player)
    end
end

function Public.get_players_from_cause(cause)
    if not (cause and cause.valid) then return end

    local players = {}
    --game.print("XDB " .. cause.type .. " " .. cause.name)
    if cause.type == 'combat-robot' then
        local owner = cause.combat_robot_owner
        if owner then
            table_insert(players, owner.player)
        end
    elseif cause.name == 'character' then
        table_insert(players, cause.player)
    elseif cause.type == 'car' then
        local driver = cause.get_driver()
        if driver then
            add_players_from_entity_or_player(players, driver)
        end
        local passenger = cause.get_passenger()
        if passenger then
            add_players_from_entity_or_player(players, passenger)
        end
    elseif cause.type == 'locomotive' then
        local train_passengers = cause.train.passengers
        if train_passengers then
            for _, passenger in pairs(train_passengers) do
                table_insert(players, passenger)
            end
        end
    end
    return players
end

return Public
