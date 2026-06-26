

local isMenuOpen  = false
local noclipOn    = false
local godmodeOn   = false
local invisibleOn = false
local spectating  = false
local noclipSpeed = 1.0

-- ─── Framework detection ──────────────────────────────────────
local Framework    = nil
local FrameworkName = 'standalone'

AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end

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
end)

-- ─── Menu open / close ────────────────────────────────────────
local function OpenMenu(permLevel)
    isMenuOpen = true
    SetNuiFocus(true, true)

    -- Build items list from shared config for NUI
    local items = {}
    for _, item in ipairs(Config.Items or {}) do
        items[#items + 1] = item
    end

    SendNUIMessage({
        action       = 'open',
        serverName   = Config.ServerName,
        framework    = FrameworkName,
        permLevel    = permLevel or 1,
        featureLevel = Config.FeatureLevel,
        items        = items,
        isSpectating = spectating,
    })
    TriggerServerEvent('admin_menu:requestPlayerList')
end

local function CloseMenu()
    isMenuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

-- ─── Key binding ──────────────────────────────────────────────
RegisterKeyMapping('admin_menu_toggle', 'Toggle Admin Menu', 'keyboard', Config.DefaultKey)

RegisterCommand('admin_menu_toggle', function()
    if isMenuOpen then
        CloseMenu()
    else
        TriggerServerEvent('admin_menu:checkAccess')
    end
end, false)

-- ─── Access response ──────────────────────────────────────────
RegisterNetEvent('admin_menu:accessGranted')
AddEventHandler('admin_menu:accessGranted', function(level)
    OpenMenu(level)
end)

RegisterNetEvent('admin_menu:accessDenied')
AddEventHandler('admin_menu:accessDenied', function()
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName('~r~No permission to access admin menu.')
    EndTextCommandThefeedPostTicker(false, true)
end)

-- ─── NUI — menu ───────────────────────────────────────────────
RegisterNUICallback('closeMenu', function(_, cb)
    CloseMenu()
    cb({})
end)

RegisterNUICallback('getPlayers', function(_, cb)
    TriggerServerEvent('admin_menu:requestPlayerList')
    cb({})
end)

-- ─── NUI — player actions ─────────────────────────────────────
RegisterNUICallback('kickPlayer', function(data, cb)
    TriggerServerEvent('admin_menu:kickPlayer', data.serverId, data.reason)
    cb({})
end)

RegisterNUICallback('banPlayer', function(data, cb)
    TriggerServerEvent('admin_menu:banPlayer', data.serverId, data.reason, data.duration)
    cb({})
end)

RegisterNUICallback('warnPlayer', function(data, cb)
    TriggerServerEvent('admin_menu:warnPlayer', data.serverId, data.reason)
    cb({})
end)

RegisterNUICallback('mutePlayer', function(data, cb)
    TriggerServerEvent('admin_menu:mutePlayer', data.serverId, data.duration, data.reason)
    cb({})
end)

RegisterNUICallback('unmutePlayer', function(data, cb)
    TriggerServerEvent('admin_menu:unmutePlayer', data.serverId)
    cb({})
end)

RegisterNUICallback('freezePlayer', function(data, cb)
    TriggerServerEvent('admin_menu:freezePlayer', data.serverId, data.freeze)
    cb({})
end)

RegisterNUICallback('healPlayer', function(data, cb)
    TriggerServerEvent('admin_menu:healPlayer', data.serverId)
    cb({})
end)

RegisterNUICallback('revivePlayer', function(data, cb)
    TriggerServerEvent('admin_menu:revivePlayer', data.serverId)
    cb({})
end)

RegisterNUICallback('bringPlayer', function(data, cb)
    TriggerServerEvent('admin_menu:bringPlayer', data.serverId)
    cb({})
end)

RegisterNUICallback('teleportToPlayer', function(data, cb)
    TriggerServerEvent('admin_menu:teleportToPlayer', data.serverId)
    cb({})
end)

RegisterNUICallback('spectatePlayer', function(data, cb)
    TriggerServerEvent('admin_menu:spectatePlayer', data.serverId)
    cb({})
end)

RegisterNUICallback('giveWeapon', function(data, cb)
    TriggerServerEvent('admin_menu:giveWeapon', data.serverId, data.weapon, data.ammo)
    cb({})
end)

RegisterNUICallback('giveMoney', function(data, cb)
    TriggerServerEvent('admin_menu:giveMoney', data.serverId, data.moneyType, data.amount)
    cb({})
end)

RegisterNUICallback('giveItems', function(data, cb)
    TriggerServerEvent('admin_menu:giveItems', data.serverId, data.item, data.count)
    cb({})
end)

RegisterNUICallback('getPlayerInfo', function(data, cb)
    TriggerServerEvent('admin_menu:requestPlayerInfo', data.serverId)
    cb({})
end)

RegisterNUICallback('unbanPlayer', function(data, cb)
    TriggerServerEvent('admin_menu:unbanPlayer', data.identifier)
    cb({})
end)

RegisterNUICallback('removeWarn', function(data, cb)
    TriggerServerEvent('admin_menu:removeWarn', data.warnId, data.identifier)
    cb({})
end)

RegisterNUICallback('getBanList', function(_, cb)
    TriggerServerEvent('admin_menu:requestBanList')
    cb({})
end)

RegisterNUICallback('getWarnList', function(_, cb)
    TriggerServerEvent('admin_menu:requestWarnList')
    cb({})
end)

-- ─── NUI — self ───────────────────────────────────────────────
RegisterNUICallback('toggleGodmode', function(data, cb)
    godmodeOn = data.state
    SetEntityInvincible(PlayerPedId(), godmodeOn)
    cb({})
end)

RegisterNUICallback('toggleNoclip', function(data, cb)
    noclipOn = data.state
    if not noclipOn then
        local ped = PlayerPedId()
        SetEntityCollision(ped, true, true)
        FreezeEntityPosition(ped, false)
        if not invisibleOn then SetEntityVisible(ped, true, false) end
    end
    cb({})
end)

RegisterNUICallback('toggleInvisible', function(data, cb)
    invisibleOn = data.state
    if not noclipOn then
        SetEntityVisible(PlayerPedId(), not invisibleOn, false)
    end
    cb({})
end)

RegisterNUICallback('healSelf', function(_, cb)
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, 100)
    cb({})
end)

