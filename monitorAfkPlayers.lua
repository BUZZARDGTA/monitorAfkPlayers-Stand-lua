-- Author: IB_U_Z_Z_A_R_Dl
-- Thanks to @someoneidfk from Stand's Discord server in #Programming channel,
-- Helped me with the "focus" code from Stand's API.


util.require_natives("1660775568-uno")

local function pluralize(word, count)
    if count > 1 then
        return word .. "s"
    else
        return word
    end
end

local function roundUp(num, decimalPlaces)
    local multiplier = 10 ^ (decimalPlaces or 0)
    return math.ceil(num * multiplier) / multiplier
end

local CURRENT_SCRIPT_VERSION <const> = "0.6"
local TITLE <const> = "Monitor AFK Players v" .. CURRENT_SCRIPT_VERSION
local MY_ROOT <const> = menu.my_root()
local STAND_PLAYERLIST_COMMANDREF <const> = menu.ref_by_command_name("playerlist")

MY_ROOT:divider("<- " ..  TITLE .. " ->")

local playerList = {}
local afkTimer = 30
local cooldownTimer = 1
local everyoneAfkAtLaunch = true
local logInToast = false
local logInConsole = false
local includeDeathEvents = true
local includeRagdollEvents = true
local ignoreInteriors = true
local has_performed_everyoneAfkAtLaunch = false
local is_any_afk_found_in_iteration = false
local is_monitor_initialized = false
local callback_playersOnLeave
local signal_stopTickHandler

local function isMenuAfkPlayerRefValid(player_id)
    if not (
        playerList[player_id]
        and playerList[player_id].playerCommandRef
    ) then
        return false
    end

    return menu.is_ref_valid(playerList[player_id].playerCommandRef)
end

local function createMenuAfkPlayerRef(player_id, formatedPlayerLastMovementTime, totalAfkTime, player_position)
    playerList[player_id].playerCommandRef = MY_ROOT:list(players.get_name_with_tags(player_id), {}, string.format(
        "Last Movement: %s"
        .. "\nTotal %s AFK: %d\n"
        .. "\nPlayer Coordinates:"
        .. "\nX: %.20f"
        .. "\nY: %.20f"
        .. "\nZ: %.20f",
        formatedPlayerLastMovementTime,
        pluralize("second", totalAfkTime),
        totalAfkTime,
        player_position.x,
        player_position.y,
        player_position.z
    ), function()
        menu.player_root(player_id):trigger()
        playerList[player_id].is_stand_player_commandRef_opened = true
    end)
end

local function deleteMenuAfkPlayerRef(player_id)
    menu.delete(playerList[player_id].playerCommandRef)
end

local function updateMenuAfkPlayerRefHelpText(player_id, formatedPlayerLastMovementTime, totalAfkTime, player_position)
    menu.set_menu_name(playerList[player_id].playerCommandRef, players.get_name_with_tags(player_id))
    menu.set_help_text(playerList[player_id].playerCommandRef, string.format(
        "Last Movement: %s"
        .. "\nTotal %s AFK: %d\n"
        .. "\nPlayer Coordinates:"
        .. "\nX: %.20f"
        .. "\nY: %.20f"
        .. "\nZ: %.20f",
        formatedPlayerLastMovementTime,
        pluralize("second", totalAfkTime),
        totalAfkTime,
        player_position.x,
        player_position.y,
        player_position.z
    ))
end

local function logAfkPlayerDetection(player_id, formatedPlayerLastMovementTime, totalAfkTime)
    if logInToast then
        util.toast(string.format(
            "[Lua Script]: %s\n"
            .. "\nPlayer %s is detected AFK!\n"
            .. "\nLast Movement: %s"
            .. "\nTotal %s AFK: %d",
            TITLE,
            playerList[player_id].name,
            formatedPlayerLastMovementTime,
            pluralize("second", totalAfkTime),
            totalAfkTime
        ))
    end

    if logInConsole then
        print(string.format(
            "[Lua Script]: %s | Player %-16s is detected AFK! | Last Movement: %s | Total %s AFK: %d",
            TITLE,
            playerList[player_id].name,
            formatedPlayerLastMovementTime,
            pluralize("second", totalAfkTime),
            totalAfkTime
        ))
    end
end

local function handle_playersOnLeave(player_id)
    if isMenuAfkPlayerRefValid(player_id) then
        deleteMenuAfkPlayerRef(player_id)
    end

    playerList[player_id] = nil
end

local function handle_tickHandler()
    if signal_stopTickHandler then
        return
    end

    for player_id, player in pairs(playerList) do
        local current_menu_commandRef = menu.get_current_menu_list()
        if
            player.is_stand_player_commandRef_opened
            and current_menu_commandRef
            and current_menu_commandRef:isValid()
            and (
                current_menu_commandRef:equals(STAND_PLAYERLIST_COMMANDREF)
                or (
                    player.playerCommandRef
                    and player.playerCommandRef:isValid()
                    and current_menu_commandRef:equals(player.playerCommandRef)
                )
            )
        then
            player.is_stand_player_commandRef_opened = false
            if isMenuAfkPlayerRefValid(player_id) then
                player.playerCommandRef:focus()
            else
                MY_ROOT:trigger()
            end
        end
    end
