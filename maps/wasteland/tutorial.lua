local Public = {}

local ScenarioTable = require 'maps.wasteland.table'
local Event = require 'utils.event'
local TeamBasics = require 'maps.wasteland.team_basics'


function Public.register_for_tutorial(player)
    local this = ScenarioTable.get_table()
    this.tutorials[player.name] = {show_after_tick = game.tick + 60 * 20}
end

local function tutorials_tick()
    local this = ScenarioTable.get_table()

    for _, player in pairs(game.connected_players) do
        if this.tutorials[player.name] then
            local tut = this.tutorials[player.name]

            if tut.show_after_tick and game.tick > tut.show_after_tick then
                this.tutorials[player.name].step = 1
                player.set_goal_description("Found a town by building your white chest\nor keep roaming as a lawless outlander")
                tut.show_after_tick = nil
            end

            if this.tutorials[player.name].step == 1 and TeamBasics.is_town_force(player.force) then
                player.set_goal_description("Good!\nMake sure your town stays alive. If your market building gets destroyed, everything is lost!"
                .. "\nNext, collect some scrap from around your town to get resources."
                .. "\n\nCollect 500 iron plates.")

                this.tutorials[player.name].step = 2
            end

            if this.tutorials[player.name].step == 2 and player.get_item_count("iron-plate") >= 500 then
                player.set_goal_description("Great!\nNow use the scrap or the ores around your town.\n\nComplete your first research.")

                this.tutorials[player.name].step = 3
            end

            if this.tutorials[player.name].step == 3 and player.force.previous_research then
                player.set_goal_description("Well done!\nNext, take care of defense against players."
                        .. "\nLaser turrets are your best chance against advanced players and tanks."
                        .. "\nYou can buy laser turrets at your market.\nGet coins by killing biters or selling items"
                        .. "\n\nBuild your first laser turret")

                this.tutorials[player.name].step = 4
            end

            if this.tutorials[player.name].step == 4 and player.surface.count_entities_filtered({force = player.force,
                                                                                                  name = 'laser-turret', position = player.position, radius = 100}) > 0 then
                player.set_goal_description("Good!\nYour starter ore patches are limited,\nbut there are many more ore patches hidden under rocks!\n\nFind a patch by hand mining big brown rocks")

                this.tutorials[player.name].step = 5
            end

            if this.tutorials[player.name].step == 5 and this.tutorials[player.name].mined_rock then
                player.set_goal_description("Great!\nThis is the end of the tutorial.\n\n"
                    .. "The goal of the game is to survive and advance through research.\nThe first town to reach 100 points wins!")

                this.tutorials[player.name].step = 6
                this.tutorials[player.name].finish_at_tick = game.tick + 60 * 30
            end

            if this.tutorials[player.name].step == 6 and game.tick > this.tutorials[player.name].finish_at_tick then
                player.set_goal_description("")
                this.tutorials[player.name] = nil
            end
        end
    end
end

Event.on_nth_tick(60, tutorials_tick)

commands.add_command(
        'skip-tutorial',
        'Turns off the tutorial',
        function(cmd)
            local player = game.player

            if not player or not player.valid then
                return
            end

            local this = ScenarioTable.get_table()

            player.set_goal_description("")
            this.tutorials[player.name] = nil
        end
)
return Public