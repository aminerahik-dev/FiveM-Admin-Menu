

local _db = false   -- true once oxmysql is confirmed running

-- In-memory stores (source of truth for sync checks like playerConnecting)
Bans    = {}  -- array of ban objects
Warns   = {}  -- { [identifier] = { warn, ... } }
WarnIdx = {}  -- identifiers that have at least one warn (KvP index)

-- ─── Safe KvP key ─────────────────────────────────────────────
local function SK(identifier)
    return identifier:gsub('[^%w]', '_')
end

-- ─── Startup ──────────────────────────────────────────────────
AddEventHandler('onResourceStart', function(res)
    if GetCurrentResourceName() ~= res then return end

    -- Always load KvP bans into memory first (used for sync connect checks)
    local savedBans = GetResourceKvpString('admin_menu_bans')
    if savedBans then Bans = json.decode(savedBans) or {} end

    local savedIdx = GetResourceKvpString('admin_warn_index')
    if savedIdx then
        WarnIdx = json.decode(savedIdx) or {}
        for _, id in ipairs(WarnIdx) do
            local s = GetResourceKvpString('admin_warns_' .. SK(id))
            if s then Warns[id] = json.decode(s) or {} end
        end
    end

    if not Config.Database.enabled then
        print('^3[admin_menu]^7 Database disabled — KvP mode')
        return
    end

    if GetResourceState('oxmysql') ~= 'started' then
        print('^3[admin_menu]^7 oxmysql not found — KvP mode')
        return
    end

    _db = true

    -- Create tables
    exports.oxmysql:execute(([[
        CREATE TABLE IF NOT EXISTS `%s` (
            `id`         INT AUTO_INCREMENT PRIMARY KEY,
            `identifier` VARCHAR(100) NOT NULL,
            `name`       VARCHAR(100),
            `reason`     TEXT,
            `duration`   INT     DEFAULT 0,
            `expiry`     BIGINT  DEFAULT 0,
            `banned_by`  VARCHAR(100),
            `banned_at`  BIGINT,
            `active`     TINYINT(1) DEFAULT 1,
            INDEX (`identifier`), INDEX (`active`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]]):format(Config.Database.bansTable), {})

    exports.oxmysql:execute(([[
        CREATE TABLE IF NOT EXISTS `%s` (
            `id`         INT AUTO_INCREMENT PRIMARY KEY,
            `identifier` VARCHAR(100) NOT NULL,
            `name`       VARCHAR(100),
            `reason`     TEXT,
            `warned_by`  VARCHAR(100),
            `warned_at`  BIGINT,
            `active`     TINYINT(1) DEFAULT 1,
            INDEX (`identifier`), INDEX (`active`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]]):format(Config.Database.warnsTable), {})

    exports.oxmysql:execute(([[
        CREATE TABLE IF NOT EXISTS `%s` (
            `id`               INT AUTO_INCREMENT PRIMARY KEY,
            `admin_identifier` VARCHAR(100),
            `admin_name`       VARCHAR(100),
            `action`           VARCHAR(60),
            `target_identifier` VARCHAR(100),
            `target_name`      VARCHAR(100),
            `details`          TEXT,
            `timestamp`        BIGINT,
            INDEX (`action`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]]):format(Config.Database.logsTable), {})

    -- Sync active bans from DB into memory
    exports.oxmysql:fetch(
        ('SELECT * FROM %s WHERE active = 1'):format(Config.Database.bansTable), {},
        function(rows)
            if rows and #rows > 0 then Bans = rows end
            print('^2[admin_menu]^7 Database ready — ' .. #Bans .. ' active ban(s)')
        end
    )
end)

-- ─── Utility ──────────────────────────────────────────────────
function DB_Using() return _db end

-- ─── Bans ─────────────────────────────────────────────────────
function DB_IsBanned(identifier)
    for _, b in ipairs(Bans) do
        if b.identifier == identifier then
            if b.duration == 0 or b.expiry == 0 or os.time() < b.expiry then
                return true, b
            end
        end
    end
    return false, nil
end

function DB_SaveBan(data)
    Bans[#Bans + 1] = data

    if _db then
        exports.oxmysql:execute(
            ('INSERT INTO %s (identifier, name, reason, duration, expiry, banned_by, banned_at) VALUES (?,?,?,?,?,?,?)'):format(Config.Database.bansTable),
            { data.identifier, data.name, data.reason, data.duration, data.expiry, data.bannedBy, os.time() }
        )
    else
        SetResourceKvp('admin_menu_bans', json.encode(Bans))
    end
end

function DB_GetBans(cb)
    if _db then
        exports.oxmysql:fetch(
            ('SELECT * FROM %s WHERE active = 1 ORDER BY banned_at DESC'):format(Config.Database.bansTable), {},
            function(rows) cb(rows or {}) end
        )
    else
        local active = {}
        for _, b in ipairs(Bans) do
            if b.duration == 0 or b.expiry == 0 or os.time() < b.expiry then
                active[#active + 1] = b
            end
        end
        cb(active)
    end
end

function DB_Unban(identifier, cb)
    -- Remove from memory
    local new = {}
    for _, b in ipairs(Bans) do
        if b.identifier ~= identifier then new[#new + 1] = b end
    end
    Bans = new

    if _db then
        exports.oxmysql:execute(
            ('UPDATE %s SET active = 0 WHERE identifier = ?'):format(Config.Database.bansTable),
            { identifier }, cb
        )
    else
        SetResourceKvp('admin_menu_bans', json.encode(Bans))
        if cb then cb() end
    end
end

-- ─── Warns ────────────────────────────────────────────────────
function DB_SaveWarn(data)
    -- In-memory
    if not Warns[data.identifier] then
        Warns[data.identifier] = {}
        local found = false
        for _, id in ipairs(WarnIdx) do
            if id == data.identifier then found = true; break end
        end
        if not found then
            WarnIdx[#WarnIdx + 1] = data.identifier
            SetResourceKvp('admin_warn_index', json.encode(WarnIdx))
        end
    end
    Warns[data.identifier][#Warns[data.identifier] + 1] = data

    if _db then
        exports.oxmysql:execute(
            ('INSERT INTO %s (identifier, name, reason, warned_by, warned_at) VALUES (?,?,?,?,?)'):format(Config.Database.warnsTable),
            { data.identifier, data.name, data.reason, data.warnedBy, os.time() }
        )
    else
        SetResourceKvp('admin_warns_' .. SK(data.identifier), json.encode(Warns[data.identifier]))
    end
end

function DB_GetWarnings(identifier, cb)
    if _db then
        exports.oxmysql:fetch(
            ('SELECT * FROM %s WHERE identifier = ? AND active = 1 ORDER BY warned_at DESC'):format(Config.Database.warnsTable),
            { identifier }, function(rows) cb(rows or {}) end
        )
    else
        cb(Warns[identifier] or {})
    end
end

function DB_GetAllWarnings(cb)
    if _db then
        exports.oxmysql:fetch(
            ('SELECT * FROM %s WHERE active = 1 ORDER BY warned_at DESC'):format(Config.Database.warnsTable), {},
            function(rows) cb(rows or {}) end
        )
    else
        local all = {}
        for _, warns in pairs(Warns) do
            for _, w in ipairs(warns) do all[#all + 1] = w end
        end
        table.sort(all, function(a, b) return (a.warned_at or 0) > (b.warned_at or 0) end)
        cb(all)
    end
end

function DB_RemoveWarn(warnId, identifier, cb)
    -- Update memory
    if Warns[identifier] then
        local new = {}
        for _, w in ipairs(Warns[identifier]) do
            if tostring(w.id) ~= tostring(warnId) then new[#new + 1] = w end
        end
        Warns[identifier] = new
    end

    if _db then
        exports.oxmysql:execute(
            ('UPDATE %s SET active = 0 WHERE id = ?'):format(Config.Database.warnsTable),
            { tonumber(warnId) }, cb
        )
    else
        if Warns[identifier] then
            SetResourceKvp('admin_warns_' .. SK(identifier), json.encode(Warns[identifier]))
        end
        if cb then cb() end
    end
end

-- ─── Logs ─────────────────────────────────────────────────────
function DB_Log(data)
    if _db and Config.Logging.database then
        exports.oxmysql:execute(
            ('INSERT INTO %s (admin_identifier, admin_name, action, target_identifier, target_name, details, timestamp) VALUES (?,?,?,?,?,?,?)'):format(Config.Database.logsTable),
            { data.adminId, data.adminName, data.action, data.targetId, data.targetName, data.details, os.time() }
        )
    end
end
