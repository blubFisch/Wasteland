local Public = {}

local ScenarioTable = require 'maps.wasteland.table'
local Event = require 'utils.event'
local Team = require 'maps.wasteland.team'



function Public.register_for_tutorial(player)
    local this = ScenarioTable.get_table()
    this.tutorials[player.index] = {show_after_tick = game.tick + 60 * 10}
end

local function tutorials_tick()
    local this = ScenarioTable.get_table()

    for _, player in pairs(game.connected_players) do
        if this.tutorials[player.index] then
            local tut = this.tutorials[player.index]

            if tut.show_after_tick and game.tick > tut.show_after_tick then
                this.tutorials[player.index].step = 1
                player.set_goal_description("Found a town by building your stone furnace.\n\nThis will also unlock your map.")
                tut.show_after_tick = nil
            end

            if this.tutorials[player.index].step == 1 and Team.is_towny(player.force) then
                player.set_goal_description("Good!\nMake sure your town stays alive. If your market building gets destroyed, everything is lost!"
                .. "\nNext, collect some scrap from around your town to get resources."
                .. "\n\nCollect 500 iron plates.")

                this.tutorials[player.index].step = 2
            end

            if this.tutorials[player.index].step == 2 and player.get_item_count("iron-plate") >= 500 then
                player.set_goal_description("Great!\nNow use the scrap or the ores around your town.\nComplete your first research.")

                this.tutorials[player.index].step = 3
            end

            if this.tutorials[player.index].step == 3 and player.force.previous_research then
                player.set_goal_description("Well done!\nNext, take care of defense against players."
                        .. "\nLaser turrets are your best chance against advanced players and tanks."
                        .. "\nYou can buy laser turrets at your market."
                        .. "\n\nBuild your first laser turret")

                this.tutorials[player.index].step = 4
            end

            if this.tutorials[player.index].step == 4 and player.surface.count_entities_filtered({force = player.force,
                                                 name = {'laser-turret'}}) > 0 then
                player.set_goal_description("Great!\nThis is the end of the tutorial.\n\n"
                    .. "The goal of the game is to survive and advance through research.\nThe first town to reach 100 points wins!")

                this.tutorials[player.index].step = 5
                this.tutorials[player.index].finish_at_tick = game.tick + 60 * 30
            end

            if this.tutorials[player.index].step == 5 and game.tick > this.tutorials[player.index].finish_at_tick then
                player.set_goal_description("")
                this.tutorials[player.index] = nil
            end
        end
    end
end

Event.on_nth_tick(60, tutorials_tick)

return Public