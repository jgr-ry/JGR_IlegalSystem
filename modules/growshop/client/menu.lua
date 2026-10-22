-- Cliente: Grow Shop (blip, zonas de interacción, panel de gestión)

JGR.GrowShop = JGR.GrowShop or {}
local GS = JGR.GrowShop
GS.Role = nil -- 'manager' | 'employee' | nil (lo decide el servidor)

local initialized = false
local blip = nil

--- Pregunta al servidor el rol del jugador en el Grow Shop (funciona en todos los frameworks).
function GS.RefreshRole()
    local ok, role = pcall(lib.callback.await, 'JGR_IlegalSystem:Server:GetGrowShopRole', false)
    GS.Role = ok and role or nil
    return GS.Role
end

local function OpenGrowShopMenu()
    local role = GS.RefreshRole()
    if not role then
        Bridge.Notify(PlayerId(), "No trabajas aquí.", "error")
        return
    end
    if role ~= 'manager' then
        Bridge.Notify(PlayerId(), "No tienes permisos suficientes (Solo Jefes/Encargados).", "error")
        return
    end

    lib.callback('JGR_IlegalSystem:Server:GetSocietyFunds', false, function(funds)
        if funds == nil then
            Bridge.Notify(PlayerId(), "No tienes permisos de gestión.", "error")
            return
        end
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = "open_grow_shop",
            market = Config.GrowShop.Wholesale,
            recipes = Config.GrowShop.Crafting,
            societyFunds = funds
        })
    end)
end

local function InitGrowShop()
    if not Config.GrowShop.Enabled or initialized then return end
    initialized = true

    GS.RefreshRole()

    if Config.GrowShop.Blip and Config.GrowShop.Blip.Enabled then
        blip = AddBlipForCoord(Config.GrowShop.Location.x, Config.GrowShop.Location.y, Config.GrowShop.Location.z)
        SetBlipSprite(blip, Config.GrowShop.Blip.Sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, Config.GrowShop.Blip.Scale)
        SetBlipColour(blip, Config.GrowShop.Blip.Color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(Config.GrowShop.Blip.Name)
        EndTextCommandSetBlipName(blip)
    end

    -- Panel de administración del Grow Shop
    Bridge.AddBoxZone("GrowShopBoss", Config.GrowShop.Location, 1.5, 0.0, {
        {
            label = "Abrir Administración Grow Shop",
            icon = "fas fa-cannabis",
            canInteract = function() return GS.Role ~= nil end,
            onSelect = OpenGrowShopMenu,
        },
    }, 2.0)

    -- Almacén del negocio
    if Config.GrowShop.Stash and Config.GrowShop.Stash.Enabled then
        Bridge.AddBoxZone("GrowShopStash", Config.GrowShop.Stash.Location, 1.5, 0.0, {
            {
                label = Config.GrowShop.Stash.Label,
                icon = "fas fa-box-open",
                canInteract = function() return GS.Role ~= nil end,
                onSelect = function()
                    TriggerServerEvent('JGR_IlegalSystem:Server:OpenGrowShopStash')
                end,
            },
        }, 2.0)
    end
end

Bridge.OnPlayerLoaded(function()
    SetTimeout(1000, function()
        InitGrowShop()
        GS.RefreshRole()
    end)
end)

Bridge.OnJobUpdate(function()
    SetTimeout(500, GS.RefreshRole)
end)

CreateThread(function()
    Wait(1500)
    InitGrowShop()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
end)

-- NUI Callbacks
RegisterNUICallback('closeGrowShop', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('checkoutGrowShopCart', function(data, cb)
    cb('ok')
    if type(data) == "table" then
        TriggerServerEvent('JGR_IlegalSystem:Server:CheckoutCart', data.cart)
    end
end)

RegisterNUICallback('craftGrowItem', function(data, cb)
    cb('ok')
    if type(data) == "table" then
        TriggerServerEvent('JGR_IlegalSystem:Server:CraftGrowItem', data.recipeId, data.batches)
    end
end)

RegisterNUICallback('manageGrowShopFunds', function(data, cb)
    cb('ok')
    if type(data) == "table" then
        TriggerServerEvent('JGR_IlegalSystem:Server:ManageFunds', data.action, data.amount)
    end
end)

RegisterNUICallback('getGrowShopEmployees', function(data, cb)
    cb('ok')
    TriggerServerEvent('JGR_IlegalSystem:Server:GetEmployees')
end)

RegisterNUICallback('hireGrowShopEmployee', function(data, cb)
    cb('ok')
    local targetServerId = Bridge.GetClosestPlayer(3.0)
    if targetServerId then
        TriggerServerEvent('JGR_IlegalSystem:Server:HireEmployee', targetServerId)
    else
        Bridge.Notify(PlayerId(), 'No hay nadie cerca.', 'error')
    end
end)

RegisterNUICallback('fireGrowShopEmployee', function(data, cb)
    cb('ok')
    if type(data) == "table" and data.citizenid then
        TriggerServerEvent('JGR_IlegalSystem:Server:FireEmployee', data.citizenid)
    end
end)

RegisterNUICallback('promoteGrowShopEmployee', function(data, cb)
    cb('ok')
    if type(data) == "table" and data.citizenid then
        TriggerServerEvent('JGR_IlegalSystem:Server:PromoteEmployee', data.citizenid)
    end
end)

RegisterNetEvent('JGR_IlegalSystem:Client:UpdateEmployeesList', function(employees)
    SendNUIMessage({
        action = "update_grow_employees",
        employees = employees
    })
end)

RegisterNetEvent('JGR_IlegalSystem:Client:UpdateGrowShopMoney', function(newFunds)
    SendNUIMessage({
        action = "update_grow_money",
        societyFunds = newFunds
    })
end)
