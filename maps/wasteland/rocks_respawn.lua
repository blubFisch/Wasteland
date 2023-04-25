local math_random = math.random
local math_floor = math.floor
local table_insert = table.insert
local table_shuffle = table.shuffle_table

local ScenarioTable = require 'maps.wasteland.table'


local function on_init()
    local this = ScenarioTable.get_table()
end

local valid_entities = {
    ['rock-big'] = true,
    ['rock-huge'] = true,
    ['sand-rock-big'] = true
}

--Todo: either create a rock when one rock has been mined, or create a rock after a certain time
--Todo: where should the rock spawn? check if its in a city or in a entity (this would be bad)

local surface = town_center.market.surface
local position = town_center.market.position
local fishes = surface.find_entities_filtered({name = 'rock-big', position = position, radius = 27})

local rockType = math_random(1, 3)
local fish = fishes[t]


surface.create_entity({name = 'rock-big', position = fish.position})



local Event = require 'utils.event'
Event.on_init(on_init)

