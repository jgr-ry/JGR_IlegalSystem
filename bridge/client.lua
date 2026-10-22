--[[
    JGR_IlegalSystem · Bridge de cliente
    ------------------------------------------------------------------------
    Notificaciones, datos del jugador, eventos de carga, texto de ayuda,
    zonas de interacción (ox_target → qb-target → tecla E con ox_lib),
    vehículos, combustible, llaves y apertura de almacenes.
]]

local FW = Bridge.Framework

local function core() return Bridge.GetCore() end

-- ---------------------------------------------------------------------------
-- Notificaciones
-- ---------------------------------------------------------------------------
local OX_TYPES = { primary = 'inform', info = 'inform', inform = 'inform', success = 'success', error = 'error', warning = 'warning' }

--- Bridge.Notify(_, msg, type) — el primer argumento se ignora en cliente (compatibilidad
--- con llamadas antiguas `Bridge.Notify(PlayerId(), msg, type)`). También acepta (msg, type).
function Bridge.Notify(target, msg, nType)
    if type(target) == 'string' and (msg == nil or OX_TYPES[msg]) then
        target, msg, nType = nil, target, msg
    end
    msg = tostring(msg or '')
    nType = nType or 'primary'
    if FW == 'qb' then
        local c = core()
        if c then return c.Functions.Notify(msg, nType) end
    elseif FW == 'qbx' then
        local ok = pcall(function() exports.qbx_core:Notify(msg, OX_TYPES[nType] or 'inform') end)
        if ok then return end
    elseif FW == 'esx' then
        local c = core()
        if c and c.ShowNotification then return c.ShowNotification(msg) end
    end
    lib.notify({ description = msg, type = OX_TYPES[nType] or 'inform' })
end

-- ---------------------------------------------------------------------------
-- Jugador
-- ---------------------------------------------------------------------------
function Bridge.GetPlayerData()
    if FW == 'qb' then
        local c = core()
        return c and c.Functions.GetPlayerData() or {}
    elseif FW == 'qbx' then
        return exports.qbx_core:GetPlayerData() or {}
    elseif FW == 'esx' then
        local c = core()
        return c and c.GetPlayerData() or {}
    end
    return {}
end

--- @return table|nil { name, grade, gradeName, label }
function Bridge.GetJob()
    local pd = Bridge.GetPlayerData()
    local job = pd and pd.job
    if not job then return nil end
    if FW == 'esx' then
        return { name = job.name, label = job.label, grade = tonumber(job.grade) or 0, gradeName = job.grade_name or '' }
    end
    local grade = type(job.grade) == 'table' and job.grade or {}
    return { name = job.name, label = job.label, grade = tonumber(grade.level) or 0, gradeName = grade.name or '' }
end

--- Ejecuta cb cuando el personaje termina de cargar (todos los frameworks).
function Bridge.OnPlayerLoaded(cb)
    if FW == 'qb' or FW == 'qbx' then
        RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() cb() end)
    elseif FW == 'esx' then
        RegisterNetEvent('esx:playerLoaded', function() cb() end)
    end
    if Bridge.IsOxCore then
        RegisterNetEvent('ox:playerLoaded', function() cb() end)
    end
end

--- Ejecuta cb cuando cambia el trabajo del jugador.
function Bridge.OnJobUpdate(cb)
    if FW == 'qb' or FW == 'qbx' then
        RegisterNetEvent('QBCore:Client:OnJobUpdate', function() cb() end)
    elseif FW == 'esx' then
        RegisterNetEvent('esx:setJob', function() cb() end)
    end
end

-- ---------------------------------------------------------------------------
-- Texto de ayuda (ox_lib textUI con "propietario" para que dos bucles no se pisen)
-- ---------------------------------------------------------------------------
local textOwner, textValue = nil, nil

function Bridge.ShowText(owner, text)
    if textOwner == owner and textValue == text then return end
    textOwner, textValue = owner, text
    lib.showTextUI(text)
end

function Bridge.HideText(owner)
    if textOwner == nil or (owner and textOwner ~= owner) then return end
    textOwner, textValue = nil, nil
    lib.hideTextUI()
end

-- ---------------------------------------------------------------------------
-- Zonas de interacción
-- ---------------------------------------------------------------------------
local Zones = {}

local function allowed(opt)
    if not opt.canInteract then return true end
    local ok, res = pcall(opt.canInteract)
    return ok and res and true or false
end

