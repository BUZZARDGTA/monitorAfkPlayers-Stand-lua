-- Author: IB_U_Z_Z_A_R_Dl

util.require_natives("1660775568-uno")

function pluralize(word, count)
    if count > 1 then
        return word .. "s"
    else
        return word
    end
end

local CURRENT_SCRIPT_VERSION <const> = "0.3"
local TITLE <const> = "Monitor AFK players v" .. CURRENT_SCRIPT_VERSION

local MY_ROOT <const> = menu.my_root()

MY_ROOT:divider("<- " ..  TITLE .. " ->")

local playerList = {}
local afkTimer = 30
local cooldownTimer = 1
local everyoneAfkAtLaunch = true
local logInToast = false
local logInConsole = false
local includeDeathEvents = true
local includeRagdollEvents = true
local is_any_afk_found_in_iteration = false

local function isMenuRefValid(pedPid)
    return menu.is_ref_valid(menu.ref_by_rel_path(MY_ROOT, playerList[pedPid].name))
end

local function updateAfkPlayerHelpText(pedPid, totalAfkTime)
    menu.set_help_text(menu.ref_by_rel_path(MY_ROOT, playerList[pedPid].name), "Last Movement: " .. os.date("%H:%M:%S", playerList[pedPid].lastMovementTime) ..  " | Total " .. pluralize("second", totalAfkTime) ..  " AFK: " .. totalAfkTime)
end

local function logAfkPlayerDetection(pedPid, totalAfkTime, hideNotifications)
    hideNotifications = hideNotifications or false

    if isMenuRefValid(pedPid) then
        updateAfkPlayerHelpText(pedPid, totalAfkTime)
    else
        MY_ROOT:list(playerList[pedPid].name, {}, "Last Movement: " .. os.date("%H:%M:%S", playerList[pedPid].lastMovementTime) ..  " | Total " .. pluralize("second", totalAfkTime) ..  " AFK: " .. totalAfkTime, function()
            menu.player_root(pedPid):trigger()
        end)
    end

    if hideNotifications then
        return
    end

    if logInToast then
        util.toast(
            "[Lua Script]: " .. TITLE .. "\n"
            .. "\nPlayer " .. playerList[pedPid].name .. " is detected AFK!\n"
            .. "\nLast Movement: " .. os.date("%H:%M:%S", playerList[pedPid].lastMovementTime)
            .. "\nTotal Time AFK: " .. totalAfkTime .. pluralize(" second", totalAfkTime)
        )
    end

    if logInConsole then
        local paddedPlayerName = string.format("%-16s", playerList[pedPid].name)
        print("[Lua Script]: " .. TITLE .. " | Player " .. paddedPlayerName .. " is detected AFK! | Last Movement: " .. os.date("%H:%M:%S", playerList[pedPid].lastMovementTime) ..  " | Total " .. pluralize("second", totalAfkTime) ..  " AFK: " .. totalAfkTime)
        util.yield()
    end
end

MY_ROOT:toggle_loop("Monitor AFK Players", {}, "Checks if the player don't move for a given ammount of time.", function()
    util.yield() -- No need to spam it.
    print(PLAYER.IS_PLAYER_PLAYING(players.user()))

    if not util.is_session_started() then
        playerList = {}
    end

    if is_any_afk_found_in_iteration then
        is_any_afk_found_in_iteration = false

        -- This is so that if the user dynamically changes 'cooldownTimer' value, it will updates in real time.
        local currentTime = 0
        while currentTime < cooldownTimer do
            util.yield(1000) -- Sleep for 1 second
            currentTime = currentTime + 1 -- Increment current time by 1 second
        end
    end

    for players.list() as pedPid do
        local pPed = PLAYER.GET_PLAYER_PED(pedPid)
        if pPed == 0 then
            goto CONTINUE
        end

        local pedPos = ENTITY.GET_ENTITY_COORDS(pPed, true)

        if not playerList[pedPid] then
            playerList[pedPid] = {
                name = players.get_name(pedPid),
                lastMovementTime = os.time(),
                isDead = false,
                hasRespawnedFromDeath = false,
                isInRagdoll = false,
                hasStandUpFromRagdoll = false,
                x = pedPos.x,
                y = pedPos.y,
                z = pedPos.z
            }

            if everyoneAfkAtLaunch then
                logAfkPlayerDetection(pedPid, 0, true)
            end

            goto CONTINUE
        end

        if includeDeathEvents then
            if PLAYER.IS_PLAYER_DEAD(pedPid) then
                playerList[pedPid].isDead = true
                playerList[pedPid].hasRespawnedFromDeath = false
            elseif playerList[pedPid].isDead then
                playerList[pedPid].isDead = false
                playerList[pedPid].hasRespawnedFromDeath = PLAYER.IS_PLAYER_PLAYING(pedPid)
            elseif playerList[pedPid].hasRespawnedFromDeath then
                playerList[pedPid].hasRespawnedFromDeath = false
            end
        else
            playerList[pedPid].isDead = false
            playerList[pedPid].hasRespawnedFromDeath = false
        end

        if includeRagdollEvents then
            if
                PED.IS_PED_RUNNING_RAGDOLL_TASK(pPed)
                or PED.IS_PED_RAGDOLL(pPed)
            then
                playerList[pedPid].isInRagdoll = true
            elseif playerList[pedPid].isInRagdoll then
                playerList[pedPid].isInRagdoll = false
            end
        else
            playerList[pedPid].isInRagdoll = false
        end

        if
            playerList[pedPid].isDead
            or playerList[pedPid].hasRespawnedFromDeath
            or playerList[pedPid].isInRagdoll
        then
            playerList[pedPid].x = pedPos.x
            playerList[pedPid].y = pedPos.y
            playerList[pedPid].z = pedPos.z
        elseif
            pedPos.x ~= playerList[pedPid].x
            or pedPos.y ~= playerList[pedPid].y
            or pedPos.z ~= playerList[pedPid].z
        then
            playerList[pedPid].lastMovementTime = os.time()

            if menu.is_ref_valid(menu.ref_by_rel_path(MY_ROOT, playerList[pedPid].name)) then
                menu.delete(menu.ref_by_rel_path(MY_ROOT, playerList[pedPid].name))
            end

            playerList[pedPid].x = pedPos.x
            playerList[pedPid].y = pedPos.y
            playerList[pedPid].z = pedPos.z

            goto CONTINUE
        end

        local totalAfkTime = os.time() - playerList[pedPid].lastMovementTime
        if totalAfkTime >= afkTimer then
            is_any_afk_found_in_iteration = true
            logAfkPlayerDetection(pedPid, totalAfkTime)
        elseif isMenuRefValid(pedPid) then
            updateAfkPlayerHelpText(pedPid, totalAfkTime)
        end

        :: CONTINUE ::
    end
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
OPTIONS:toggle("Everyone AFK at launch", {}, "When enabled, sets all players as AFK when the script starts.", function(toggle)
    everyoneAfkAtLaunch = toggle
end, everyoneAfkAtLaunch)
OPTIONS:toggle("Include death events", {}, "When enabled, AFK detection continues even if a player's character dies.", function(toggle)
    includeDeathEvents = toggle
end, includeDeathEvents)
OPTIONS:toggle("Include ragdoll events", {}, "When enabled, AFK detection continues even if a player's character receives a ragdoll effect.", function(toggle)
    includeRagdollEvents = toggle
end, includeRagdollEvents)
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
