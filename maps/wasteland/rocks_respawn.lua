local ScenarioTable = require 'maps.scrap_towny_ffa.table'


local function on_init()
    local this = ScenarioTable.get_table()
    this.rocks_yield_ore_veins = {}
    this.rocks_yield_ore_veins.raffle = {}
    this.rocks_yield_ore_veins.mixed_ores = {}
    this.rocks_yield_ore_veins.chance = 5
    set_raffle()
end

local Event = require 'utils.event'
Event.on_init(on_init)
Event.add(defines.events.on_player_mined_entity, on_player_mined_entity)