RegisterNUICallback('setNoclipSpeed', function(data, cb)
    noclipSpeed = tonumber(data.speed) or 1.0
    cb({})
end)

RegisterNUICallback('stopSpectate', function(_, cb)
    spectating = false
    local ped  = PlayerPedId()
    if NetworkGetNetworkIdFromEntity(ped) ~= 0 then
        NetworkSetInSpectatorMode(false, ped)
    end
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    cb({})
end)

-- ─── NUI — vehicle ────────────────────────────────────────────
RegisterNUICallback('spawnVehicle', function(data, cb)
    local hash = GetHashKey(data.model)
    if not IsModelValid(hash) then
        cb({ success = false, msg = 'Invalid model: ' .. data.model }); return
    end

    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 150 do Wait(100); t = t + 1 end

    if not HasModelLoaded(hash) then
        cb({ success = false, msg = 'Model timed out' }); return
    end

    local ped     = PlayerPedId()
    local pos     = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    if IsPedInAnyVehicle(ped, false) then
        DeleteVehicle(GetVehiclePedIsIn(ped, false))
    end

    local veh = CreateVehicle(hash, pos.x, pos.y, pos.z + 1.0, heading, true, false)
    SetPedIntoVehicle(ped, veh, -1)
    SetVehicleOnGroundProperly(veh)
    SetModelAsNoLongerNeeded(hash)
    cb({ success = true })
end)

RegisterNUICallback('fixVehicle', function(_, cb)
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        SetVehicleFixed(veh)
        SetVehicleDeformationFixed(veh)
        SetVehicleUndriveable(veh, false)
        SetVehicleEngineOn(veh, true, true, false)
    end
    cb({})
end)

RegisterNUICallback('flipVehicle', function(_, cb)
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        SetVehicleOnGroundProperly(GetVehiclePedIsIn(ped, false))
    end
    cb({})
end)

RegisterNUICallback('maxVehicle', function(_, cb)
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        for mod = 0, 3 do
            SetVehicleMod(veh, mod, GetNumVehicleMods(veh, mod) - 1, false)
        end
        ToggleVehicleMod(veh, 18, true)
        SetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveMaxFlatVel', 500.0)
    end
    cb({})
end)

RegisterNUICallback('deleteVehicle', function(_, cb)
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        TaskLeaveVehicle(ped, veh, 0)
        Wait(800)
        DeleteVehicle(veh)
    end
    cb({})
end)

-- ─── NUI — server ─────────────────────────────────────────────
RegisterNUICallback('setWeather', function(data, cb)
    TriggerServerEvent('admin_menu:setWeather', data.weather)
    cb({})
end)

RegisterNUICallback('setTime', function(data, cb)
    TriggerServerEvent('admin_menu:setTime', data.hour, data.minute)
    cb({})
end)

RegisterNUICallback('sendAnnouncement', function(data, cb)
    TriggerServerEvent('admin_menu:sendAnnouncement', data.message)
    cb({})
end)

-- ─── NUI — teleport ───────────────────────────────────────────
RegisterNUICallback('teleportToCoords', function(data, cb)
    SetEntityCoords(PlayerPedId(), data.x, data.y, data.z, false, false, false, false)
    cb({})
end)

-- ─── Server → client events ───────────────────────────────────
RegisterNetEvent('admin_menu:receivePlayerList')
AddEventHandler('admin_menu:receivePlayerList', function(players)
    SendNUIMessage({ action = 'updatePlayers', players = players })
end)

RegisterNetEvent('admin_menu:notification')
AddEventHandler('admin_menu:notification', function(msg, ntype)
    SendNUIMessage({ action = 'notification', message = msg, type = ntype or 'info' })
end)

RegisterNetEvent('admin_menu:freezeSelf')
AddEventHandler('admin_menu:freezeSelf', function(state)
    FreezeEntityPosition(PlayerPedId(), state)
end)

