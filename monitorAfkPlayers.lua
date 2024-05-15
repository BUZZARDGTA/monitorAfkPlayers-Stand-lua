-- Author: IB_U_Z_Z_A_R_Dl

util.require_natives("1660775568-uno")

function pluralize(word, count)
    if count > 1 then
        return word .. "s"
    else
        return word
    end
end

local CURRENT_SCRIPT_VERSION <const> = "0.5.1"
local TITLE <const> = "Monitor AFK Players v" .. CURRENT_SCRIPT_VERSION

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
local ignoreInteriors = true
local is_any_afk_found_in_iteration = false

local function isMenuAfkPlayerRefValid(pedPid)
    if not playerList[pedPid] then
        return false
    end

    return menu.is_ref_valid(menu.ref_by_rel_path(MY_ROOT, playerList[pedPid].name))
end

local function deleteMenuAfkPlayerRef(pedPid)
    menu.delete(menu.ref_by_rel_path(MY_ROOT, playerList[pedPid].name))
end

local function updateMenuAfkPlayerRefHelpText(pedPid, pedPos, totalAfkTime)
    menu.set_help_text(menu.ref_by_rel_path(MY_ROOT, playerList[pedPid].name),
        "Last Movement: " .. os.date("%H:%M:%S", playerList[pedPid].lastMovement_time) .. " | Total " .. pluralize("second", totalAfkTime) .. " AFK: " .. totalAfkTime
        .. "\n\nPlayer Coordinates:\nX: " .. pedPos.x .. "\nY: " .. pedPos.y .. "\nZ: " .. pedPos.z
    )
end

local function logAfkPlayerDetection(pedPid, pedPos, totalAfkTime, hideNotifications)
    hideNotifications = hideNotifications or false

    if isMenuAfkPlayerRefValid(pedPid) then
        updateMenuAfkPlayerRefHelpText(pedPid, pedPos, totalAfkTime)
    else
        MY_ROOT:list(playerList[pedPid].name, {},
            "Last Movement: " .. os.date("%H:%M:%S", playerList[pedPid].lastMovement_time) .. " | Total " .. pluralize("second", totalAfkTime) .. " AFK: " .. totalAfkTime
            .. "\n\nPlayer Coordinates:\nX: " .. pedPos.x .. "\nY: " .. pedPos.y .. "\nZ: " .. pedPos.z
        , function()
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
            .. "\nLast Movement: " .. os.date("%H:%M:%S", playerList[pedPid].lastMovement_time)
            .. "\nTotal Time AFK: " .. totalAfkTime .. pluralize(" second", totalAfkTime)
        )
    end

    if logInConsole then
        local paddedPlayerName = string.format("%-16s", playerList[pedPid].name)
        print("[Lua Script]: " .. TITLE .. " | Player " .. paddedPlayerName .. " is detected AFK! | Last Movement: " .. os.date("%H:%M:%S", playerList[pedPid].lastMovement_time) ..  " | Total " .. pluralize("second", totalAfkTime) ..  " AFK: " .. totalAfkTime)
        util.yield()
    end
end

