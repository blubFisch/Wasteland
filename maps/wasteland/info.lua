local Public = {}

local changelog =
    [[[font=heading-2]Jun 2024 updates[/font]
 - In survival mode, league 4 towns only get survival time score when offline (only when offline for 2h or longer)
 - Laser turret distance adjustments + Before researching laser turret, can build max 8
 - Fluid tanks are no longer explosive - this caused too much frustration for beginners
 - Tank shells are now very effective against other tanks with direct hits
 - Time score now only counts survival time without shield (=online or L4)
 - Less cost increase for adding players to a town
 - Battle mode (="Short) has no yellow/purple science + smaller towns
 - Exploit fixes
 - When a town is offline, it gains a rest bonus, which is applied to player damage output and research cost]]

local info =
    [[[font=heading-1]Welcome to the Wasteland![/font]
Can you build a town that survives against biters and other players?


]] .. changelog

local info_adv =
    changelog ..
    [[


[font=heading-1]Goal of the game[/font]
- Build the strongest town and be the first to reach 100 score on the leaderboard
- Build or join a town. Defend your town. Raid other towns.

[font=heading-1]Town members, alliances and cease fire[/font]
- Join town: Drop a coin on that outlander (with the Z key). To accept an invite, they also need to drop a coin on you.
- Cease fire: Drop a fish on one of them or their town center (works for outlanders too). If they agree they need to drop a fish on you too.
    - Cease fire means your weapons (turrets, bots, ..) won't target them automatically. You still can't access the other's bases.
    - If you cause damage, the ceasefire is broken immediately
    - Cease fire declarations are private (other players won't know)
- Alliances: Drop a coin on a player. If they agree they need to drop a coin on you too.
    - They can now access all of your stuff and radar is shared
    - Alliances do not get cancelled automatically when damage is taken
    - To cancel an alliance, drop coal on them or their member
    - Alliance declarations are public
- Leave a town: Drop coal on the market. Note that their turrets will target you immediately.
- Kick a town member: Use the chat command /kick-town-member PLAYER_NAME

[font=heading-1]Leagues and PvP Shields[/font]
- PVP Shields protect player's towns while offline and balance players who join later
- PvP shields prevent players and biters from entering, building and damaging
- League shield protects your town from players of a higher league and cover the outer blue tile square of your town
- League scores: L1: 15 score or tank. L2: 35 score. L3: 60 score
    - To see how town scores are calculated, hover the mouse over a town's score in the leaderboard
- In League 4, towns don't get score for being online. Players must be offline for 2h for the score to resume
- Offline PvP shields deploy automatically once all players of a town leave the game
    - The size is marked by the blue square around towns
    - This only gets deployed if there are no enemies in your town's range - it is only safe to log out if your town market shows "No enemies"
    - This shield is available before League 4
    - Shields also stop all production buildings, labs, roboports, turrets and others (enable AFK mode to test it)
    - If no players are in a town for more than 24h (ingame time), the town is "Abandoned" and loses its PvP protection
- Your town has a AFK PvP shield that you can use to safely take a quick break - deploy it from the market

[font=heading-1]Advanced tips and tricks[/font]
- To join our discord, open wasteland-discord.fun in your web browser
- It's best to found new towns far from existing towns, as biters advance based on the tech of nearby towns
- Need more ores? Mine or destroy big rocks to find ore patches under them!
- Need more oil? Kill biter worms - some of them will leave you an oil patch
- When your town is offline, it gains a rest bonus, which is applied to player damage output, scrap/mining productivity and research cost
- The town market is the heart of your town. If it is destroyed, you lose everything.
    Protect it well and increase its health by purchasing upgrades.
- It's possible to automate trading with the town center! How cool is that?!! Try it out.
    Tip: use filter inserters to get coins out of the market or to buy items
- Fishes procreate near towns. The more fishes, the quicker they multiply. Automated fish farm, anyone?
    Accidentally overfished? No problem, you can drop them back in
- Use /rename-town NEWNAME (chat command) to rename your town
- If you get stuck or trapped, use the /suicide chat command to respawn. Use /new-spawn to set up a new spawn point
- It is not possible to build near other towns turrets, town centers or PvP shields
    except logistics entities (inserters, belts, boxes, rails) that can be used to steal items from other bases and can be built anywhere except near turrets
- Research modifier: Towns with more members (online+recently offline) have more expensive research. Less advanced towns have cheaper research
- Damage modifier: Members of towns with more online members cause reduced damage against other towns and players
- Biter waves with boss units (the ones with health bar) will attack advanced towns while their players are online
- Spawn biters by dropping coins on nests. They will attack the closest town
- Laser and gun turrets shoot empty vehicles which can be used to block bots in offline attacks]]

function Public.toggle_button(player)
    if player.gui.top['wl_map_intro_button'] then
        return
    end
    local b = player.gui.top.add({type = 'sprite-button', caption = 'Help', name = 'wl_map_intro_button'})
    b.style.font_color = {r = 0.5, g = 0.3, b = 0.99}
    b.style.font = 'heading-1'
    b.style.minimal_height = 38
    b.style.minimal_width = 80
    b.style.top_padding = 1
    b.style.left_padding = 1
    b.style.right_padding = 1
    b.style.bottom_padding = 1
end


function Public.update_last_winner_name(player)
    player.gui.top['wl_map_last_winner'].caption = "Last round winner: " .. global.last_winner_name
end

function Public.add_last_winner_button(player)
    local b = player.gui.top.add({ type = 'sprite-button', caption = "", name = 'wl_map_last_winner'})
    b.style.font_color = { r = 1, g = 0.7, b = 0.1}
    b.style.minimal_height = 38
    b.style.minimal_width = 480
    b.style.top_padding = 1
    b.style.left_padding = 1
    b.style.right_padding = 1
    b.style.bottom_padding = 1

    Public.update_last_winner_name(player)
end

function Public.show(player, info_type)
    if player.gui.center['towny_map_intro_frame'] then
        player.gui.center['towny_map_intro_frame'].destroy()
    end
    local frame = player.gui.center.add {type = 'frame', name = 'towny_map_intro_frame'}
    frame = frame.add {type = 'frame', direction = 'vertical'}

    local cap = info
    if info_type == 'adv' then
        cap = info_adv
    end
    local l2 = frame.add {type = 'label', caption = cap}
    l2.style.single_line = false
    l2.style.font = 'heading-2'
    l2.style.font_color = {r = 0.8, g = 0.7, b = 0.99}
end

function Public.close(event)
    if not event.element then
        return
    end
    if not event.element.valid then
        return
    end
    local parent = event.element.parent
    for _ = 1, 4, 1 do
        if not parent then
            return
        end
        if parent.name == 'towny_map_intro_frame' then
            parent.destroy()
            return
        end
        parent = parent.parent
    end
end

function Public.toggle(event)
    if not event.element then
        return
    end
    if not event.element.valid then
        return
    end
    if event.element.name == 'wl_map_intro_button' then
        local player = game.players[event.player_index]
        if player.gui.center['towny_map_intro_frame'] then
            player.gui.center['towny_map_intro_frame'].destroy()
        else
            Public.show(player, 'adv')
        end
    end
end

local function on_gui_click(event)
    Public.close(event)
    Public.toggle(event)
end

local Event = require 'utils.event'
Event.add(defines.events.on_gui_click, on_gui_click)

return Public
