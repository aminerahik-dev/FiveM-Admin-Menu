

// ── State ──────────────────────────────────────────────────────
const state = {
    godmode:    false,
    noclip:     false,
    invisible:  false,
    spectating: false,
    frozen:     {},   // { [serverId]: bool }
    players:    [],
    selected:   null,
    permLevel:  1,
    bans:       [],
    warns:      [],
    items:      [],   // from config, sent on open
    activeRecord: 'bans',
};

// ── NUI bridge ─────────────────────────────────────────────────
function post(callback, data = {}) {
    const res = typeof GetParentResourceName === 'function'
        ? GetParentResourceName()
        : 'admin_menu';
    fetch(`https://${res}/${callback}`, {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify(data),
    }).catch(() => {});
}

// ── Lua → JS messages ──────────────────────────────────────────
window.addEventListener('message', ({ data }) => {
    if (!data?.action) return;

    switch (data.action) {
        case 'open':
            document.getElementById('app').classList.remove('hidden');
            if (data.serverName) document.getElementById('serverName').textContent = data.serverName;
            if (data.framework)  document.getElementById('frameworkBadge').textContent = data.framework.toUpperCase();
            if (data.permLevel)  setPermLevel(data.permLevel);
            if (data.items)      buildItemSelect(data.items);
            if (data.isSpectating) {
                state.spectating = true;
                document.getElementById('spectateBanner').classList.remove('hidden');
            }
            break;

        case 'close':
            document.getElementById('app').classList.add('hidden');
            closeModal();
            break;

        case 'updatePlayers':
            state.players = data.players || [];
            renderPlayers();
            break;

        case 'notification':
            toast(data.message, data.type || 'info');
            break;

        case 'playerInfo':
            renderPlayerInfo(data.info);
            break;

        case 'updateBanList':
            state.bans = data.bans || [];
            renderBans();
            break;

        case 'updateWarnList':
            state.warns = data.warns || [];
            renderWarns();
            break;
    }
});

// ── Permission system ──────────────────────────────────────────
const PERM_LABELS = { 1: 'MOD', 2: 'ADMIN', 3: 'SUPERADMIN' };

function setPermLevel(level) {
    state.permLevel = level;

    // Update badge
    const badge = document.getElementById('permBadge');
    badge.textContent  = PERM_LABELS[level] || 'MOD';
    badge.className    = 'perm-badge level-' + level;

    // Lock elements below their required level
    document.querySelectorAll('[data-minlevel]').forEach(el => {
        const required = parseInt(el.dataset.minlevel) || 1;
        el.classList.toggle('perm-locked', level < required);
    });
}

// ── Menu ───────────────────────────────────────────────────────
function closeMenu() { post('closeMenu'); }

// ── Tab switching ──────────────────────────────────────────────
function switchTab(name) {
    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.nav-item').forEach(b => b.classList.remove('active'));
    document.getElementById('tab-' + name).classList.add('active');
    document.querySelector(`[data-tab="${name}"]`).classList.add('active');

    if (name === 'records') loadRecords(state.activeRecord);
}

// ── Players ────────────────────────────────────────────────────
function renderPlayers() {
    const list  = document.getElementById('playerList');
    const count = document.getElementById('playerCount');
    count.textContent = state.players.length;

    if (state.players.length === 0) {
        list.innerHTML = `<div class="empty-state">
            <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                <circle cx="9" cy="7" r="4"/>
                <path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>
            </svg>
            <span>No players online</span>
        </div>`;
        return;
    }

    list.innerHTML = '';
    state.players.forEach(p => {
        const pingClass = p.ping < 80 ? 'ping-good' : p.ping < 160 ? 'ping-mid' : 'ping-bad';
        const card      = document.createElement('div');
        card.className  = 'player-card';
        card.innerHTML  = `
            <div class="player-avatar">${esc(p.name).charAt(0).toUpperCase()}</div>
            <div class="player-info">
                <div class="player-name">${esc(p.name)}</div>
                <div class="player-meta">ID: ${p.serverId} &nbsp;·&nbsp; ${esc((p.identifier || '').slice(0, 24))}</div>
            </div>
            <div class="player-tags">
                ${p.isMuted ? '<span class="muted-tag">MUTED</span>' : ''}
                <span class="ping-badge ${pingClass}">${p.ping}ms</span>
            </div>`;
        card.addEventListener('click', () => openModal(p));
        list.appendChild(card);
    });
}

