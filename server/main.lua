

local Muted  = {}  -- { [identifier] = { expiry=0, reason='', by='' } }
local Frozen = {}  -- { [identifier] = bool }

-- Pending coordinate relays (security: source must match initiator)
local PendingBrings    = {}  -- [adminId] = targetId
local PendingTeleports = {}  -- [targetId] = adminId

-- ─── Startup ──────────────────────────────────────────────────
AddEventHandler('onResourceStart', function(res)
    if GetCurrentResourceName() ~= res then return end

    if Config.Framework == 'auto' or Config.Framework == 'esx' then
        if GetResourceState('es_extended') == 'started' then
            Framework    = exports['es_extended']:getSharedObject()
            FrameworkName = 'esx'
        end
    end

    if FrameworkName == 'standalone' and
       (Config.Framework == 'auto' or Config.Framework == 'qb') then
        if GetResourceState('qb-core') == 'started' then
            Framework    = exports['qb-core']:GetCoreObject()
            FrameworkName = 'qb'
        end
    end

    print(string.format('^2[admin_menu]^7 v2.0 started | Framework: ^3%s^7', FrameworkName))
end)

-- ─── Mute expiry check ────────────────────────────────────────
CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        for id, m in pairs(Muted) do
            if m.expiry > 0 and now >= m.expiry then
                Muted[id] = nil
            end
        end
    end
end)

-- ─── Helpers ──────────────────────────────────────────────────
local function GetIdentifier(src)
    return GetPlayerIdentifierByType(src, 'license')
        or GetPlayerIdentifierByType(src, 'steam')
        or GetPlayerIdentifierByType(src, 'discord')
        or tostring(src)
end

local function Notify(src, msg, ntype)
    TriggerClientEvent('admin_menu:notification', src, msg, ntype or 'info')
end

local function NotifyAdmins(msg, ntype)
    for _, pid in ipairs(GetPlayers()) do
        local id = tonumber(pid)
        if IsAdmin(id) then Notify(id, msg, ntype) end
    end
end

local function BuildPlayerList()
    local list = {}
    for _, pid in ipairs(GetPlayers()) do
        local id         = tonumber(pid)
        local identifier = GetIdentifier(id)
        list[#list + 1] = {
            serverId   = id,
            name       = GetPlayerName(id) or 'Unknown',
            ping       = GetPlayerPing(id),
            identifier = identifier,
            isMuted    = Muted[identifier] ~= nil,
        }
    end
    return list
end

-- ─── Ban check on connect ─────────────────────────────────────
AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update('[admin_menu] Checking ban status...')

    local banned, data = DB_IsBanned(GetIdentifier(src))
    if banned then
        local msg = ('Banned.\nReason: %s\nDuration: %s'):format(
            data.reason or 'N/A',
            (data.duration == 0 or data.expiry == 0) and 'Permanent'
            or (math.ceil((data.expiry - os.time()) / 3600) .. ' hour(s) remaining')
        )
        deferrals.done(msg)
    else
        deferrals.done()
    end
end)

-- ─── Mute intercept ───────────────────────────────────────────
AddEventHandler('chatMessage', function(source, _, _)
    local src        = source
    local identifier = GetIdentifier(src)
    local mute       = Muted[identifier]

    if not mute then return end

    if mute.expiry == 0 or os.time() < mute.expiry then
        CancelEvent()
        TriggerClientEvent('chat:addMessage', src, {
            color = { 220, 50, 50 },
            args  = { '[Muted]', 'You cannot chat while muted.' .. (mute.reason ~= '' and ' Reason: ' .. mute.reason or '') }
        })
    else
        Muted[identifier] = nil
    end
end)

-- ─── Access check ─────────────────────────────────────────────
RegisterNetEvent('admin_menu:checkAccess')
AddEventHandler('admin_menu:checkAccess', function()
    local src   = source
    local level = GetAdminLevel(src)
    if level > 0 then
        TriggerClientEvent('admin_menu:accessGranted', src, level)
    else
        TriggerClientEvent('admin_menu:accessDenied', src)
    end
end)

