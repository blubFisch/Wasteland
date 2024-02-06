local TeamBasics = require 'maps.wasteland.team_basics'
local Event = require 'utils.event'

local function turrets_shoot_empty_vehicles()   -- Prevent players from using tanks to block construction bots
    local surface = game.surfaces.nauvis
    for _, vehicle in pairs(surface.find_entities_filtered({type = 'car'})) do
        --game.print("XDB v: " .. vehicle.name)
        for _, turret in pairs(surface.find_entities_filtered({type = 'electric-turret', position=vehicle.position, radius=24})) do
            --game.print("XDB t: " .. turret.name .. " " .. turret.status)
            if not TeamBasics.is_friendly_towards(turret.force, vehicle.force)
                    and turret.status ~= defines.entity_status.no_power and vehicle.get_driver() == nil
                    and vehicle.get_passenger() == nil then
                vehicle.damage(500, turret.force)
                surface.create_entity(
                    {
                        name = 'flying-text',
                        position = vehicle.position,
                        text = "Turret damages vehicle",
                        color = {r = 1, g = 0, b = 0}
                    }
                )
            end
        end
    end
end

Event.on_nth_tick(37, turrets_shoot_empty_vehicles)
