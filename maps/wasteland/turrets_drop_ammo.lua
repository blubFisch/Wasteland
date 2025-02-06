local random = math.random
local min = math.min


local __stack = {name = 'piercing-rounds-magazine', count = 1}
local __spill_item_stack_param = {
    stack = __stack,
    position = nil,
    enable_looted = true, allow_belts = true
}
local function on_entity_died(event)
    local entity = event.entity
    local surface = entity.surface
    if entity.type == 'ammo-turret' and entity.force.index == 2 then -- enemy
        local min_value = min(entity.get_item_count('piercing-rounds-magazine'), 20)
        if min_value > 0 then
            __spill_item_stack_param.position = entity.position
            __stack.count = random(1, min_value)
            surface.spill_item_stack(__spill_item_stack_param)
        end
    end
end

local Event = require 'utils.event'
Event.add(defines.events.on_entity_died, on_entity_died)
