// NUI State Variables
let configData = {};
let translations = {};
let selectedSpecialization = null;

// Global Context
const doc = document;
const app = doc.getElementById('app');

/**
 * NUI → cliente Lua. FiveM expone GetParentResourceName como global (no siempre en window).
 * Había una segunda función `post` más abajo que sobrescribía esta y usaba window.GetParentResourceName → undefined → ningún botón funcionaba.
 */
function getNuiResourceName() {
    try {
        if (typeof GetParentResourceName === 'function') return GetParentResourceName();
    } catch (e) { /* ignore */ }
    try {
        if (typeof window !== 'undefined' && typeof window.GetParentResourceName === 'function') {
            return window.GetParentResourceName();
        }
    } catch (e2) { /* ignore */ }
    try {
        const host = typeof window !== 'undefined' && window.location && window.location.hostname;
        if (host && /^cfx-nui-/i.test(host)) {
            return host.replace(/^cfx-nui-/i, '');
        }
    } catch (e3) { /* ignore */ }
    return '';
}

function post(url, data) {
    const name = getNuiResourceName();
    if (!name) {
        console.error('[JGR NUI] GetParentResourceName no disponible; no se puede llamar a', url);
        return;
    }
    fetch(`https://${name}/${url}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data != null ? data : {})
    }).catch(err => console.error('[JGR NUI] post', url, err));
}
window.post = post;

/** Respuesta JSON del callback NUI (coords, etc.) */
async function fetchNui(url, data) {
    const name = getNuiResourceName();
    if (!name) return null;
    try {
        const res = await fetch(`https://${name}/${url}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data != null ? data : {})
        });
        return await res.json();
    } catch (e) {
        console.error('[JGR NUI] fetchNui', url, e);
        return null;
    }
}

// Global UI State
let currentEditGang = null;
let currentDeleteGang = null;
let currentGangData = null;
let currentPlayerPerms = null;
let gmLocales = {};
let currentEditingRank = null;
let currentGangRanks = {};
let deliveryTotalSeconds = 0;
let deliverySecondsLeft = 0;
let currentRecipes = {};
let selectedRecipeId = null;

// Admin Panel State
let adminData = null;
let adminConfig = null;
let adminLocales = null;

// Documents State
let currentDocuments = [];
let editingDocId = null;
/** false hasta pulsar «Nuevo» o elegir un archivo de la lista */
let docComposerActive = false;

// Territories / zone state
let currentTerritories = [];
let editingTerrId = null;
let currentControlZone = null;
let currentRankOrder = [];
let lastPlayerWorldCoords = null;
let territoryCoordsPollId = null;

// DOM Elements: Containers
const step1 = doc.getElementById('step1');
const step3 = doc.getElementById('step3');
const step4 = doc.getElementById('step4');
const adminPanel = doc.getElementById('adminPanel');
const gangMenuWrapper = doc.getElementById('gangMenuWrapper');
const gangMenuContainer = doc.getElementById('gangMenuContainer');

// Translation Elements Step 1
const elTitle1 = doc.getElementById('ui_title');
const elSub1 = doc.getElementById('ui_subtitle');
const elNameInput = doc.getElementById('gangName');
const elRanksTitle = doc.getElementById('ui_ranks');
const elPermsTitle = doc.getElementById('ui_permissions');
const elAddRankBtnText = doc.getElementById('ui_add_rank');
const btnCancel = doc.getElementById('btnCancel');
const btnContinue1 = doc.getElementById('btnContinueStep1');
const btnAddRank = doc.getElementById('btnAddRank');

// Translation Elements Step 3
const elTitle3 = doc.getElementById('ui_spec_title');
const elSub3 = doc.getElementById('ui_spec_subtitle');
const btnContinue3 = doc.getElementById('btnContinueStep3');

// Translation Elements Step 4
const elTitle4 = doc.getElementById('ui_finish_title');
const elDesc4 = doc.getElementById('ui_finish_desc');
const btnFinish = doc.getElementById('btnFinish');

// Dynamic Selection Containers
const permsList = doc.getElementById('permissionsList');
const specGrid = doc.getElementById('specializationsGrid');
const gangColor = doc.getElementById('gangColor');

// Admin Panel Components
const btnCloseAdmin = doc.getElementById('btnCloseAdmin');
const editModal = doc.getElementById('editLimitModal');
const editModalInput = doc.getElementById('editModalInput');
const btnCancelEdit = doc.getElementById('btnCancelEdit');
const btnConfirmEdit = doc.getElementById('btnConfirmEdit');
const deleteModal = doc.getElementById('deleteConfirmModal');
const btnCancelDelete = doc.getElementById('btnCancelDelete');
const btnConfirmDelete = doc.getElementById('btnConfirmDelete');

// Gang Management Components
const btnBackGM = doc.getElementById('btnBackGangMenu');
const btnCloseGM = doc.getElementById('btnCloseGangMenu');
const navButtons = doc.querySelectorAll('.gm-nav-btn');

// Document Components
const btnNewDoc = doc.getElementById('btnNewDoc');
const gmDocTitle = doc.getElementById('gmDocTitle');
const gmDocContent = doc.getElementById('gmDocContent');
const gmBtnSaveDoc = doc.getElementById('gmBtnSaveDoc');
const gmBtnDeleteDoc = doc.getElementById('gmBtnDeleteDoc');
const gmDocList = doc.getElementById('gmDocList');

// Map Components
const mapContainer = doc.getElementById('gmMapContainer');
const mapScroll = doc.getElementById('gmMapScroll');
const mapBg = doc.getElementById('gmMapBg');
const territoryPins = doc.getElementById('gmTerritoryPins');
const gmZoneCircleSvg = doc.getElementById('gmZoneCircleSvg');
let mapScale = 1;
let mapPanning = false;
let mapStartX = 0, mapStartY = 0;
let mapTransX = 0, mapTransY = 0;

// Config Tab Components
const btnInviteMember = doc.getElementById('btnInviteMember');
const btnManageRanks = doc.getElementById('btnManageRanks');
const btnPlaceStash = doc.getElementById('btnPlaceStash');
const btnPlaceGarageMenu = doc.getElementById('btnPlaceGarageMenu');
const btnPlaceGarageSpawn = doc.getElementById('btnPlaceGarageSpawn');
const btnPlaceGarageStore = doc.getElementById('btnPlaceGarageStore');
const btnPlaceBoss = doc.getElementById('btnPlaceBoss');
const gmConfigMembersList = doc.getElementById('gmConfigMembersList');
const gmRanksList = doc.getElementById('gmRanksList');

// Grow Shop Components
const growShopWrapper = doc.getElementById('growShopWrapper');
const btnCloseGrowShop = doc.getElementById('btnCloseGrowShop');
const gsNavBtns = doc.querySelectorAll('.gs-nav-btn');
const gsViews = doc.querySelectorAll('.gs-view');
const gsWholesaleGrid = doc.getElementById('gsWholesaleGrid');
const gsRecipeList = doc.getElementById('gsRecipeList');
const gsRecipeDetails = doc.getElementById('gsRecipeDetails');
const gsSocietyMoney = doc.getElementById('gsSocietyMoney');
const gsFundAmount = doc.getElementById('gsFundAmount');
const gsEmployeeList = doc.getElementById('gsEmployeeList');

// Cart Sub-Module Logic
const cartState = {
    items: {} // key: item_name, value: {qty, price, label}
};
const reactiveCart = new Proxy(cartState, {
    set(target, property, value) {
        target[property] = value;
        if (property === 'items') {
            renderCartUI();
        }
        return true;
    }
});

// Internal Creator Data
let ranksData = {
    "Jefe": {}
};
let currentRankEdit = "Jefe";

// Main NUI Listener
window.addEventListener('message', (event) => {
    const data = event.data;

    // Phase 1: Gang Creator
    if (data.action === "open_gang_creator") {
        configData = data.config;
        translations = configData.Translations || {};

        applyTranslations();
        buildPermissions(configData.BasePermissions);

        showStep(1);
        if (app) app.style.display = "flex";
        doc.body.style.display = "flex";
    }
    else if (data.action === "open_specialization_step") {
        buildSpecializations(data.specializations);

        showStep(3);
        if (app) app.style.display = "flex";
        doc.body.style.display = "flex";
    }
    // Phase 1.5: 3D Control Prompt
    else if (data.action === "open_step_2_controls") {
        showStep(0); // Hide all steps
        doc.getElementById('step2Controls').classList.remove('hidden');
        if (app) app.style.display = "flex";
        app.style.background = "transparent";
        app.style.backdropFilter = "none";
        doc.body.style.display = "flex";
    }
    else if (data.action === "close_step_2_controls") {
        doc.getElementById('step2Controls').classList.add('hidden');
        app.style.background = "";
        app.style.backdropFilter = "";
        doc.body.style.display = "none";
    }
    // Phase 3: Admin Panel
    else if (data.action === "open_admin_panel") {
        adminData = data.gangs;
        translations = data.translations || {}; // Corrected: use translations from data
        app.classList.remove('hidden');
        if (app) app.style.display = "flex";
        showStep('admin');
        renderAdminPanel();
        doc.body.style.display = "flex";
    }
    // Phase 4: Gang Management Menu
    else if (data.action === "open_gang_menu") {
        if (app) app.style.display = "flex";
        app.style.background = "transparent";
        app.style.backdropFilter = "none";
        app.classList.remove('hidden');
        showStep('gangMenu');
        populateGangMenu(data.gang, data.permissions, data.translations, { preserveView: false });
        doc.body.style.display = "flex";
    }
    else if (data.action === 'gang_menu_sync') {
        if (!data.gang) return;
        populateGangMenu(data.gang, data.permissions, data.translations, { preserveView: true });
    }
    // Hide gang menu (called from Lua when opening dialogs)
    else if (data.action === "hide_gang_menu") {
        stopTerritoryCoordsPoll();
        doc.getElementById('gangMenuWrapper').classList.add('hidden');
        doc.body.style.display = "none";
    }
    // Update ranks panel (instant visual refresh after create/delete)
    else if (data.action === "update_ranks") {
        currentGangRanks = data.ranks || {};
        currentRankOrder = computeRankOrder(currentGangRanks);
        renderRanksPanel(currentGangRanks);
        fillInviteRankSelect();
    }
    else if (data.action === "update_control_zone") {
        currentControlZone = data.zone || null;
        if (currentGangData) {
            currentGangData.control_zone = currentControlZone;
            if (!currentGangData.stats) currentGangData.stats = {};
            currentGangData.stats.control_zone = currentControlZone;
            currentGangData.territories = currentControlZone ? 1 : 0;
        }
        const tc = doc.getElementById('gmTerritoryCount');
        if (tc) tc.innerText = currentControlZone ? '1' : '0';
        syncZonePanelFromState();
        renderTerritoryPins();
    }
    // Update documents panel
    else if (data.action === "update_documents") {
        currentDocuments = data.documents || [];
        renderDocList();
    }
    else if (data.action === "update_territories") {
        currentTerritories = data.territories || [];
        const c = data.count != null ? data.count : currentTerritories.length;
        const tc = doc.getElementById('gmTerritoryCount');
        if (tc && !currentControlZone) tc.innerText = c;
        renderTerritoryPins();
    }
    else if (data.action === 'show_placement_hint') {
        doc.body.style.display = 'flex';
        const wrap = doc.getElementById('jgrPlacementHint');
        const t = doc.getElementById('jgrPlacementHintTitle');
        const s = doc.getElementById('jgrPlacementHintSub');
        if (t && data.title) t.textContent = data.title;
        if (s) s.innerHTML = data.subtitle != null ? data.subtitle : '<kbd>E</kbd> Confirmar · <kbd>ESC</kbd> Cancelar';
        if (wrap) wrap.classList.remove('hidden');
    }
    else if (data.action === 'hide_placement_hint') {
        const wrap = doc.getElementById('jgrPlacementHint');
        if (wrap) wrap.classList.add('hidden');
    }
    else if (data.action === 'open_gang_garage_standalone') {
        doc.body.style.display = 'flex';
        /* #app sigue en flex por CSS y tapa el garaje en CEF (fondo + stacking) */
        if (app) {
            app.dataset.jgrGaragePrevDisplay = app.style.display || '';
            app.style.display = 'none';
            app.style.pointerEvents = 'none';
        }
        openGangGarageStandaloneUI(data.vehicles || []);
    }
    else if (data.action === 'hide_gang_garage_standalone') {
        closeGangGarageStandaloneUI();
        if (app) {
            app.style.display = app.dataset.jgrGaragePrevDisplay != null && app.dataset.jgrGaragePrevDisplay !== ''
                ? app.dataset.jgrGaragePrevDisplay
                : '';
            delete app.dataset.jgrGaragePrevDisplay;
            app.style.pointerEvents = '';
        }
        const deliveryHud = doc.getElementById('deliveryHud');
        const deliveryVisible = deliveryHud && deliveryHud.style.display !== 'none' && deliveryHud.style.display !== '';
        if (!deliveryVisible) {
            doc.body.style.display = 'none';
        }
    }
});