--- @param name string identificador único
--- @param coords vector3
--- @param size number lado de la caja
--- @param heading number
--- @param options table[] { label, icon, onSelect, canInteract }
--- @param distance number distancia de interacción
function Bridge.AddBoxZone(name, coords, size, heading, options, distance)
    Bridge.RemoveZone(name)
    coords = vector3(coords.x, coords.y, coords.z)
    size = size or 1.5
    distance = distance or 2.0

    if Bridge.IsStarted('ox_target') then
        local oxOptions = {}
        for i, opt in ipairs(options) do
            oxOptions[i] = {
                name = ('%s_%d'):format(name, i),
                label = opt.label,
                icon = opt.icon,
                distance = distance,
                canInteract = function() return allowed(opt) end,
                onSelect = function() opt.onSelect() end,
            }
        end
        local id = exports.ox_target:addBoxZone({
            coords = coords,
            size = vec3(size, size, 2.5),
            rotation = heading or 0.0,
            debug = false,
            options = oxOptions,
        })
        Zones[name] = { kind = 'ox', id = id }
        return
    end

    if Bridge.IsStarted('qb-target') then
        local qbOptions = {}
        for i, opt in ipairs(options) do
            qbOptions[i] = {
                type = 'client',
                icon = opt.icon,
                label = opt.label,
                canInteract = function() return allowed(opt) end,
                action = function() opt.onSelect() end,
            }
        end
        exports['qb-target']:AddBoxZone(name, coords, size, size, {
            name = name,
            heading = heading or 0.0,
            debugPoly = false,
            minZ = coords.z - 1.0,
            maxZ = coords.z + 1.5,
        }, { options = qbOptions, distance = distance })
        Zones[name] = { kind = 'qb' }
        return
    end

    -- Sin sistema de target: tecla E con ox_lib.
    local owner = 'zone:' .. name
    local point = lib.points.new({ coords = coords, distance = distance })
    function point:nearby()
        local opt
        for _, o in ipairs(options) do
            if allowed(o) then opt = o break end
        end
        if not opt then
            Bridge.HideText(owner)
            return
        end
        Bridge.ShowText(owner, '[E] ' .. opt.label)
        if IsControlJustReleased(0, 38) then
            Bridge.HideText(owner)
            opt.onSelect()
        end
    end
    function point:onExit()
        Bridge.HideText(owner)
    end
    Zones[name] = { kind = 'points', point = point, owner = owner }
end

function Bridge.RemoveZone(name)
    local z = Zones[name]
    if not z then return end
    if z.kind == 'ox' then
        pcall(function() exports.ox_target:removeZone(z.id) end)
    elseif z.kind == 'qb' then
        pcall(function() exports['qb-target']:RemoveZone(name) end)
    elseif z.kind == 'points' then
        z.point:remove()
        Bridge.HideText(z.owner)
    end
    Zones[name] = nil
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for name in pairs(Zones) do Bridge.RemoveZone(name) end
    lib.hideTextUI()
end)

-- ---------------------------------------------------------------------------
-- Items
-- ---------------------------------------------------------------------------
--- Cantidades de items consultadas al servidor (funciona con cualquier inventario).
--- @param names string[]
--- @return table<string, number>
function Bridge.GetItemCounts(names)
    local ok, res = pcall(lib.callback.await, 'JGR_IlegalSystem:server:GetItemCounts', false, names)
    return (ok and type(res) == 'table') and res or {}
end

function Bridge.HasItem(name, amount)
    return (Bridge.GetItemCounts({ name })[name] or 0) >= (amount or 1)
end

function Bridge.GetItemLabel(name, fallback)
    if Bridge.IsStarted('ox_inventory') then
        local ok, data = pcall(function() return exports.ox_inventory:Items(name) end)
        if ok and type(data) == 'table' and data.label then return data.label end
    end
    if FW == 'qb' or FW == 'qbx' then
        local c = core()
        local item = c and c.Shared and c.Shared.Items and c.Shared.Items[name]
        if item and item.label then return item.label end
    end
    return fallback or name
end

-- ---------------------------------------------------------------------------
-- Jugadores cercanos
-- ---------------------------------------------------------------------------
--- @return number|nil serverId, number|nil distance
function Bridge.GetClosestPlayer(maxDistance)
    local myCoords = GetEntityCoords(PlayerPedId())
    local playerId, _, coords = lib.getClosestPlayer(myCoords, maxDistance or 3.0, false)
    if not playerId then return nil end
    return GetPlayerServerId(playerId), #(myCoords - coords)
end

-- ---------------------------------------------------------------------------
-- Vehículos
-- ---------------------------------------------------------------------------
function Bridge.SpawnVehicle(model, coords, heading, cb)
    local hash = type(model) == 'string' and joaat(model) or model
    if not hash or not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        if cb then cb(nil) end
        return
    end
    if not pcall(lib.requestModel, hash, 10000) then
        if cb then cb(nil) end
        return
    end
    local veh = CreateVehicle(hash, coords.x + 0.0, coords.y + 0.0, coords.z + 0.0, (heading or 0.0) + 0.0, true, false)
    SetModelAsNoLongerNeeded(hash)
    if not veh or veh == 0 then
        if cb then cb(nil) end
        return
    end
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetVehicleNeedsToBeHotwired(veh, false)
    SetVehicleOnGroundProperly(veh)
    if cb then cb(veh) end
    return veh
end

function Bridge.SetFuel(veh, level)
    level = (level or 100.0) + 0.0
    SetVehicleFuelLevel(veh, level)
    if Bridge.IsStarted('ox_fuel') then
        Entity(veh).state:set('fuel', level, true)
    elseif Bridge.IsStarted('LegacyFuel') then
        pcall(function() exports.LegacyFuel:SetFuel(veh, level) end)
    elseif Bridge.IsStarted('cdn-fuel') then
        pcall(function() exports['cdn-fuel']:SetFuel(veh, level) end)
    end
end

function Bridge.GiveKeys(veh, plate)
    if Bridge.IsStarted('qb-vehiclekeys') then
        TriggerServerEvent('qb-vehiclekeys:server:AcquireVehicleKeys', plate)
    end
end

-- ---------------------------------------------------------------------------
-- Almacenes (el servidor valida y decide cómo abrir)
-- ---------------------------------------------------------------------------
RegisterNetEvent('JGR_IlegalSystem:client:OpenStash', function(kind, id, data)
    if type(id) ~= 'string' then return end
    if kind == 'ox' then
        if Bridge.IsStarted('ox_inventory') then exports.ox_inventory:openInventory('stash', id) end
    else
        TriggerServerEvent('inventory:server:OpenInventory', 'stash', id, data or {})
        TriggerEvent('inventory:client:SetCurrentStash', id)
    end
end)
