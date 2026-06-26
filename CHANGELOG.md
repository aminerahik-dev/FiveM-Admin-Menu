# Changelog

All notable changes to this project will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [2.0.0] — 2026

### Added
- Server-side permission check on every net event handler — authority always server-side, no client trust
- Coordinate relay system with pending-request table and source verification to prevent position spoofing
- In-memory ban/warn mirror for synchronous checks during `playerConnecting` (async DB not viable at that hook)
- Noclip fully rewritten: smooth velocity-based movement, proper exit cleanup, no residual physics state
- Modal system rewritten: each modal rendered independently with isolated state, no shared DOM conflicts
- Player info panel now shows identifier list, current coords, active job, and cash balance (framework-aware)
- `server/logging.lua` expanded: Discord webhook payload includes admin identifier, target identifier, reason, timestamp

### Fixed
- **Black screen on modal open** — caused by a z-index conflict and a missing `display: flex` reset on the modal container; modal backdrop now renders correctly on all screen sizes
- **Noclip crash on rapid toggle** — noclip exit was not clearing `SetEntityVelocity` before disabling, leaving the player with residual velocity that triggered a fall-damage-into-ragdoll loop; fixed with a full state reset on exit
- **All players showing as Mod rank** — root cause was malformed ACE permission syntax in `server.cfg`; `add_ace` and `add_principal` lines were missing the correct spacing format that FiveM's parser requires; documented in README and `docs/server-cfg-setup.md` with verified working examples

### Changed
- `fxmanifest.lua`: `@oxmysql/lib/MySQL.lua` is now **commented out by default** — servers without oxmysql no longer get a startup error; README updated with opt-in instructions
- `server/database.lua`: database mode detection moved from `Config.Database` to runtime check — oxmysql presence detected automatically, no config entry needed
- `server/permissions.lua`: permission resolution order changed to ACE first → framework group fallback → deny; previously framework was checked before ACE on some paths
- NUI `script.js`: all fetch callbacks now use consistent error handling with `response.ok` checks before parsing JSON

### Security
- All sensitive actions (ban, kick, give money, give items, give weapons) now require server-side permission re-validation even if the NUI already gated the button — prevents crafted NUI callbacks from bypassing UI-level checks

---

## [1.0.0] — 2026

### Added
- Online player list with real-time data (ID, name, identifier, ping)
- Player actions: kick, ban, warn, mute, unmute, freeze, revive
- Give weapon, give money, give items to players
- Teleport to player / bring player to you
- Spectate system with network object validation guard
- God mode, noclip, invisible, heal self
- Vehicle spawner
- Weather and time control (server-wide)
- Server-wide announcement system
- Coordinate teleport (X, Y, Z input)
- Records tab: ban list and warning list with search
- Three-tier permission system: `mod`, `admin`, `superadmin` via ACE nodes
- Backward compatibility with legacy `admin_menu.open` ACE node
- oxmysql database layer with automatic KvP fallback
- Warn thresholds: configurable auto-kick and auto-ban
- Action logging with optional Discord webhook
- Modular server architecture: `database.lua`, `permissions.lua`, `logging.lua`, `main.lua`
- Chat commands: `/kick`, `/ban`, `/warn`, `/mute`, `/unmute`, `/revive`
- Framework auto-detection: ESX, QBCore, Standalone
- Dark professional NUI theme, transparent background

### Fixed
- Console warning from unguarded `NetworkGetEntityFromNetworkId` on zero netIds
- `NetworkSetInSpectatorMode` crash caused by missing network object validation

---

## [Unreleased]

> Planned for upcoming versions.

- Per-player session notes
- Admin activity log viewer in UI
- Configurable UI accent color
- `/goto [coords]` command shorthand
- Bulk ban import / export
- Temp ban with expiry timestamp and auto-unban on connect