-- ─── Player list ──────────────────────────────────────────────
RegisterNetEvent('admin_menu:requestPlayerList')
AddEventHandler('admin_menu:requestPlayerList', function()
    local src = source
    if not IsAdmin(src) then return end
    TriggerClientEvent('admin_menu:receivePlayerList', src, BuildPlayerList())
end)

-- ─── Player info ──────────────────────────────────────────────
RegisterNetEvent('admin_menu:requestPlayerInfo')
AddEventHandler('admin_menu:requestPlayerInfo', function(targetId)
    local src = source
    if not HasPermission(src, 'playerInfo') then return end

    targetId = tonumber(targetId)
    if not GetPlayerName(targetId) then return end

    local identifier = GetIdentifier(targetId)
    local info = {
        serverId   = targetId,
        name       = GetPlayerName(targetId),
        identifier = identifier,
        ping       = GetPlayerPing(targetId),
        isMuted    = Muted[identifier] ~= nil,
    }

    -- Framework data
    if FrameworkName == 'esx' and Framework then
        local xPlayer = Framework.GetPlayerFromId(targetId)
        if xPlayer then
            info.job  = xPlayer.job and xPlayer.job.label or '—'
            info.cash = xPlayer.getMoney()
            info.bank = xPlayer.getAccount('bank') and xPlayer.getAccount('bank').money or 0
        end
    elseif FrameworkName == 'qb' and Framework then
        local Player = Framework.Functions.GetPlayer(targetId)
        if Player then
            info.job  = Player.PlayerData.job and Player.PlayerData.job.label or '—'
            info.cash = Player.PlayerData.money and Player.PlayerData.money.cash or 0
            info.bank = Player.PlayerData.money and Player.PlayerData.money.bank or 0
        end
    end

    -- Warn count
    DB_GetWarnings(identifier, function(warns)
        info.warnCount = #warns
        TriggerClientEvent('admin_menu:receivePlayerInfo', src, info)
    end)
end)

-- ─── Kick ─────────────────────────────────────────────────────
local function DoKick(adminSrc, targetId, reason)
    reason = reason ~= '' and reason or 'No reason provided'
    if not GetPlayerName(targetId) then
        Notify(adminSrc, 'Player not found.', 'error'); return
    end
    local tName = GetPlayerName(targetId)
    DropPlayer(targetId, ('Kicked by admin\nReason: %s'):format(reason))
    NotifyAdmins(('%s kicked %s — %s'):format(GetPlayerName(adminSrc), tName, reason), 'warn')
    ActionLog(adminSrc, 'KICK', targetId, reason)
end

RegisterNetEvent('admin_menu:kickPlayer')
AddEventHandler('admin_menu:kickPlayer', function(targetId, reason)
    local src = source
    if not HasPermission(src, 'kick') then return end
    DoKick(src, tonumber(targetId), reason or '')
end)

-- ─── Ban ──────────────────────────────────────────────────────
local function DoBan(adminSrc, targetId, reason, duration, identifier, targetName)
    reason   = reason ~= '' and reason or 'No reason provided'
    duration = tonumber(duration) or 0
    identifier = identifier or GetIdentifier(targetId)
    targetName = targetName or GetPlayerName(targetId) or 'Unknown'

    local banData = {
        identifier = identifier,
        name       = targetName,
        reason     = reason,
        duration   = duration,
        expiry     = duration == 0 and 0 or (os.time() + duration * 3600),
        bannedBy   = GetPlayerName(adminSrc) or 'SYSTEM',
        timestamp  = os.time(),
    }
    DB_SaveBan(banData)

    if GetPlayerName(targetId) then
        local dropMsg = ('Banned\nReason: %s\nDuration: %s'):format(
            reason, duration == 0 and 'Permanent' or (duration .. ' hour(s)'))
        DropPlayer(targetId, dropMsg)
    end

    local durStr = duration == 0 and 'permanently' or ('for ' .. duration .. 'h')
    if adminSrc ~= 0 then
        NotifyAdmins(('%s banned %s %s — %s'):format(GetPlayerName(adminSrc), targetName, durStr, reason), 'error')
    end
    ActionLog(adminSrc, 'BAN', targetId, reason .. ' | ' .. durStr)
