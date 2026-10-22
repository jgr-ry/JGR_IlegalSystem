-- Servidor: quién trabaja en el Grow Shop y quién lo gestiona (común a todos los archivos del módulo)
--
--   QBCore / Qbox / ESX → trabajo Config.GrowShop.JobName; gestores = Config.GrowShop.ManagementRanks
--                         (nombre del grado o número de grado).
--   Standalone / ox_core → permisos ACE:
--       add_ace identifier.license:xxxx jgr_ilegalsystem.growshop allow        (empleado)
--       add_ace identifier.license:xxxx jgr_ilegalsystem.growshop.boss allow   (gestor)

JGR.GrowShop = JGR.GrowShop or {}
local GS = JGR.GrowShop

--- @return 'manager'|'employee'|nil
function GS.GetRole(src)
    if not Config.GrowShop or not Config.GrowShop.Enabled then return nil end

    if Bridge.Framework == 'standalone' then
        if IsPlayerAceAllowed(src, 'jgr_ilegalsystem.growshop.boss') then return 'manager' end
        if IsPlayerAceAllowed(src, 'jgr_ilegalsystem.growshop') then return 'employee' end
        return nil
    end

    local job = Bridge.GetJob(src)
    if not job or job.name ~= Config.GrowShop.JobName then return nil end

    local gradeName = string.lower(tostring(job.gradeName or ''))
    local gradeLevel = tostring(job.grade or '')
    for _, rank in pairs(Config.GrowShop.ManagementRanks or {}) do
        if gradeName == string.lower(tostring(rank)) or gradeLevel == tostring(rank) then
            return 'manager'
        end
    end
    return 'employee'
end

function GS.IsManager(src)
    return GS.GetRole(src) == 'manager'
end

lib.callback.register('JGR_IlegalSystem:Server:GetGrowShopRole', function(source)
    return GS.GetRole(source)
end)

-- Almacén del negocio
local function stashCfg() return Config.GrowShop and Config.GrowShop.Stash end

CreateThread(function()
    local s = stashCfg()
    if not Config.GrowShop.Enabled or not s or not s.Enabled then return end
    local groups = Bridge.Framework ~= 'standalone' and { [Config.GrowShop.JobName] = 0 } or nil
    Bridge.RegisterStash(s.Name, s.Label, s.Slots, s.Weight, groups, s.Location)
end)

RegisterNetEvent('JGR_IlegalSystem:Server:OpenGrowShopStash', function()
    local src = source
    local s = stashCfg()
    if not s or not s.Enabled then return end
    if not GS.GetRole(src) then
        Bridge.Notify(src, "No trabajas aquí.", "error")
        return
    end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or #(GetEntityCoords(ped) - vector3(s.Location.x, s.Location.y, s.Location.z)) > 4.0 then
        return
    end
    Bridge.OpenStash(src, s.Name, {
        label = s.Label, slots = s.Slots, weight = s.Weight,
        groups = Bridge.Framework ~= 'standalone' and { [Config.GrowShop.JobName] = 0 } or nil,
        coords = s.Location,
    })
end)
