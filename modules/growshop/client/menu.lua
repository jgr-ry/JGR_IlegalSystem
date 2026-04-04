local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    InitGrowShop()
end)

AddEventHandler("onResourceStart", function(resourceName)
    if GetCurrentResourceName() == resourceName then
        InitGrowShop()
    end
end)

function InitGrowShop()
    if not Config.GrowShop.Enabled then return end

    if Config.GrowShop.Blip and Config.GrowShop.Blip.Enabled then
        local blip = AddBlipForCoord(Config.GrowShop.Location.x, Config.GrowShop.Location.y, Config.GrowShop.Location.z)
        SetBlipSprite(blip, Config.GrowShop.Blip.Sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, Config.GrowShop.Blip.Scale)
        SetBlipColour(blip, Config.GrowShop.Blip.Color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(Config.GrowShop.Blip.Name)
        EndTextCommandSetBlipName(blip)
    end

    -- Target for the Grow Shop Boss Menu
    exports['qb-target']:AddBoxZone("GrowShopBoss", Config.GrowShop.Location, 1.5, 1.5, {
        name = "GrowShopBoss",
        heading = 0,
        debugPoly = false,
        minZ = Config.GrowShop.Location.z - 1.0,
        maxZ = Config.GrowShop.Location.z + 1.0,
    }, {
        options = {
            {
                type = "client",
                action = function()
                    OpenGrowShopMenu()
                end,
                icon = "fas fa-cannabis",
                label = "Abrir Administración Grow Shop",
                job = Config.GrowShop.JobName,
            },
        },
        distance = 2.0
    })

    -- Target for the Grow Shop Stash
    if Config.GrowShop.Stash and Config.GrowShop.Stash.Enabled then
        exports['qb-target']:AddBoxZone("GrowShopStash", Config.GrowShop.Stash.Location, 1.5, 1.5, {
            name = "GrowShopStash",
            heading = 0,
            debugPoly = false,
            minZ = Config.GrowShop.Stash.Location.z - 1.0,
            maxZ = Config.GrowShop.Stash.Location.z + 1.0,
        }, {
            options = {
                {
                    type = "client",
                    action = function()
                        TriggerServerEvent("inventory:server:OpenInventory", "stash", Config.GrowShop.Stash.Name, {
                            maxweight = Config.GrowShop.Stash.Weight,
                            slots = Config.GrowShop.Stash.Slots,
                        })
                        TriggerEvent("inventory:client:SetCurrentStash", Config.GrowShop.Stash.Name)
                    end,
                    icon = "fas fa-box-open",
                    label = Config.GrowShop.Stash.Label,
                    job = Config.GrowShop.JobName,
                },
            },
            distance = 2.0
        })
    end
end

function OpenGrowShopMenu()
    local PlayerData = QBCore.Functions.GetPlayerData()
    local playerJob = PlayerData.job
    
    if playerJob.name ~= Config.GrowShop.JobName then
        QBCore.Functions.Notify("No trabajas aquí.", "error")
        return
    end

    local isManager = false
    for _, rank in pairs(Config.GrowShop.ManagementRanks) do
        -- Check grade level name or number based on how QBCore assigns it, typically grade.name or grade.level
        if string.lower(playerJob.grade.name) == string.lower(rank) or tostring(playerJob.grade.level) == rank then
            isManager = true
            break
        end
    end

    if not isManager then
        QBCore.Functions.Notify("No tienes permisos suficientes (Solo Jefes/Encargados).", "error")
        return
    end

    -- Fetch society money from server via callback before opening
    QBCore.Functions.TriggerCallback('JGR_IlegalSystem:Server:GetSocietyFunds', function(funds)
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = "open_grow_shop",
            market = Config.GrowShop.Wholesale,
            recipes = Config.GrowShop.Crafting,
            societyFunds = funds
        })
    end, Config.GrowShop.JobName)
end

-- NUI Callbacks
RegisterNUICallback('closeGrowShop', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('checkoutGrowShopCart', function(data, cb)
    TriggerServerEvent('JGR_IlegalSystem:Server:CheckoutCart', data.cart)
    cb('ok')
end)

RegisterNUICallback('craftGrowItem', function(data, cb)
    TriggerServerEvent('JGR_IlegalSystem:Server:CraftGrowItem', data.recipeId, data.batches)
    cb('ok')
end)

RegisterNUICallback('manageGrowShopFunds', function(data, cb)
    TriggerServerEvent('JGR_IlegalSystem:Server:ManageFunds', data.action, data.amount)
    cb('ok')
end)

RegisterNUICallback('getGrowShopEmployees', function(data, cb)
    TriggerServerEvent('JGR_IlegalSystem:Server:GetEmployees')
    cb('ok')
end)

RegisterNUICallback('hireGrowShopEmployee', function(data, cb)
    -- Get closest player
    local target, distance = QBCore.Functions.GetClosestPlayer()
    if target ~= -1 and distance < 3.0 then
        local targetServerId = GetPlayerServerId(target)
        TriggerServerEvent('JGR_IlegalSystem:Server:HireEmployee', targetServerId)
    else
        QBCore.Functions.Notify('No hay nadie cerca.', 'error')
    end
    cb('ok')
end)

RegisterNUICallback('fireGrowShopEmployee', function(data, cb)
    if data.citizenid then
        TriggerServerEvent('JGR_IlegalSystem:Server:FireEmployee', data.citizenid)
    end
    cb('ok')
end)

RegisterNUICallback('promoteGrowShopEmployee', function(data, cb)
    if data.citizenid then
        TriggerServerEvent('JGR_IlegalSystem:Server:PromoteEmployee', data.citizenid)
    end
    cb('ok')
end)

RegisterNetEvent('JGR_IlegalSystem:Client:UpdateEmployeesList')
AddEventHandler('JGR_IlegalSystem:Client:UpdateEmployeesList', function(employees)
    SendNUIMessage({
        action = "update_grow_employees",
        employees = employees
    })
end)

RegisterNetEvent('JGR_IlegalSystem:Client:UpdateGrowShopMoney')
AddEventHandler('JGR_IlegalSystem:Client:UpdateGrowShopMoney', function(newFunds)
    SendNUIMessage({
        action = "update_grow_money",
        societyFunds = newFunds
    })
end)