end

RegisterNetEvent('admin_menu:banPlayer')
AddEventHandler('admin_menu:banPlayer', function(targetId, reason, duration)
    local src = source
    if not HasPermission(src, 'ban') then return end
    targetId = tonumber(targetId)
    if not GetPlayerName(targetId) then Notify(src, 'Player not found.', 'error'); return end
    DoBan(src, targetId, reason or '', duration or 0)
end)

-- ─── Unban ────────────────────────────────────────────────────
RegisterNetEvent('admin_menu:unbanPlayer')
AddEventHandler('admin_menu:unbanPlayer', function(identifier)
    local src = source
    if not HasPermission(src, 'unban') then Notify(src, 'Insufficient permissions.', 'error'); return end
    DB_Unban(identifier, function()
        Notify(src, 'Player unbanned.', 'success')
        ActionLog(src, 'UNBAN', nil, identifier)
    end)
end)

-- ─── Warn ─────────────────────────────────────────────────────
RegisterNetEvent('admin_menu:warnPlayer')
AddEventHandler('admin_menu:warnPlayer', function(targetId, reason)
    local src = source
    if not HasPermission(src, 'warn') then return end

    targetId = tonumber(targetId)
    if not GetPlayerName(targetId) then Notify(src, 'Player not found.', 'error'); return end

    reason = reason ~= '' and reason or 'No reason provided'
    local identifier = GetIdentifier(targetId)
    local targetName = GetPlayerName(targetId)
    local adminName  = GetPlayerName(src)

    local warnData = {
        id         = tostring(os.time()) .. tostring(math.random(100, 999)),
        identifier = identifier,
        name       = targetName,
        reason     = reason,
        warnedBy   = adminName,
        warned_by  = adminName,
        warned_at  = os.time(),
    }
    DB_SaveWarn(warnData)

    -- Notify target via chat
    TriggerClientEvent('chat:addMessage', targetId, {
        color = { 255, 140, 0 },
        args  = { '⚠️ Warning', ('You were warned by %s: %s'):format(adminName, reason) }
    })

    -- Check thresholds
    DB_GetWarnings(identifier, function(warns)
        local count   = #warns
        local action  = Config.WarnThresholds[count]

        Notify(src, ('%s warned (%d total warnings)'):format(targetName, count), 'warn')
        ActionLog(src, 'WARN', targetId, reason .. ' | warn #' .. count)

        if action == 'kick' and GetPlayerName(targetId) then
            DropPlayer(targetId, ('Auto-kicked: %d warnings accumulated.'):format(count))
            NotifyAdmins(('Auto-kicked %s — %d warnings'):format(targetName, count), 'warn')
        elseif action == 'ban' then
            DoBan(0, targetId, ('Auto-ban: %d warnings accumulated'):format(count), 0, identifier, targetName)
            NotifyAdmins(('Auto-banned %s — %d warnings'):format(targetName, count), 'error')
        end
    end)
end)

-- ─── Remove warning ───────────────────────────────────────────
RegisterNetEvent('admin_menu:removeWarn')
AddEventHandler('admin_menu:removeWarn', function(warnId, identifier)
    local src = source
    if not HasPermission(src, 'removeWarn') then return end
    DB_RemoveWarn(warnId, identifier, function()
        Notify(src, 'Warning removed.', 'success')
        ActionLog(src, 'REMOVE_WARN', nil, identifier)
    end)
end)

