

local COLORS = {
    KICK       = '^1',
    BAN        = '^1',
    UNBAN      = '^2',
    WARN       = '^3',
    MUTE       = '^3',
    UNMUTE     = '^2',
    REVIVE     = '^2',
    FREEZE     = '^5',
    UNFREEZE   = '^5',
    TELEPORT   = '^5',
    SPECTATE   = '^5',
    GIVE_MONEY  = '^2',
    GIVE_WEAPON = '^2',
    GIVE_ITEMS  = '^2',
    HEAL        = '^2',
    ANNOUNCE    = '^3',
    WEATHER     = '^5',
    TIME        = '^5',
}

--[[
    ActionLog(adminSrc, action, targetSrc, details)
    targetSrc = nil for server-wide actions (announce, weather, etc.)
--]]
function ActionLog(adminSrc, action, targetSrc, details)
    local adminName = GetPlayerName(adminSrc) or 'Console'
    local adminId   = adminSrc ~= 0 and GetPlayerIdentifierByType(adminSrc, 'license') or 'console'
    local targetName, targetId = '', ''

    if targetSrc then
        targetName = GetPlayerName(targetSrc) or 'Unknown'
        targetId   = GetPlayerIdentifierByType(targetSrc, 'license') or tostring(targetSrc)
    end

    -- Console output
    if Config.Logging.console then
        local color  = COLORS[action] or '^7'
        local target = targetSrc and (' → ' .. targetName .. ' [' .. targetSrc .. ']') or ''
        local det    = details and (' — ' .. details) or ''
        print(('%s[admin_menu]^7 [%s] %s%s%s'):format(color, action, adminName, target, det))
    end

    -- Database
    DB_Log({
        adminId    = adminId,
        adminName  = adminName,
        action     = action,
        targetId   = targetId,
        targetName = targetName,
        details    = details or '',
    })
end