function refreshPlayers() { post('getPlayers'); }

function filterPlayers() {
    const q = document.getElementById('playerSearch').value.toLowerCase();
    document.querySelectorAll('.player-card').forEach(c => {
        const name = c.querySelector('.player-name').textContent.toLowerCase();
        const meta = c.querySelector('.player-meta').textContent.toLowerCase();
        c.style.display = (name.includes(q) || meta.includes(q)) ? '' : 'none';
    });
}

// ── Player modal ───────────────────────────────────────────────
function openModal(player) {
    state.selected = player;

    document.getElementById('modalName').textContent = player.name;
    document.getElementById('modalMeta').textContent =
        `ID: ${player.serverId}  ·  ${(player.identifier || '').slice(0, 30)}`;

    // Freeze toggle label
    document.getElementById('freezeLabel').textContent =
        state.frozen[player.serverId] ? 'Unfreeze' : 'Freeze';

    // Mute toggle label
    document.getElementById('muteLabel').textContent =
        player.isMuted ? 'Unmute' : 'Mute';

    hideAllSubs();
    document.getElementById('playerInfoPanel').classList.add('hidden');
    document.getElementById('modal').classList.remove('hidden');
}

function closeModal() {
    document.getElementById('modal').classList.add('hidden');
    state.selected = null;
    hideAllSubs();
    document.getElementById('playerInfoPanel').classList.add('hidden');
}

function onModalBackdrop(e) {
    if (e.target === document.getElementById('modal')) closeModal();
}

function hideAllSubs() {
    ['subKick','subBan','subWarn','subMute','subWeapon','subItems','subMoney'].forEach(id => {
        document.getElementById(id).classList.add('hidden');
    });
}

function showSub(id) {
    hideAllSubs();
    document.getElementById(id).classList.remove('hidden');
}

// ── Player actions ─────────────────────────────────────────────
function playerAction(action) {
    const p = state.selected;
    if (!p) return;

    switch (action) {
        case 'teleport':
            post('teleportToPlayer', { serverId: p.serverId });
            toast(`Teleporting to ${p.name}…`, 'info');
            closeModal(); break;

        case 'bring':
            post('bringPlayer', { serverId: p.serverId });
            toast(`Bringing ${p.name}…`, 'info');
            closeModal(); break;

        case 'heal':
            post('healPlayer', { serverId: p.serverId });
            toast(`${p.name} healed`, 'success');
            closeModal(); break;

        case 'revive':
            post('revivePlayer', { serverId: p.serverId });
            toast(`${p.name} revived`, 'success');
            closeModal(); break;

        case 'freeze':
            state.frozen[p.serverId] = !state.frozen[p.serverId];
            post('freezePlayer', { serverId: p.serverId, freeze: state.frozen[p.serverId] });
            toast(`${p.name} ${state.frozen[p.serverId] ? 'frozen' : 'unfrozen'}`, 'info');
            closeModal(); break;

        case 'spectate':
            post('spectatePlayer', { serverId: p.serverId });
            state.spectating = true;
            toast(`Spectating ${p.name}`, 'info');
            closeModal();
            closeMenu(); break;
    }
}

function handleMute() {
    const p = state.selected;
    if (!p) return;
    if (p.isMuted) {
        post('unmutePlayer', { serverId: p.serverId });
        toast(`${p.name} unmuted`, 'info');
        closeModal();
    } else {
        showSub('subMute');
    }
}

function doKick() {
    const p = state.selected; if (!p) return;
    const reason = document.getElementById('kickReason').value.trim() || 'No reason provided';
    post('kickPlayer', { serverId: p.serverId, reason });
    toast(`${p.name} kicked`, 'warn');
    closeModal();
}

function doBan() {
    const p        = state.selected; if (!p) return;
    const reason   = document.getElementById('banReason').value.trim()     || 'No reason provided';
    const duration = parseInt(document.getElementById('banDuration').value) || 0;
    post('banPlayer', { serverId: p.serverId, reason, duration });
    toast(`${p.name} banned${duration ? ` for ${duration}h` : ' permanently'}`, 'error');
    closeModal();
}

