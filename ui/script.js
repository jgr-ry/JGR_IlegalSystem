// NUI State Variables
let configData = {};
let translations = {};
let selectedSpecialization = null;

// DOM Elements
const doc = document;
const app = doc.getElementById('app');
const step1 = doc.getElementById('step1');
const step3 = doc.getElementById('step3');
const step4 = doc.getElementById('step4');
const adminPanel = doc.getElementById('adminPanel');

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

// Dynamic Containers
const permsList = doc.getElementById('permissionsList');
const specGrid = doc.getElementById('specializationsGrid');
const gangColor = doc.getElementById('gangColor');


// Data state
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
        doc.body.style.display = "flex";
    }
    else if (data.action === "open_specialization_step") {
        buildSpecializations(data.specializations);

        showStep(3);
        doc.body.style.display = "flex";
    }
    // Phase 1.5: 3D Control Prompt
    else if (data.action === "open_step_2_controls") {
        showStep(0); // Hide all steps
        doc.getElementById('step2Controls').classList.remove('hidden');
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
        adminConfig = data.config;
        adminLocales = data.locales;
        app.classList.remove('hidden');
        showStep('admin');
        renderAdminPanel();
        doc.body.style.display = "flex";
    }
    // Phase 4: Gang Management Menu
    else if (data.action === "open_gang_menu") {
        app.style.background = "transparent";
        app.style.backdropFilter = "none";
        app.classList.remove('hidden');
        showStep('gangMenu');
        populateGangMenu(data.gang, data.permissions, data.translations);
        doc.body.style.display = "flex";
    }
    // Hide gang menu (called from Lua when opening dialogs)
    else if (data.action === "hide_gang_menu") {
        doc.getElementById('gangMenuWrapper').classList.add('hidden');
        doc.body.style.display = "none";
    }
    // Update ranks panel (instant visual refresh after create/delete)
    else if (data.action === "update_ranks") {
        renderRanksPanel(data.ranks || {});
    }
    // Update documents panel
    else if (data.action === "update_documents") {
        currentDocuments = data.documents || [];
        renderDocList();
    }
});

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