RegisterNetEvent('admin_menu:healSelf')
AddEventHandler('admin_menu:healSelf', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, 100)
end)

RegisterNetEvent('admin_menu:reviveSelf')
AddEventHandler('admin_menu:reviveSelf', function()
    local ped = PlayerPedId()
    if IsEntityDead(ped) then
        NetworkResurrectLocalPlayer(GetEntityCoords(ped), GetEntityHeading(ped), true, false)
    end
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, 100)
end)

RegisterNetEvent('admin_menu:receiveWeapon')
AddEventHandler('admin_menu:receiveWeapon', function(weapon, ammo)
    GiveWeaponToPed(PlayerPedId(), GetHashKey(weapon), ammo, false, true)
end)

RegisterNetEvent('admin_menu:teleportToCoords')
AddEventHandler('admin_menu:teleportToCoords', function(coords)
    SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, false)
end)

RegisterNetEvent('admin_menu:setWeather')
AddEventHandler('admin_menu:setWeather', function(weather)
    SetWeatherTypeNow(weather)
    ClearWeatherTypePersist()
    SetWeatherTypePersist(weather)
    SetWeatherTypeNowPersist(weather)
end)

RegisterNetEvent('admin_menu:setTime')
AddEventHandler('admin_menu:setTime', function(hour, minute)
    NetworkOverrideClockTime(hour, minute, 0)
end)

-- Coordinate relay — bring player
RegisterNetEvent('admin_menu:sendAdminPos')
AddEventHandler('admin_menu:sendAdminPos', function(targetId)
    local c = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('admin_menu:receiveAdminPos', targetId, { x = c.x, y = c.y, z = c.z })
end)

-- Coordinate relay — teleport to player
RegisterNetEvent('admin_menu:sendTargetPos')
AddEventHandler('admin_menu:sendTargetPos', function(adminId)
    local c = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('admin_menu:receiveTargetPos', adminId, { x = c.x, y = c.y, z = c.z + 0.5 })
end)

-- Spectate
RegisterNetEvent('admin_menu:startSpectate')
AddEventHandler('admin_menu:startSpectate', function(targetNetId)
    if not targetNetId or targetNetId == 0 then return end
    local targetEnt = NetworkGetEntityFromNetworkId(targetNetId)
    if not targetEnt or not DoesEntityExist(targetEnt) then return end
    spectating = true
    SetEntityVisible(PlayerPedId(), false, false)
    NetworkSetInSpectatorMode(true, targetEnt)
end)

-- Player info (from server)
RegisterNetEvent('admin_menu:receivePlayerInfo')
AddEventHandler('admin_menu:receivePlayerInfo', function(info)
    SendNUIMessage({ action = 'playerInfo', info = info })
end)

-- Records
RegisterNetEvent('admin_menu:receiveBanList')
AddEventHandler('admin_menu:receiveBanList', function(bans)
    SendNUIMessage({ action = 'updateBanList', bans = bans })
end)

RegisterNetEvent('admin_menu:receiveWarnList')
AddEventHandler('admin_menu:receiveWarnList', function(warns)
    SendNUIMessage({ action = 'updateWarnList', warns = warns })
end)

-- ─── NoClip thread ────────────────────────────────────────────
CreateThread(function()
    while true do
        if noclipOn then
            Wait(0)
            local ped = PlayerPedId()

            SetEntityCollision(ped, false, false)
            SetEntityVisible(ped, false, false)
            -- FreezeEntityPosition is intentionally NOT used here —
            -- it conflicts with SetEntityCoords every frame and causes crashes.

            local rot = GetGameplayCamRot(2)
            local rz  = math.rad(rot.z)
            local spd = noclipSpeed * 0.5

            -- Horizontal-only vectors so W/S never drift vertically with camera pitch
            local fwd   = vector3(-math.sin(rz),  math.cos(rz), 0.0)
            local right = vector3( math.cos(rz),  math.sin(rz), 0.0)

            local pos = GetEntityCoords(ped)

            if IsControlPressed(0, 32) then pos = pos + fwd   * spd end  -- W
            if IsControlPressed(0, 33) then pos = pos - fwd   * spd end  -- S
            if IsControlPressed(0, 34) then pos = pos - right * spd end  -- A
            if IsControlPressed(0, 35) then pos = pos + right * spd end  -- D
            if IsControlPressed(0, 38) then pos = vector3(pos.x, pos.y, pos.z + spd) end  -- E  up
            if IsControlPressed(0, 44) then pos = vector3(pos.x, pos.y, pos.z - spd) end  -- Q  down

            SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
            SetEntityVelocity(ped, 0.0, 0.0, 0.0)  -- cancel gravity / physics drift
        else
            Wait(500)
        end
    end
end)

-- ─── God mode thread ──────────────────────────────────────────
CreateThread(function()
    while true do
        Wait(1000)
        if godmodeOn then
            local ped = PlayerPedId()
            SetEntityInvincible(ped, true)
            SetEntityHealth(ped, GetEntityMaxHealth(ped))
            SetPedArmour(ped, 100)
        end
    end
end)