function doWarn() {
    const p      = state.selected; if (!p) return;
    const reason = document.getElementById('warnReason').value.trim() || 'No reason provided';
    post('warnPlayer', { serverId: p.serverId, reason });
    toast(`${p.name} warned`, 'warn');
    closeModal();
}

function doMute() {
    const p        = state.selected; if (!p) return;
    const reason   = document.getElementById('muteReason').value.trim()      || 'No reason provided';
    const duration = parseInt(document.getElementById('muteDuration').value)  || 0;
    post('mutePlayer', { serverId: p.serverId, reason, duration });
    toast(`${p.name} muted${duration ? ` for ${duration}min` : ' permanently'}`, 'warn');
    closeModal();
}

function doGiveWeapon() {
    const p      = state.selected; if (!p) return;
    const weapon = document.getElementById('weaponSelect').value;
    const ammo   = parseInt(document.getElementById('weaponAmmo').value) || 250;
    post('giveWeapon', { serverId: p.serverId, weapon, ammo });
    toast(`Weapon given to ${p.name}`, 'success');
    closeModal();
}

function doGiveItems() {
    const p     = state.selected; if (!p) return;
    const item  = document.getElementById('itemSelect').value;
    const count = parseInt(document.getElementById('itemCount').value) || 1;
    if (!item) { toast('Select an item', 'error'); return; }
    post('giveItems', { serverId: p.serverId, item, count });
    toast(`${count}x ${item} given to ${p.name}`, 'success');
    closeModal();
}

function doGiveMoney() {
    const p         = state.selected; if (!p) return;
    const moneyType = document.getElementById('moneyType').value;
    const amount    = parseInt(document.getElementById('moneyAmount').value) || 0;
    if (amount <= 0) { toast('Enter a valid amount', 'error'); return; }
    post('giveMoney', { serverId: p.serverId, moneyType, amount });
    toast(`$${amount.toLocaleString()} given to ${p.name}`, 'success');
    closeModal();
}

// ── Player info ────────────────────────────────────────────────
function loadPlayerInfo() {
    const p = state.selected; if (!p) return;
    post('getPlayerInfo', { serverId: p.serverId });
    toast('Loading player info…', 'info');
}

function renderPlayerInfo(info) {
    document.getElementById('infoId').textContent     = (info.identifier || '—').slice(0, 32);
    document.getElementById('infoPing').textContent   = (info.ping || 0) + 'ms';
    document.getElementById('infoWarns').textContent  = (info.warnCount || 0) + ' active';
    document.getElementById('infoStatus').textContent = info.isMuted ? '🔇 Muted' : '✓ Active';

    const jobRow  = document.getElementById('infoJobRow');
    const cashRow = document.getElementById('infoCashRow');
    const bankRow = document.getElementById('infoBankRow');

    if (info.job !== undefined) {
        document.getElementById('infoJob').textContent = info.job;
        jobRow.style.display = '';
    } else { jobRow.style.display = 'none'; }

    if (info.cash !== undefined) {
        document.getElementById('infoCash').textContent = '$' + Number(info.cash).toLocaleString();
        cashRow.style.display = '';
    } else { cashRow.style.display = 'none'; }

    if (info.bank !== undefined) {
        document.getElementById('infoBank').textContent = '$' + Number(info.bank).toLocaleString();
        bankRow.style.display = '';
    } else { bankRow.style.display = 'none'; }

    document.getElementById('playerInfoPanel').classList.remove('hidden');
}

// ── Self ───────────────────────────────────────────────────────
function toggleGodmode() {
    state.godmode = !state.godmode;
    post('toggleGodmode', { state: state.godmode });
    setToggleUI('btnGodmode', 'badgeGodmode', state.godmode);
    toast(`God Mode ${state.godmode ? 'ON' : 'OFF'}`, 'info');
}

function toggleNoclip() {
    state.noclip = !state.noclip;
    post('toggleNoclip', { state: state.noclip });
    setToggleUI('btnNoclip', 'badgeNoclip', state.noclip);
    toast(state.noclip ? 'NoClip ON  —  WASD · E/Q for altitude' : 'NoClip OFF', 'info');
}

function toggleInvisible() {
    state.invisible = !state.invisible;
    post('toggleInvisible', { state: state.invisible });
    setToggleUI('btnInvisible', 'badgeInvisible', state.invisible);
    toast(`Invisible ${state.invisible ? 'ON' : 'OFF'}`, 'info');
}