function openGangGarageStandaloneUI(vehicles) {
    const overlay = doc.getElementById('jgrGangGarageOverlay');
    const listEl = doc.getElementById('jgrGangGarageList');
    const emptyEl = doc.getElementById('jgrGangGarageEmpty');
    if (!overlay || !listEl || !emptyEl) return;
    listEl.innerHTML = '';
    const arr = Array.isArray(vehicles) ? vehicles : [];
    emptyEl.style.display = arr.length ? 'none' : 'block';
    arr.forEach((v, i) => {
        const idx = i + 1;
        const plate = (v && v.plate) ? String(v.plate) : '—';
        const model = (v && v.model != null) ? String(v.model) : '—';
        const li = doc.createElement('li');
        const left = doc.createElement('div');
        left.innerHTML = `<strong>${plate}</strong><div class="jgr-gv-meta">Modelo: ${model}</div>`;
        const btn = doc.createElement('button');
        btn.type = 'button';
        btn.className = 'btn btn-primary gm-btn-accent';
        btn.style.flexShrink = '0';
        btn.textContent = 'Sacar';
        btn.onclick = () => post('takeGangGarageVehicle', { index: idx });
        li.appendChild(left);
        li.appendChild(btn);
        listEl.appendChild(li);
    });
    overlay.classList.remove('hidden');
}

function closeGangGarageStandaloneUI() {
    const overlay = doc.getElementById('jgrGangGarageOverlay');
    if (overlay) overlay.classList.add('hidden');
}

// Translation Applier
function applyTranslations() {
    if (!translations) return;

    // Step 1
    if (translations.ui_title) elTitle1.innerText = translations.ui_title;
    if (translations.ui_subtitle) elSub1.innerText = translations.ui_subtitle;
    if (translations.ui_org_name) elNameInput.placeholder = translations.ui_org_name;
    if (translations.ui_ranks) elRanksTitle.innerHTML = `${translations.ui_ranks} <span class="badge">(Permisos)</span>`;
    if (translations.ui_permissions) elPermsTitle.innerHTML = `${translations.ui_permissions} <span class="badge" id="currentRankBadge">Jefe</span>`;
    if (translations.ui_cancel) btnCancel.innerText = translations.ui_cancel;
    if (translations.ui_continue) btnContinue1.innerHTML = `${translations.ui_continue} <i class="fa-solid fa-arrow-right"></i>`;
    if (translations.ui_add_rank) elAddRankBtnText.innerText = translations.ui_add_rank;

    // Step 2 Controls (Fallback if not translated)
    doc.getElementById('ctrl_confirm').innerText = translations.place_npc_confirm || "Confirmar";
    doc.getElementById('ctrl_rotate').innerText = translations.place_npc_rotate || "Rotar";
    doc.getElementById('ctrl_change').innerText = translations.place_npc_change || "Cambiar Modelo";

    // Step 3
    if (translations.ui_spec_title) elTitle3.innerText = translations.ui_spec_title;
    if (translations.ui_spec_subtitle) elSub3.innerText = translations.ui_spec_subtitle;
    if (translations.ui_continue) btnContinue3.innerHTML = `${translations.ui_continue} <i class="fa-solid fa-arrow-right"></i>`;

    // Step 4
    if (translations.ui_finish_title) elTitle4.innerText = translations.ui_finish_title;
    if (translations.ui_finish_desc) elDesc4.innerText = translations.ui_finish_desc;
    if (translations.ui_finish_btn) btnFinish.innerHTML = `${translations.ui_finish_btn} <i class="fa-solid fa-check"></i>`;
}

// Builders
function buildPermissions(permsArray) {
    permsList.innerHTML = '';
    if (!permsArray) return;

    permsArray.forEach(perm => {
        permsList.innerHTML += `
            <div class="perm-item" style="flex-direction: row; justify-content: space-between;">
                <div class="perm-info" style="display: flex; flex-direction: column;">
                    <h4 style="margin-bottom: 4px; font-weight: bold;">${perm.label}</h4>
                    <p style="font-size: 0.85rem; color: var(--text-muted);">${perm.desc}</p>
                </div>
                <label class="switch">
                    <input type="checkbox" id="perm_${perm.id}" onchange="updateRankPermission('${perm.id}', this.checked)">
                    <span class="slider"></span>
                </label>
            </div>
        `;
    });
}

function updateRankPermission(permId, isChecked) {
    if (ranksData[currentRankEdit]) {
        ranksData[currentRankEdit][permId] = isChecked;
    }
}

function loadRankPermissions() {
    doc.getElementById('currentRankBadge').innerText = currentRankEdit;

    // Reset all switches
    doc.querySelectorAll('.switch input').forEach(input => {
        input.checked = false;

        // If this rank has this permission, set it to checked
        let permId = input.id.replace('perm_', '');
        if (ranksData[currentRankEdit] && ranksData[currentRankEdit][permId]) {
            input.checked = true;
        }
    });
}

function buildSpecializations(specs) {
    specGrid.innerHTML = '';
    if (!specs) return;

    selectedSpecialization = null;
    btnContinue3.classList.add("disabled");

    for (const [key, label] of Object.entries(specs)) {
        const card = doc.createElement('div');
        card.className = "spec-card spec-background";
        card.dataset.spec = key;
        card.innerHTML = `<span class="spec-text">${label}</span>`;

        // Inject large faint icons based on spec
        let iconHtml = '';
        if (key === 'weed') iconHtml = '<i class="fa-solid fa-cannabis spec-bg-icon"></i>';
        if (key === 'cocaine') iconHtml = '<i class="fa-solid fa-snowflake spec-bg-icon"></i>';
        if (key === 'meth') iconHtml = '<i class="fa-solid fa-flask spec-bg-icon"></i>';
        if (key === 'weapons') iconHtml = '<i class="fa-solid fa-gun spec-bg-icon"></i>';

        card.innerHTML += iconHtml;

        card.onclick = () => {
            // Remove active from all
            document.querySelectorAll('.spec-card').forEach(c => c.classList.remove('active'));
            card.classList.add('active');
            selectedSpecialization = key;
            btnContinue3.classList.remove('disabled');
        };

        specGrid.appendChild(card);
    }
}

// Navigation flow
function showStep(stepNumber) {
    step1.classList.add('hidden');
    step3.classList.add('hidden');
    step4.classList.add('hidden');
    adminPanel.classList.add('hidden');
    doc.getElementById('gangMenuWrapper').classList.add('hidden');

    if (stepNumber === 1) step1.classList.remove('hidden');
    if (stepNumber === 3) step3.classList.remove('hidden');
    if (stepNumber === 4) step4.classList.remove('hidden');
    if (stepNumber === "admin") adminPanel.classList.remove('hidden');
    if (stepNumber === "gangMenu") doc.getElementById('gangMenuWrapper').classList.remove('hidden');

    // Restore Background if a normal step is shown
    if ([1, 3, 4, "admin"].includes(stepNumber)) {
        app.style.background = "";
        app.style.backdropFilter = "";
    } else if (stepNumber === "gangMenu") {
        app.style.background = "transparent";
        app.style.backdropFilter = "none";
    }
}

// Event Listeners
btnCancel.onclick = () => {
    doc.body.style.display = "none";
    post('closeUI');
};

btnAddRank.onclick = () => {
    // Add new generic rank
    let index = Object.keys(ranksData).length;
    if (index >= (configData.MaxRoles || 10)) {
        return; // Max reached
    }

    let newRankName = `Rango ${index + 1}`;
    ranksData[newRankName] = {};

    // Add to UI
    const rankListEl = doc.getElementById('ranksList');
    const newEl = doc.createElement('div');
    newEl.className = "rank-item";
    newEl.dataset.rank = newRankName;
    newEl.innerHTML = `
        <i class="fa-solid fa-tag"></i> 
        <span class="rank-name" onclick="editRankName(this)" onblur="updateRankName('${newRankName}', this)" onkeydown="handleRankKey(event, this)">${newRankName}</span>
        <i class="fa-solid fa-trash btn-delete-rank" onclick="deleteRank('${newRankName}', this)" style="margin-left:auto; z-index: 10;"></i>
    `;

    newEl.onclick = (e) => {
        if (e.target.classList.contains('btn-delete-rank') || e.target.classList.contains('rank-name')) return;
        selectRank(newRankName, newEl);
    };

    rankListEl.appendChild(newEl);
};

window.editRankName = function (el) {
    el.setAttribute('contenteditable', 'true');
    el.focus();
    // Select all text
    let range = document.createRange();
    range.selectNodeContents(el);
    let sel = window.getSelection();
    sel.removeAllRanges();
    sel.addRange(range);
};

window.handleRankKey = function (event, el) {
    if (event.key === 'Enter') {
        event.preventDefault();
        el.blur();
    }
};

window.updateRankName = function (oldName, el) {
    el.removeAttribute('contenteditable');
    let newName = el.innerText.trim();
    if (newName === "" || newName === oldName || ranksData[newName]) {
        el.innerText = oldName; // revert
        return;
    }
    // Rename key
    ranksData[newName] = ranksData[oldName];
    delete ranksData[oldName];

    // Update Element
    el.parentElement.dataset.rank = newName;
    el.parentElement.querySelector('.btn-delete-rank').setAttribute('onclick', `deleteRank('${newName}', this)`);
    el.setAttribute('onblur', `updateRankName('${newName}', this)`);

    if (currentRankEdit === oldName) {
        currentRankEdit = newName;
        doc.getElementById('currentRankBadge').innerText = newName;
    }
}

