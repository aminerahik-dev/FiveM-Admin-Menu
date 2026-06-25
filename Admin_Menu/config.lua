Config = {}

--[[
    FRAMEWORK
    'auto'       — auto-detect ESX / QBCore (recommended)
    'esx'        — force ESX
    'qb'         — force QBCore
    'standalone' — no framework
--]]
Config.Framework = 'auto'

--[[
    ACCESS CONTROL
    Priority: ace permission → framework group check
    To grant access via ace:
        add_ace identifier.license:XXXX admin_menu.open allow
--]]
Config.AcePermission = 'admin_menu.open'
Config.AdminGroups   = { 'admin', 'superadmin', 'mod', 'moderator' }

-- Display name in the UI header
Config.ServerName = 'My Server'

-- Max money per give transaction
Config.MaxGiveAmount = 999999

-- Announcement chat prefix
Config.AnnouncementPrefix = '[ADMIN]'

-- Key to toggle menu — F10 by default (users can rebind in FiveM key bindings)
Config.DefaultKey = 'F10'
