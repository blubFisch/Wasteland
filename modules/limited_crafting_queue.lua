local Event = require 'utils.event'
local MAX_INGREDIENT_COUNT = 2000

local function on_pre_player_crafted_item(event)
    local player = game.players[event.player_index]
    local total_item_count_in_queue = 0
    local crafting_queue = player.crafting_queue
    local player_recipes = player.force.recipes

    for _, queue in pairs(crafting_queue) do
        local queue_recipe = player_recipes[queue.recipe]
        for _, ingredient in pairs(queue_recipe.ingredients) do
            total_item_count_in_queue = total_item_count_in_queue + queue.count * ingredient.amount
        end
    end

    if total_item_count_in_queue <= MAX_INGREDIENT_COUNT then return end

    for index = #crafting_queue, 1, -1 do
        local queue = crafting_queue[index]
        local excess = total_item_count_in_queue - MAX_INGREDIENT_COUNT
        local queue_recipe = player_recipes[queue.recipe]
        local ingredients_used = 0
        for _, ingredient in pairs(queue_recipe.ingredients) do
            ingredients_used = ingredients_used + ingredient.amount
        end
        local cancel_count = math.ceil(excess / ingredients_used)
        player.cancel_crafting({index = index, count = cancel_count})
        total_item_count_in_queue = total_item_count_in_queue - cancel_count * ingredients_used
        game.print("Your crafting queue is full", {r = 0.7, g = 0, b = 0})
        if total_item_count_in_queue <= MAX_INGREDIENT_COUNT then break end
    end
end

Event.add(defines.events.on_pre_player_crafted_item, on_pre_player_crafted_item)