window.deleteRank = function (rankName, deleteBtnEl) {
    if (rankName === "Jefe") return; // Cant delete boss
    delete ranksData[rankName];
    deleteBtnEl.parentElement.remove();

    // If was editing, fallback to Jefe
    if (currentRankEdit === rankName) {
        let firstEl = doc.querySelector('.rank-item[data-rank="Jefe"]');
        selectRank("Jefe", firstEl);
    }
}

window.selectRank = function (rankName, el) {
    doc.querySelectorAll('.rank-item').forEach(e => e.classList.remove('active'));
    el.classList.add('active');
    currentRankEdit = rankName;
    loadRankPermissions();
}

// Initial Boss Select binding
doc.querySelector('.rank-item[data-rank="Jefe"]').onclick = function (e) {
    if (e.target.classList.contains('rank-name')) return;
    selectRank("Jefe", this);
};

btnContinue1.onclick = () => {
    const name = elNameInput.value.trim();
    const color = gangColor.value;

    if (name === "") {
        elNameInput.style.border = "1px solid red";
        // Shake animation
        elNameInput.parentElement.style.animation = "bounce 0.5s";
        setTimeout(() => { elNameInput.parentElement.style.animation = ""; }, 500);
        return;
    }

    Object.keys(ranksData).forEach(k => {
        const low = String(k).toLowerCase();
        if (low === 'jefe' || low === 'boss') {
            ranksData[k] = ranksData[k] || {};
            ranksData[k].isBoss = true;
        }
    });

    const data = {
        name: name,
        color: color,
        ranks: ranksData
    };

    doc.body.style.display = "none";
    post('step1_config_complete', data);
};

btnContinue3.onclick = () => {
    if (!selectedSpecialization) return;

    // Go to step 4
    showStep(4);
};

btnFinish.onclick = () => {
    doc.body.style.display = "none";
    post('finishCreation', { specialization: selectedSpecialization });
};

// Admin Panel Logic
btnCloseAdmin.onclick = () => {
    doc.body.style.display = "none";
    post('closeAdminPanel');
};

function applyAdminTranslations() {
    if (!translations) return;
    if (translations.panel_title) doc.getElementById('ui_admin_title').innerText = translations.panel_title;
    if (translations.panel_desc) doc.getElementById('ui_admin_desc').innerText = translations.panel_desc;
    if (translations.table_name) doc.getElementById('th_name').innerText = translations.table_name;
    if (translations.table_members) doc.getElementById('th_members').innerText = translations.table_members;
    if (translations.table_max) doc.getElementById('th_max').innerText = translations.table_max;
    if (translations.table_actions) doc.getElementById('th_actions').innerText = translations.table_actions;
    if (translations.btn_close) btnCloseAdmin.innerHTML = `${translations.btn_close} <i class="fa-solid fa-xmark"></i>`;
}

function renderAdminPanel() {
    applyAdminTranslations();
    buildAdminTable(adminData);
}

function buildAdminTable(gangs) {
    const listEl = doc.getElementById('adminGangList');
    listEl.innerHTML = '';

    if (!gangs || gangs.length === 0) {
        listEl.innerHTML = `<tr><td colspan="4" style="text-align:center; padding: 20px;">No gangs found.</td></tr>`;
        return;
    }

    gangs.forEach(gang => {
        const tr = doc.createElement('tr');
        tr.id = `gang_row_${gang.name}`;

        // Members Bar Color Check (Red if maxed)
        let memColor = gang.current_members >= gang.max_members ? "var(--danger)" : "var(--primary)";

        tr.innerHTML = `
            <td>
                <div style="display: flex; align-items: center; gap: 10px;">
                    <div class="color-dot" style="background-color: ${gang.color}"></div>
                    <strong>${gang.name}</strong>
                </div>
            </td>
            <td id="td_members_${gang.name}">
                <span style="color: ${memColor}; font-weight: bold;">${gang.current_members}</span> / 
                <span id="label_max_${gang.name}">${gang.max_members}</span>
            </td>
            <td>
                <strong id="td_max_${gang.name}">${gang.max_members}</strong>
            </td>
            <td>
                <div class="admin-actions-cell">
                    <button class="btn btn-primary" onclick="openEditModal('${gang.name}', ${gang.max_members})">${translations.action_edit || 'Editar Límite'}</button>
                    <button class="btn btn-danger" onclick="openDeleteModal('${gang.name}')">${translations.action_delete || 'Eliminar'}</button>
                </div>
            </td>
        `;
        listEl.appendChild(tr);
    });
}

// Modal Logic
window.openEditModal = function (gangName, currentMax) {
    currentEditGang = gangName;
    doc.getElementById('editModalGangName').innerText = gangName;

    const dynamicMaxEl = doc.getElementById(`td_max_${gangName}`);
    if (dynamicMaxEl) {
        editModalInput.value = dynamicMaxEl.innerText;
    } else {
        editModalInput.value = currentMax;
    }

    editModal.classList.remove('hidden');
}

btnCancelEdit.onclick = () => {
    editModal.classList.add('hidden');
    currentEditGang = null;
}

btnConfirmEdit.onclick = () => {
    if (!currentEditGang) return;
    const newMaxVal = parseInt(editModalInput.value);

    if (newMaxVal && newMaxVal > 0) {
        post('adminEditGang', { gangName: currentEditGang, newMax: newMaxVal });

        // Optimistic DOM Update
        const tdMax = doc.getElementById(`td_max_${currentEditGang}`);
        const labelMax = doc.getElementById(`label_max_${currentEditGang}`);
        if (tdMax) tdMax.innerText = newMaxVal;
        if (labelMax) labelMax.innerText = newMaxVal;

        editModal.classList.add('hidden');
        currentEditGang = null;
    }
}

// Modal Logic Delete
window.openDeleteModal = function (gangName) {
    currentDeleteGang = gangName;
    doc.getElementById('deleteModalGangName').innerText = gangName;
    deleteModal.classList.remove('hidden');
}

btnCancelDelete.onclick = () => {
    deleteModal.classList.add('hidden');
    currentDeleteGang = null;
}

btnConfirmDelete.onclick = () => {
    if (!currentDeleteGang) return;

    post('adminDeleteGang', { gangName: currentDeleteGang });

    const rowEl = doc.getElementById(`gang_row_${currentDeleteGang}`);
    if (rowEl) {
        rowEl.style.transition = "all 0.4s ease";
        rowEl.style.opacity = "0";
        rowEl.style.transform = "translateX(-20px)";
        setTimeout(() => rowEl.remove(), 400);
    }

    deleteModal.classList.add('hidden');
    currentDeleteGang = null;
}

/* ====================================================
   PHASE 4: GANG MANAGEMENT MENU (SPA LOGIC)
==================================================== */

function applyGangMenuTranslations() {
    if (!gmLocales) return;
    const safeSet = (id, str) => { if (doc.getElementById(id) && gmLocales[str]) doc.getElementById(id).innerText = gmLocales[str]; };

    safeSet('t_rank', 'ui_gm_rank');
    safeSet('t_members', 'ui_gm_members');
    safeSet('t_territories', 'ui_gm_territories');
    safeSet('t_nav_terr', 'ui_gm_territories');
    safeSet('t_nav_cam', 'ui_gm_cameras');
    safeSet('t_nav_doc', 'ui_gm_documents');
    safeSet('t_nav_conf', 'ui_gm_config');
    safeSet('t_panel_members', 'ui_gm_members');
    safeSet('t_panel_stats', 'ui_gm_stats');
    safeSet('t_panel_activities', 'ui_gm_activities');
    safeSet('t_act_weed', 'ui_gm_weed');

    // Subcategories Text
    safeSet('t_terr_header', 'ui_gm_t_terr_header');
    safeSet('t_terr_empty', 'ui_gm_t_terr_empty');
    safeSet('t_terr_desc', 'ui_gm_t_terr_desc');
    safeSet('t_terr_list_header', 'ui_gm_t_terr_header');
    safeSet('t_terr_editor_header', 'ui_gm_t_terr_editor');
    safeSet('t_terr_new_btn', 'ui_gm_t_terr_new');
    safeSet('t_terr_save_btn', 'ui_gm_t_terr_save');
    safeSet('t_terr_place_btn', 'ui_gm_t_terr_place');
    safeSet('t_terr_delete_btn', 'ui_gm_t_terr_delete');
    safeSet('t_terr_influence_lbl', 'ui_gm_t_terr_influence');

    safeSet('t_cam_header', 'ui_gm_t_cam_header');
    safeSet('t_cam_empty', 'ui_gm_t_cam_empty');
    safeSet('t_cam_desc', 'ui_gm_t_cam_desc');

    safeSet('t_doc_header', 'ui_gm_t_doc_header');
    safeSet('t_doc_new', 'ui_gm_t_doc_new');
    safeSet('t_doc_viewer', 'ui_gm_t_doc_viewer');
    safeSet('t_doc_save', 'ui_gm_t_doc_save');
    const phTitle = doc.getElementById('gmDocPlaceholderTitle');
    if (phTitle && gmLocales.ui_gm_doc_placeholder_title) phTitle.textContent = gmLocales.ui_gm_doc_placeholder_title;
    const mh = doc.getElementById('gmMapHudTitle');
    const ms = doc.getElementById('gmMapHudSub');
    if (mh && gmLocales.ui_gm_map_hud_title) mh.textContent = gmLocales.ui_gm_map_hud_title;
    if (ms && gmLocales.ui_gm_map_hud_sub) ms.textContent = gmLocales.ui_gm_map_hud_sub;

    safeSet('t_cfg_members', 'ui_gm_t_cfg_members');
    safeSet('t_cfg_invite', 'ui_gm_t_cfg_invite');
    safeSet('t_cfg_settings', 'ui_gm_t_cfg_settings');
    safeSet('t_terr_list_header', 'ui_gm_t_zone_header');
    safeSet('t_terr_live_pos', 'ui_gm_t_zone_live');
    safeSet('t_terr_zone_hint', 'ui_gm_t_zone_hint');
    safeSet('t_terr_radius_lbl', 'ui_gm_t_zone_radius');
    safeSet('t_terr_saved_label', 'ui_gm_t_zone_saved');
    safeSet('t_terr_center_map', 'ui_gm_t_zone_center');
    safeSet('t_terr_save_zone', 'ui_gm_t_zone_save');
}

function hexToRgbCss(hex) {
    if (!hex || typeof hex !== 'string') return '168, 85, 247';
    const m = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex.trim());
    if (!m) return '168, 85, 247';
    return `${parseInt(m[1], 16)}, ${parseInt(m[2], 16)}, ${parseInt(m[3], 16)}`;
}

function worldToMapPercent(wx, wy) {
    const minX = -4000, maxX = 4500;
    const minY = -8000, maxY = 4200;
    const nx = Math.max(0, Math.min(1, (wx - minX) / (maxX - minX)));
    const ny = Math.max(0, Math.min(1, 1 - (wy - minY) / (maxY - minY)));
    return { leftPct: nx * 100, topPct: ny * 100 };
}

