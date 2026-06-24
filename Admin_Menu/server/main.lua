

local Framework    = nil
local FrameworkName = 'standalone'
local Bans         = {}

-- Pending coordinate relays (security: verify correct source)
local pendingBrings    = {} -- [adminId] = targetId
local pendingTeleports = {} -- [targetId] = adminId

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

    -- Load persisted bans
    local saved = GetResourceKvpString('admin_menu_bans')
    if saved then
        Bans = json.decode(saved) or {}
    end

    print(string.format('^2[admin_menu]^7 Started | Framework: ^3%s^7 | Bans loaded: ^3%d^7',
        FrameworkName, #Bans))
end)

-- ─── Helpers ──────────────────────────────────────────────────
local function IsAdmin(src)
    if IsPlayerAceAllowed(src, Config.AcePermission) then return true end

    if FrameworkName == 'esx' then
        local xPlayer = Framework.GetPlayerFromId(src)
        if xPlayer then
            local group = xPlayer.getGroup()
            for _, g in ipairs(Config.AdminGroups) do
                if group == g then return true end
            end
        end
    elseif FrameworkName == 'qb' then
        local Player = Framework.Functions.GetPlayer(src)
        if Player then
            local perm = Player.PlayerData.permission
            for _, g in ipairs(Config.AdminGroups) do
                if perm == g then return true end
            end
        end
    end

    return false
end

local function GetIdentifier(src)
    return GetPlayerIdentifierByType(src, 'license')
        or GetPlayerIdentifierByType(src, 'steam')
        or GetPlayerIdentifierByType(src, 'discord')
        or tostring(src)
end

local function SaveBans()
    SetResourceKvp('admin_menu_bans', json.encode(Bans))
end

local function IsBanned(identifier)
    for _, b in ipairs(Bans) do
        if b.identifier == identifier then
            if b.duration == 0 or os.time() < b.expiry then
                return true, b
            end
        end
    end
    return false, nil
end

local function NotifyClient(src, msg, ntype)
    TriggerClientEvent('admin_menu:notification', src, msg, ntype or 'info')
end

local function NotifyAdmins(msg, ntype)
    for _, pid in ipairs(GetPlayers()) do
        local id = tonumber(pid)
        if IsAdmin(id) then
            NotifyClient(id, msg, ntype)
        end
    end
end

local function BuildPlayerList()
    local list = {}
    for _, pid in ipairs(GetPlayers()) do
        local id = tonumber(pid)
        list[#list + 1] = {
            serverId   = id,
            name       = GetPlayerName(id) or 'Unknown',
            ping       = GetPlayerPing(id),
            identifier = GetIdentifier(id),
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

    local banned, data = IsBanned(GetIdentifier(src))
    if banned then
        local msg = ('You are banned.\nReason: %s'):format(data.reason or 'N/A')
        if data.duration ~= 0 then
            local hours = math.ceil((data.expiry - os.time()) / 3600)
            msg = msg .. ('\nExpires in: %d hour(s)'):format(hours)
        else
            msg = msg .. '\nType: Permanent'
        end
        deferrals.done(msg)
    else
        deferrals.done()
    end
end)

-- ─── Access check ─────────────────────────────────────────────
RegisterNetEvent('admin_menu:checkAccess')
AddEventHandler('admin_menu:checkAccess', function()
    local src = source
    if IsAdmin(src) then
        TriggerClientEvent('admin_menu:accessGranted', src)
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

-- ─── Kick ─────────────────────────────────────────────────────
RegisterNetEvent('admin_menu:kickPlayer')
AddEventHandler('admin_menu:kickPlayer', function(targetId, reason)
    local src = source
    if not IsAdmin(src) then return end

    targetId = tonumber(targetId)
    reason   = reason or 'No reason provided'

    if not GetPlayerName(targetId) then
        NotifyClient(src, 'Player not found.', 'error')
        return
    end

    local targetName = GetPlayerName(targetId)
    local adminName  = GetPlayerName(src)

    DropPlayer(targetId, ('Kicked by admin\nReason: %s'):format(reason))
    NotifyAdmins(('%s kicked %s — %s'):format(adminName, targetName, reason), 'warn')
    print(string.format('^3[admin_menu]^7 %s kicked %s (%d) — %s', adminName, targetName, targetId, reason))
end)

-- ─── Ban ──────────────────────────────────────────────────────
RegisterNetEvent('admin_menu:banPlayer')
AddEventHandler('admin_menu:banPlayer', function(targetId, reason, duration)
    local src = source
    if not IsAdmin(src) then return end

    targetId = tonumber(targetId)
    reason   = reason or 'No reason provided'
    duration = tonumber(duration) or 0

    if not GetPlayerName(targetId) then
        NotifyClient(src, 'Player not found.', 'error')
        return
    end

    local targetName = GetPlayerName(targetId)
    local adminName  = GetPlayerName(src)
    local identifier = GetIdentifier(targetId)

    Bans[#Bans + 1] = {
        identifier = identifier,
        name       = targetName,
        reason     = reason,
        duration   = duration,
        expiry     = duration == 0 and 0 or (os.time() + duration * 3600),
        bannedBy   = adminName,
        timestamp  = os.time(),
    }
    SaveBans()

    local dropMsg = ('Banned\nReason: %s\nDuration: %s'):format(
        reason, duration == 0 and 'Permanent' or (duration .. ' hour(s)'))

    DropPlayer(targetId, dropMsg)

    local durStr = duration == 0 and 'permanently' or ('for ' .. duration .. 'h')
    NotifyAdmins(('%s banned %s %s — %s'):format(adminName, targetName, durStr, reason), 'error')
    print(string.format('^1[admin_menu]^7 %s banned %s (%s) — %s', adminName, targetName, identifier, reason))
end)

-- ─── Freeze ───────────────────────────────────────────────────
RegisterNetEvent('admin_menu:freezePlayer')
AddEventHandler('admin_menu:freezePlayer', function(targetId, freeze)
    local src = source
    if not IsAdmin(src) then return end

    targetId = tonumber(targetId)
    if not GetPlayerName(targetId) then
        NotifyClient(src, 'Player not found.', 'error')
        return
    end

    TriggerClientEvent('admin_menu:freezeSelf', targetId, freeze)
    NotifyClient(src, ('Player %s.'):format(freeze and 'frozen' or 'unfrozen'), 'success')
end)

-- ─── Heal ─────────────────────────────────────────────────────
RegisterNetEvent('admin_menu:healPlayer')
AddEventHandler('admin_menu:healPlayer', function(targetId)
    local src = source
    if not IsAdmin(src) then return end

    targetId = tonumber(targetId)
    if not GetPlayerName(targetId) then
        NotifyClient(src, 'Player not found.', 'error')
        return
    end

    TriggerClientEvent('admin_menu:healSelf', targetId)
    NotifyClient(src, 'Player healed.', 'success')
end)

-- ─── Bring player ─────────────────────────────────────────────
RegisterNetEvent('admin_menu:bringPlayer')
AddEventHandler('admin_menu:bringPlayer', function(targetId)
    local src = source
    if not IsAdmin(src) then return end

    targetId = tonumber(targetId)
    if not GetPlayerName(targetId) then
        NotifyClient(src, 'Player not found.', 'error')
        return
    end

    pendingBrings[src] = targetId
    TriggerClientEvent('admin_menu:sendAdminPos', src, targetId)
end)

RegisterNetEvent('admin_menu:receiveAdminPos')
AddEventHandler('admin_menu:receiveAdminPos', function(targetId, coords)
    local src = source
    if not IsAdmin(src) then return end

    targetId = tonumber(targetId)
    if pendingBrings[src] ~= targetId then return end
    pendingBrings[src] = nil

    TriggerClientEvent('admin_menu:teleportToCoords', targetId, coords)
    NotifyClient(src, 'Player brought to you.', 'success')
end)

-- ─── Teleport to player ───────────────────────────────────────
RegisterNetEvent('admin_menu:teleportToPlayer')
AddEventHandler('admin_menu:teleportToPlayer', function(targetId)
    local src = source
    if not IsAdmin(src) then return end

    targetId = tonumber(targetId)
    if not GetPlayerName(targetId) then
        NotifyClient(src, 'Player not found.', 'error')
        return
    end

    pendingTeleports[targetId] = src
    TriggerClientEvent('admin_menu:sendTargetPos', targetId, src)
end)

RegisterNetEvent('admin_menu:receiveTargetPos')
AddEventHandler('admin_menu:receiveTargetPos', function(adminId, coords)
    local src = source
    adminId = tonumber(adminId)

    if pendingTeleports[src] ~= adminId then return end
    pendingTeleports[src] = nil

    TriggerClientEvent('admin_menu:teleportToCoords', adminId, coords)
end)

-- ─── Spectate ─────────────────────────────────────────────────
RegisterNetEvent('admin_menu:spectatePlayer')
AddEventHandler('admin_menu:spectatePlayer', function(targetId)
    local src = source
    if not IsAdmin(src) then return end

    targetId = tonumber(targetId)
    if not GetPlayerName(targetId) then
        NotifyClient(src, 'Player not found.', 'error')
        return
    end

    local targetPed = GetPlayerPed(targetId)
    local netId     = NetworkGetNetworkIdFromEntity(targetPed)

    if netId == 0 then
        NotifyClient(src, 'Could not get player entity.', 'error')
        return
    end

    TriggerClientEvent('admin_menu:startSpectate', src, netId)
end)

-- ─── Give weapon ──────────────────────────────────────────────
RegisterNetEvent('admin_menu:giveWeapon')
AddEventHandler('admin_menu:giveWeapon', function(targetId, weapon, ammo)
    local src = source
    if not IsAdmin(src) then return end

    targetId = tonumber(targetId)
    ammo     = tonumber(ammo) or 250

    if not GetPlayerName(targetId) then
        NotifyClient(src, 'Player not found.', 'error')
        return
    end

    TriggerClientEvent('admin_menu:receiveWeapon', targetId, weapon, ammo)
    NotifyClient(src, 'Weapon given to ' .. GetPlayerName(targetId), 'success')
end)

-- ─── Give money ───────────────────────────────────────────────
RegisterNetEvent('admin_menu:giveMoney')
AddEventHandler('admin_menu:giveMoney', function(targetId, moneyType, amount)
    local src = source
    if not IsAdmin(src) then return end

    targetId = tonumber(targetId)
    amount   = tonumber(amount) or 0

    if amount <= 0 or amount > Config.MaxGiveAmount then
        NotifyClient(src, 'Invalid amount.', 'error')
        return
    end

    if not GetPlayerName(targetId) then
        NotifyClient(src, 'Player not found.', 'error')
        return
    end

    local targetName = GetPlayerName(targetId)

    if FrameworkName == 'esx' then
        local xPlayer = Framework.GetPlayerFromId(targetId)
        if xPlayer then
            xPlayer.addMoney(amount)
            NotifyClient(src, ('$%d given to %s'):format(amount, targetName), 'success')
        end
    elseif FrameworkName == 'qb' then
        local Player = Framework.Functions.GetPlayer(targetId)
        if Player then
            Player.Functions.AddMoney(moneyType or 'cash', amount, 'admin-give')
            NotifyClient(src, ('$%d given to %s'):format(amount, targetName), 'success')
        end
    else
        NotifyClient(src, 'Give money requires ESX or QBCore.', 'error')
    end
end)

-- ─── Weather ──────────────────────────────────────────────────
RegisterNetEvent('admin_menu:setWeather')
AddEventHandler('admin_menu:setWeather', function(weather)
    local src = source
    if not IsAdmin(src) then return end
    TriggerClientEvent('admin_menu:setWeather', -1, weather)
    print(string.format('^2[admin_menu]^7 Weather → ^3%s^7 by %s', weather, GetPlayerName(src)))
end)

-- ─── Time ─────────────────────────────────────────────────────
RegisterNetEvent('admin_menu:setTime')
AddEventHandler('admin_menu:setTime', function(hour, minute)
    local src = source
    if not IsAdmin(src) then return end
    TriggerClientEvent('admin_menu:setTime', -1, tonumber(hour), tonumber(minute) or 0)
    print(string.format('^2[admin_menu]^7 Time → ^3%02d:%02d^7 by %s', hour, minute or 0, GetPlayerName(src)))
end)

-- ─── Announcement ─────────────────────────────────────────────
RegisterNetEvent('admin_menu:sendAnnouncement')
AddEventHandler('admin_menu:sendAnnouncement', function(message)
    local src = source
    if not IsAdmin(src) then return end

    TriggerClientEvent('chat:addMessage', -1, {
        color     = { 255, 140, 0 },
        multiline = true,
        args      = { Config.AnnouncementPrefix, message }
    })

    print(string.format('^3[admin_menu]^7 Announcement by %s: %s', GetPlayerName(src), message))
end)
