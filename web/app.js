const ESCAPES = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ESCAPES[c]);
const $ = (sel) => document.querySelector(sel);
const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'arca_inventory';
const post = (name, data = {}) =>
    fetch(`https://${resource}/${name}`, { method: 'POST', body: JSON.stringify(data) }).catch(() => {});
const kg = (g) => (g / 1000).toFixed(g % 1000 === 0 ? 0 : 1);

const ICONS = { player: 'fa-user', drop: 'fa-hand-holding', trunk: 'fa-car-rear', glovebox: 'fa-box', stash: 'fa-warehouse' };
const LAYOUT_KEY = 'arca_inventory_layout';
const HOTBAR = 5;

let defs = {};          // item definitions
let inventories = {};   // id -> payload
let order = [];         // window ids, player first
let selected = null;    // { inv, slot }

/* ---------- layout (saved per container type in this player's browser) ---------- */
function loadLayout() {
    try { return JSON.parse(localStorage.getItem(LAYOUT_KEY)) || {}; } catch (e) { return {}; }
}
function saveLayout(layout) {
    try { localStorage.setItem(LAYOUT_KEY, JSON.stringify(layout)); } catch (e) {}
}
let layout = loadLayout();

function defaultPosition(type, index) {
    const w = window.innerWidth, h = window.innerHeight;
    if (type === 'player') return { x: Math.round(w * 0.18), y: Math.round(h * 0.16) };
    return { x: Math.round(w * 0.55), y: Math.round(h * 0.16 + (index - 1) * 60) };
}

function clamp(win, x, y) {
    const r = win.getBoundingClientRect();
    return {
        x: Math.max(0, Math.min(window.innerWidth - r.width, x)),
        y: Math.max(0, Math.min(window.innerHeight - 50, y)),
    };
}

/* ---------- rendering ---------- */
function itemHtml(item) {
    const d = defs[item.name] || { label: item.name, icon: 'fa-solid fa-box' };
    const icon = esc(d.icon || 'fa-solid fa-box').replace(/[^\w\s-]/g, '');
    return `<div class="item" data-name="${esc(item.name)}">
        <span class="count">${item.count > 1 || d.stack ? item.count : ''}</span>
        <span class="img"><img src="images/${esc(item.name)}.png" onerror="this.replaceWith(Object.assign(document.createElement('i'),{className:'${icon}'}))"></span>
        <span class="label">${esc(d.label)}</span>
    </div>`;
}

function headHtml(inv) {
    const pct = inv.maxWeight ? Math.min(100, (inv.weight / inv.maxWeight) * 100) : 0;
    const cls = pct >= 100 ? 'full' : pct >= 80 ? 'heavy' : '';
    return `<span class="w-icon"><i class="fa-solid ${ICONS[inv.type] || 'fa-box'}"></i></span>
        <span class="w-weight">${kg(inv.weight)}/${kg(inv.maxWeight)}kg
            <span class="w-bar"><span class="w-fill ${cls}" style="width:${pct}%"></span></span></span>
        <span class="w-title">${esc(inv.label)}</span>
        ${inv.type === 'player' ? '<button class="w-btn" data-reset title="Reset layout"><i class="fa-solid fa-table-cells-large"></i></button>' : ''}`;
}

function renderWindow(id, index) {
    const inv = inventories[id];
    let win = document.querySelector(`.window[data-inv="${CSS.escape(id)}"]`);
    const isNew = !win;

    if (isNew) {
        win = document.createElement('div');
        win.className = 'window';
        win.dataset.inv = id;
        win.dataset.type = inv.type;
        win.innerHTML = `<div class="w-head"></div><div class="grid"></div>` +
            (inv.type === 'player'
                ? `<div class="actions"><button data-act="use">Use</button><input type="number" min="0" value="0" id="amount" title="Amount (0 = all)"><button data-act="give">Give</button></div>`
                : '');
        $('#windows').appendChild(win);
        bindWindow(win);
    }

    win.querySelector('.w-head').innerHTML = headHtml(inv);
    const grid = win.querySelector('.grid');
    grid.style.setProperty('--cols', Math.min(5, Math.max(1, inv.slots)));
    grid.dataset.inv = id;

    const bySlot = {};
    (inv.items || []).forEach((it) => (bySlot[it.slot] = it));

    let html = '';
    for (let s = 1; s <= inv.slots; s++) {
        const it = bySlot[s];
        const sel = selected && selected.inv === id && selected.slot === s ? ' selected' : '';
        html += `<div class="slot${sel}" data-inv="${esc(id)}" data-slot="${s}">` +
            (inv.type === 'player' && s <= HOTBAR ? `<span class="key">${s}</span>` : '') +
            (it ? itemHtml(it) : '') + `</div>`;
    }
    grid.innerHTML = html;

    if (isNew) win.dataset.placed = '';
}