/** Solo bloquea UI si el servidor dice explícitamente false (isBoss siempre puede). El servidor sigue validando. */
function nuiPermAllows(key) {
    const p = currentPlayerPerms;
    if (!p) return true;
    if (p.isBoss === true) return true;
    if (p[key] === false) return false;
    return true;
}

function applyGmPermissions(perms) {
    if (perms) currentPlayerPerms = perms;
    if (!currentPlayerPerms) return;
    const lock = (gmLocales && gmLocales.ui_gm_perm_lock) || 'Sin permiso';
    /* No usar disabled/pointer-events: los botones dejaban de disparar el NUI y parecía que «no funcionaba nada». Solo aviso en title. */
    doc.querySelectorAll('[data-req-perm]').forEach(el => {
        const key = el.getAttribute('data-req-perm');
        const ok = nuiPermAllows(key);
        if (el.tagName === 'INPUT' && el.type === 'range') {
            el.disabled = !ok;
            el.style.opacity = ok ? '' : '0.45';
            el.title = ok ? '' : lock;
            return;
        }
        el.disabled = false;
        el.style.opacity = ok ? '' : '0.55';
        el.style.pointerEvents = '';
        el.title = ok ? (el.getAttribute('data-title-default') || '') : lock;
    });
    const docTitle = doc.getElementById('gmDocTitle');
    const docContent = doc.getElementById('gmDocContent');
    if (docTitle && docContent) {
        const canEdit = nuiPermAllows('manage_docs');
        docTitle.readOnly = !canEdit || !docComposerActive;
        docContent.readOnly = !canEdit || !docComposerActive;
    }
    const terrTitle = doc.getElementById('gmTerrTitle');
    const terrNotes = doc.getElementById('gmTerrNotes');
    const terrInf = doc.getElementById('gmTerrInfluence');
    if (terrTitle && terrNotes && terrInf) {
        const ok = nuiPermAllows('manage_territories');
        terrTitle.readOnly = !ok;
        terrNotes.readOnly = !ok;
        terrInf.disabled = !ok;
    }
    syncDocPlaceholder();
}

function setDocComposerActive(active) {
    docComposerActive = !!active;
    const ph = doc.getElementById('gmDocPlaceholder');
    const inner = doc.getElementById('gmDocEditorInner');
    if (ph) ph.classList.toggle('gm-doc-placeholder--hidden', docComposerActive);
    if (inner) inner.classList.toggle('gm-doc-editor-inner--dimmed', !docComposerActive);
    const docTitle = doc.getElementById('gmDocTitle');
    const docContent = doc.getElementById('gmDocContent');
    if (docTitle && docContent) {
        const canEdit = nuiPermAllows('manage_docs');
        docTitle.readOnly = !canEdit || !docComposerActive;
        docContent.readOnly = !canEdit || !docComposerActive;
    }
}

function syncDocPlaceholder() {
    const ph = doc.getElementById('gmDocPlaceholder');
    if (!ph) return;
    const msg = (gmLocales && gmLocales.ui_gm_doc_pick_hint) || 'Elige un documento de la lista o pulsa «Nuevo documento» para empezar.';
    const sub = ph.querySelector('.gm-doc-placeholder-sub');
    if (sub) sub.textContent = msg;
}

function updatePointStatusPills(points) {
    const pts = points || {};
    const okLabel = (gmLocales && gmLocales.ui_gm_point_ok) || 'Configurado';
    const noLabel = (gmLocales && gmLocales.ui_gm_point_pending) || 'Sin colocar';
    const setPill = (id, type) => {
        const el = doc.getElementById(id);
        if (!el) return;
        const ok = pts[type] && pts[type].x != null;
        el.textContent = ok ? okLabel : noLabel;
        el.classList.toggle('gm-point-pill--ok', !!ok);
        el.classList.toggle('gm-point-pill--no', !ok);
    };
    setPill('gmPointPillStash', 'stash');
    setPill('gmPointPillGarageMenu', 'garage_menu');
    setPill('gmPointPillGarageSpawn', 'garage_spawn');
    setPill('gmPointPillGarageStore', 'garage_store');
    /* Compat: antiguo punto único "garage" cuenta como menú */
    const elMenu = doc.getElementById('gmPointPillGarageMenu');
    if (elMenu && pts.garage && pts.garage.x != null && !(pts.garage_menu && pts.garage_menu.x != null)) {
        elMenu.textContent = okLabel;
        elMenu.classList.add('gm-point-pill--ok');
        elMenu.classList.remove('gm-point-pill--no');
    }
    setPill('gmPointPillBoss', 'boss');
}

function populateGangMenu(gang, perms, translationsData, syncOpts) {
    syncOpts = syncOpts || {};
    const preserveView = !!syncOpts.preserveView;
    const activeViewId = preserveView
        ? (doc.querySelector('.gm-view.active') && doc.querySelector('.gm-view.active').id)
        : null;

    currentGangData = gang;
    currentPlayerPerms = perms;
    gmLocales = translationsData || {};

    applyGangMenuTranslations();

    const wrap = doc.getElementById('gangMenuWrapper');
    if (wrap) {
        const col = gang.color || '#a855f7';
        wrap.style.setProperty('--gang-color', col);
        wrap.style.setProperty('--gang-color-rgb', hexToRgbCss(col));
    }

    // Load documents (si vienen como objeto JSON, evitar .forEach roto)
    let docs = gang.documents;
    if (!Array.isArray(docs)) {
        docs = docs && typeof docs === "object" ? Object.values(docs) : [];
    }
    currentDocuments = docs;
    editingDocId = null;
    renderDocList();
    if (gmDocTitle) gmDocTitle.value = '';
    if (gmDocContent) gmDocContent.value = '';
    setDocComposerActive(false);

    currentTerritories = [];
    editingTerrId = null;
    currentControlZone = gang.control_zone || (gang.stats && gang.stats.control_zone) || null;
    currentRankOrder = (gang.rank_order && gang.rank_order.length)
        ? gang.rank_order.slice()
        : computeRankOrder(gang.ranks || {});
    syncZonePanelFromState();
    renderTerritoryPins();

    applyGmPermissions(perms);
    updatePointStatusPills(gang.stats && gang.stats.points);
    resetTacticalMap(gang.npc_coords);

    // Header updates
    doc.getElementById('gmGangName').innerText = gang.name || "BANDA DESCONOCIDA";
    doc.getElementById('gmGangName').style.webkitTextStrokeColor = gang.color || "#a855f7";
    doc.getElementById('gmGangName').style.textShadow = `0 0 20px ${gang.color}80`;

    // Core Level Progression
    const level = gang.level || 0;
    const xp = gang.xp || 0;
    const xpRequired = (level + 1) * 1000; // Linear scale for now: 1000, 2000, 3000 XP
    const xpPercent = Math.min(100, Math.max(0, (xp / xpRequired) * 100));

    doc.getElementById('gmLevelText').innerText = `LEVEL ${level}`;
    doc.getElementById('gmNextLevel').innerText = `NIVEL ${level + 1}`;

    const progressFill = doc.querySelector('.gm-progress-fill');
    if (progressFill) {
        progressFill.style.width = `${xpPercent}%`;
        progressFill.style.backgroundColor = gang.color || "#a855f7";
        progressFill.style.boxShadow = `0 0 10px ${gang.color}`;
    }

    // Update Activities UI
    updateActivitiesUI(gang);

    // Top cards
    doc.getElementById('gmPlayerRank').innerText = perms.rankName || "Miembro";
    doc.getElementById('gmMemberCount').innerText = gang.members ? gang.members.length : 1;
    doc.getElementById('gmTerritoryCount').innerText = gang.territories || 0;

    // Load Members into dashboard list
    const dmList = doc.getElementById('gmDashboardMembers');
    dmList.innerHTML = '';
    if (gang.members && gang.members.length > 0) {
        gang.members.forEach(m => {
            dmList.innerHTML += `
                <div class="gm-member-row">
                    <div class="gm-member-avatar"><i class="fa-regular fa-user"></i></div>
                    <div class="gm-member-details">
                        <span class="gm-member-name">${m.name || m.citizenid}</span>
                        <div style="display:flex; gap: 10px; align-items:center; margin-top: 5px;">
                            <span class="badge gm-badge-blue">${m.rank}</span>
                            <span style="color: var(--text-muted); font-size: 0.8rem;"><i class="fa-solid fa-phone" style="font-size: 0.75rem; color: var(--gang-color, #a855f7);"></i> ${m.phone || 'N/A'}</span>
                        </div>
                    </div>
                </div>
            `;
        });
    } else {
        dmList.innerHTML = '<p style="color:var(--text-muted); font-size:0.9rem;">No hay miembros disponibles</p>';
    }

    if (preserveView && activeViewId && doc.getElementById(activeViewId)) {
        switchGMView(activeViewId);
    } else {
        switchGMView('gmViewDashboard');
    }

    // Load members into config list (expulsar vía data-jgr-kick + delegación, evita comillas rotas en citizenid)
    const cfgList = doc.getElementById('gmConfigMembersList');
    if (cfgList) {
        cfgList.innerHTML = '';
        if (gang.members && gang.members.length > 0) {
            gang.members.forEach(m => {
                const row = doc.createElement('div');
                row.className = 'gm-manage-row';
                row.style.cssText = 'display:flex; justify-content:space-between; align-items:center; background:rgba(255,255,255,0.05); padding:10px 15px; border-radius:8px;';
                const left = doc.createElement('div');
                const nameEl = doc.createElement('span');
                nameEl.style.cssText = 'color:white; font-family:var(--font-heading);';
                nameEl.textContent = m.name || m.citizenid || '—';
                left.appendChild(nameEl);
                left.appendChild(doc.createElement('br'));
                const badge = doc.createElement('span');
                badge.className = 'badge gm-badge-blue mt-1';
                badge.style.cssText = 'display:inline-block; margin-top:5px;';
                badge.textContent = m.rank || '—';
                left.appendChild(badge);
                row.appendChild(left);
                const actions = doc.createElement('div');
                actions.style.cssText = 'display:flex; gap:5px;';
                if (nuiPermAllows('manage_members')) {
                    const kickBtn = doc.createElement('button');
                    kickBtn.type = 'button';
                    kickBtn.className = 'btn btn-danger';
                    kickBtn.style.cssText = 'padding:5px 10px; font-size:0.8rem;';
                    kickBtn.title = 'Expulsar';
                    kickBtn.setAttribute('data-jgr-kick', encodeURIComponent(String(m.citizenid || '')));
                    kickBtn.innerHTML = '<i class="fa-solid fa-user-xmark"></i>';
                    actions.appendChild(kickBtn);
                }
                row.appendChild(actions);
                cfgList.appendChild(row);
            });
        } else {
            cfgList.innerHTML = '<p style="text-align:center; color:var(--text-muted); font-size:0.9rem;">No hay miembros.</p>';
        }
    }

    // Load ranks into config panel
    currentGangRanks = gang.ranks || {};
    renderRanksPanel(currentGangRanks);
    fillInviteRankSelect();
}

