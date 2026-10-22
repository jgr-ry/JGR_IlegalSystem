--[[
    JGR_IlegalSystem · Bridge de servidor
    ------------------------------------------------------------------------
    Jugadores, permisos, trabajos, dinero, inventario y stashes para
    QBCore, Qbox, ESX Legacy y standalone/ox_core.

    Identificador de personaje que se guarda en la base de datos:
      QBCore / Qbox → citizenid
      ESX           → xPlayer.identifier
      Standalone    → license (GetPlayerIdentifierByType)
]]

local FW = Bridge.Framework

local function core() return Bridge.GetCore() end

-- ---------------------------------------------------------------------------
-- Jugadores
-- ---------------------------------------------------------------------------
--- Objeto de jugador del framework (o nil en standalone).
function Bridge.GetPlayer(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    if FW == 'qb' then
        local c = core()
        return c and c.Functions.GetPlayer(src) or nil
    elseif FW == 'qbx' then
        return exports.qbx_core:GetPlayer(src)
    elseif FW == 'esx' then
        local c = core()
        return c and c.GetPlayerFromId(src) or nil
    end
    return nil
end

local function standaloneIdentifier(src)
    local id = GetPlayerIdentifierByType(tostring(src), 'license')
        or GetPlayerIdentifierByType(tostring(src), 'license2')
    if id then return id end
    for _, ident in ipairs(GetPlayerIdentifiers(tostring(src))) do
        if ident:find('^license') then return ident end
    end
    return nil
end

--- Identificador persistente del personaje (citizenid / identifier / license).
function Bridge.GetIdentifier(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    if FW == 'qb' or FW == 'qbx' then
        local p = Bridge.GetPlayer(src)
        return p and p.PlayerData and p.PlayerData.citizenid or nil
    elseif FW == 'esx' then
        local p = Bridge.GetPlayer(src)
        return p and p.identifier or nil
    end
    if not GetPlayerName(src) then return nil end
    return standaloneIdentifier(src)
end

--- Nombre del personaje (o el nombre de FiveM si no hay framework).
function Bridge.GetCharName(src)
    if FW == 'qb' or FW == 'qbx' then
        local p = Bridge.GetPlayer(src)
        local ci = p and p.PlayerData and p.PlayerData.charinfo
        if ci and ci.firstname then return ('%s %s'):format(ci.firstname, ci.lastname or '') end
    elseif FW == 'esx' then
        local p = Bridge.GetPlayer(src)
        if p and p.getName then return p.getName() end
    end
    return GetPlayerName(src) or tostring(src)
end

--- Server ID de un jugador conectado a partir de su identificador, o nil.
function Bridge.GetSourceFromIdentifier(identifier)
    if not identifier then return nil end
    if FW == 'qb' then
        local c = core()
        local p = c and c.Functions.GetPlayerByCitizenId(identifier)
        return p and p.PlayerData.source or nil
    elseif FW == 'qbx' then
        local p = exports.qbx_core:GetPlayerByCitizenId(identifier)
        return p and p.PlayerData.source or nil
    elseif FW == 'esx' then
        local c = core()
        local p = c and c.GetPlayerFromIdentifier(identifier)
        return p and p.source or nil
    end
    for _, pid in ipairs(GetPlayers()) do
        if standaloneIdentifier(pid) == identifier then return tonumber(pid) end
    end
    return nil
end

function Bridge.IsOnline(src)
    src = tonumber(src)
    return src ~= nil and src > 0 and GetPlayerName(src) ~= nil
end

-- ---------------------------------------------------------------------------
-- Permisos
-- ---------------------------------------------------------------------------
--- Administrador: consola, ACE `jgr_ilegalsystem.admin` o el sistema de permisos del framework.
function Bridge.IsAdmin(src)
    src = tonumber(src)
    if src == 0 then return true end
    if not src then return false end
    if IsPlayerAceAllowed(src, 'jgr_ilegalsystem.admin') then return true end

    if FW == 'qb' then
        local c = core()
        if c and (c.Functions.HasPermission(src, 'admin') or c.Functions.HasPermission(src, 'god')) then
            return true
        end
    elseif FW == 'qbx' then
        if IsPlayerAceAllowed(src, 'group.admin') then return true end
        local ok, allowed = pcall(function() return exports.qbx_core:HasPermission(src, 'admin') end)
        if ok and allowed then return true end
    elseif FW == 'esx' then
        local p = Bridge.GetPlayer(src)
        local group = p and p.getGroup and p.getGroup()
        if group == 'admin' or group == 'superadmin' then return true end
    else
        if IsPlayerAceAllowed(src, 'command') then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Notificaciones
-- ---------------------------------------------------------------------------
local OX_TYPES = { primary = 'inform', info = 'inform', inform = 'inform', success = 'success', error = 'error', warning = 'warning' }

function Bridge.Notify(src, msg, nType)
    src = tonumber(src)
    msg = tostring(msg or '')
    nType = nType or 'primary'
    if not src or src <= 0 then
        print(('[JGR_IlegalSystem] %s'):format(msg))
        return
    end
    if FW == 'qb' then
        TriggerClientEvent('QBCore:Notify', src, msg, nType)
    elseif FW == 'qbx' then
        local ok = pcall(function() exports.qbx_core:Notify(src, msg, OX_TYPES[nType] or 'inform') end)
        if not ok then TriggerClientEvent('ox_lib:notify', src, { description = msg, type = OX_TYPES[nType] or 'inform' }) end
    elseif FW == 'esx' then
        TriggerClientEvent('esx:showNotification', src, msg, nType)
    else
        TriggerClientEvent('ox_lib:notify', src, { description = msg, type = OX_TYPES[nType] or 'inform' })
    end
end

-- ---------------------------------------------------------------------------
-- Trabajos
-- ---------------------------------------------------------------------------
--- @return table|nil { name, grade (número), gradeName, label }
function Bridge.GetJob(src)
    if FW == 'qb' or FW == 'qbx' then
        local p = Bridge.GetPlayer(src)
        local job = p and p.PlayerData and p.PlayerData.job
        if not job then return nil end
        local grade = type(job.grade) == 'table' and job.grade or {}
        return {
            name = job.name,
            label = job.label,
            grade = tonumber(grade.level) or tonumber(job.grade) or 0,
            gradeName = grade.name or '',
        }
    elseif FW == 'esx' then
        local p = Bridge.GetPlayer(src)
        local job = p and p.getJob and p.getJob()
        if not job then return nil end
        return {
            name = job.name,
            label = job.label,
            grade = tonumber(job.grade) or 0,
            gradeName = job.grade_name or job.grade_label or '',
        }
    end
    return nil
end

function Bridge.SetJob(src, jobName, grade)
    local p = Bridge.GetPlayer(src)
    if not p then return false end
    if FW == 'qb' or FW == 'qbx' then
        return p.Functions.SetJob(jobName, grade or 0) ~= false
    elseif FW == 'esx' then
        p.setJob(jobName, grade or 0)
        return true
    end
    return false
end

--- Lista de empleados (conectados o no) de un trabajo.
--- @return table[] { identifier, name, gradeLevel, gradeLabel }
function Bridge.GetJobEmployees(jobName)
    local list = {}
    if FW == 'qb' or FW == 'qbx' then
        local rows = MySQL.query.await('SELECT citizenid, charinfo, job FROM players WHERE job LIKE ?', { '%"' .. jobName .. '"%' }) or {}
        for _, row in ipairs(rows) do
            local job = Bridge.Util.SafeDecode(row.job, {})
            if job.name == jobName then
                local ci = Bridge.Util.SafeDecode(row.charinfo, {})
                local grade = type(job.grade) == 'table' and job.grade or {}
                list[#list + 1] = {
                    identifier = row.citizenid,
                    name = ci.firstname and ((ci.firstname or '') .. ' ' .. (ci.lastname or '')) or 'Desconocido',
                    gradeLevel = tonumber(grade.level) or 0,
                    gradeLabel = grade.name or '',
                }
            end
        end
    elseif FW == 'esx' then
        local rows = MySQL.query.await('SELECT identifier, firstname, lastname, job_grade FROM users WHERE job = ?', { jobName }) or {}
        for _, row in ipairs(rows) do
            list[#list + 1] = {
                identifier = row.identifier,
                name = row.firstname and ((row.firstname or '') .. ' ' .. (row.lastname or '')) or 'Desconocido',
                gradeLevel = tonumber(row.job_grade) or 0,
                gradeLabel = tostring(row.job_grade or 0),
            }
        end
    else
        Bridge.WarnOnce('employees', 'La lista de empleados no está disponible en modo standalone (se usan permisos ACE).')
    end
    return list
end

--- Despide a un empleado desconectado. Solo si su trabajo actual es `jobName`.
function Bridge.FireOfflineEmployee(identifier, jobName)
    if FW == 'qb' then
        local rows = MySQL.query.await('SELECT job FROM players WHERE citizenid = ?', { identifier })
        if not rows or not rows[1] then return false end
        local job = Bridge.Util.SafeDecode(rows[1].job, {})
        if job.name ~= jobName then return false end
        job.name = 'unemployed'
        job.label = 'Civil'
        job.payment = 10
        job.onduty = true
        job.isboss = false
        job.grade = { name = 'Sin Asignar', level = 0 }
        MySQL.update.await('UPDATE players SET job = ? WHERE citizenid = ?', { json.encode(job), identifier })
        return true
    elseif FW == 'qbx' then
        local ok = pcall(function() exports.qbx_core:RemovePlayerFromJob(identifier, jobName) end)
        if not ok then
            Bridge.WarnOnce('qbx_fire_offline', 'Qbox: no se pudo despedir a un empleado desconectado; debe estar conectado.')
        end
        return ok
    elseif FW == 'esx' then
        local affected = MySQL.update.await('UPDATE users SET job = ?, job_grade = 0 WHERE identifier = ? AND job = ?', { 'unemployed', identifier, jobName })
        return (affected or 0) > 0
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Datos de personajes (para listas de miembros)
-- ---------------------------------------------------------------------------
--- @param identifiers string[]
--- @return table<string, { name: string, phone: string }>
function Bridge.GetCharacterInfo(identifiers)
    local out = {}
    if type(identifiers) ~= 'table' or #identifiers == 0 then return out end

    if FW == 'qb' or FW == 'qbx' then
        local rows = MySQL.query.await('SELECT citizenid, charinfo FROM players WHERE citizenid IN (?)', { identifiers }) or {}
        for _, row in ipairs(rows) do
            local ci = Bridge.Util.SafeDecode(row.charinfo, {})
            out[row.citizenid] = {
                name = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')),
                phone = ci.phone and tostring(ci.phone) or 'N/A',
            }
        end
    elseif FW == 'esx' then
        -- SELECT * para no fallar si la tabla no tiene phone_number.
        local rows = MySQL.query.await('SELECT * FROM users WHERE identifier IN (?)', { identifiers }) or {}
        for _, row in ipairs(rows) do
            out[row.identifier] = {
                name = row.firstname and ((row.firstname or '') .. ' ' .. (row.lastname or '')) or row.identifier,
                phone = row.phone_number and tostring(row.phone_number) or 'N/A',
            }
        end
    else
        for _, pid in ipairs(GetPlayers()) do
            local ident = standaloneIdentifier(pid)
            if ident then out[ident] = { name = GetPlayerName(pid) or ident, phone = 'N/A' } end
        end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Dinero ('cash' | 'bank')
-- ---------------------------------------------------------------------------
local ESX_ACCOUNTS = { cash = 'money', money = 'money', bank = 'bank', black_money = 'black_money' }

local function oxMoneyFallback(account)
    if account == 'bank' then
        Bridge.WarnOnce('standalone_bank', 'Standalone: no hay cuenta bancaria; se usa el item "money" de ox_inventory.')
    end
    return Bridge.IsStarted('ox_inventory')
end

function Bridge.GetMoney(src, account)
    account = account or 'cash'
    if FW == 'qb' or FW == 'qbx' then
        local p = Bridge.GetPlayer(src)
        return p and (p.Functions.GetMoney(account) or 0) or 0
    elseif FW == 'esx' then
        local p = Bridge.GetPlayer(src)
        local acc = p and p.getAccount(ESX_ACCOUNTS[account] or account)
        return acc and acc.money or 0
    end
    if oxMoneyFallback(account) then
        return exports.ox_inventory:GetItemCount(src, 'money') or 0
    end
    return 0
end

function Bridge.RemoveMoney(src, account, amount, reason)
    account = account or 'cash'
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    if FW == 'qb' or FW == 'qbx' then
        local p = Bridge.GetPlayer(src)
        return p ~= nil and p.Functions.RemoveMoney(account, amount, reason) == true
    elseif FW == 'esx' then
        local p = Bridge.GetPlayer(src)
        if not p then return false end
        local accName = ESX_ACCOUNTS[account] or account
        local acc = p.getAccount(accName)
        if not acc or acc.money < amount then return false end
        p.removeAccountMoney(accName, amount, reason)
        return true
    end
    if oxMoneyFallback(account) then
        if (exports.ox_inventory:GetItemCount(src, 'money') or 0) < amount then return false end
        return exports.ox_inventory:RemoveItem(src, 'money', amount) == true
    end
    return false
end

function Bridge.AddMoney(src, account, amount, reason)
    account = account or 'cash'
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    if FW == 'qb' or FW == 'qbx' then
        local p = Bridge.GetPlayer(src)
        return p ~= nil and p.Functions.AddMoney(account, amount, reason) ~= false
    elseif FW == 'esx' then
        local p = Bridge.GetPlayer(src)
        if not p then return false end
        p.addAccountMoney(ESX_ACCOUNTS[account] or account, amount, reason)
        return true
    end
    if oxMoneyFallback(account) then
        return exports.ox_inventory:AddItem(src, 'money', amount) == true
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Inventario
-- ---------------------------------------------------------------------------
--- 'ox' | 'qb' (qb-inventory/ps/lj vía Player.Functions) | 'esx' | 'none'
function Bridge.InventoryType()
    if Bridge.IsStarted('ox_inventory') then return 'ox' end
    if FW == 'qb' or FW == 'qbx' then return 'qb' end
    if FW == 'esx' then return 'esx' end
    return 'none'
end

local function warnNoInventory()
    Bridge.WarnOnce('no_inventory', 'No se encontró ningún inventario compatible (ox_inventory recomendado). Las funciones con items no funcionarán.')
end

--- Animación de item de qb-inventory (solo tiene efecto con qb-inventory).
function Bridge.ItemBox(src, item, action, amount)
    if Bridge.InventoryType() ~= 'qb' then return end
    local c = core()
    local data = c and c.Shared and c.Shared.Items and c.Shared.Items[item]
    if data then TriggerClientEvent('inventory:client:ItemBox', src, data, action, amount) end
end

function Bridge.GetItemCount(src, item)
    local inv = Bridge.InventoryType()
    if inv == 'ox' then
        return exports.ox_inventory:GetItemCount(src, item) or 0
    elseif inv == 'qb' then
        local p = Bridge.GetPlayer(src)
        if not p then return 0 end
        local total = 0
        for _, it in pairs(p.PlayerData.items or {}) do
            if it and it.name == item then total = total + (tonumber(it.amount or it.count) or 0) end
        end
        return total
    elseif inv == 'esx' then
        local p = Bridge.GetPlayer(src)
        local it = p and p.getInventoryItem(item)
        return it and (it.count or 0) or 0
    end
    warnNoInventory()
    return 0
end

function Bridge.CanCarryItem(src, item, count)
    local inv = Bridge.InventoryType()
    if inv == 'ox' then
        return exports.ox_inventory:CanCarryItem(src, item, count) == true
    elseif inv == 'qb' then
        if Bridge.IsStarted('qb-inventory') then
            local ok, can = pcall(function() return exports['qb-inventory']:CanAddItem(src, item, count) end)
            if ok and can ~= nil then return can and true or false end
        end
        return true
    elseif inv == 'esx' then
        local p = Bridge.GetPlayer(src)
        if p and p.canCarryItem then return p.canCarryItem(item, count) end
        return p ~= nil
    end
    return false
end

function Bridge.AddItem(src, item, count, metadata)
    count = math.floor(tonumber(count) or 0)
    if count <= 0 then return false end
    local inv = Bridge.InventoryType()
    if inv == 'ox' then
        local ok = exports.ox_inventory:AddItem(src, item, count, metadata)
        return ok and true or false
    elseif inv == 'qb' then
        local p = Bridge.GetPlayer(src)
        if not p then return false end
        local ok = p.Functions.AddItem(item, count, false, metadata)
        if ok then Bridge.ItemBox(src, item, 'add', count) end
        return ok and true or false
    elseif inv == 'esx' then
        local p = Bridge.GetPlayer(src)
        if not p then return false end
        if p.canCarryItem and not p.canCarryItem(item, count) then return false end
        p.addInventoryItem(item, count)
        return true
    end
    warnNoInventory()
    return false
end

function Bridge.RemoveItem(src, item, count, slot)
    count = math.floor(tonumber(count) or 0)
    if count <= 0 then return false end
    local inv = Bridge.InventoryType()
    if inv == 'ox' then
        return exports.ox_inventory:RemoveItem(src, item, count, nil, slot) and true or false
    elseif inv == 'qb' then
        local p = Bridge.GetPlayer(src)
        if not p then return false end
        local ok = p.Functions.RemoveItem(item, count, slot)
        if ok then Bridge.ItemBox(src, item, 'remove', count) end
        return ok and true or false
    elseif inv == 'esx' then
        local p = Bridge.GetPlayer(src)
        if not p then return false end
        local it = p.getInventoryItem(item)
        if not it or (it.count or 0) < count then return false end
        p.removeInventoryItem(item, count)
        return true
    end
    warnNoInventory()
    return false
end

--- Registra un item usable. cb(source, { name, slot })
--- En standalone con ox_inventory, el item debe declarar en ox_inventory/data/items.lua:
---   server = { export = 'JGR_IlegalSystem.<nombre_item>' }
function Bridge.RegisterUsableItem(name, cb)
    if (FW == 'qb' or FW == 'esx') and not core() then
        Bridge.WarnOnce('no_core', 'No se pudo obtener el objeto del framework; los items usables no se registrarán.')
        return
    end
    if FW == 'qb' then
        core().Functions.CreateUseableItem(name, function(source, item)
            cb(source, { name = (item and item.name) or name, slot = item and item.slot })
        end)
    elseif FW == 'qbx' then
        local ok = pcall(function()
            exports.qbx_core:CreateUseableItem(name, function(source, item)
                cb(source, { name = (item and item.name) or name, slot = item and item.slot })
            end)
        end)
        if not ok then
            Bridge.WarnOnce('qbx_usable', 'Qbox: no se pudo registrar items usables con qbx_core:CreateUseableItem.')
        end
    elseif FW == 'esx' then
        core().RegisterUsableItem(name, function(source, _, itemData)
            cb(source, { name = name, slot = type(itemData) == 'table' and itemData.slot or nil })
        end)
    elseif Bridge.IsStarted('ox_inventory') then
        exports(name, function(event, item, inventory, slot)
            if event == 'usingItem' then
                cb(inventory.id, { name = (item and item.name) or name, slot = slot })
                return false -- el script quita el item él mismo cuando corresponde
            end
        end)
    else
        warnNoInventory()
    end
end

-- ---------------------------------------------------------------------------
-- Stashes / almacenes
-- ---------------------------------------------------------------------------
--- Solo tiene efecto con ox_inventory (el resto crea los stashes al abrirlos).
function Bridge.RegisterStash(id, label, slots, weight, groups, coords)
    if not Bridge.IsStarted('ox_inventory') then return end
    pcall(function()
        exports.ox_inventory:RegisterStash(id, label, slots, weight, nil, groups, coords)
    end)
end

--- Añade items directamente a un stash. Devuelve true si se pudo.
function Bridge.AddItemToStash(id, item, count)
    if Bridge.IsStarted('ox_inventory') then
        local ok, res = pcall(function() return exports.ox_inventory:AddItem(id, item, count) end)
        return ok and res and true or false
    end
    if Bridge.IsStarted('qb-inventory') then
        local ok, res = pcall(function() return exports['qb-inventory']:AddItem(id, item, count, false, false, 'jgr-ilegalsystem') end)
        return ok and res and true or false
    end
    return false
end

--- Abre un stash al jugador (ya validado por quien llama).
--- @param opts table { label, slots, weight, groups, coords }
function Bridge.OpenStash(src, id, opts)
    opts = opts or {}
    if Bridge.IsStarted('ox_inventory') then
        Bridge.RegisterStash(id, opts.label or id, opts.slots or 50, opts.weight or 100000, opts.groups, opts.coords)
        TriggerClientEvent('JGR_IlegalSystem:client:OpenStash', src, 'ox', id)
        return true
    end
    if Bridge.IsStarted('qb-inventory') then
        -- qb-inventory v2 abre stashes desde el servidor con este export.
        local ok = pcall(function()
            exports['qb-inventory']:OpenInventory(src, id, { label = opts.label, maxweight = opts.weight, slots = opts.slots })
        end)
        if ok then return true end
    end
    if FW == 'qb' or FW == 'qbx' or Bridge.IsStarted('qs-inventory') then
        -- qb-inventory antiguo / qs-inventory / ps-inventory: evento clásico desde el cliente.
        TriggerClientEvent('JGR_IlegalSystem:client:OpenStash', src, 'legacy', id, { maxweight = opts.weight, slots = opts.slots })
        return true
    end
    Bridge.Notify(src, 'Este servidor no tiene un inventario con almacenes compatible (usa ox_inventory).', 'error')
    return false
end

-- ---------------------------------------------------------------------------
-- Callback común: cantidades de items del jugador (para menús del cliente)
-- ---------------------------------------------------------------------------
lib.callback.register('JGR_IlegalSystem:server:GetItemCounts', function(source, names)
    local out = {}
    if type(names) ~= 'table' then return out end
    local n = 0
    for _, name in ipairs(names) do
        n = n + 1
        if n > 50 then break end
        if type(name) == 'string' then out[name] = Bridge.GetItemCount(source, name) end
    end
    return out
end)
