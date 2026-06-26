Config = {}

--[[
    FRAMEWORK
    'auto'       — auto-detect ESX / QBCore (recommended)
    'esx'        — force ESX
    'qb'         — force QBCore
    'standalone' — no framework
--]]
Config.Framework = 'auto'

-- Display name shown in the menu header
Config.ServerName       = 'My Server'
Config.AnnouncementPrefix = '[ADMIN]'
Config.DefaultKey       = 'F10'

--[[
    PERMISSION LEVELS
    3 = Superadmin  |  2 = Admin  |  1 = Mod

    Ace permission nodes (server.cfg):
        add_ace identifier.license:xxx admin_menu.superadmin allow
        add_ace identifier.license:xxx admin_menu.admin      allow
        add_ace identifier.license:xxx admin_menu.mod        allow
    
    Old 'admin_menu.open' node still works (treated as level 1).
--]]
Config.AcePermissions = {
    [3] = 'admin_menu.superadmin',
    [2] = 'admin_menu.admin',
    [1] = 'admin_menu.mod',
}

-- Framework groups that map to each level
Config.PermissionGroups = {
    [3] = { 'superadmin' },
    [2] = { 'admin' },
    [1] = { 'mod', 'moderator' },
}

-- Minimum level required per feature
Config.FeatureLevel = {
    kick        = 1,
    warn        = 1,
    mute        = 1,
    freeze      = 1,
    revive      = 1,
    spectate    = 1,
    teleport    = 1,
    noclip      = 1,
    healOther   = 1,
    playerInfo  = 1,
    ban         = 2,
    giveWeapon  = 2,
    giveMoney   = 2,
    giveItems   = 2,
    godmode     = 2,
    invisible   = 2,
    vehicle     = 2,
    weather     = 2,
    setTime     = 2,
    announce    = 2,
    viewRecords = 2,
    removeWarn  = 2,
    unban       = 3,
}

--[[
    DATABASE (optional — requires oxmysql)
    If oxmysql is not running, falls back to KvP automatically.
--]]
Config.Database = {
    enabled    = true,
    bansTable  = 'admin_bans',
    warnsTable = 'admin_warns',
    logsTable  = 'admin_logs',
}

-- Action logging
Config.Logging = {
    console  = true,   -- print to server console
    database = true,   -- save to DB (if enabled)
}

--[[
    WARN THRESHOLDS
    key = warn count, value = 'kick' | 'ban' | false (disabled)
--]]
Config.WarnThresholds = {
    [3] = 'kick',
    [5] = 'ban',
}

-- Limits
Config.MaxGiveAmount   = 999999
Config.MaxMuteDuration = 0  -- 0 = no limit (minutes)

--[[
    ITEMS — available in Give Items
    Names must match your server's inventory item names exactly.
--]]
Config.Items = {
    { name = 'water',      label = 'Water'       },
    { name = 'bread',      label = 'Bread'       },
    { name = 'bandage',    label = 'Bandage'     },
    { name = 'medikit',    label = 'Medikit'     },
    { name = 'lockpick',   label = 'Lockpick'    },
    { name = 'armor',      label = 'Body Armor'  },
    { name = 'id_card',    label = 'ID Card'     },
    { name = 'phone',      label = 'Phone'       },
    { name = 'radio',      label = 'Radio'       },
    { name = 'handcuffs',  label = 'Handcuffs'   },
}
