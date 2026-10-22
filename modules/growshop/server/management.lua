-- Servidor: gestión del Grow Shop (fondos de la sociedad y empleados)

local GS = JGR.GrowShop

-- ==========================================
-- FONDOS DE LA SOCIEDAD
-- ==========================================

--- Lee los fondos y crea la fila si no existe (sin tocar fondos existentes).
local function GetSocietyFunds(jobName)
    local funds = MySQL.scalar.await('SELECT funds FROM jgr_societies WHERE job_name = ?', { jobName })
    if funds ~= nil then return funds end
    MySQL.insert.await('INSERT IGNORE INTO jgr_societies (job_name, funds) VALUES (?, 0)', { jobName })
    return MySQL.scalar.await('SELECT funds FROM jgr_societies WHERE job_name = ?', { jobName }) or 0
end

--- Descuenta de forma atómica. Devuelve true si había fondos suficientes.
function RemoveSocietyFunds(jobName, amount)
    amount = Bridge.Util.ToInt(amount, 1)
    if not amount then return false end
    GetSocietyFunds(jobName)
    local affected = MySQL.update.await('UPDATE jgr_societies SET funds = funds - ? WHERE job_name = ? AND funds >= ?', { amount, jobName, amount })
    return (affected or 0) > 0
end

-- Callback al abrir la UI. Solo devuelve los fondos del propio negocio y a sus gestores.
lib.callback.register('JGR_IlegalSystem:Server:GetSocietyFunds', function(source)
    if not GS.IsManager(source) then return nil end
    return GetSocietyFunds(Config.GrowShop.JobName)
end)

RegisterNetEvent('JGR_IlegalSystem:Server:ManageFunds', function(action, amount)
    local src = source
    if not GS.IsManager(src) then
        Bridge.Notify(src, "No tienes permisos de gestión.", "error")
        return
    end

    local amountInt = Bridge.Util.ToInt(amount, 1, 100000000)
    if not amountInt then return end
    local jobName = Config.GrowShop.JobName

    if action == "deposit" then
        if Bridge.RemoveMoney(src, 'bank', amountInt, "growshop-deposit") then
            GetSocietyFunds(jobName)
            MySQL.update.await('UPDATE jgr_societies SET funds = funds + ? WHERE job_name = ?', { amountInt, jobName })
            Bridge.Notify(src, "Has depositado $" .. amountInt .. " a la sociedad.", "success")
        else
            Bridge.Notify(src, "No tienes suficiente dinero en el banco.", "error")
        end
    elseif action == "withdraw" then
        if RemoveSocietyFunds(jobName, amountInt) then
            if not Bridge.AddMoney(src, 'bank', amountInt, "growshop-withdraw") then
                -- Si no se pudo pagar al jugador, el dinero vuelve a la sociedad.
                MySQL.update.await('UPDATE jgr_societies SET funds = funds + ? WHERE job_name = ?', { amountInt, jobName })
                Bridge.Notify(src, "No se pudo ingresar el dinero.", "error")
            else
                Bridge.Notify(src, "Has retirado $" .. amountInt .. " de la sociedad.", "success")
            end
        else
            Bridge.Notify(src, "La sociedad no tiene fondos suficientes.", "error")
        end
    else
        return
    end

    TriggerClientEvent('JGR_IlegalSystem:Client:UpdateGrowShopMoney', src, GetSocietyFunds(jobName))
end)

-- ==========================================
-- EMPLEADOS
-- ==========================================

local function SendEmployees(src)
    local employees = {}
    for _, e in ipairs(Bridge.GetJobEmployees(Config.GrowShop.JobName)) do
        employees[#employees + 1] = {
            citizenid = e.identifier, -- el NUI sigue usando "citizenid" (en ESX es el identifier)
            name = e.name,
            gradeLevel = e.gradeLevel,
            gradeLabel = e.gradeLabel,
        }
    end
    TriggerClientEvent('JGR_IlegalSystem:Client:UpdateEmployeesList', src, employees)
end

RegisterNetEvent('JGR_IlegalSystem:Server:GetEmployees', function()
    local src = source
    if not GS.IsManager(src) then return end
    SendEmployees(src)
end)

RegisterNetEvent('JGR_IlegalSystem:Server:FireEmployee', function(targetCitizenId)
    local src = source
    if not GS.IsManager(src) then
        Bridge.Notify(src, "No tienes permisos de gestión.", "error")
        return
    end
    if type(targetCitizenId) ~= "string" or targetCitizenId == "" then return end
    if targetCitizenId == Bridge.GetIdentifier(src) then
        Bridge.Notify(src, "No puedes despedirte a ti mismo.", "error")
        return
    end

    local jobName = Config.GrowShop.JobName
    local targetSrc = Bridge.GetSourceFromIdentifier(targetCitizenId)
    if targetSrc then
        -- Solo se puede despedir a empleados de ESTE negocio.
        local job = Bridge.GetJob(targetSrc)
        if not job or job.name ~= jobName then
            Bridge.Notify(src, "Esa persona no trabaja en el Grow Shop.", "error")
            return
        end
        Bridge.SetJob(targetSrc, "unemployed", 0)
        Bridge.Notify(targetSrc, "Has sido despedido de " .. jobName, "error")
        Bridge.Notify(src, "Empleado despedido con éxito.", "success")
    elseif Bridge.FireOfflineEmployee(targetCitizenId, jobName) then
        Bridge.Notify(src, "Empleado (desconectado) despedido con éxito.", "success")
    else
        Bridge.Notify(src, "No se pudo despedir a ese empleado.", "error")
    end

    SendEmployees(src)
end)

RegisterNetEvent('JGR_IlegalSystem:Server:PromoteEmployee', function()
    local src = source
    if not GS.IsManager(src) then
        Bridge.Notify(src, "No tienes permisos de gestión.", "error")
        return
    end
    -- Pendiente: leer los grados del trabajo del framework y abrir un submenú.
    Bridge.Notify(src, "Funcionalidad de promoción en desarrollo.", "primary")
end)

RegisterNetEvent('JGR_IlegalSystem:Server:HireEmployee', function(targetServerId)
    local src = source
    if not GS.IsManager(src) then
        Bridge.Notify(src, "No tienes permisos de gestión.", "error")
        return
    end
    targetServerId = tonumber(targetServerId)
    if not targetServerId or targetServerId == src or not Bridge.IsOnline(targetServerId) then
        Bridge.Notify(src, "Jugador no encontrado.", "error")
        return
    end

    -- Hay que tener al candidato delante.
    local myPed, targetPed = GetPlayerPed(src), GetPlayerPed(targetServerId)
    if #(GetEntityCoords(myPed) - GetEntityCoords(targetPed)) > 5.0 then
        Bridge.Notify(src, "No hay nadie cerca.", "error")
        return
    end

    if Bridge.Framework == 'standalone' then
        Bridge.Notify(src, "En modo standalone los empleados se gestionan con permisos ACE (ver README).", "error")
        return
    end

    local job = Bridge.GetJob(targetServerId)
    if job and job.name == Config.GrowShop.JobName then
        Bridge.Notify(src, "Esa persona ya trabaja aquí.", "error")
        return
    end

    if not Bridge.SetJob(targetServerId, Config.GrowShop.JobName, 0) then
        Bridge.Notify(src, "No se pudo contratar a esa persona.", "error")
        return
    end
    Bridge.Notify(src, "Has contratado a " .. Bridge.GetCharName(targetServerId), "success")
    Bridge.Notify(targetServerId, "Has sido contratado en el Grow Shop.", "success")

    SendEmployees(src)
end)