-- ─── Mute ─────────────────────────────────────────────────────
RegisterNetEvent('admin_menu:mutePlayer')
AddEventHandler('admin_menu:mutePlayer', function(targetId, duration, reason)
    local src = source
    if not HasPermission(src, 'mute') then return end

    targetId = tonumber(targetId)
    if not GetPlayerName(targetId) then Notify(src, 'Player not found.', 'error'); return end

    duration = tonumber(duration) or 0
    reason   = reason ~= '' and reason or 'No reason provided'
    local identifier = GetIdentifier(targetId)
    local targetName = GetPlayerName(targetId)

    Muted[identifier] = {
        expiry = duration == 0 and 0 or (os.time() + duration * 60),
        reason = reason,
        by     = GetPlayerName(src),
    }

    local durStr = duration == 0 and 'permanently' or ('for ' .. duration .. ' min')
    TriggerClientEvent('chat:addMessage', targetId, {
        color = { 220, 50, 50 },
        args  = { '[Muted]', ('You have been muted %s. Reason: %s'):format(durStr, reason) }
    })
    Notify(src, ('%s muted %s.'):format('', targetName), 'warn')
    ActionLog(src, 'MUTE', targetId, reason .. ' | ' .. durStr)
end)

-- ─── Unmute ───────────────────────────────────────────────────
RegisterNetEvent('admin_menu:unmutePlayer')
AddEventHandler('admin_menu:unmutePlayer', function(targetId)
    local src = source
    if not HasPermission(src, 'mute') then return end

    targetId = tonumber(targetId)
    if not GetPlayerName(targetId) then Notify(src, 'Player not found.', 'error'); return end

    local identifier = GetIdentifier(targetId)
    Muted[identifier] = nil

    TriggerClientEvent('chat:addMessage', targetId, {
        color = { 50, 220, 50 },
        args  = { '[Unmuted]', 'You have been unmuted.' }
    })
    Notify(src, (GetPlayerName(targetId) .. ' unmuted.'), 'success')
    ActionLog(src, 'UNMUTE', targetId, '')
end)

-- ─── Freeze ───────────────────────────────────────────────────
RegisterNetEvent('admin_menu:freezePlayer')
AddEventHandler('admin_menu:freezePlayer', function(targetId, freeze)
    local src = source
    if not HasPermission(src, 'freeze') then return end

    targetId = tonumber(targetId)
    if not GetPlayerName(targetId) then Notify(src, 'Player not found.', 'error'); return end

    TriggerClientEvent('admin_menu:freezeSelf', targetId, freeze)
    Notify(src, (GetPlayerName(targetId) .. (freeze and ' frozen.' or ' unfrozen.')), 'info')
    ActionLog(src, freeze and 'FREEZE' or 'UNFREEZE', targetId, '')
end)

-- ─── Heal ─────────────────────────────────────────────────────
RegisterNetEvent('admin_menu:healPlayer')
AddEventHandler('admin_menu:healPlayer', function(targetId)
    local src = source
    if not HasPermission(src, 'healOther') then return end

    targetId = tonumber(targetId)
    if not GetPlayerName(targetId) then Notify(src, 'Player not found.', 'error'); return end

    TriggerClientEvent('admin_menu:healSelf', targetId)
    Notify(src, (GetPlayerName(targetId) .. ' healed.'), 'success')
    ActionLog(src, 'HEAL', targetId, '')
end)

-- ─── Revive ───────────────────────────────────────────────────
RegisterNetEvent('admin_menu:revivePlayer')
AddEventHandler('admin_menu:revivePlayer', function(targetId)
    local src = source
    if not HasPermission(src, 'revive') then return end

    targetId = tonumber(targetId)
    if not GetPlayerName(targetId) then Notify(src, 'Player not found.', 'error'); return end

    TriggerClientEvent('admin_menu:reviveSelf', targetId)
    Notify(src, (GetPlayerName(targetId) .. ' revived.'), 'success')
    ActionLog(src, 'REVIVE', targetId, '')
end)

-- ─── Bring player ─────────────────────────────────────────────
RegisterNetEvent('admin_menu:bringPlayer')
AddEventHandler('admin_menu:bringPlayer', function(targetId)
    local src = source
    if not HasPermission(src, 'teleport') then return end

    targetId = tonumber(targetId)
    if not GetPlayerName(targetId) then Notify(src, 'Player not found.', 'error'); return end

    PendingBrings[src] = targetId
    TriggerClientEvent('admin_menu:sendAdminPos', src, targetId)
end)

