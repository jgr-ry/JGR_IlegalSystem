local QBCore = exports['qb-core']:GetCoreObject()

local pickupProp = nil -- Entity handle for pickup visual prop

-- ============================================================
-- LARGE ORDER: Physical Pickup Mission (>= 6 items)
-- ============================================================
RegisterNetEvent('JGR_IlegalSystem:Client:StartPickupMission', function(coords)
    SetNewWaypoint(coords.x, coords.y)
    QBCore.Functions.Notify('Pedido grande. Ve al punto del GPS con la furgoneta para recogerlo.', 'primary', 7500)

    -- Spawn visible prop (stack of boxes) so the player can find the pickup spot
    local propHash = GetHashKey("hei_prop_heist_box")
    RequestModel(propHash)
    while not HasModelLoaded(propHash) do Wait(10) end
    pickupProp = CreateObject(propHash, coords.x, coords.y, coords.z - 0.5, false, false, false)
    PlaceObjectOnGroundProperly(pickupProp)
    FreezeEntityPosition(pickupProp, true)

    exports['qb-target']:AddBoxZone("GrowShopPickup", coords, 2.5, 2.5, {
        name = "GrowShopPickup",
        heading = 0,
        debugPoly = false,
        minZ = coords.z - 1.0,
        maxZ = coords.z + 1.5,
    }, {
        options = {
            {
                type = "server",
                event = "JGR_IlegalSystem:Server:CompletePickup",
                icon = "fas fa-box-open",
                label = "Recoger y Cargar Pedido",
                job = Config.GrowShop.JobName
            }
        },
        distance = 3.0
    })
end)

RegisterNetEvent('JGR_IlegalSystem:Client:RemovePickupTarget', function()
    exports['qb-target']:RemoveZone("GrowShopPickup")
    if pickupProp and DoesEntityExist(pickupProp) then
        DeleteEntity(pickupProp)
        pickupProp = nil
    end
end)

-- ============================================================
-- SMALL ORDER: NPC Delivery with HUD Timer (< 6 items)
-- ============================================================
local deliveryTimerActive = false
local deliveryTimeLeft = 0

RegisterNetEvent('JGR_IlegalSystem:Client:StartDeliveryTimer', function(seconds)
    deliveryTimeLeft = seconds
    deliveryTimerActive = true

    -- Show the HUD
    SendNUIMessage({ action = "show_delivery_timer", seconds = seconds })

    -- Countdown loop
    CreateThread(function()
        while deliveryTimerActive and deliveryTimeLeft > 0 do
            Wait(1000)
            deliveryTimeLeft = deliveryTimeLeft - 1
            SendNUIMessage({ action = "update_delivery_timer", seconds = deliveryTimeLeft })
        end
    end)
end)

RegisterNetEvent('JGR_IlegalSystem:Client:DeliveryArrived', function()
    deliveryTimerActive = false
    deliveryTimeLeft = 0
    SendNUIMessage({ action = "hide_delivery_timer" })

    QBCore.Functions.Notify("¡El repartidor ha llegado con tu pedido! Se ha dejado en el almacén.", "success", 7500)

    -- Trigger the NPC walking IN with a box
    RunDeliveryNPC()
end)

local lastDeliveryNPC = nil

function RunDeliveryNPC()
    local hash = GetHashKey('s_m_y_dealer_01')
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(10) end

    -- NPC spawns 15m away from the shop and walks to the stash
    local shopLoc = Config.GrowShop.Location
    local stashLoc = Config.GrowShop.Stash.Location
    local npcSpawn = vector4(shopLoc.x + 15.0, shopLoc.y + 10.0, shopLoc.z, 180.0)
    local targetCoords = stashLoc

    if Config.Debug then
        print(("[GrowShop] NPC Spawn: %.2f, %.2f, %.2f"):format(npcSpawn.x, npcSpawn.y, npcSpawn.z))
        print(("[GrowShop] NPC Target: %.2f, %.2f, %.2f"):format(targetCoords.x, targetCoords.y, targetCoords.z))
    end

    local ped = CreatePed(4, hash, npcSpawn.x, npcSpawn.y, npcSpawn.z, npcSpawn.w, false, true)
    lastDeliveryNPC = ped
    if Config.Debug then
        print(("[GrowShop] NPC Entity: %s, Exists: %s"):format(tostring(ped), tostring(DoesEntityExist(ped))))
    end
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    local prop = CreateObject(GetHashKey("prop_paper_box_02"), 0, 0, 0, true, true, true)
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)

    TaskGoStraightToCoord(ped, targetCoords.x, targetCoords.y, targetCoords.z, 1.0, -1, 0.0, 0.0)

    CreateThread(function()
        while #(GetEntityCoords(ped) - targetCoords) > 1.5 do
            Wait(500)
        end

        DeleteEntity(prop)
        TaskGoStraightToCoord(ped, npcSpawn.x, npcSpawn.y, npcSpawn.z, 1.0, -1, 0.0, 0.0)

        Wait(8000)
        DeleteEntity(ped)
        lastDeliveryNPC = nil

        -- Tell server to put items in stash
        TriggerServerEvent('JGR_IlegalSystem:Server:CompleteDelivery')
    end)
end