function healSelf() {
    post('healSelf');
    toast('Healed — full HP & armor', 'success');
}

function setNoclipSpeed(val) {
    const v = parseFloat(val).toFixed(1);
    document.getElementById('noclipSpeedVal').textContent = v + '×';
    post('setNoclipSpeed', { speed: v });
}

function stopSpectate() {
    state.spectating = false;
    post('stopSpectate');
    document.getElementById('spectateBanner').classList.add('hidden');
    toast('Stopped spectating', 'info');
}

function setToggleUI(btnId, badgeId, on) {
    document.getElementById(btnId).classList.toggle('is-on', on);
    const badge = document.getElementById(badgeId);
    badge.textContent = on ? 'ON' : 'OFF';
    badge.className   = 'toggle-badge ' + (on ? 'on' : 'off');
}

// ── Vehicle ────────────────────────────────────────────────────
function spawnVehicle() {
    const model = document.getElementById('vehicleModel').value.trim();
    if (!model) { toast('Enter a vehicle model name', 'error'); return; }
    post('spawnVehicle', { model });
    toast(`Spawning ${model}…`, 'info');
}

function fixVehicle()    { post('fixVehicle');    toast('Vehicle repaired',        'success'); }
function flipVehicle()   { post('flipVehicle');   toast('Vehicle flipped upright', 'info');    }
function maxVehicle()    { post('maxVehicle');    toast('Vehicle fully upgraded',   'success'); }
function deleteVehicle() { post('deleteVehicle'); toast('Vehicle deleted',          'warn');    }

// ── Server ─────────────────────────────────────────────────────
function setWeather() {
    const w = document.getElementById('weatherSelect').value;
    post('setWeather', { weather: w });
    toast(`Weather → ${w}`, 'success');
}

function setTime() {
    const h = Math.min(23, Math.max(0, parseInt(document.getElementById('timeHour').value)   || 12));
    const m = Math.min(59, Math.max(0, parseInt(document.getElementById('timeMinute').value) || 0));
    post('setTime', { hour: h, minute: m });
    toast(`Time set to ${pad(h)}:${pad(m)}`, 'success');
}

function sendAnnouncement() {
    const msg = document.getElementById('announcementText').value.trim();
    if (!msg) { toast('Write a message first', 'error'); return; }
    post('sendAnnouncement', { message: msg });
    document.getElementById('announcementText').value = '';
    toast('Announcement sent to all players', 'success');
}

// ── Teleport ───────────────────────────────────────────────────
function teleportCoords() {
    const x = parseFloat(document.getElementById('tpX').value);
    const y = parseFloat(document.getElementById('tpY').value);
    const z = parseFloat(document.getElementById('tpZ').value);
    if (isNaN(x) || isNaN(y) || isNaN(z)) { toast('Enter valid X / Y / Z', 'error'); return; }
    post('teleportToCoords', { x, y, z });
    toast(`Teleporting to ${x.toFixed(0)}, ${y.toFixed(0)}, ${z.toFixed(0)}`, 'info');
}

function quickTP(x, y, z) {
    post('teleportToCoords', { x, y, z });
    toast('Teleporting…', 'info');
}

// ── Records ────────────────────────────────────────────────────
function loadRecords(type) {
    state.activeRecord = type;
    document.getElementById('recordSearch').value = '';

    // Toggle sub-panels
    document.getElementById('records-bans').classList.toggle('hidden',  type !== 'bans');
    document.getElementById('records-warns').classList.toggle('hidden', type !== 'warns');

    // Toggle subtab active state
    document.getElementById('subtab-bans').classList.toggle('active',  type === 'bans');
    document.getElementById('subtab-warns').classList.toggle('active', type === 'warns');

    if (type === 'bans') {
        post('getBanList');
        renderBans();
    } else {
        post('getWarnList');
        renderWarns();
    }
}

function filterRecords() {
    if (state.activeRecord === 'bans') renderBans();
    else renderWarns();
}