function computeRankOrder(ranks) {
    const keys = Object.keys(ranks || {});
    if (!keys.length) return [];
    let boss = keys.find(k => {
        const r = ranks[k];
        const n = String(k).toLowerCase();
        return (r && typeof r === 'object' && r.isBoss) || n === 'jefe' || n === 'boss';
    });
    const rest = keys.filter(k => k !== boss).sort((a, b) => String(a).localeCompare(String(b)));
    const out = [];
    if (boss) out.push(boss);
    rest.forEach(k => out.push(k));
    return out.length ? out : keys.sort((a, b) => String(a).localeCompare(String(b)));
}

function syncZonePanelFromState() {
    const rEl = doc.getElementById('gmZoneRadius');
    const rVal = doc.getElementById('gmZoneRadiusVal');
    const savedBlock = doc.getElementById('gmZoneSavedBlock');
    const savedCoords = doc.getElementById('gmZoneCoordsSaved');
    const savedDate = doc.getElementById('gmZoneSavedDate');
    const z = currentControlZone;
    if (rEl && z && z.radius != null) {
        const rv = Math.max(25, Math.min(400, parseInt(z.radius, 10) || 100));
        rEl.value = String(rv);
        if (rVal) rVal.innerText = String(rv);
    } else if (rEl) {
        if (rVal) rVal.innerText = rEl.value;
    }
    if (savedBlock && savedCoords) {
        if (z && z.x != null && z.y != null) {
            savedBlock.style.display = 'block';
            savedCoords.innerText = `X ${z.x.toFixed(1)}  Y ${z.y.toFixed(1)}  Z ${(z.z != null ? z.z : 0).toFixed(1)}  ·  R ${(z.radius != null ? z.radius : 100)} m`;
            if (savedDate) savedDate.innerText = z.updated || '';
        } else {
            savedBlock.style.display = 'none';
        }
    }
    updateZoneSvg();
}

function updateZoneSvg() {
    if (!gmZoneCircleSvg) return;
    gmZoneCircleSvg.innerHTML = '';
    const z = currentControlZone;
    if (!z || z.x == null || z.y == null) return;
    const c = worldToMapPercent(z.x, z.y);
    const rad = z.radius != null ? Number(z.radius) : 100;
    const east = worldToMapPercent(z.x + rad, z.y);
    let rPct = Math.abs(east.leftPct - c.leftPct);
    if (rPct < 0.15) rPct = 0.15;
    if (rPct > 48) rPct = 48;
    const col = (currentGangData && currentGangData.color) || '#a855f7';
    const circ = doc.createElementNS('http://www.w3.org/2000/svg', 'circle');
    circ.setAttribute('cx', String(c.leftPct));
    circ.setAttribute('cy', String(c.topPct));
    circ.setAttribute('r', String(rPct));
    circ.setAttribute('fill', hexToSvgFill(col, 0.12));
    circ.setAttribute('stroke', col);
    circ.setAttribute('stroke-width', '0.4');
    circ.setAttribute('stroke-opacity', '0.9');
    gmZoneCircleSvg.appendChild(circ);
}

function hexToSvgFill(hex, alpha) {
    const m = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec((hex || '').trim());
    if (!m) return `rgba(168,85,247,${alpha})`;
    return `rgba(${parseInt(m[1], 16)},${parseInt(m[2], 16)},${parseInt(m[3], 16)},${alpha})`;
}

function stopTerritoryCoordsPoll() {
    if (territoryCoordsPollId) {
        clearInterval(territoryCoordsPollId);
        territoryCoordsPollId = null;
    }
}

function startTerritoryCoordsPoll() {
    stopTerritoryCoordsPoll();
    const tick = async () => {
        const d = await fetchNui('requestPlayerCoords', {});
        if (d && d.x != null) {
            lastPlayerWorldCoords = d;
            const el = doc.getElementById('gmZoneCoordsLive');
            if (el) el.innerText = `X ${d.x.toFixed(1)}  Y ${d.y.toFixed(1)}  Z ${d.z.toFixed(1)}`;
            const tv = doc.getElementById('gmViewTerritories');
            if (tv && !tv.classList.contains('hidden')) renderTerritoryPins();
        }
    };
    tick();
    territoryCoordsPollId = setInterval(tick, 500);
}

function fillInviteRankSelect() {
    const sel = doc.getElementById('gmInviteRankSelect');
    if (!sel) return;
    sel.innerHTML = '';
    const order = currentRankOrder.length ? currentRankOrder : computeRankOrder(currentGangRanks);
    order.forEach((name, idx) => {
        const opt = doc.createElement('option');
        opt.value = name;
        opt.textContent = `${idx} — ${name}`;
        sel.appendChild(opt);
    });
}

function showGangModal(el) {
    if (!el) return;
    el.classList.remove('hidden');
    el.style.display = 'flex';
}

function hideGangModal(el) {
    if (!el) return;
    el.classList.add('hidden');
    el.style.display = 'none';
}

function renderRanksPanel(ranks) {
    const ranksList = doc.getElementById('gmRanksList');
    if (!ranksList) return;
    ranksList.innerHTML = '';
    const rk = ranks || {};
    const order = (currentRankOrder && currentRankOrder.length)
        ? currentRankOrder.filter(n => Object.prototype.hasOwnProperty.call(rk, n))
        : computeRankOrder(rk);
    const rankNames = order.length ? order : Object.keys(rk);
    const canRank = nuiPermAllows('manage_ranks');
    if (rankNames.length > 0) {
        rankNames.forEach(rName => {
            const r = ranks[rName];
            const rn = String(rName).toLowerCase();
            const isBoss = !!(r && typeof r === 'object' && r.isBoss) || rn === 'jefe' || rn === 'boss';
            const el = document.createElement('div');
            el.style.cssText = 'display:flex; justify-content:space-between; align-items:center; background:rgba(255,255,255,0.05); padding:10px 15px; border-radius:8px; border: 1px solid rgba(255,255,255,0.08); transition: all 0.2s;';
            const left = document.createElement('div');
            left.style.cssText = 'display:flex; align-items:center; gap:10px;';
            left.innerHTML = `
                        <i class="fa-solid ${isBoss ? 'fa-crown' : 'fa-shield-halved'}" style="color: ${isBoss ? '#f59e0b' : 'var(--gang-color, #a855f7)'}; font-size: 1.1rem;"></i>
                        <div>
                            <span style="color:white; font-weight:600; font-family:var(--font-heading); font-size:0.95rem;"></span>
                            ${isBoss ? '<br><span style="color:#f59e0b; font-size:0.7rem; text-transform:uppercase; letter-spacing:1px;">JEFE</span>' : ''}
                        </div>`;
            const nameSpan = left.querySelector('span');
            if (nameSpan) nameSpan.textContent = rName;

            const actions = document.createElement('div');
            actions.style.cssText = 'display:flex; gap:5px;';
            if (isBoss) {
                actions.innerHTML = '<span style="color:var(--text-muted); font-size:0.7rem;">ADMINISTRADOR</span>';
            } else if (canRank) {
                const bEdit = document.createElement('button');
                bEdit.type = 'button';
                bEdit.className = 'btn btn-primary';
                bEdit.style.cssText = 'padding:4px 10px; font-size:0.75rem; background:rgba(255,255,255,0.1);';
                bEdit.title = 'Editar permisos';
                bEdit.innerHTML = '<i class="fa-solid fa-pen-to-square"></i>';
                bEdit.onclick = () => openRankPerms(rName);
                const bDel = document.createElement('button');
                bDel.type = 'button';
                bDel.className = 'btn btn-danger';
                bDel.style.cssText = 'padding:4px 10px; font-size:0.75rem;';
                bDel.title = 'Eliminar rango';
                bDel.innerHTML = '<i class="fa-solid fa-trash"></i>';
                bDel.onclick = () => post('deleteRankReq', { rank: rName });
                actions.appendChild(bEdit);
                actions.appendChild(bDel);
            } else {
                actions.innerHTML = '<span style="color:var(--text-muted); font-size:0.7rem;">—</span>';
            }

            el.appendChild(left);
            el.appendChild(actions);
            el.onmouseenter = () => { el.style.borderColor = 'var(--gang-color, #a855f7)'; };
            el.onmouseleave = () => { el.style.borderColor = 'rgba(255,255,255,0.08)'; };
            ranksList.appendChild(el);
        });
    } else {
        ranksList.innerHTML = '<p style="text-align:center; color:var(--text-muted); font-size:0.9rem;">No hay rangos configurados.</p>';
    }
}

(function bindGangMenuKickDelegation() {
    const wrap = doc.getElementById('gangMenuWrapper');
    if (!wrap || wrap.dataset.jgrKickBound) return;
    wrap.dataset.jgrKickBound = '1';
    wrap.addEventListener('click', (ev) => {
        const b = ev.target.closest('button[data-jgr-kick]');
        if (!b) return;
        const enc = b.getAttribute('data-jgr-kick');
        if (!enc) return;
        try {
            const id = decodeURIComponent(enc);
            if (id) post('kickMemberReq', { id });
        } catch (e) { /* ignore */ }
    });
})();

function openRankPerms(rankName) {
    currentEditingRank = rankName;
    const modal = doc.getElementById('gmRankPermissionsModal');
    const permsList = doc.getElementById('permsList');
    const title = doc.getElementById('permsModalTitle');

    if (!modal || !permsList) return;

    title.innerText = `PERMISOS: ${rankName.toUpperCase()}`;
    permsList.innerHTML = '';

    const rankData = currentGangRanks[rankName] || {};
    const permissions = [
        { id: 'manage_members', label: 'Gestionar miembros', icon: 'fa-users-gear' },
        { id: 'manage_points', label: 'Gestionar puntos (sedes)', icon: 'fa-location-dot' },
        { id: 'manage_ranks', label: 'Gestionar rangos', icon: 'fa-layer-group' },
        { id: 'manage_docs', label: 'Gestionar documentos', icon: 'fa-file-signature' },
        { id: 'manage_territories', label: 'Gestionar territorios', icon: 'fa-map-location-dot' }
    ];

    permissions.forEach(p => {
        const isChecked = rankData[p.id] || false;
        const row = document.createElement('div');
        row.style.cssText = 'display:flex; justify-content:space-between; align-items:center; background:rgba(255,255,255,0.03); padding:12px 15px; border-radius:8px;';
        row.innerHTML = `
            <div style="display:flex; align-items:center; gap:12px;">
                <i class="fa-solid ${p.icon}" style="color:var(--text-muted); font-size:1rem; width:20px;"></i>
                <span style="color:white; font-size:0.9rem;">${p.label}</span>
            </div>
            <label class="gm-switch">
                <input type="checkbox" id="perm_${p.id}" ${isChecked ? 'checked' : ''}>
                <span class="gm-slider"></span>
            </label>
        `;
        permsList.appendChild(row);
    });

    modal.style.display = 'flex';
    modal.classList.remove('hidden');
}
window.openRankPerms = openRankPerms;

function closeRankPerms() {
    const modal = doc.getElementById('gmRankPermissionsModal');
    if (modal) {
        modal.classList.add('hidden');
        modal.style.display = 'none';
    }
}

if (doc.getElementById('btnSavePerms')) {
    doc.getElementById('btnSavePerms').onclick = () => {
        if (!currentEditingRank) return;

        const gt = id => { const e = doc.getElementById(id); return e ? e.checked : false; };
        const newPerms = {
            manage_members: gt('perm_manage_members'),
            manage_points: gt('perm_manage_points'),
            manage_ranks: gt('perm_manage_ranks'),
            manage_docs: gt('perm_manage_docs'),
            manage_territories: gt('perm_manage_territories')
        };

        post('updateRankPermsReq', { rank: currentEditingRank, permissions: newPerms });
        closeRankPerms();
    };
}