-- DEBUG: Test commands (only registered if Config.Debug is true)
if Config.Debug then
    RegisterCommand('testnpc', function()
        print("[GrowShop] Spawning test delivery NPC...")
        RunDeliveryNPC()
    end, false)

    RegisterCommand('tpnpc', function()
        if lastDeliveryNPC and DoesEntityExist(lastDeliveryNPC) then
            local npcPos = GetEntityCoords(lastDeliveryNPC)
            SetEntityCoords(PlayerPedId(), npcPos.x, npcPos.y, npcPos.z, false, false, false, true)
            print(("[GrowShop] TP to NPC at %.2f, %.2f, %.2f"):format(npcPos.x, npcPos.y, npcPos.z))
        else
            print("[GrowShop] No delivery NPC active.")
        end
    end, false)
end

-- ============================================================
-- COMPANY GARAGE (Persistent vehicle, small black marker, QBCore text)
-- ============================================================
local companyVehicle = nil -- Entity handle of the spawned vehicle
local savedDamage = nil   -- Stored damage state

local function SaveVehicleDamage(veh)
    if not DoesEntityExist(veh) then return nil end
    return {
        bodyHealth = GetVehicleBodyHealth(veh),
        engineHealth = GetVehicleEngineHealth(veh),
        dirtLevel = GetVehicleDirtLevel(veh),
    }
end

local function ApplyVehicleDamage(veh, dmg)
    if not dmg then return end
    SetVehicleBodyHealth(veh, dmg.bodyHealth)
    SetVehicleEngineHealth(veh, dmg.engineHealth)
    SetVehicleDirtLevel(veh, dmg.dirtLevel)
end

local isNearGarage = false

CreateThread(function()
    if not Config.GrowShop.Enabled or not Config.GrowShop.Garage then return end

    local garagePos = Config.GrowShop.Garage.Location

    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local dist = #(pos - garagePos)

        if dist < 15.0 then
            sleep = 0
            -- Small black circle marker on the ground
            DrawMarker(25, garagePos.x, garagePos.y, garagePos.z - 0.98, 0, 0, 0, 0, 0, 0, 0.8, 0.8, 0.3, 0, 0, 0, 180, false, false, 2, nil, nil, false)

            if dist < 3.0 then
                local pData = QBCore.Functions.GetPlayerData()
                if pData.job and pData.job.name == Config.GrowShop.JobName then
                    if not isNearGarage then
                        isNearGarage = true
                        exports['qb-core']:DrawText('[E] Garaje de Empresa', 'left')
                    end

                    if IsControlJustReleased(0, 38) then -- E key
                        if IsPedInAnyVehicle(ped, false) then
                            -- STORE vehicle
                            local veh = GetVehiclePedIsIn(ped, false)
                            savedDamage = SaveVehicleDamage(veh)
                            TaskLeaveVehicle(ped, veh, 0)
                            Wait(1500)
                            DeleteVehicle(veh)
                            companyVehicle = nil
                            QBCore.Functions.Notify("Vehículo guardado en el garaje.", "success")
                        elseif companyVehicle and DoesEntityExist(companyVehicle) then
                            QBCore.Functions.Notify("La furgoneta ya está fuera.", "error")
                        else
                            -- SPAWN vehicle
                            QBCore.Functions.SpawnVehicle(Config.GrowShop.Garage.Vehicle, function(veh)
                                companyVehicle = veh
                                local plate = "GROW"..tostring(math.random(1000, 9999))
                                SetVehicleNumberPlateText(veh, plate)
                                SetEntityHeading(veh, Config.GrowShop.Garage.Heading)
                                SetVehicleFuelLevel(veh, 100.0)

                                TriggerServerEvent('qb-vehiclekeys:server:AcquireVehicleKeys', plate)

                                SetVehicleCustomPrimaryColour(veh, 16, 185, 129)
                                SetVehicleCustomSecondaryColour(veh, 168, 85, 247)

                                -- Restore damage if previously stored
                                if savedDamage then
                                    ApplyVehicleDamage(veh, savedDamage)
                                end

                                SetPedIntoVehicle(ped, veh, -1)
                                QBCore.Functions.Notify("Vehículo de empresa retirado.", "success")
                            end, garagePos, true)
                        end
                    end
                end
            else
                if isNearGarage then
                    isNearGarage = false
                    exports['qb-core']:HideText()
                end
            end
        else
            if isNearGarage then
                isNearGarage = false
                exports['qb-core']:HideText()
            end
        end
        Wait(sleep)
    end
end)

-- ============================================================
-- NPC COURIER for El Cocinero Crafting
-- ============================================================
RegisterNetEvent('JGR_IlegalSystem:Client:RunNPCSequence', function(isDelivery)
    local hash = GetHashKey('s_m_y_dealer_01')
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(10) end

    local shopLoc = Config.GrowShop.Location
    local stashLoc = Config.GrowShop.Stash.Location
    local npcSpawn = vector4(shopLoc.x + 15.0, shopLoc.y + 10.0, shopLoc.z, 180.0)
    local targetCoords = stashLoc

    local ped = CreatePed(4, hash, npcSpawn.x, npcSpawn.y, npcSpawn.z, npcSpawn.w, false, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    local prop = CreateObject(GetHashKey("prop_paper_box_02"), 0, 0, 0, true, true, true)
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)

    TaskGoStraightToCoord(ped, targetCoords.x, targetCoords.y, targetCoords.z, 1.0, -1, 0.0, 0.0)

    CreateThread(function()
        while #(GetEntityCoords(ped) - targetCoords) > 1.5 do
            Wait(500)
        end

        DeleteEntity(prop)
        TaskGoStraightToCoord(ped, npcSpawn.x, npcSpawn.y, npcSpawn.z, 1.0, -1, 0.0, 0.0)

        Wait(8000)
        DeleteEntity(ped)

        if isDelivery then
            TriggerServerEvent('JGR_IlegalSystem:Server:CookFinished')
        end
    end)
end)
