## server.cfg — Permission Setup Reference

Copy the relevant sections into your server.cfg.

---

### 1. Ensure the resource

```cfg
ensure fivem-admin-menu
```

> Place this after your framework resource (es_extended / qb-core).

---

### 2. Define permission nodes

```cfg
# ── Admin Menu Permissions ──────────────────────────────────────────

# Mod — basic moderation
add_ace group.mod  admin_menu.mod  allow

# Admin — full player management
add_ace group.admin  admin_menu.admin  allow

# Superadmin — unrestricted access + records management
add_ace group.superadmin  admin_menu.superadmin  allow

# Superadmins inherit admin and mod automatically
add_principal group.admin      group.mod
add_principal group.superadmin group.admin
```

---

### 3. Assign players to groups

```cfg
# Replace with actual identifiers

# By Rockstar license
add_principal identifier.license:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  group.superadmin

# By Steam hex
add_principal identifier.steam:110000XXXXXXXXXXXXXXXXX  group.admin

# By FiveM account
add_principal identifier.fivem:XXXXXXXX  group.mod
```

---

### How to find your identifier

In-game, open F8 and type:

```
status
```

Your identifiers appear in the player list. Copy the one starting with `license:`.

Alternatively, on the server console:

```
clientkick 0 test
```

The server will print the player's identifiers in the kick log.

---

### Verify ACE is active (server console)

```
test_ace [player_id] admin_menu.admin
```

Returns `true` if the permission is correctly applied.