// saved positions first; anything without one is stacked down the right-hand column
function placeWindows(all = false) {
    let nextY = Math.round(window.innerHeight * 0.12);
    document.querySelectorAll('.window').forEach((win) => {
        const saved = layout[win.dataset.type];
        const auto = !saved && win.dataset.type !== 'player';
        const height = win.getBoundingClientRect().height;
        if (all || win.dataset.placed !== undefined) {
            const pos = saved || (auto ? { x: Math.round(window.innerWidth * 0.55), y: nextY } : defaultPosition('player', 0));
            const p = clamp(win, pos.x, pos.y);
            win.style.left = `${p.x}px`;
            win.style.top = `${p.y}px`;
            delete win.dataset.placed;
        }
        if (auto) nextY = win.offsetTop + height + 14;
    });
}

function renderAll() {
    // remove windows that are gone
    document.querySelectorAll('.window').forEach((w) => { if (!inventories[w.dataset.inv]) w.remove(); });
    order.forEach((id, i) => renderWindow(id, i));
    placeWindows();
}

/* ---------- window dragging ---------- */
function bindWindow(win) {
    win.addEventListener('mousedown', () => {
        document.querySelectorAll('.window').forEach((w) => w.classList.toggle('front', w === win));
    });

    const head = win.querySelector('.w-head');
    head.addEventListener('mousedown', (e) => {
        if (e.button !== 0 || e.target.closest('[data-reset]')) return;
        const startX = e.clientX, startY = e.clientY;
        const left = win.offsetLeft, top = win.offsetTop;
        const move = (ev) => {
            const p = clamp(win, left + ev.clientX - startX, top + ev.clientY - startY);
            win.style.left = `${p.x}px`;
            win.style.top = `${p.y}px`;
        };
        const up = () => {
            window.removeEventListener('mousemove', move);
            window.removeEventListener('mouseup', up);
            layout[win.dataset.type] = { x: win.offsetLeft, y: win.offsetTop };
            saveLayout(layout);
        };
        window.addEventListener('mousemove', move);
        window.addEventListener('mouseup', up);
    });

    head.addEventListener('click', (e) => {
        if (!e.target.closest('[data-reset]')) return;
        layout = {};
        saveLayout(layout);
        placeWindows(true);
    });

    const actions = win.querySelector('.actions');
    if (actions) {
        actions.addEventListener('click', (e) => {
            const act = e.target.closest('[data-act]');
            if (!act || !selected || selected.inv !== order[0]) return;
            const amount = Number($('#amount').value) || 0;
            if (act.dataset.act === 'use') post('use', { slot: selected.slot });
            else post('give', { slot: selected.slot, count: amount > 0 ? amount : null });
        });
    }
}

/* ---------- item dragging ---------- */
let drag = null;

function itemAt(invId, slot) {
    return (inventories[invId]?.items || []).find((i) => i.slot === slot);
}

document.addEventListener('mousedown', (e) => {
    const itemEl = e.target.closest('.item');
    if (!itemEl || e.button !== 0 || itemEl.closest('#hotbar')) return;
    const slotEl = itemEl.parentElement;
    drag = {
        inv: slotEl.dataset.inv, slot: Number(slotEl.dataset.slot), el: itemEl,
        startX: e.clientX, startY: e.clientY, active: false, half: e.shiftKey,
    };
});

document.addEventListener('mousemove', (e) => {
    moveTooltip(e);
    if (!drag) return;
    if (!drag.active) {
        if (Math.abs(e.clientX - drag.startX) + Math.abs(e.clientY - drag.startY) < 5) return;
        drag.active = true;
        drag.el.classList.add('dragging');
        const ghost = $('#ghost');
        ghost.innerHTML = drag.el.outerHTML;
        ghost.querySelector('.item').classList.remove('dragging');
        ghost.classList.remove('hidden');
        hideTooltip();
    }
    const ghost = $('#ghost');
    ghost.style.left = `${e.clientX}px`;
    ghost.style.top = `${e.clientY}px`;
    document.querySelectorAll('.slot.over').forEach((s) => s.classList.remove('over'));
    const over = document.elementFromPoint(e.clientX, e.clientY)?.closest('.slot');
    if (over && over.closest('.window')) over.classList.add('over');
});