MY_ROOT:toggle_loop("Monitor AFK Players", {}, "Checks if the player don't move for a given ammount of time.", function()
    players.on_leave(function(pedPid)
        if isMenuAfkPlayerRefValid(pedPid) then
            deleteMenuAfkPlayerRef(pedPid)
        end
        playerList[pedPid] = nil
    end)

    if is_any_afk_found_in_iteration then
        is_any_afk_found_in_iteration = false

        -- This is so that if the user dynamically changes 'cooldownTimer' value, it will updates in real time.
        local currentTime = 0
        while currentTime < cooldownTimer do
            util.yield(1000)
            currentTime = currentTime + 1
        end
    end

    for players.list() as pedPid do
        if
            not NETWORK.NETWORK_IS_PLAYER_CONNECTED(pedPid)
            or not NETWORK.NETWORK_IS_PLAYER_ACTIVE(pedPid)
            or NETWORK.NETWORK_IS_PLAYER_FADING(pedPid)
            or NETWORK.IS_PLAYER_IN_CUTSCENE(pedPid)
            or NETWORK.NETWORK_IS_PLAYER_IN_MP_CUTSCENE(pedPid)
        then
            goto CONTINUE
        end

        if
            ignoreInteriors
            and players.is_in_interior(pedPid)
        then
            if isMenuAfkPlayerRefValid(pedPid) then
                deleteMenuAfkPlayerRef(pedPid)
            end
            playerList[pedPid] = nil
            goto CONTINUE
        end


        local pPed = PLAYER.GET_PLAYER_PED(pedPid)
        if pPed == 0 then
            goto CONTINUE
        end

        local pedPos = ENTITY.GET_ENTITY_COORDS(pPed, true)

        if not playerList[pedPid] then
            playerList[pedPid] = {
                name = players.get_name(pedPid),
                lastMovement_time = os.time(),
                isDead = false,
                hasRespawnedFromDeath_time = nil,
                isInRagdoll = false,
                hasStandUpFromRagdoll_time = nil,
                x = pedPos.x,
                y = pedPos.y,
                z = pedPos.z
            }

            if everyoneAfkAtLaunch then
                logAfkPlayerDetection(pedPid, pedPos, 0, true)
            end

            goto CONTINUE
        end

        if includeDeathEvents then
            if PLAYER.IS_PLAYER_DEAD(pedPid) then
                playerList[pedPid].isDead = true
                playerList[pedPid].hasRespawnedFromDeath_time = os.time()
            elseif playerList[pedPid].isDead then
                if
                    PLAYER.IS_PLAYER_PLAYING(pedPid)
                    and (os.time() - playerList[pedPid].hasRespawnedFromDeath_time) >= 3 -- Allows an extra margin of safety, considering the game's usual 0.5-second adjustment for player positions.
                then
                    playerList[pedPid].isDead = false
                    playerList[pedPid].hasRespawnedFromDeath_time = nil
                end
            elseif playerList[pedPid].hasRespawnedFromDeath_time then
                playerList[pedPid].hasRespawnedFromDeath_time = nil
            end
        else
            playerList[pedPid].isDead = false
            playerList[pedPid].hasRespawnedFromDeath_time = nil
        end

        if includeRagdollEvents then
            if
                PED.IS_PED_RUNNING_RAGDOLL_TASK(pPed)
                or PED.IS_PED_RAGDOLL(pPed)
            then
                playerList[pedPid].isInRagdoll = true
                playerList[pedPid].hasStandUpFromRagdoll_time = os.clock()
            elseif playerList[pedPid].isInRagdoll then
                if (os.clock() - playerList[pedPid].hasStandUpFromRagdoll_time) >= 3 then -- Allows an extra margin of safety, considering the game's usual 0.3-second adjustment for player positions.
                    playerList[pedPid].isInRagdoll = false
                    playerList[pedPid].hasStandUpFromRagdoll_time = nil
                end
            elseif playerList[pedPid].hasStandUpFromRagdoll_time then
                playerList[pedPid].hasStandUpFromRagdoll_time = nil
            end
        else
            playerList[pedPid].isInRagdoll = false
            playerList[pedPid].hasStandUpFromRagdoll_time = nil
        end

        if
            playerList[pedPid].isDead
            or playerList[pedPid].hasRespawnedFromDeath_time
            or playerList[pedPid].isInRagdoll
            or playerList[pedPid].hasStandUpFromRagdoll_time
        then
            playerList[pedPid].x = pedPos.x
            playerList[pedPid].y = pedPos.y
            playerList[pedPid].z = pedPos.z

        elseif
            pedPos.x ~= playerList[pedPid].x
            or pedPos.y ~= playerList[pedPid].y
            or pedPos.z ~= playerList[pedPid].z
        then
            playerList[pedPid].lastMovement_time = os.time()

            if isMenuAfkPlayerRefValid(pedPid) then
                deleteMenuAfkPlayerRef(pedPid)
            end

            playerList[pedPid].x = pedPos.x
            playerList[pedPid].y = pedPos.y
            playerList[pedPid].z = pedPos.z

            goto CONTINUE
        end

        local totalAfkTime = os.time() - playerList[pedPid].lastMovement_time
        if totalAfkTime >= afkTimer then
            is_any_afk_found_in_iteration = true
            logAfkPlayerDetection(pedPid, pedPos, totalAfkTime)
        elseif isMenuAfkPlayerRefValid(pedPid) then
            updateMenuAfkPlayerRefHelpText(pedPid, pedPos, totalAfkTime)
        end

        :: CONTINUE ::
    end
end, function()
    for pedPid, _ in pairs(playerList) do
        if isMenuAfkPlayerRefValid(pedPid) then
            deleteMenuAfkPlayerRef(pedPid)
        end
        playerList[pedPid] = nil
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
