local QBCore = exports['qb-core']:GetCoreObject()

-- ==========================================
-- FUNDS MANAGEMENT
-- ==========================================

-- Check/Init society funds
local function GetSocietyFunds(jobName)
    local result = MySQL.query.await('SELECT funds FROM jgr_societies WHERE job_name = ?', {jobName})
    if result and #result > 0 then
        return result[1].funds
    else
        -- Initialize to 0 if doesn't exist
        MySQL.insert.await('INSERT INTO jgr_societies (job_name, funds) VALUES (?, 0) ON DUPLICATE KEY UPDATE funds = 0', {jobName})
        return 0
    end
end

-- Used by UI Open Callback
QBCore.Functions.CreateCallback('JGR_IlegalSystem:Server:GetSocietyFunds', function(source, cb, societyName)
    local funds = GetSocietyFunds(societyName)
    cb(funds)
end)

-- Used by server events to deduct (like wholesale)
function RemoveSocietyFunds(jobName, amount)
    local current = GetSocietyFunds(jobName)
    if current >= amount then
        MySQL.update.await('UPDATE jgr_societies SET funds = funds - ? WHERE job_name = ?', {amount, jobName})
        return true
    end
    return false
end

-- Client NUI Callbacks
RegisterNetEvent('JGR_IlegalSystem:Server:ManageFunds', function(action, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if Player.PlayerData.job.name ~= Config.GrowShop.JobName then return end

    local isManager = false
    for _, rank in pairs(Config.GrowShop.ManagementRanks) do
        if string.lower(Player.PlayerData.job.grade.name) == string.lower(rank) or tostring(Player.PlayerData.job.grade.level) == rank then
            isManager = true
            break
        end
    end

    if not isManager then
        TriggerClientEvent('QBCore:Notify', src, "No tienes permisos de gestión.", "error")
        return
    end

    local amountInt = tonumber(amount)
    if not amountInt or amountInt <= 0 then return end

    if action == "deposit" then
        if Player.Functions.RemoveMoney('bank', amountInt, "growshop-deposit") then
            MySQL.update.await('UPDATE jgr_societies SET funds = funds + ? WHERE job_name = ?', {amountInt, Config.GrowShop.JobName})
            TriggerClientEvent('QBCore:Notify', src, "Has depositado $" .. amountInt .. " a la sociedad.", "success")
        else
            TriggerClientEvent('QBCore:Notify', src, "No tienes suficiente dinero en el banco.", "error")
        end
    elseif action == "withdraw" then
        if RemoveSocietyFunds(Config.GrowShop.JobName, amountInt) then
            Player.Functions.AddMoney('bank', amountInt, "growshop-withdraw")
            TriggerClientEvent('QBCore:Notify', src, "Has retirado $" .. amountInt .. " de la sociedad.", "success")
        else
            TriggerClientEvent('QBCore:Notify', src, "La sociedad no tiene fondos suficientes.", "error")
        end
    end

    -- Trigger update for UI
    local newFunds = GetSocietyFunds(Config.GrowShop.JobName)
    TriggerClientEvent('JGR_IlegalSystem:Client:UpdateGrowShopMoney', src, newFunds)
end)

-- ==========================================
-- EMPLOYEES MANAGEMENT
-- ==========================================

RegisterNetEvent('JGR_IlegalSystem:Server:GetEmployees', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if Player.PlayerData.job.name ~= Config.GrowShop.JobName then return end

    -- Query QBCore players table
    local results = MySQL.query.await('SELECT * FROM players')
    local employees = {}
    
    for _, row in ipairs(results) do
        local jobData = json.decode(row.job)
        if jobData and jobData.name == Config.GrowShop.JobName then
            local charinfo = json.decode(row.charinfo)
            local fullName = "Desconocido"
            if charinfo and charinfo.firstname and charinfo.lastname then
                fullName = charinfo.firstname .. " " .. charinfo.lastname
            end
            
            table.insert(employees, {
                citizenid = row.citizenid,
                name = fullName,
                gradeLevel = jobData.grade.level,
                gradeLabel = jobData.grade.name
            })
        end
    end

    -- Send back to client NUI
    TriggerClientEvent('JGR_IlegalSystem:Client:UpdateEmployeesList', src, employees)
end)

RegisterNetEvent('JGR_IlegalSystem:Server:FireEmployee', function(targetCitizenId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local Target = QBCore.Functions.GetPlayerByCitizenId(targetCitizenId)
    if Target then
        -- Player is online
        Target.Functions.SetJob("unemployed", 0)
        TriggerClientEvent('QBCore:Notify', Target.PlayerData.source, "Has sido despedido de " .. Config.GrowShop.JobName, "error")
        TriggerClientEvent('QBCore:Notify', src, "Empleado despedido con éxito.", "success")
    else
        -- Player is offline, update DB
        local result = MySQL.query.await('SELECT job FROM players WHERE citizenid = ?', {targetCitizenId})
        if result[1] then
            local jobData = json.decode(result[1].job)
            jobData.name = "unemployed"
            jobData.label = "Civil"
            jobData.payment = 10
            jobData.onduty = true
            jobData.isboss = false
            jobData.grade = {}
            jobData.grade.name = "Sin Asignar"
            jobData.grade.level = 0
            MySQL.update.await('UPDATE players SET job = ? WHERE citizenid = ?', {json.encode(jobData), targetCitizenId})
            TriggerClientEvent('QBCore:Notify', src, "Empleado (Offline) despedido con éxito.", "success")
        end
    end

    -- Refresh lists
    TriggerEvent('JGR_IlegalSystem:Server:GetEmployees')
end)

RegisterNetEvent('JGR_IlegalSystem:Server:PromoteEmployee', function(targetCitizenId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Very basic promote logic (you can expand this to read max grades from jobs.lua or open a sub-UI)
    TriggerClientEvent('QBCore:Notify', src, "Funcionalidad de promoción en desarrollo.", "primary")
end)

RegisterNetEvent('JGR_IlegalSystem:Server:HireEmployee', function(targetServerId)
    local src = source
    local Target = QBCore.Functions.GetPlayer(targetServerId)
    if not Target then 
        TriggerClientEvent('QBCore:Notify', src, "Jugador no encontrado.", "error")
        return 
    end

    Target.Functions.SetJob(Config.GrowShop.JobName, 0)
    TriggerClientEvent('QBCore:Notify', src, "Has contratado a " .. Target.PlayerData.name, "success")
    TriggerClientEvent('QBCore:Notify', Target.PlayerData.source, "Has sido contratado en el Grow Shop.", "success")

    TriggerEvent('JGR_IlegalSystem:Server:GetEmployees')
end)