// Nav Logic
navButtons.forEach(btn => {
    btn.addEventListener('click', () => {
        const targetId = btn.getAttribute('data-target');
        switchGMView(targetId);
    });
});

function switchGMView(viewId) {
    doc.querySelectorAll('.gm-view').forEach(v => {
        v.classList.add('hidden');
        v.classList.remove('active');
        v.style.opacity = '';
        v.style.pointerEvents = '';
    });
    const target = doc.getElementById(viewId);
    if (target) {
        target.classList.remove('hidden');
        target.classList.add('active');
    }
    if (btnBackGM) {
        if (viewId === 'gmViewDashboard') btnBackGM.classList.add('hidden');
        else btnBackGM.classList.remove('hidden');
    }
    if (viewId === 'gmViewTerritories') {
        startTerritoryCoordsPoll();
        const z = currentControlZone;
        const center = (lastPlayerWorldCoords && lastPlayerWorldCoords.x != null)
            ? { x: lastPlayerWorldCoords.x, y: lastPlayerWorldCoords.y, z: lastPlayerWorldCoords.z }
            : (z && z.x != null ? { x: z.x, y: z.y, z: z.z } : (currentGangData && currentGangData.npc_coords));
        resetTacticalMap(center);
        renderTerritoryPins();
        updateZoneSvg();
    } else {
        stopTerritoryCoordsPoll();
    }
}

// Back Button logic
if (btnBackGM) {
    btnBackGM.onclick = () => {
        switchGMView('gmViewDashboard');
    };
}

// Close Menu Btn
if (doc.getElementById('btnCloseGangMenu')) {
    doc.getElementById('btnCloseGangMenu').onclick = () => {
        stopTerritoryCoordsPoll();
        doc.body.style.display = "none";
        if (doc.getElementById('gangMenuWrapper')) doc.getElementById('gangMenuWrapper').classList.add('hidden');
        post('closeUI');
    };
}

/* ====================================================
   DOCUMENTS TAB LOGIC
==================================================== */

function renderDocList() {
    if (!gmDocList) return;
    gmDocList.innerHTML = '';
    if (currentDocuments.length === 0) {
        gmDocList.innerHTML = '<p style="text-align:center; color:var(--text-muted); font-size:0.9rem; margin-top:20px;">No hay documentos creados.</p>';
        return;
    }
    currentDocuments.forEach(d => {
        const el = document.createElement('div');
        el.className = 'gm-doc-item';
        el.innerHTML = `
            <i class="fa-solid fa-file-lines" style="color: var(--gang-color, #a855f7); font-size: 1.2rem;"></i>
            <div style="flex:1; overflow:hidden;">
                <span style="color:white; font-weight:600; display:block; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">${d.title}</span>
                <span style="color:var(--text-muted); font-size:0.75rem;">${d.date || ''}</span>
            </div>
        `;
        el.style.cssText = 'display:flex; align-items:center; gap:12px; padding:10px 15px; background:rgba(255,255,255,0.05); border-radius:8px; cursor:pointer; border:1px solid transparent; transition:all 0.2s;';
        el.onmouseenter = () => { el.style.borderColor = 'var(--gang-color, #a855f7)'; el.style.background = 'rgba(255,255,255,0.08)'; };
        el.onmouseleave = () => { el.style.borderColor = 'transparent'; el.style.background = 'rgba(255,255,255,0.05)'; };
        el.onclick = () => {
            editingDocId = d.id;
            if (gmDocTitle) gmDocTitle.value = d.title || '';
            if (gmDocContent) gmDocContent.value = d.content || '';
            setDocComposerActive(true);
        };
        gmDocList.appendChild(el);
    });
}

if (btnNewDoc) {
    btnNewDoc.onclick = () => {
        editingDocId = null;
        if (gmDocTitle) gmDocTitle.value = '';
        if (gmDocContent) gmDocContent.value = '';
        setDocComposerActive(true);
        if (gmDocTitle) gmDocTitle.focus();
    };
}

if (gmBtnSaveDoc) {
    gmBtnSaveDoc.onclick = () => {
        const title = gmDocTitle ? gmDocTitle.value.trim() : '';
        const content = gmDocContent ? gmDocContent.value.trim() : '';
        if (title === '' || content === '') {
            post('notifyError', { msg: "El título y el contenido no pueden estar vacíos." });
            return;
        }
        post('saveDocument', { id: editingDocId, title: title, content: content });
    };
}

if (gmBtnDeleteDoc) {
    gmBtnDeleteDoc.onclick = () => {
        if (editingDocId === null) {
            post('notifyError', { msg: "Selecciona un documento para eliminar." });
            return;
        }
        post('deleteDocument', { id: editingDocId });
        editingDocId = null;
        if (gmDocTitle) gmDocTitle.value = '';
        if (gmDocContent) gmDocContent.value = '';
        setDocComposerActive(false);
    };
}

/* ====================================================
   ZONA DE CONTROL (mapa + radio)
==================================================== */
const gmZoneRadiusEl = doc.getElementById('gmZoneRadius');
if (gmZoneRadiusEl) {
    gmZoneRadiusEl.addEventListener('input', () => {
        const v = doc.getElementById('gmZoneRadiusVal');
        if (v) v.innerText = gmZoneRadiusEl.value;
        updateZoneSvg();
    });
}

const btnZoneSave = doc.getElementById('btnZoneSave');
if (btnZoneSave) {
    btnZoneSave.onclick = () => {
        const r = gmZoneRadiusEl ? parseInt(gmZoneRadiusEl.value, 10) : 100;
        post('saveControlZone', { radius: isNaN(r) ? 100 : r });
    };
}

const btnZoneCenterMap = doc.getElementById('btnZoneCenterMap');
if (btnZoneCenterMap) {
    btnZoneCenterMap.onclick = () => {
        if (lastPlayerWorldCoords && lastPlayerWorldCoords.x != null) {
            resetTacticalMap({
                x: lastPlayerWorldCoords.x,
                y: lastPlayerWorldCoords.y,
                z: lastPlayerWorldCoords.z
            });
        } else {
            post('notifyError', { msg: 'Aún no hay posición del jugador; espera un instante.' });
        }
    };
}

/* ====================================================
   TERRITORIES MAP LOGIC (DRAG & ZOOM)
==================================================== */

if (mapContainer && mapBg) {
    mapContainer.addEventListener('wheel', (e) => {
        e.preventDefault();
        const zoomAmount = 0.1;
        if (e.deltaY < 0) mapScale = Math.min(mapScale + zoomAmount, 3);
        else mapScale = Math.max(mapScale - zoomAmount, 0.5);
        applyMapTransform();
    }, { passive: false });

    // Pan
    mapContainer.addEventListener('mousedown', (e) => {
        mapPanning = true;
        mapContainer.style.cursor = 'grabbing';
        mapStartX = e.clientX - mapTransX;
        mapStartY = e.clientY - mapTransY;
    });

    doc.addEventListener('mousemove', (e) => {
        if (!mapPanning) return;
        mapTransX = e.clientX - mapStartX;
        mapTransY = e.clientY - mapStartY;
        applyMapTransform();
    });

    doc.addEventListener('mouseup', () => {
        mapPanning = false;
        if (mapContainer) mapContainer.style.cursor = 'grab';
    });
}

function applyMapTransform() {
    const t = `translate(${mapTransX}px, ${mapTransY}px) scale(${mapScale})`;
    if (mapScroll) mapScroll.style.transform = t;
    else if (mapBg) mapBg.style.transform = t;
}

/** Centra el mapa táctico en la sede (NPC) de la banda. */
function resetTacticalMap(npc) {
    mapScale = 1;
    mapTransX = 0;
    mapTransY = 0;
    applyMapTransform();
    if (!mapContainer || !npc || npc.x == null || npc.y == null) return;
    requestAnimationFrame(() => {
        const rect = mapContainer.getBoundingClientRect();
        const w = rect.width || 1;
        const h = rect.height || 1;
        const { leftPct, topPct } = worldToMapPercent(npc.x, npc.y);
        const pinX = (leftPct / 100) * w;
        const pinY = (topPct / 100) * h;
        mapTransX = w * 0.5 - pinX;
        mapTransY = h * 0.5 - pinY;
        applyMapTransform();
    });
}

function renderTerritoryPins() {
    if (!territoryPins) return;
    territoryPins.innerHTML = '';
    const npc = currentGangData && currentGangData.npc_coords;
    if (npc && npc.x != null && npc.y != null) {
        const { leftPct, topPct } = worldToMapPercent(npc.x, npc.y);
        const hub = doc.createElement('div');
        hub.className = 'gm-map-pin gm-map-pin--npc';
        hub.style.left = `${leftPct}%`;
        hub.style.top = `${topPct}%`;
        const lbl = (gmLocales && gmLocales.ui_gm_map_npc_label) || 'SEDE';
        hub.innerHTML = `<span class="gm-map-pin-dot gm-map-pin-dot--npc"></span><span class="gm-map-pin-label">${lbl}</span>`;
        hub.title = (gmLocales && gmLocales.ui_gm_map_npc_title) || 'NPC de la banda';
        territoryPins.appendChild(hub);
    }
    const z = currentControlZone;
    if (z && z.x != null && z.y != null) {
        const { leftPct, topPct } = worldToMapPercent(z.x, z.y);
        const pin = doc.createElement('div');
        pin.className = 'gm-map-pin gm-map-pin--zone-center';
        pin.style.left = `${leftPct}%`;
        pin.style.top = `${topPct}%`;
        pin.innerHTML = `<span class="gm-map-pin-dot" style="background:#38bdf8;box-shadow:0 0 12px #38bdf8;"></span><span class="gm-map-pin-label">ZONA</span>`;
        pin.title = 'Centro de la zona guardada';
        territoryPins.appendChild(pin);
    }
    if (lastPlayerWorldCoords && lastPlayerWorldCoords.x != null) {
        const { leftPct, topPct } = worldToMapPercent(lastPlayerWorldCoords.x, lastPlayerWorldCoords.y);
        const you = doc.createElement('div');
        you.className = 'gm-map-pin gm-map-pin--you';
        you.style.left = `${leftPct}%`;
        you.style.top = `${topPct}%`;
        you.innerHTML = `<span class="gm-map-pin-dot" style="width:0.65rem;height:0.65rem;background:#22c55e;border:2px solid #fff;"></span><span class="gm-map-pin-label">TÚ</span>`;
        you.title = 'Tu posición';
        territoryPins.appendChild(you);
    }
    updateZoneSvg();
}

/* ====================================================
   CONFIG TAB LOGIC
==================================================== */
if (btnInviteMember) {
    btnInviteMember.onclick = () => {
        fillInviteRankSelect();
        const inp = doc.getElementById('gmInvitePlayerId');
        if (inp) inp.value = '';
        showGangModal(doc.getElementById('gmInviteModal'));
    };
}