document.addEventListener('mouseup', (e) => {
    if (!drag) return;
    const d = drag;
    drag = null;
    document.querySelectorAll('.slot.over').forEach((s) => s.classList.remove('over'));
    $('#ghost').classList.add('hidden');
    d.el.classList.remove('dragging');

    if (!d.active) {
        // plain click: select
        selected = selected && selected.inv === d.inv && selected.slot === d.slot ? null : { inv: d.inv, slot: d.slot };
        document.querySelectorAll('.slot.selected').forEach((s) => s.classList.remove('selected'));
        if (selected) document.querySelector(`.slot[data-inv="${CSS.escape(d.inv)}"][data-slot="${d.slot}"]`)?.classList.add('selected');
        return;
    }

    const target = document.elementFromPoint(e.clientX, e.clientY);
    const slotEl = target?.closest('.slot');
    const gridEl = target?.closest('.grid');
    const toInv = slotEl?.dataset.inv || gridEl?.dataset.inv;
    if (!toInv) return;

    const item = itemAt(d.inv, d.slot);
    if (!item) return;
    const amount = Number($('#amount')?.value) || 0;
    let count = amount > 0 ? Math.min(amount, item.count) : item.count;
    if (d.half && item.count > 1) count = Math.ceil(item.count / 2);

    post('move', { from: d.inv, fromSlot: d.slot, to: toInv, toSlot: slotEl ? Number(slotEl.dataset.slot) : null, count });
    selected = null;
});

document.addEventListener('dblclick', (e) => {
    const slotEl = e.target.closest('.slot');
    if (!slotEl || slotEl.dataset.inv !== order[0] || !slotEl.querySelector('.item')) return;
    post('use', { slot: Number(slotEl.dataset.slot) });
});

/* ---------- tooltip ---------- */
const tooltip = $('#tooltip');
function hideTooltip() { tooltip.classList.add('hidden'); }
function moveTooltip(e) {
    if (drag && drag.active) return;
    const slotEl = e.target.closest?.('.window .slot');
    const item = slotEl && itemAt(slotEl.dataset.inv, Number(slotEl.dataset.slot));
    if (!item) return hideTooltip();
    const d = defs[item.name] || {};
    const meta = Object.entries(item.metadata || {})
        .filter(([, v]) => typeof v !== 'object')
        .map(([k, v]) => `<div class="meta"><span>${esc(k)}</span><b>${esc(v)}</b></div>`).join('');
    tooltip.innerHTML = `<strong>${esc(d.label || item.name)}</strong>` +
        (d.description ? `<p>${esc(d.description)}</p>` : '') +
        `<div class="meta"><span>Weight</span><b>${kg((d.weight || 0) * item.count)}kg</b></div>` +
        `<div class="meta"><span>Amount</span><b>${item.count}</b></div>` + meta;
    tooltip.classList.remove('hidden');
    const r = tooltip.getBoundingClientRect();
    tooltip.style.left = `${Math.min(window.innerWidth - r.width - 10, e.clientX + 16)}px`;
    tooltip.style.top = `${Math.min(window.innerHeight - r.height - 10, e.clientY + 16)}px`;
}

/* ---------- hotbar popup ---------- */
let hotbarTimer;
function showHotbar({ inventory, slot }) {
    const bar = $('#hotbar');
    const bySlot = {};
    (inventory.items || []).forEach((it) => (bySlot[it.slot] = it));
    let html = '';
    for (let s = 1; s <= HOTBAR; s++) {
        html += `<div class="slot${s === slot ? ' used' : ''}"><span class="key">${s}</span>${bySlot[s] ? itemHtml(bySlot[s]) : ''}</div>`;
    }
    bar.innerHTML = html;
    bar.classList.remove('hidden');
    clearTimeout(hotbarTimer);
    hotbarTimer = setTimeout(() => bar.classList.add('hidden'), 1800);
}