RegisterNetEvent('admin_menu:receiveAdminPos')
AddEventHandler('admin_menu:receiveAdminPos', function(targetId, coords)
    local src = source
    if not IsAdmin(src) then return end

    targetId = tonumber(targetId)
    if PendingBrings[src] ~= targetId then return end
    PendingBrings[src] = nil

    TriggerClientEvent('admin_menu:teleportToCoords', targetId, coords)
    Notify(src, (GetPlayerName(targetId) .. ' brought to you.'), 'success')
    ActionLog(src, 'TELEPORT', targetId, 'bring')
end)

-- ─── Teleport to player ───────────────────────────────────────
RegisterNetEvent('admin_menu:teleportToPlayer')
AddEventHandler('admin_menu:teleportToPlayer', function(targetId)
    local src = source
    if not HasPermission(src, 'teleport') then return end

    targetId = tonumber(targetId)
    if not GetPlayerName(targetId) then Notify(src, 'Player not found.', 'error'); return end

    PendingTeleports[targetId] = src
    TriggerClientEvent('admin_menu:sendTargetPos', targetId, src)
end)

RegisterNetEvent('admin_menu:receiveTargetPos')
AddEventHandler('admin_menu:receiveTargetPos', function(adminId, coords)
    local src = source
    adminId = tonumber(adminId)
    if PendingTeleports[src] ~= adminId then return end
    PendingTeleports[src] = nil
    TriggerClientEvent('admin_menu:teleportToCoords', adminId, coords)
end)

-- ─── Spectate ─────────────────────────────────────────────────
RegisterNetEvent('admin_menu:spectatePlayer')
AddEventHandler('admin_menu:spectatePlayer', function(targetId)
    local src = source
    if not HasPermission(src, 'spectate') then return end

    targetId = tonumber(targetId)
    if not GetPlayerName(targetId) then Notify(src, 'Player not found.', 'error'); return end

    local targetPed = GetPlayerPed(targetId)
    local netId     = NetworkGetNetworkIdFromEntity(targetPed)

    if netId == 0 then Notify(src, 'Could not get player entity.', 'error'); return end

    TriggerClientEvent('admin_menu:startSpectate', src, netId)
    ActionLog(src, 'SPECTATE', targetId, '')
end)

-- ─── Give weapon ──────────────────────────────────────────────
RegisterNetEvent('admin_menu:giveWeapon')
AddEventHandler('admin_menu:giveWeapon', function(targetId, weapon, ammo)
    local src = source
    if not HasPermission(src, 'giveWeapon') then return end

    targetId = tonumber(targetId)
    ammo     = tonumber(ammo) or 250
    if not GetPlayerName(targetId) then Notify(src, 'Player not found.', 'error'); return end

    TriggerClientEvent('admin_menu:receiveWeapon', targetId, weapon, ammo)
    Notify(src, ('Weapon given to %s'):format(GetPlayerName(targetId)), 'success')
    ActionLog(src, 'GIVE_WEAPON', targetId, weapon .. ' x' .. ammo)
end)

-- ─── Give money ───────────────────────────────────────────────
RegisterNetEvent('admin_menu:giveMoney')
AddEventHandler('admin_menu:giveMoney', function(targetId, moneyType, amount)
    local src = source
    if not HasPermission(src, 'giveMoney') then return end

    targetId = tonumber(targetId)
    amount   = tonumber(amount) or 0

    if amount <= 0 or amount > Config.MaxGiveAmount then
        Notify(src, 'Invalid amount.', 'error'); return
    end
    if not GetPlayerName(targetId) then Notify(src, 'Player not found.', 'error'); return end

    local targetName = GetPlayerName(targetId)

    if FrameworkName == 'esx' and Framework then
        local xPlayer = Framework.GetPlayerFromId(targetId)
        if xPlayer then
            xPlayer.addMoney(amount)
            Notify(src, ('$%d given to %s'):format(amount, targetName), 'success')
            ActionLog(src, 'GIVE_MONEY', targetId, '$' .. amount .. ' (' .. (moneyType or 'cash') .. ')')
        end
    elseif FrameworkName == 'qb' and Framework then
        local Player = Framework.Functions.GetPlayer(targetId)
        if Player then
            Player.Functions.AddMoney(moneyType or 'cash', amount, 'admin-give')
            Notify(src, ('$%d given to %s'):format(amount, targetName), 'success')
            ActionLog(src, 'GIVE_MONEY', targetId, '$' .. amount .. ' (' .. (moneyType or 'cash') .. ')')
        end
    else
        Notify(src, 'Give money requires ESX or QBCore.', 'error')
    end
end)