function renderBans() {
    const list = document.getElementById('banList');
    const q    = document.getElementById('recordSearch').value.toLowerCase();

    const filtered = state.bans.filter(b =>
        (b.name    || '').toLowerCase().includes(q) ||
        (b.reason  || '').toLowerCase().includes(q)
    );

    if (filtered.length === 0) {
        list.innerHTML = `<div class="empty-state"><svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" style="opacity:0.4"><circle cx="12" cy="12" r="10"/><line x1="4.93" y1="4.93" x2="19.07" y2="19.07"/></svg><span>No active bans</span></div>`;
        return;
    }

    list.innerHTML = '';
    filtered.forEach(ban => {
        const isPerm = ban.duration === 0 || ban.duration == null || ban.expiry === 0;
        const card   = document.createElement('div');
        card.className = 'record-card';
        card.innerHTML = `
            <div class="record-info">
                <div class="record-name">${esc(ban.name || 'Unknown')}</div>
                <div class="record-reason">${esc(ban.reason || 'No reason')}</div>
                <div class="record-meta">
                    <span class="${isPerm ? 'badge-perm' : 'badge-temp'}">${isPerm ? 'PERMANENT' : ban.duration + 'h'}</span>
                    <span class="record-by">by ${esc(ban.banned_by || ban.bannedBy || '?')}</span>
                </div>
            </div>
            ${state.permLevel >= 3
                ? `<button class="btn btn-danger btn-sm" onclick="doUnban('${esc(ban.identifier || '')}')">Unban</button>`
                : ''}`;
        list.appendChild(card);
    });
}

function renderWarns() {
    const list = document.getElementById('warnList');
    const q    = document.getElementById('recordSearch').value.toLowerCase();

    const filtered = state.warns.filter(w =>
        (w.name   || '').toLowerCase().includes(q) ||
        (w.reason || '').toLowerCase().includes(q)
    );

    if (filtered.length === 0) {
        list.innerHTML = `<div class="empty-state"><svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" style="opacity:0.4"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg><span>No active warnings</span></div>`;
        return;
    }

    list.innerHTML = '';
    filtered.forEach(warn => {
        const card = document.createElement('div');
        card.className = 'record-card';
        card.innerHTML = `
            <div class="record-info">
                <div class="record-name">${esc(warn.name || 'Unknown')}</div>
                <div class="record-reason">${esc(warn.reason || 'No reason')}</div>
                <div class="record-meta">
                    <span class="badge-warn">WARNING</span>
                    <span class="record-by">by ${esc(warn.warned_by || warn.warnedBy || '?')}</span>
                </div>
            </div>
            ${state.permLevel >= 2
                ? `<button class="btn btn-ghost btn-sm" onclick="doRemoveWarn('${esc(String(warn.id || ''))}', '${esc(warn.identifier || '')}')">Remove</button>`
                : ''}`;
        list.appendChild(card);
    });
}

function doUnban(identifier) {
    if (state.permLevel < 3) { toast('Insufficient permissions', 'error'); return; }
    post('unbanPlayer', { identifier });
    state.bans = state.bans.filter(b => b.identifier !== identifier);
    renderBans();
    toast('Player unbanned', 'success');
}

function doRemoveWarn(warnId, identifier) {
    if (state.permLevel < 2) { toast('Insufficient permissions', 'error'); return; }
    post('removeWarn', { warnId, identifier });
    state.warns = state.warns.filter(w => String(w.id) !== String(warnId));
    renderWarns();
    toast('Warning removed', 'info');
}

// ── Items select ───────────────────────────────────────────────
function buildItemSelect(items) {
    state.items = items;
    const select = document.getElementById('itemSelect');
    select.innerHTML = '';
    items.forEach(item => {
        const opt = document.createElement('option');
        opt.value       = item.name;
        opt.textContent = item.label || item.name;
        select.appendChild(opt);
    });
}

// ── Toast ──────────────────────────────────────────────────────
let toastTimer = null;

function toast(msg, type = 'info') {
    const el   = document.getElementById('toast');
    el.textContent = msg;
    el.className   = `toast ${type}`;
    el.classList.remove('hidden');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => el.classList.add('hidden'), 3200);
}

// ── Utils ──────────────────────────────────────────────────────
function esc(str) {
    const d = document.createElement('div');
    d.appendChild(document.createTextNode(str || ''));
    return d.innerHTML;
}

function pad(n) { return String(n).padStart(2, '0'); }

// ── Keyboard ───────────────────────────────────────────────────
document.addEventListener('keydown', e => {
    if (e.key !== 'Escape') return;
    if (!document.getElementById('modal').classList.contains('hidden')) {
        closeModal();
    } else {
        closeMenu();
    }
});