/* ---------- messages ---------- */
function setInventory(inv) {
    // the ground: swap the "newdrop" placeholder for the real drop and back again when emptied
    if (inv.type === 'drop') {
        if (!inventories[inv.id] && inventories.newdrop) {
            delete inventories.newdrop;
            order = order.map((id) => (id === 'newdrop' ? inv.id : id));
            document.querySelector('.window[data-inv="newdrop"]')?.remove();
        }
        if (!inv.items || inv.items.length === 0) {
            delete inventories[inv.id];
            document.querySelector(`.window[data-inv="${CSS.escape(inv.id)}"]`)?.remove();
            inventories.newdrop = { id: 'newdrop', type: 'drop', label: 'Ground', slots: inv.slots, maxWeight: inv.maxWeight, weight: 0, items: [] };
            order = order.map((id) => (id === inv.id ? 'newdrop' : id));
            return renderAll();
        }
    }
    if (!inventories[inv.id] && !order.includes(inv.id)) return; // not one of our open windows
    inventories[inv.id] = inv;
    renderAll();
}

window.addEventListener('message', ({ data }) => {
    const d = data.data;
    switch (data.action) {
        case 'open':
            defs = d.items || {};
            inventories = {};
            order = [d.player.id];
            inventories[d.player.id] = d.player;
            (d.others || []).forEach((inv) => { inventories[inv.id] = inv; order.push(inv.id); });
            selected = null;
            $('#windows').innerHTML = '';
            $('#inventory').classList.remove('hidden');
            renderAll();
            break;
        case 'update':
            if ($('#inventory').classList.contains('hidden')) return;
            setInventory(d);
            break;
        case 'close':
            $('#inventory').classList.add('hidden');
            hideTooltip();
            drag = null;
            break;
        case 'hotbar':
            showHotbar(d);
            break;
    }
});

window.addEventListener('keydown', (e) => {
    if ($('#inventory').classList.contains('hidden')) return;
    if (e.key === 'Escape' || (e.key === 'Tab' && document.activeElement?.id !== 'amount')) {
        e.preventDefault();
        post('close');
    }
});

// browser preview: open web/index.html?preview
if (location.search.includes('preview')) {
    document.body.style.background = 'linear-gradient(135deg,#3a4a44,#1a2420)';
    const items = {
        water: { label: 'Water', weight: 500, stack: true, icon: 'fa-solid fa-bottle-water', description: 'Fresh bottled water.' },
        bread: { label: 'Bread', weight: 250, stack: true, icon: 'fa-solid fa-bread-slice' },
        armor: { label: 'Body Armor', weight: 3000, stack: true, icon: 'fa-solid fa-shield-halved' },
        backpack: { label: 'Backpack', weight: 1000, icon: 'fa-solid fa-suitcase' },
        medikit: { label: 'Medikit', weight: 1000, stack: true, icon: 'fa-solid fa-kit-medical' },
        copper: { label: 'Copper', weight: 200, stack: true, icon: 'fa-solid fa-cubes' },
        phone: { label: 'Phone', weight: 200, icon: 'fa-solid fa-mobile-screen' },
        pistol_ammo: { label: 'Pistol Ammo', weight: 200, stack: true, icon: 'fa-solid fa-grip-lines-vertical' },
    };
    window.postMessage({ action: 'open', data: {
        items,
        player: { id: 'player:1', type: 'player', label: 'Inventory', slots: 30, maxWeight: 30000, weight: 17000, items: [
            { slot: 1, name: 'water', count: 3 }, { slot: 2, name: 'bread', count: 1 }, { slot: 3, name: 'armor', count: 1 },
            { slot: 4, name: 'backpack', count: 1 }, { slot: 6, name: 'medikit', count: 1 }, { slot: 7, name: 'copper', count: 12 },
            { slot: 8, name: 'phone', count: 1 }, { slot: 9, name: 'pistol_ammo', count: 3 },
        ] },
        others: [
            { id: 'trunk:ARCA', type: 'trunk', label: 'Trunk · ARCA1234', slots: 20, maxWeight: 40000, weight: 2000, items: [{ slot: 1, name: 'copper', count: 10 }] },
            { id: 'newdrop', type: 'drop', label: 'Ground', slots: 10, maxWeight: 200000, weight: 0, items: [] },
        ],
    } });
}