if (btnManageRanks) {
    btnManageRanks.onclick = () => {
        const inp = doc.getElementById('gmNewRankNameInput');
        if (inp) inp.value = '';
        showGangModal(doc.getElementById('gmNewRankModal'));
    };
}

(function wireGangModals() {
    const invM = doc.getElementById('gmInviteModal');
    const btnIc = doc.getElementById('btnInviteCancel');
    const btnIo = doc.getElementById('btnInviteConfirm');
    if (btnIc && invM) btnIc.onclick = () => hideGangModal(invM);
    if (btnIo && invM) btnIo.onclick = () => {
        const id = doc.getElementById('gmInvitePlayerId');
        const sel = doc.getElementById('gmInviteRankSelect');
        const tid = id ? parseInt(id.value, 10) : NaN;
        const rankName = sel ? sel.value : '';
        if (!tid || tid < 1) {
            post('notifyError', { msg: 'Introduce un ID de jugador válido.' });
            return;
        }
        if (!rankName) {
            post('notifyError', { msg: 'Selecciona un rango.' });
            return;
        }
        post('submitInvite', { targetId: tid, rankName });
        hideGangModal(invM);
    };

    const nrM = doc.getElementById('gmNewRankModal');
    const btnNc = doc.getElementById('btnNewRankCancel');
    const btnNo = doc.getElementById('btnNewRankConfirm');
    if (btnNc && nrM) btnNc.onclick = () => hideGangModal(nrM);
    if (btnNo && nrM) btnNo.onclick = () => {
        const inp = doc.getElementById('gmNewRankNameInput');
        const name = inp ? inp.value.trim() : '';
        if (!name) {
            post('notifyError', { msg: 'Escribe un nombre para el rango.' });
            return;
        }
        post('submitNewRank', { rankName: name });
        hideGangModal(nrM);
    };
})();

// Config Placement Points
if (btnPlaceStash) {
    btnPlaceStash.onclick = () => post('placePoint', { type: 'stash' });
}

if (btnPlaceGarageMenu) {
    btnPlaceGarageMenu.onclick = () => post('placePoint', { type: 'garage_menu' });
}
if (btnPlaceGarageSpawn) {
    btnPlaceGarageSpawn.onclick = () => post('placePoint', { type: 'garage_spawn' });
}
if (btnPlaceGarageStore) {
    btnPlaceGarageStore.onclick = () => post('placePoint', { type: 'garage_store' });
}

if (btnPlaceBoss) {
    btnPlaceBoss.onclick = () => post('placePoint', { type: 'boss' });
}

const jgrGangGarageClose = doc.getElementById('jgrGangGarageClose');
if (jgrGangGarageClose) {
    jgrGangGarageClose.onclick = () => post('closeGangGarageStandalone', {});
}

function updateActivitiesUI(gang) {
    const stats = gang.stats || {};

    // Defs: xp thresholds and titles for activities
    const getActData = (actXp) => {
        const x = actXp || 0;
        if (x < 100) return { title: "PRINCIPIANTE", pct: (x / 100) * 100, nxt: "NOVATO" };
        if (x < 500) return { title: "NOVATO", pct: ((x - 100) / 400) * 100, nxt: "EXPERT" };
        if (x < 1500) return { title: "EXPERT", pct: ((x - 500) / 1000) * 100, nxt: "MAESTRO" };
        return { title: "MAESTRO", pct: 100, nxt: "MÁXIMO" };
    };

    // 1. Weed
    const weed = getActData(stats.weed);
    if (doc.getElementById('act_weed_badge')) doc.getElementById('act_weed_badge').innerText = weed.title;
    if (doc.getElementById('act_weed_cur')) doc.getElementById('act_weed_cur').innerText = weed.title;
    if (doc.getElementById('act_weed_nxt')) doc.getElementById('act_weed_nxt').innerText = weed.nxt;
    if (doc.getElementById('act_weed_fill')) doc.getElementById('act_weed_fill').style.width = `${weed.pct}%`;

    // 2. Meth
    const meth = getActData(stats.meth);
    if (doc.getElementById('act_meth_badge')) doc.getElementById('act_meth_badge').innerText = meth.title;
    if (doc.getElementById('act_meth_cur')) doc.getElementById('act_meth_cur').innerText = meth.title;
    if (doc.getElementById('act_meth_nxt')) doc.getElementById('act_meth_nxt').innerText = meth.nxt;
    if (doc.getElementById('act_meth_fill')) doc.getElementById('act_meth_fill').style.width = `${meth.pct}%`;

    // 3. Cocaine
    const coke = getActData(stats.coke);
    if (doc.getElementById('act_coke_badge')) doc.getElementById('act_coke_badge').innerText = coke.title;
    if (doc.getElementById('act_coke_cur')) doc.getElementById('act_coke_cur').innerText = coke.title;
    if (doc.getElementById('act_coke_nxt')) doc.getElementById('act_coke_nxt').innerText = coke.nxt;
    if (doc.getElementById('act_coke_fill')) doc.getElementById('act_coke_fill').style.width = `${coke.pct}%`;
}

/* =========================================================================
   GROW SHOP MODULE (PHASE 6) 
   ========================================================================= */

// Listeners
if (btnCloseGrowShop) {
    btnCloseGrowShop.addEventListener('click', () => {
        growShopWrapper.classList.add('hidden');
        // Hide the dark overlay (#app)
        const appDiv = doc.getElementById('app');
        if (appDiv) appDiv.style.display = 'none';

        const hud = doc.getElementById('deliveryHud');
        if (hud && hud.style.display !== 'none') {
            // Delivery active: keep body visible for the HUD only
            doc.body.style.display = 'flex';
        } else {
            doc.body.style.display = 'none';
        }
        post('closeGrowShop');
    });
}

gsNavBtns.forEach(btn => {
    btn.addEventListener('click', (e) => {
        // Remove active class from all
        gsNavBtns.forEach(b => b.classList.remove('active'));
        // Add to clicked
        const targetBtn = e.currentTarget;
        targetBtn.classList.add('active');

        // Switch views
        const targetId = targetBtn.getAttribute('data-target');
        gsViews.forEach(view => {
            if (view.id === targetId) {
                view.classList.remove('hidden');
                // Trigger reflow
                void view.offsetWidth;
                view.style.opacity = '1';
                view.style.pointerEvents = 'auto';
            } else {
                view.style.opacity = '0';
                view.style.pointerEvents = 'none';
                setTimeout(() => {
                    if (view.style.opacity === '0') {
                        view.classList.add('hidden');
                    }
                }, 300);
            }
        });
    });
});

// NUI Message Receiver for Grow Shop
window.addEventListener('message', (event) => {
    const data = event.data;
    if (data.action === "open_grow_shop") {
        openGrowShop(data.market, data.recipes, data.societyFunds);
    } else if (data.action === "update_grow_money") {
        if (gsSocietyMoney) gsSocietyMoney.innerText = `$${data.societyFunds}`;
        const gsSocietyFundsDetail = doc.getElementById('gsSocietyFundsDetail');
        if (gsSocietyFundsDetail) gsSocietyFundsDetail.innerText = `$${data.societyFunds}`;
    } else if (data.action === "update_grow_employees") {
        populateGrowShopEmployees(data.employees);
    }
    // ---- Delivery HUD Timer ----
    else if (data.action === "show_delivery_timer") {
        deliveryTotalSeconds = data.seconds;
        deliverySecondsLeft = data.seconds;
        const hud = doc.getElementById('deliveryHud');
        if (hud) {
            hud.style.display = 'block';
            doc.body.style.display = 'flex';
        }
        updateDeliveryHud();
    }
    else if (data.action === "update_delivery_timer") {
        deliverySecondsLeft = data.seconds;
        updateDeliveryHud();
    }
    else if (data.action === "hide_delivery_timer") {
        const hud = doc.getElementById('deliveryHud');
        if (hud) hud.style.display = 'none';
        // Hide everything since menu is also closed
        if (growShopWrapper && growShopWrapper.classList.contains('hidden')) {
            doc.body.style.display = 'none';
        }
    }
    // ---- Plant HUD ----
    else if (data.action === "show_plant_hud") {
        const hud = doc.getElementById('plantHud');
        if (!hud) return;
        doc.getElementById('plantName').innerText = data.name || 'Planta';
        doc.getElementById('plantStage').style.display = 'none';

        const growthPct = Math.min(100, Math.round(((data.stage - 1) / 5 * 100) + (data.elapsed / data.stageTime) * 20));
        doc.getElementById('plantGrowthBar').style.width = growthPct + '%';
        doc.getElementById('plantGrowthPct').innerText = growthPct + '%';

        const waterPct = Math.max(0, Math.min(100, data.water || 0));
        const waterBar = doc.getElementById('plantWaterBar');
        waterBar.style.width = waterPct + '%';
        waterBar.classList.toggle('low', waterPct < 25);
        doc.getElementById('plantWaterPct').innerText = waterPct + '%';

        hud.style.display = 'block';
        doc.body.style.display = 'flex';
        // Hide the main app overlay so only the HUD shows
        if (app) app.style.display = 'none';
    }
    else if (data.action === "update_plant_hud") {
        const growthPct = Math.min(100, Math.round(((data.stage - 1) / 5 * 100) + (data.elapsed / data.stageTime) * 20));
        doc.getElementById('plantGrowthBar').style.width = growthPct + '%';
        doc.getElementById('plantGrowthPct').innerText = growthPct + '%';

        const waterPct = Math.max(0, Math.min(100, data.water || 0));
        const waterBar = doc.getElementById('plantWaterBar');
        waterBar.style.width = waterPct + '%';
        waterBar.classList.toggle('low', waterPct < 25);
        doc.getElementById('plantWaterPct').innerText = waterPct + '%';
    }
    else if (data.action === "hide_plant_hud") {
        const hud = doc.getElementById('plantHud');
        if (hud) hud.style.display = 'none';
        // Restore app and hide body if nothing else is open
        if (app) app.style.display = '';
        const deliveryHud = doc.getElementById('deliveryHud');
        const deliveryVisible = deliveryHud && deliveryHud.style.display !== 'none';
        if (!deliveryVisible) {
            doc.body.style.display = 'none';
        }
    }
});

function updateDeliveryHud() {
    const countdown = doc.getElementById('deliveryCountdown');
    const progressBar = doc.getElementById('deliveryProgressBar');
    if (!countdown || !progressBar) return;

    const mins = Math.floor(deliverySecondsLeft / 60);
    const secs = deliverySecondsLeft % 60;
    countdown.innerText = `${mins}:${secs < 10 ? '0' : ''}${secs}`;

    const pct = deliveryTotalSeconds > 0 ? (deliverySecondsLeft / deliveryTotalSeconds) * 100 : 0;
    progressBar.style.width = `${pct}%`;
}

