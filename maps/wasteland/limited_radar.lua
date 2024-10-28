local Public = {}

local ScenarioTable = require 'maps.wasteland.table'

function Public.reset()
    local this = ScenarioTable.get_table()
    if this.testing_mode then
        return
    end
    for _, force in pairs(game.forces) do
        force.clear_chart('nauvis')
    end
end

local function add_force(rendered, force_name)
    local forces = rendered.forces
    for _, force in ipairs(forces) do
        if force.name == force_name or force == force_name then
            return
        end
    end
    forces[#forces + 1] = force_name
    rendered.forces = forces
end

local function update_forces(rendered)
    local forces = rendered.forces
    local new_forces = {}
    for _, force in ipairs(forces) do
        if force ~= nil and force.valid then
            new_forces[#new_forces + 1] = force.name
        end
    end
    rendered.forces = new_forces
end

local function on_chunk_charted(event)
    local surface = game.surfaces[event.surface_index]
    local force = event.force
    local area = event.area
    local markets = surface.find_entities_filtered({area = area, name = 'market'})
    for _, market in pairs(markets) do
        local force_name = market.force.name
        local this = ScenarioTable.get_table()
        local town_center = this.town_centers[force_name]
        if not town_center then
            return
        end

        local town_caption = town_center.town_caption
        update_forces(town_caption)
        add_force(town_caption, force.name)

        local health_text = town_center.health_text
        update_forces(health_text)
        add_force(health_text, force.name)

        local shield_text = town_center.shield_text
        update_forces(shield_text)
        add_force(shield_text, force.name)

        local enemies_text = town_center.enemies_text
        update_forces(enemies_text)
        add_force(enemies_text, force.name)
    end
end

local Event = require 'utils.event'
Event.add(defines.events.on_chunk_charted, on_chunk_charted)

return Public