-- ─── Give items ───────────────────────────────────────────────
RegisterNetEvent('admin_menu:giveItems')
AddEventHandler('admin_menu:giveItems', function(targetId, itemName, count)
    local src = source
    if not HasPermission(src, 'giveItems') then return end

    targetId = tonumber(targetId)
    count    = math.max(1, tonumber(count) or 1)
    if not GetPlayerName(targetId) then Notify(src, 'Player not found.', 'error'); return end

    -- Validate item is in config
    local valid = false
    for _, item in ipairs(Config.Items) do
        if item.name == itemName then valid = true; break end
    end
    if not valid then Notify(src, 'Item not in config.', 'error'); return end

    local targetName = GetPlayerName(targetId)

    if FrameworkName == 'esx' and Framework then
        local xPlayer = Framework.GetPlayerFromId(targetId)
        if xPlayer then
            xPlayer.addInventoryItem(itemName, count)
            Notify(src, ('%dx %s given to %s'):format(count, itemName, targetName), 'success')
            ActionLog(src, 'GIVE_ITEMS', targetId, count .. 'x ' .. itemName)
        end
    elseif FrameworkName == 'qb' and Framework then
        local Player = Framework.Functions.GetPlayer(targetId)
        if Player then
            Player.Functions.AddItem(itemName, count)
            TriggerClientEvent('inventory:client:ItemBox', targetId, Framework.Shared.Items[itemName], 'add', count)
            Notify(src, ('%dx %s given to %s'):format(count, itemName, targetName), 'success')
            ActionLog(src, 'GIVE_ITEMS', targetId, count .. 'x ' .. itemName)
        end
    else
        Notify(src, 'Give items requires ESX or QBCore.', 'error')
    end
end)

-- ─── Weather ──────────────────────────────────────────────────
RegisterNetEvent('admin_menu:setWeather')
AddEventHandler('admin_menu:setWeather', function(weather)
    local src = source
    if not HasPermission(src, 'weather') then return end
    TriggerClientEvent('admin_menu:setWeather', -1, weather)
    ActionLog(src, 'WEATHER', nil, weather)
end)

-- ─── Time ─────────────────────────────────────────────────────
RegisterNetEvent('admin_menu:setTime')
AddEventHandler('admin_menu:setTime', function(hour, minute)
    local src = source
    if not HasPermission(src, 'setTime') then return end
    TriggerClientEvent('admin_menu:setTime', -1, tonumber(hour), tonumber(minute) or 0)
    ActionLog(src, 'TIME', nil, ('%02d:%02d'):format(hour, minute or 0))
end)

-- ─── Announcement ─────────────────────────────────────────────
RegisterNetEvent('admin_menu:sendAnnouncement')
AddEventHandler('admin_menu:sendAnnouncement', function(message)
    local src = source
    if not HasPermission(src, 'announce') then return end
    TriggerClientEvent('chat:addMessage', -1, {
        color     = { 255, 140, 0 },
        multiline = true,
        args      = { Config.AnnouncementPrefix, message }
    })
    ActionLog(src, 'ANNOUNCE', nil, message)
end)

-- ─── Records — ban list ───────────────────────────────────────
RegisterNetEvent('admin_menu:requestBanList')
AddEventHandler('admin_menu:requestBanList', function()
    local src = source
    if not HasPermission(src, 'viewRecords') then return end
    DB_GetBans(function(bans)
        TriggerClientEvent('admin_menu:receiveBanList', src, bans)
    end)
end)