// Callbacks to Client
function post(event, data) {
    fetch(`https://${window.GetParentResourceName()}/${event}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {})
    }).catch(e => console.log(e));
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
const btnCloseAdmin = doc.getElementById('btnCloseAdmin');
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
let currentEditGang = null;
const editModal = doc.getElementById('editLimitModal');
const editModalInput = doc.getElementById('editModalInput');
const btnCancelEdit = doc.getElementById('btnCancelEdit');
const btnConfirmEdit = doc.getElementById('btnConfirmEdit');

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
let currentDeleteGang = null;
const deleteModal = doc.getElementById('deleteConfirmModal');
const btnCancelDelete = doc.getElementById('btnCancelDelete');
const btnConfirmDelete = doc.getElementById('btnConfirmDelete');

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
let currentGangData = null;
let currentPlayerPerms = null;
let gmLocales = {};

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

    safeSet('t_cam_header', 'ui_gm_t_cam_header');
    safeSet('t_cam_empty', 'ui_gm_t_cam_empty');
    safeSet('t_cam_desc', 'ui_gm_t_cam_desc');

    safeSet('t_doc_header', 'ui_gm_t_doc_header');
    safeSet('t_doc_new', 'ui_gm_t_doc_new');
    safeSet('t_doc_viewer', 'ui_gm_t_doc_viewer');
    safeSet('t_doc_save', 'ui_gm_t_doc_save');

    safeSet('t_cfg_members', 'ui_gm_t_cfg_members');
    safeSet('t_cfg_invite', 'ui_gm_t_cfg_invite');
    safeSet('t_cfg_settings', 'ui_gm_t_cfg_settings');
}

function populateGangMenu(gang, perms, translationsData) {
    currentGangData = gang;
    currentPlayerPerms = perms;
    gmLocales = translationsData || {};

    applyGangMenuTranslations();

    // Load documents
    currentDocuments = gang.documents || [];
    editingDocId = null;
    renderDocList();
    if (gmDocTitle) gmDocTitle.value = '';
    if (gmDocContent) gmDocContent.value = '';

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

    // Default to Dashboard
    switchGMView('gmViewDashboard');

    // Load members into config list
    const cfgList = doc.getElementById('gmConfigMembersList');
    if (cfgList) {
        cfgList.innerHTML = '';
        if (gang.members && gang.members.length > 0) {
            gang.members.forEach(m => {
                cfgList.innerHTML += `
                    <div class="gm-manage-row" style="display:flex; justify-content:space-between; align-items:center; background:rgba(255,255,255,0.05); padding:10px 15px; border-radius:8px;">
                        <div>
                            <span style="color:white; font-family:var(--font-heading);">${m.name || m.citizenid}</span><br>
                            <span class="badge gm-badge-blue mt-1" style="display:inline-block; margin-top:5px;">${m.rank}</span>
                        </div>
                        <div style="display:flex; gap:5px;">
                            <button class="btn btn-danger" onclick="post('kickMemberReq', {id: '${m.citizenid}'})" style="padding:5px 10px; font-size:0.8rem;" title="Expulsar"><i class="fa-solid fa-user-xmark"></i></button>
                        </div>
                    </div>
                `;
            });
        } else {
            cfgList.innerHTML = '<p style="text-align:center; color:var(--text-muted); font-size:0.9rem;">No hay miembros.</p>';
        }
    }

    // Load ranks into config panel
    currentGangRanks = gang.ranks || {};
    renderRanksPanel(currentGangRanks);
}

function renderRanksPanel(ranks) {
    const ranksList = doc.getElementById('gmRanksList');
    if (!ranksList) return;
    ranksList.innerHTML = '';
    const rankNames = Object.keys(ranks);
    if (rankNames.length > 0) {
        rankNames.forEach(rName => {
            const r = ranks[rName];
            const isBoss = r.isBoss || false;
            const el = document.createElement('div');
            el.style.cssText = 'display:flex; justify-content:space-between; align-items:center; background:rgba(255,255,255,0.05); padding:10px 15px; border-radius:8px; border: 1px solid rgba(255,255,255,0.08); transition: all 0.2s;';
            el.innerHTML = `
                    <div style="display:flex; align-items:center; gap:10px;">
                        <i class="fa-solid ${isBoss ? 'fa-crown' : 'fa-shield-halved'}" style="color: ${isBoss ? '#f59e0b' : 'var(--gang-color, #a855f7)'}; font-size: 1.1rem;"></i>
                        <div>
                            <span style="color:white; font-weight:600; font-family:var(--font-heading); font-size:0.95rem;">${rName}</span>
                            ${isBoss ? '<br><span style="color:#f59e0b; font-size:0.7rem; text-transform:uppercase; letter-spacing:1px;">JEFE</span>' : ''}
                        </div>
                    </div>
                    <div style="display:flex; gap:5px;">
                        ${!isBoss ? `<button class="btn btn-primary" onclick="openRankPerms('${rName}')" style="padding:4px 10px; font-size:0.75rem; background:rgba(255,255,255,0.1);" title="Editar permisos"><i class="fa-solid fa-pen-to-square"></i></button>` : ''}
                        ${!isBoss ? `<button class="btn btn-danger" onclick="post('deleteRankReq', {rank: '${rName}'})" style="padding:4px 10px; font-size:0.75rem;" title="Eliminar rango"><i class="fa-solid fa-trash"></i></button>` : '<span style="color:var(--text-muted); font-size:0.7rem;">ADMINISTRADOR</span>'}
                    </div>
                `;
            el.onmouseenter = () => { el.style.borderColor = 'var(--gang-color, #a855f7)'; };
            el.onmouseleave = () => { el.style.borderColor = 'rgba(255,255,255,0.08)'; };
            ranksList.appendChild(el);
        });
    } else {
        ranksList.innerHTML = '<p style="text-align:center; color:var(--text-muted); font-size:0.9rem;">No hay rangos configurados.</p>';
    }
}

let currentEditingRank = null;
let currentGangRanks = {};

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
        { id: 'manage_members', label: 'Gestionar Miembros', icon: 'fa-users-gear' },
        { id: 'manage_points', label: 'Gestionar Puntos (Sedes)', icon: 'fa-location-dot' },
        { id: 'manage_ranks', label: 'Gestionar Rangos', icon: 'fa-layer-group' },
        { id: 'manage_docs', label: 'Gestionar Documentos', icon: 'fa-file-signature' }
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

function closeRankPerms() {
    const modal = doc.getElementById('gmRankPermissionsModal');
    if (modal) {
        modal.classList.add('hidden');
        modal.style.display = 'none';
    }
}

doc.getElementById('btnSavePerms').onclick = () => {
    if (!currentEditingRank) return;

    const newPerms = {
        manage_members: doc.getElementById('perm_manage_members').checked,
        manage_points: doc.getElementById('perm_manage_points').checked,
        manage_ranks: doc.getElementById('perm_manage_ranks').checked,
        manage_docs: doc.getElementById('perm_manage_docs').checked
    };

    post('updateRankPermsReq', { rank: currentEditingRank, permissions: newPerms });
    closeRankPerms();
};

// Nav Logic
const navButtons = doc.querySelectorAll('.gm-nav-btn');
navButtons.forEach(btn => {
    btn.addEventListener('click', () => {
        const targetId = btn.getAttribute('data-target');
        switchGMView(targetId);
    });
});

function switchGMView(viewId) {
    const views = doc.querySelectorAll('.gm-view');

    // Smooth transition
    views.forEach(v => {
        if (v.id !== viewId) {
            v.style.opacity = '0';
            v.style.pointerEvents = 'none';
            setTimeout(() => {
                if (v.id !== doc.querySelector('.gm-view[style*="opacity: 1"]').id) {
                    v.classList.add('hidden');
                }
            }, 300);
        }
    });

    const target = doc.getElementById(viewId);
    if (target) {
        target.classList.remove('hidden');
        // Trigger reflow
        void target.offsetWidth;
        target.style.opacity = '1';
        target.style.pointerEvents = 'auto';
    }

    // Toggle back button visibility depending on active view
    const backBtn = doc.getElementById('btnBackGangMenu');
    if (backBtn) {
        if (viewId === 'gmViewDashboard') {
            backBtn.classList.add('hidden');
        } else {
            backBtn.classList.remove('hidden');
        }
    }
}

// Back Button logic
const btnBackGM = doc.getElementById('btnBackGangMenu');
if (btnBackGM) {
    btnBackGM.onclick = () => {
        switchGMView('gmViewDashboard');
    };
}

// Close Menu Btn
doc.getElementById('btnCloseGangMenu').onclick = () => {
    doc.body.style.display = "none";
    doc.getElementById('gangMenuWrapper').classList.add('hidden');
    post('closeUI');
};

/* ====================================================
   DOCUMENTS TAB LOGIC
==================================================== */
const btnNewDoc = doc.getElementById('btnNewDoc');
const gmDocTitle = doc.getElementById('gmDocTitle');
const gmDocContent = doc.getElementById('gmDocContent');
const gmBtnSaveDoc = doc.getElementById('gmBtnSaveDoc');
const gmBtnDeleteDoc = doc.getElementById('gmBtnDeleteDoc');
const gmDocList = doc.getElementById('gmDocList');

let currentDocuments = [];
let editingDocId = null;

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
            if (gmDocTitle) gmDocTitle.value = d.title;
            if (gmDocContent) gmDocContent.value = d.content;
        };
        gmDocList.appendChild(el);
    });
}

if (btnNewDoc) {
    btnNewDoc.onclick = () => {
        editingDocId = null;
        if (gmDocTitle) gmDocTitle.value = '';
        if (gmDocContent) gmDocContent.value = '';
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
    };
}

/* ====================================================
   TERRITORIES MAP LOGIC (DRAG & ZOOM)
==================================================== */
const mapContainer = doc.getElementById('gmMapContainer');
const mapBg = doc.getElementById('gmMapBg');
const mapMock = doc.getElementById('gmMapMockPoint');

let mapScale = 1;
let mapPanning = false;
let mapStartX = 0, mapStartY = 0;
let mapTransX = 0, mapTransY = 0;

if (mapContainer && mapBg) {
    // Zoom
    mapContainer.addEventListener('wheel', (e) => {
        e.preventDefault();
        const zoomAmount = 0.1;
        if (e.deltaY < 0) mapScale = Math.min(mapScale + zoomAmount, 3);
        else mapScale = Math.max(mapScale - zoomAmount, 0.5);
        applyMapTransform();
    });

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
    if (mapBg) mapBg.style.transform = `translate(${mapTransX}px, ${mapTransY}px) scale(${mapScale})`;
    if (mapMock) mapMock.style.transform = `translate(${mapTransX}px, ${mapTransY}px) scale(${mapScale})`;
}

/* ====================================================
   CONFIG TAB LOGIC
==================================================== */
const btnInviteMember = doc.getElementById('btnInviteMember');
if (btnInviteMember) {
    btnInviteMember.onclick = () => {
        post('inviteMemberReq');
    }
}

const btnManageRanks = doc.getElementById('btnManageRanks');
if (btnManageRanks) {
    btnManageRanks.onclick = () => {
        post('manageRanksReq');
    }
}

// Config Placement Points
const btnPlaceStash = doc.getElementById('btnPlaceStash');
if (btnPlaceStash) {
    btnPlaceStash.onclick = () => post('placePoint', { type: 'stash' });
}

const btnPlaceGarage = doc.getElementById('btnPlaceGarage');
if (btnPlaceGarage) {
    btnPlaceGarage.onclick = () => post('placePoint', { type: 'garage' });
}

const btnPlaceBoss = doc.getElementById('btnPlaceBoss');
if (btnPlaceBoss) {
    btnPlaceBoss.onclick = () => post('placePoint', { type: 'boss' });
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

// DOM Elements
const growShopWrapper = doc.getElementById('growShopWrapper');
const btnCloseGrowShop = doc.getElementById('btnCloseGrowShop');
const gsNavBtns = doc.querySelectorAll('.gs-nav-btn');
const gsViews = doc.querySelectorAll('.gs-view');
const gsWholesaleGrid = doc.getElementById('gsWholesaleGrid');
const gsRecipeList = doc.getElementById('gsRecipeList');
const gsRecipeDetails = doc.getElementById('gsRecipeDetails');
const gsSocietyMoney = doc.getElementById('gsSocietyMoney');

let currentRecipes = {};
let selectedRecipeId = null;

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

let deliveryTotalSeconds = 0;
let deliverySecondsLeft = 0;

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

// --- Cart Reactivity Proxy ---
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
