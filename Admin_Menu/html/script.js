

// ── State ──────────────────────────────────────────────────────
const state = {
    godmode:    false,
    noclip:     false,
    invisible:  false,
    spectating: false,
    frozen:     {},      // { [serverId]: boolean }
    players:    [],
    selected:   null,
};

// ── NUI bridge ─────────────────────────────────────────────────
function post(callback, data = {}) {
    const resource = typeof GetParentResourceName === 'function'
        ? GetParentResourceName()
        : 'admin_menu';

    fetch(`https://${resource}/${callback}`, {
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
            if (data.serverName) {
                document.getElementById('serverName').textContent = data.serverName;
            }
            if (data.framework) {
                document.getElementById('frameworkBadge').textContent = data.framework.toUpperCase();
            }
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
    }
});

// ── Menu ───────────────────────────────────────────────────────
function closeMenu() {
    post('closeMenu');
}

// ── Tab switching ──────────────────────────────────────────────
function switchTab(name) {
    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.nav-item').forEach(b => b.classList.remove('active'));
    document.getElementById('tab-' + name).classList.add('active');
    document.querySelector(`[data-tab="${name}"]`).classList.add('active');
}

// ── Players — render ───────────────────────────────────────────
function renderPlayers() {
    const list  = document.getElementById('playerList');
    const count = document.getElementById('playerCount');

    count.textContent = state.players.length;

    if (state.players.length === 0) {
        list.innerHTML = `
            <div class="empty-state">
                <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                    <circle cx="9" cy="7" r="4"/>
                    <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
                    <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
                </svg>
                <span>No players online</span>
            </div>`;
        return;
    }

    list.innerHTML = '';
    state.players.forEach(p => {
        const card = document.createElement('div');
        card.className = 'player-card';

        const pingClass = p.ping < 80 ? 'ping-good' : p.ping < 160 ? 'ping-mid' : 'ping-bad';
        const initial   = (p.name || '?').charAt(0).toUpperCase();
        const shortId   = (p.identifier || '').slice(0, 22);

        card.innerHTML = `
            <div class="player-avatar">${initial}</div>
            <div class="player-info">
                <div class="player-name">${esc(p.name)}</div>
                <div class="player-meta">ID: ${p.serverId} &nbsp;·&nbsp; ${esc(shortId)}</div>
            </div>
            <span class="ping-badge ${pingClass}">${p.ping}ms</span>`;

        card.addEventListener('click', () => openModal(p));
        list.appendChild(card);
    });
}

function refreshPlayers() {
    post('getPlayers');
}