end

local MONITOR_AFK_PLAYERS <const> = MY_ROOT:toggle_loop("Monitor AFK Players", {}, "Checks if the player don't move for a given ammount of time.", function()
    if not is_monitor_initialized then
        is_monitor_initialized = true

        callback_playersOnLeave = players.on_leave(handle_playersOnLeave)

        signal_stopTickHandler = false
        util.create_tick_handler(handle_tickHandler)
    end

    -- This code achieves the same task as the callback version above, but with reduced efficiency.
    --for player_id, _ in pairs(playerList) do
    --    if not players.exists(player_id) then
    --        if isMenuAfkPlayerRefValid(player_id) then
    --            deleteMenuAfkPlayerRef(player_id)
    --        end
    --
    --        playerList[player_id] = nil
    --    end
    --end

    if is_any_afk_found_in_iteration then
        is_any_afk_found_in_iteration = false

        -- This is so that if the user dynamically changes 'cooldownTimer' value, it will updates in real time.
        local currentTime = 0
        while currentTime < cooldownTimer do
            util.yield(1000)
            currentTime = currentTime + 1
        end
    end

    for players.list() as player_id do
        local playerPed = PLAYER.GET_PLAYER_PED(player_id)

        if
            not players.exists(player_id)
            or not NETWORK.NETWORK_IS_PLAYER_CONNECTED(player_id)
            or not NETWORK.NETWORK_IS_PLAYER_ACTIVE(player_id)
            or NETWORK.NETWORK_IS_PLAYER_FADING(player_id)
            or NETWORK.IS_PLAYER_IN_CUTSCENE(player_id)
            or NETWORK.NETWORK_IS_PLAYER_IN_MP_CUTSCENE(player_id)
            or (
                ignoreInteriors
                and players.is_in_interior(player_id)
            )
            or playerPed == 0
        then
            if isMenuAfkPlayerRefValid(player_id) then
                deleteMenuAfkPlayerRef(player_id)
            end
            playerList[player_id] = nil

            goto CONTINUE
        end


        local player_position = players.get_position(player_id)
        local totalAfkTime = 0
        local formatedPlayerLastMovementTime = "Unknown"

        if not playerList[player_id] then
            playerList[player_id] = {
                playerCommandRef = nil,
                is_stand_player_commandRef_opened = false,
                name = players.get_name(player_id),
                found_time = os.time(),
                lastMovement_time = nil,
                isDead = false,
                hasRespawnedFromDeath_time = nil,
                isInRagdoll = false,
                hasStandUpFromRagdoll_time = nil,
                x = player_position.x,
                y = player_position.y,
                z = player_position.z
            }

            if
                everyoneAfkAtLaunch
                and not has_performed_everyoneAfkAtLaunch
            then
                createMenuAfkPlayerRef(player_id, formatedPlayerLastMovementTime, totalAfkTime, player_position)
            end

            goto CONTINUE
        end

        if includeDeathEvents then
            if PLAYER.IS_PLAYER_DEAD(player_id) then
                playerList[player_id].isDead = true
                playerList[player_id].hasRespawnedFromDeath_time = os.time()
            elseif playerList[player_id].isDead then
                if
                    PLAYER.IS_PLAYER_PLAYING(player_id)
                    and (os.time() - playerList[player_id].hasRespawnedFromDeath_time) >= 3 -- Allows an extra margin of safety, considering the game's usual 0.5-second adjustment for player positions.
                then
                    playerList[player_id].isDead = false
                    playerList[player_id].hasRespawnedFromDeath_time = nil
                end
            elseif playerList[player_id].hasRespawnedFromDeath_time then
                playerList[player_id].hasRespawnedFromDeath_time = nil
            end
        else
            playerList[player_id].isDead = false
            playerList[player_id].hasRespawnedFromDeath_time = nil
        end

        if includeRagdollEvents then
            if
                PED.IS_PED_RUNNING_RAGDOLL_TASK(playerPed)
                or PED.IS_PED_RAGDOLL(playerPed)
            then
                playerList[player_id].isInRagdoll = true
                playerList[player_id].hasStandUpFromRagdoll_time = os.clock()
            elseif playerList[player_id].isInRagdoll then
                if (os.clock() - playerList[player_id].hasStandUpFromRagdoll_time) >= 3 then -- Allows an extra margin of safety, considering the game's usual 0.3-second adjustment for player positions.
                    playerList[player_id].isInRagdoll = false
                    playerList[player_id].hasStandUpFromRagdoll_time = nil
                end
            elseif playerList[player_id].hasStandUpFromRagdoll_time then
                playerList[player_id].hasStandUpFromRagdoll_time = nil
            end
        else
            playerList[player_id].isInRagdoll = false
            playerList[player_id].hasStandUpFromRagdoll_time = nil
        end

        if
            playerList[player_id].isDead
            or playerList[player_id].hasRespawnedFromDeath_time
            or playerList[player_id].isInRagdoll
            or playerList[player_id].hasStandUpFromRagdoll_time
        then
            playerList[player_id].x = player_position.x
            playerList[player_id].y = player_position.y
            playerList[player_id].z = player_position.z

        elseif
            -- X and Y coordinates change as the player gets closer, so we round to 1 decimal place
            -- Unfortunately, it adds a false positive if the player moves EXTREMELY slighly.
            -- TODO: 'round up' only if player is far away at more then a certain distance.
            roundUp(player_position.x, 2) ~= roundUp(playerList[player_id].x, 2)
            or roundUp(player_position.y, 2) ~= roundUp(playerList[player_id].y, 2)
            or roundUp(player_position.z, 2) ~=  roundUp(playerList[player_id].z, 2)
        then
            playerList[player_id].lastMovement_time = os.time()

            if isMenuAfkPlayerRefValid(player_id) then
                deleteMenuAfkPlayerRef(player_id)
            end

            playerList[player_id].x = player_position.x
            playerList[player_id].y = player_position.y
            playerList[player_id].z = player_position.z

            goto CONTINUE
        end

        if playerList[player_id].lastMovement_time then
            totalAfkTime = os.time() - playerList[player_id].lastMovement_time
        else
            totalAfkTime = os.time() - playerList[player_id].found_time
        end

        if playerList[player_id].lastMovement_time then
            formatedPlayerLastMovementTime = os.date("%H:%M:%S", playerList[player_id].lastMovement_time)
        end

        if totalAfkTime >= afkTimer then
            is_any_afk_found_in_iteration = true
            if not isMenuAfkPlayerRefValid(player_id) then
                createMenuAfkPlayerRef(player_id, formatedPlayerLastMovementTime, totalAfkTime, player_position)
            end
            logAfkPlayerDetection(player_id, formatedPlayerLastMovementTime, totalAfkTime)
        end

        if isMenuAfkPlayerRefValid(player_id) then
            updateMenuAfkPlayerRefHelpText(player_id, formatedPlayerLastMovementTime, totalAfkTime, player_position)
        end

        :: CONTINUE ::
    end

    has_performed_everyoneAfkAtLaunch = true
end, function()
    is_monitor_initialized = false
    signal_stopTickHandler = true
    has_performed_everyoneAfkAtLaunch = false

    if callback_playersOnLeave then
        util.remove_handler(callback_playersOnLeave)
    end

    for player_id, _ in pairs(playerList) do
        if isMenuAfkPlayerRefValid(player_id) then
            deleteMenuAfkPlayerRef(player_id)
        end
    end
    playerList = {}
end)
local OPTIONS <const> = MY_ROOT:list("Options")
OPTIONS:divider("---------------------------------------")
OPTIONS:divider("Detection Options:")
OPTIONS:divider("---------------------------------------")
OPTIONS:slider("AFK Detection Timer", {"monitorAfkPlayers_afkTimer"}, "The time in second(s) after which a player will be detected as AFK if they haven't moved.", 3, 300, 30, 1, function(value)
    afkTimer = value
end)
OPTIONS:slider("Cooldown Timer", {"monitorAfkPlayers_cooldownTimer"}, "The time in second(s) before checking again for AFK players after at least one was found.", 0, 60, 1, 1, function(value)
    cooldownTimer = value
end)
OPTIONS:toggle("Everyone AFK at Launch", {}, "When enabled, sets all players as AFK when the script starts.", function(toggle)
    everyoneAfkAtLaunch = toggle
end, everyoneAfkAtLaunch)
OPTIONS:toggle("Include Death Events", {}, "When enabled, AFK detection continues even if a player's character dies.", function(toggle)
    includeDeathEvents = toggle
end, includeDeathEvents)
OPTIONS:toggle("Include Ragdoll Events", {}, "When enabled, AFK detection continues even if a player's character receives a ragdoll effect.", function(toggle)
    includeRagdollEvents = toggle
end, includeRagdollEvents)
OPTIONS:toggle("Ignore Interiors", {}, "When enabled, ignores AFK detection for players inside interiors.", function(toggle)
    ignoreInteriors = toggle
end, ignoreInteriors)
OPTIONS:divider("---------------------------------------")
OPTIONS:divider("Logging Options:")
OPTIONS:divider("---------------------------------------")
OPTIONS:toggle("Log Results in Toast Notificaitons", {}, "Logs the AFK players results in Stand's Toast Notifications.", function(toggle)
    logInToast = toggle
end, logInToast)
OPTIONS:toggle("Log Results in Console Output", {}, "Logs the AFK players results in Stand's Console Output.", function(toggle)
    logInConsole = toggle
end, logInConsole)

MY_ROOT:divider("---------------------------------------")
MY_ROOT:divider("AFK Players List:")
MY_ROOT:divider("---------------------------------------")