function populateWholesale(items) {
    if (!gsWholesaleGrid) return;
    gsWholesaleGrid.innerHTML = '';

    if (!items || items.length === 0) {
        gsWholesaleGrid.innerHTML = '<p style="color:var(--text-muted);">No hay stock disponible en el mercado mayorista.</p>';
        return;
    }

    items.forEach(item => {
        const card = doc.createElement('div');
        card.className = 'gs-item-card';
        // QBCore default inventory image path pattern usually: nvep_inventory/html/images/ or similar. We will just pass the basic name.
        card.innerHTML = `
            <img src="assets/items/${item.item}.png" class="gs-item-img" onerror="this.style.display='none'">
            <h4 class="gs-item-title">${item.label}</h4>
            <span class="gs-item-price">$${item.price}</span>
            <div style="display:flex; gap:10px; width:100%;">
                <input type="number" id="qty_buy_${item.item}" class="admin-input" value="1" min="1" style="width:60px; text-align:center; background: rgba(255,255,255,0.1); border: 1px solid rgba(255,255,255,0.2); color:white; border-radius:4px;">
                <button class="btn btn-primary" style="flex:1; justify-content:center; background: rgba(16, 185, 129, 0.2); border: 1px solid #10b981; color: #10b981;" onclick="addToCart('${item.item}', ${item.price}, '${item.label}')">
                    <i class="fa-solid fa-cart-shopping"></i> Pedir
                </button>
            </div>
        `;
        gsWholesaleGrid.appendChild(card);
    });
}

function addToCart(itemName, price, label) {
    const qtyInput = doc.getElementById(`qty_buy_${itemName}`);
    const amount = parseInt(qtyInput.value) || 1;

    // Create a new reference to trigger the Proxy set
    const newItems = { ...reactiveCart.items };

    if (newItems[itemName]) {
        newItems[itemName].qty += amount;
    } else {
        newItems[itemName] = { qty: amount, price: price, label: label };
    }

    reactiveCart.items = newItems;
}

function renderCartUI() {
    const cartList = doc.getElementById('cartList');
    const cartTotal = doc.getElementById('cartTotal');
    if (!cartList || !cartTotal) return;

    cartList.innerHTML = '';
    let total = 0;

    const keys = Object.keys(reactiveCart.items);
    if (keys.length === 0) {
        cartList.innerHTML = '<p style="color:var(--text-muted); text-align:center; margin-top:20px;">Tu carrito está vacío.</p>';
        cartTotal.innerText = '$0';
        return;
    }

    keys.forEach(key => {
        const item = reactiveCart.items[key];
        total += item.qty * item.price;

        const el = doc.createElement('div');
        el.style = "display: flex; justify-content: space-between; align-items: center; background: rgba(255,255,255,0.05); padding: 10px; border-radius: 6px;";
        el.innerHTML = `
            <div>
                <span style="color: white; font-weight: bold; display: block;">${item.label}</span>
                <span style="color: var(--text-muted); font-size: 0.8rem;">$${item.price} c/u</span>
            </div>
            <div style="display: flex; align-items: center; gap: 10px;">
                <span style="color: #10b981; font-weight: bold;">x${item.qty}</span>
                <button title="Quitar 1" style="background:transparent; border:none; color:#ef4444; cursor:pointer;" onclick="removeFromCart('${key}')"><i class="fa-solid fa-minus"></i></button>
            </div>
        `;
        cartList.appendChild(el);
    });

    // Format total with commas
    cartTotal.innerText = '$' + total.toLocaleString();
}

function removeFromCart(itemName) {
    const newItems = { ...reactiveCart.items };
    if (newItems[itemName]) {
        newItems[itemName].qty -= 1;
        if (newItems[itemName].qty <= 0) {
            delete newItems[itemName];
        }
    }
    reactiveCart.items = newItems;
}

function checkoutCart() {
    if (Object.keys(reactiveCart.items).length === 0) return;
    post('checkoutGrowShopCart', { cart: reactiveCart.items });
    reactiveCart.items = {}; // Clear cart after sending
}

function populateCrafting(recipes) {
    if (!gsRecipeList) return;
    gsRecipeList.innerHTML = '';
    currentRecipes = recipes;

    Object.keys(recipes).forEach(recipeId => {
        const recipe = recipes[recipeId];
        const card = doc.createElement('div');
        card.className = 'gs-recipe-card';
        card.id = `recipe_card_${recipeId}`;
        card.innerHTML = `
            <span class="gs-recipe-title">${recipe.label}</span>
            <span class="gs-recipe-yield">x${recipe.amount}</span>
        `;
        card.onclick = () => selectRecipe(recipeId);
        gsRecipeList.appendChild(card);
    });

    // Clear details pane
    if (gsRecipeDetails) {
        gsRecipeDetails.innerHTML = `
            <div style="text-align: center; margin-top: 50px; color: var(--text-muted);">
              <i class="fa-solid fa-flask" style="font-size: 4rem; opacity: 0.2; margin-bottom: 20px;"></i>
              <h3>Selecciona una receta</h3>
            </div>
        `;
    }
}

function selectRecipe(recipeId) {
    // Visual selection
    doc.querySelectorAll('.gs-recipe-card').forEach(c => c.classList.remove('active'));
    doc.getElementById(`recipe_card_${recipeId}`).classList.add('active');

    selectedRecipeId = recipeId;
    const recipe = currentRecipes[recipeId];

    if (!gsRecipeDetails) return;

    let reqsHtml = '';
    recipe.required.forEach(req => {
        reqsHtml += `
            <div class="gs-req-item">
                <img src="assets/items/${req.item}.png" onerror="this.style.display='none'">
                <div class="gs-req-info">
                    <span class="gs-req-name">${req.item}</span>
                    <span class="gs-req-desc">Material requerido</span>
                </div>
                <span class="gs-req-amount">x${req.amount}</span>
            </div>
        `;
    });

    gsRecipeDetails.innerHTML = `
        <div style="display:flex; justify-content:space-between; align-items:center; border-bottom: 1px solid rgba(168, 85, 247, 0.3); padding-bottom: 15px; margin-bottom: 20px;">
            <div style="display:flex; align-items:center; gap:15px;">
                <img src="assets/items/${recipeId}.png" style="width:60px; height:60px; object-fit:contain; filter:drop-shadow(0 0 10px rgba(168,85,247,0.5));" onerror="this.style.display='none'">
                <div>
                    <h3 style="color:white; font-family:var(--font-heading); font-size:1.5rem; margin:0;">${recipe.label}</h3>
                    <span style="color:var(--text-muted); font-size:0.9rem;">Rendimiento de producción: <strong style="color:#a855f7;">${recipe.amount} Unidades</strong></span>
                </div>
            </div>
        </div>
        
        <h4 style="color:rgba(255,255,255,0.8); margin-bottom:15px; font-size:1.1rem;"><i class="fa-solid fa-clipboard-list" style="color:#a855f7; margin-right:8px;"></i> Requisitos</h4>
        <div style="flex:1; overflow-y:auto; padding-right:10px;">
            ${reqsHtml}
        </div>
        
        <div style="margin-top:20px; border-top: 1px solid rgba(168, 85, 247, 0.3); padding-top:20px; display:flex; gap:15px; align-items:center;">
            <div style="display:flex; flex-direction:column; gap:5px;">
                <label style="color:var(--text-muted); font-size:0.8rem;">Lotes a fabricar</label>
                <input type="number" id="qty_craft_${recipeId}" class="admin-input" value="1" min="1" style="width:80px; text-align:center; background: rgba(0,0,0,0.5); border: 1px solid rgba(168, 85, 247, 0.5); color:white; border-radius:4px; padding:10px; font-size:1.1rem;">
            </div>
            <button class="btn btn-primary" style="flex:1; justify-content:center; background: rgba(168, 85, 247, 0.2); border: 1px solid #a855f7; color: #d8b4fe; font-size:1.1rem; padding:15px;" onclick="craftGrowItem('${recipeId}')">
                <i class="fa-solid fa-fire-burner"></i> Iniciar Producción
            </button>
        </div>
    `;
}

function craftGrowItem(recipeId) {
    const qtyInput = doc.getElementById(`qty_craft_${recipeId}`);
    const batches = parseInt(qtyInput.value) || 1;
    post('craftGrowItem', { recipeId: recipeId, batches: batches });
}

// ==========================================
// GROW SHOP MANAGEMENT (PHASE 7)
// ==========================================

function openGrowShop(market, recipes, funds) {
    doc.body.style.display = 'flex';
    // Restore #app overlay for the menu
    const appDiv = doc.getElementById('app');
    if (appDiv) appDiv.style.display = 'flex';
    if (growShopWrapper) {
        growShopWrapper.classList.remove('hidden');
    }

    if (gsSocietyMoney) gsSocietyMoney.innerText = `$${funds}`;
    const gsSocietyFundsDetail = doc.getElementById('gsSocietyFundsDetail');
    if (gsSocietyFundsDetail) gsSocietyFundsDetail.innerText = `$${funds}`;

    populateWholesale(market);
    populateCrafting(recipes);

    // Fetch employees whenever the boss menu is opened
    post('getGrowShopEmployees');
}

function manageFunds(action) {
    const input = doc.getElementById('gsFundAmount');
    if (!input) return;
    const amount = parseInt(input.value);

    if (isNaN(amount) || amount <= 0) {
        return; // Alternatively, we could notify the player via an event, but ignoring is fine
    }

    if (action === 'deposit') {
        post('manageGrowShopFunds', { action: 'deposit', amount: amount });
    } else if (action === 'withdraw') {
        post('manageGrowShopFunds', { action: 'withdraw', amount: amount });
    }

    // Clear input
    input.value = '';
}

function populateGrowShopEmployees(employees) {
    const list = doc.getElementById('gsEmployeeList');
    if (!list) return;

    list.innerHTML = '';

    if (!employees || employees.length === 0) {
        list.innerHTML = '<p style="color:var(--text-muted); text-align:center;">No hay empleados en plantilla.</p>';
        return;
    }

    employees.forEach(emp => {
        let name = emp.name;
        // In QBCore, name is mostly stored in JSON charinfo for modern setups or as distinct columns, we expect the server to send a proper string.
        const card = doc.createElement('div');
        card.style = "background: rgba(255,255,255,0.05); border: 1px solid rgba(255,255,255,0.1); border-radius: 8px; padding: 15px; display: flex; justify-content: space-between; align-items: center;";

        card.innerHTML = `
            <div>
                <h4 style="color: white; margin: 0; font-size: 1.1rem;">${name}</h4>
                <span style="color: var(--text-muted); font-size: 0.85rem;"><i class="fa-solid fa-briefcase" style="color: #3b82f6;"></i> ${emp.gradeLabel} (Nivel ${emp.gradeLevel})</span>
            </div>
            <div style="display: flex; gap: 8px;">
                <button class="btn btn-primary" title="Ascender/Manejar" style="background: rgba(59, 130, 246, 0.2); border: 1px solid #3b82f6; color: #3b82f6; padding: 8px;" onclick="promoteEmployee('${emp.citizenid}')">
                    <i class="fa-solid fa-arrow-up"></i>
                </button>
                <button class="btn btn-danger" title="Despedir" style="background: rgba(239, 68, 68, 0.2); border: 1px solid #ef4444; color: #ef4444; padding: 8px;" onclick="fireEmployee('${emp.citizenid}')">
                    <i class="fa-solid fa-user-xmark"></i>
                </button>
            </div>
        `;
        list.appendChild(card);
    });
}

function hireEmployee() {
    post('hireGrowShopEmployee');
}

function fireEmployee(citizenid) {
    post('fireGrowShopEmployee', { citizenid: citizenid });
}

function promoteEmployee(citizenid) {
    post('promoteGrowShopEmployee', { citizenid: citizenid });
}