function filterPlayers() {
    const q     = document.getElementById('playerSearch').value.toLowerCase();
    const cards = document.querySelectorAll('.player-card');
    cards.forEach(c => {
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
        `ID: ${player.serverId}  ·  ${(player.identifier || '').slice(0, 28)}`;

    const frozen = !!state.frozen[player.serverId];
    document.getElementById('freezeLabel').textContent = frozen ? 'Unfreeze' : 'Freeze';

    hideAllSubs();
    document.getElementById('modal').classList.remove('hidden');
}

function closeModal() {
    document.getElementById('modal').classList.add('hidden');
    state.selected = null;
    hideAllSubs();
}

function onModalBackdrop(e) {
    if (e.target === document.getElementById('modal')) closeModal();
}

function hideAllSubs() {
    ['subKick', 'subBan', 'subWeapon', 'subMoney'].forEach(id => {
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
            closeModal();
            break;

        case 'bring':
            post('bringPlayer', { serverId: p.serverId });
            toast(`Bringing ${p.name} to you…`, 'info');
            closeModal();
            break;

        case 'heal':
            post('healPlayer', { serverId: p.serverId });
            toast(`${p.name} healed`, 'success');
            closeModal();
            break;

        case 'freeze':
            state.frozen[p.serverId] = !state.frozen[p.serverId];
            post('freezePlayer', { serverId: p.serverId, freeze: state.frozen[p.serverId] });
            toast(`${p.name} ${state.frozen[p.serverId] ? 'frozen' : 'unfrozen'}`, 'info');
            closeModal();
            break;

        case 'spectate':
            post('spectatePlayer', { serverId: p.serverId });
            state.spectating = true;
            toast(`Spectating ${p.name}`, 'info');
            closeModal();
            closeMenu();
            break;
    }
}

function doKick() {
    const p      = state.selected; if (!p) return;
    const reason = document.getElementById('kickReason').value.trim() || 'No reason provided';
    post('kickPlayer', { serverId: p.serverId, reason });
    toast(`${p.name} kicked`, 'warn');
    closeModal();
}

function doBan() {
    const p        = state.selected; if (!p) return;
    const reason   = document.getElementById('banReason').value.trim()    || 'No reason provided';
    const duration = parseInt(document.getElementById('banDuration').value) || 0;
    post('banPlayer', { serverId: p.serverId, reason, duration });
    toast(`${p.name} banned${duration ? ` for ${duration}h` : ' permanently'}`, 'error');
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

function doGiveMoney() {
    const p         = state.selected; if (!p) return;
    const moneyType = document.getElementById('moneyType').value;
    const amount    = parseInt(document.getElementById('moneyAmount').value) || 0;

    if (amount <= 0) { toast('Enter a valid amount', 'error'); return; }

    post('giveMoney', { serverId: p.serverId, moneyType, amount });
    toast(`$${amount.toLocaleString()} given to ${p.name}`, 'success');
    closeModal();
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
    toast(
        state.noclip
            ? 'NoClip ON  —  W/S/A/D · E/Q for altitude'
            : 'NoClip OFF',
        'info'
    );
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
    const btn   = document.getElementById(btnId);
    const badge = document.getElementById(badgeId);
    btn.classList.toggle('is-on', on);
    badge.textContent  = on ? 'ON' : 'OFF';
    badge.className    = 'toggle-badge ' + (on ? 'on' : 'off');
}

// ── Vehicle ────────────────────────────────────────────────────
function spawnVehicle() {
    const model = document.getElementById('vehicleModel').value.trim();
    if (!model) { toast('Enter a vehicle model name', 'error'); return; }

    post('spawnVehicle', { model });
    toast(`Spawning ${model}…`, 'info');
}

function fixVehicle()    { post('fixVehicle');    toast('Vehicle repaired',          'success'); }
function flipVehicle()   { post('flipVehicle');   toast('Vehicle flipped upright',   'info');    }
function maxVehicle()    { post('maxVehicle');    toast('Vehicle fully upgraded',     'success'); }
function deleteVehicle() { post('deleteVehicle'); toast('Vehicle deleted',            'warn');    }

// ── Server ─────────────────────────────────────────────────────
function setWeather() {
    const weather = document.getElementById('weatherSelect').value;
    post('setWeather', { weather });
    toast(`Weather → ${weather}`, 'success');
}

function setTime() {
    const hour   = Math.min(23, Math.max(0, parseInt(document.getElementById('timeHour').value)   || 12));
    const minute = Math.min(59, Math.max(0, parseInt(document.getElementById('timeMinute').value) || 0));
    post('setTime', { hour, minute });
    toast(`Time set to ${pad(hour)}:${pad(minute)}`, 'success');
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

    if (isNaN(x) || isNaN(y) || isNaN(z)) {
        toast('Enter valid X / Y / Z coordinates', 'error');
        return;
    }

    post('teleportToCoords', { x, y, z });
    toast(`Teleporting to ${x.toFixed(0)}, ${y.toFixed(0)}, ${z.toFixed(0)}`, 'info');
}

function quickTP(x, y, z) {
    post('teleportToCoords', { x, y, z });
    toast('Teleporting…', 'info');
}

// ── Toast ──────────────────────────────────────────────────────
let toastTimer = null;

function toast(msg, type = 'info') {
    const el = document.getElementById('toast');
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

    const modal = document.getElementById('modal');
    if (!modal.classList.contains('hidden')) {
        closeModal();
    } else {
        closeMenu();
    }
});