-- ─── Records — warning list ───────────────────────────────────
RegisterNetEvent('admin_menu:requestWarnList')
AddEventHandler('admin_menu:requestWarnList', function()
    local src = source
    if not HasPermission(src, 'viewRecords') then return end
    DB_GetAllWarnings(function(warns)
        TriggerClientEvent('admin_menu:receiveWarnList', src, warns)
    end)
end)

-- ─── Coordinate relay events ──────────────────────────────────
RegisterNetEvent('admin_menu:sendAdminPos')
AddEventHandler('admin_menu:sendAdminPos', function(targetId)
    -- Handled client-side, fires back receiveAdminPos
end)

RegisterNetEvent('admin_menu:sendTargetPos')
AddEventHandler('admin_menu:sendTargetPos', function(adminId)
    -- Handled client-side, fires back receiveTargetPos
end)

-- ─── Commands ─────────────────────────────────────────────────
RegisterCommand('kick', function(src, args)
    if src ~= 0 and not HasPermission(src, 'kick') then
        Notify(src, 'No permission.', 'error'); return
    end
    local id = tonumber(args[1])
    if not id then print('[admin_menu] Usage: /kick [id] [reason]'); return end
    table.remove(args, 1)
    DoKick(src, id, table.concat(args, ' '))
end, false)

RegisterCommand('ban', function(src, args)
    if src ~= 0 and not HasPermission(src, 'ban') then
        Notify(src, 'No permission.', 'error'); return
    end
    local id  = tonumber(args[1])
    local dur = tonumber(args[2]) or 0
    if not id then print('[admin_menu] Usage: /ban [id] [hours] [reason]'); return end
    table.remove(args, 1); table.remove(args, 1)
    DoBan(src, id, table.concat(args, ' '), dur)
end, false)

RegisterCommand('warn', function(src, args)
    if src ~= 0 and not HasPermission(src, 'warn') then
        Notify(src, 'No permission.', 'error'); return
    end
    local id = tonumber(args[1])
    if not id then print('[admin_menu] Usage: /warn [id] [reason]'); return end
    table.remove(args, 1)
    TriggerEvent('admin_menu:warnPlayer', id, table.concat(args, ' '))
end, false)

RegisterCommand('mute', function(src, args)
    if src ~= 0 and not HasPermission(src, 'mute') then
        Notify(src, 'No permission.', 'error'); return
    end
    local id  = tonumber(args[1])
    local dur = tonumber(args[2]) or 0
    if not id then print('[admin_menu] Usage: /mute [id] [minutes] [reason]'); return end
    table.remove(args, 1); table.remove(args, 1)
    -- Re-use event logic
    if GetPlayerName(id) then
        local identifier = GetIdentifier(id)
        Muted[identifier] = {
            expiry = dur == 0 and 0 or (os.time() + dur * 60),
            reason = table.concat(args, ' '),
            by     = GetPlayerName(src) or 'Console',
        }
        TriggerClientEvent('chat:addMessage', id, {
            color = { 220, 50, 50 },
            args  = { '[Muted]', 'You have been muted.' }
        })
        ActionLog(src, 'MUTE', id, table.concat(args, ' '))
    end
end, false)

RegisterCommand('unmute', function(src, args)
    if src ~= 0 and not HasPermission(src, 'mute') then
        Notify(src, 'No permission.', 'error'); return
    end
    local id = tonumber(args[1])
    if not id or not GetPlayerName(id) then return end
    Muted[GetIdentifier(id)] = nil
    TriggerClientEvent('chat:addMessage', id, {
        color = { 50, 220, 50 },
        args  = { '[Unmuted]', 'You have been unmuted.' }
    })
    ActionLog(src, 'UNMUTE', id, '')
end, false)

RegisterCommand('revive', function(src, args)
    if src ~= 0 and not HasPermission(src, 'revive') then
        Notify(src, 'No permission.', 'error'); return
    end
    local id = tonumber(args[1]) or src
    if GetPlayerName(id) then
        TriggerClientEvent('admin_menu:reviveSelf', id)
        ActionLog(src, 'REVIVE', id, 'command')
    end
end, false)
