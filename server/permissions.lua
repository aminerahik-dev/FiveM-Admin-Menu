

-- Framework reference (populated in main.lua onResourceStart)
Framework    = nil
FrameworkName = 'standalone'

-- ─── Get admin permission level (0 = no access) ───────────────
function GetAdminLevel(source)
    -- Ace permissions take priority
    for level = 3, 1, -1 do
        if IsPlayerAceAllowed(source, Config.AcePermissions[level]) then
            return level
        end
    end

    -- Backward compat: old 'admin_menu.open' node = level 1
    if IsPlayerAceAllowed(source, 'admin_menu.open') then return 1 end

    -- Framework group fallback
    if FrameworkName == 'esx' and Framework then
        local xPlayer = Framework.GetPlayerFromId(source)
        if xPlayer then
            local group = xPlayer.getGroup()
            for level = 3, 1, -1 do
                for _, g in ipairs(Config.PermissionGroups[level] or {}) do
                    if group == g then return level end
                end
            end
        end
    elseif FrameworkName == 'qb' and Framework then
        local Player = Framework.Functions.GetPlayer(source)
        if Player then
            local perm = Player.PlayerData.permission
            for level = 3, 1, -1 do
                for _, g in ipairs(Config.PermissionGroups[level] or {}) do
                    if perm == g then return level end
                end
            end
        end
    end

    return 0
end

-- ─── Check if a source has access to a specific feature ───────
function HasPermission(source, feature)
    local required = Config.FeatureLevel[feature] or 3
    return GetAdminLevel(source) >= required
end

-- ─── Simple admin check (any level > 0) ───────────────────────
function IsAdmin(source)
    return GetAdminLevel(source) > 0
end
