-- Cliente: logística del Grow Shop (recogidas, repartos, garaje de empresa y NPC del Cocinero)

local pickupProp = nil -- Caja visible en el punto de recogida
local NPC_WALK_TIMEOUT = 60000 -- ms máximos esperando a que el NPC llegue (evita bucles infinitos)
local RunDeliveryNPC

--- Espera a que el ped llegue a destino o se agote el tiempo.
local function waitForArrival(ped, target, timeoutMs)
    local deadline = GetGameTimer() + (timeoutMs or NPC_WALK_TIMEOUT)
    while DoesEntityExist(ped) and #(GetEntityCoords(ped) - target) > 1.5 and GetGameTimer() < deadline do
        Wait(500)
    end
end

-- ============================================================
-- LARGE ORDER: Physical Pickup Mission (>= 6 items)
-- ============================================================
local function clearPickup()
    Bridge.RemoveZone("GrowShopPickup")
    if pickupProp and DoesEntityExist(pickupProp) then
        DeleteEntity(pickupProp)
    end
    pickupProp = nil
end

RegisterNetEvent('JGR_IlegalSystem:Client:StartPickupMission', function(coords)
    if type(coords) ~= "vector3" and type(coords) ~= "table" then return end
    coords = vector3(coords.x, coords.y, coords.z)
    clearPickup()
    SetNewWaypoint(coords.x, coords.y)
    Bridge.Notify(PlayerId(), 'Pedido grande. Ve al punto del GPS con la furgoneta para recogerlo.', 'primary')

    -- Caja visible para encontrar el punto de recogida
    local propHash = GetHashKey("hei_prop_heist_box")
    if pcall(lib.requestModel, propHash, 10000) then
        pickupProp = CreateObject(propHash, coords.x, coords.y, coords.z - 0.5, false, false, false)
        PlaceObjectOnGroundProperly(pickupProp)
        FreezeEntityPosition(pickupProp, true)
        SetModelAsNoLongerNeeded(propHash)
    end

    Bridge.AddBoxZone("GrowShopPickup", coords, 2.5, 0.0, {
        {
            label = "Recoger y Cargar Pedido",
            icon = "fas fa-box-open",
            onSelect = function()
                TriggerServerEvent("JGR_IlegalSystem:Server:CompletePickup")
            end,
        },
    }, 3.0)
end)

RegisterNetEvent('JGR_IlegalSystem:Client:RemovePickupTarget', clearPickup)

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

    Bridge.Notify(PlayerId(), "¡El repartidor ha llegado con tu pedido! Se ha dejado en el almacén.", "success")

    -- Trigger the NPC walking IN with a box
    RunDeliveryNPC()
end)

local lastDeliveryNPC = nil

function RunDeliveryNPC()
    local hash = GetHashKey('s_m_y_dealer_01')
    if not pcall(lib.requestModel, hash, 10000) then
        TriggerServerEvent('JGR_IlegalSystem:Server:CompleteDelivery')
        return
    end

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

    local boxHash = GetHashKey("prop_paper_box_02")
    pcall(lib.requestModel, boxHash, 5000)
    local prop = CreateObject(boxHash, 0, 0, 0, false, true, true)
    SetModelAsNoLongerNeeded(boxHash)
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)

    TaskGoStraightToCoord(ped, targetCoords.x, targetCoords.y, targetCoords.z, 1.0, -1, 0.0, 0.0)

    CreateThread(function()
        waitForArrival(ped, targetCoords)

        if DoesEntityExist(prop) then DeleteEntity(prop) end
        TaskGoStraightToCoord(ped, npcSpawn.x, npcSpawn.y, npcSpawn.z, 1.0, -1, 0.0, 0.0)

        Wait(8000)
        if DoesEntityExist(ped) then DeleteEntity(ped) end
        lastDeliveryNPC = nil

        -- El servidor deja los items en el almacén (comprueba que el pedido esté listo)
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
-- GARAJE DE EMPRESA (furgoneta persistente, marcador negro y texto de ayuda)
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
local GARAGE_TEXT = "growshop_garage"

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

            if dist < 3.0 and JGR.GrowShop and JGR.GrowShop.Role then
                if not isNearGarage then
                    isNearGarage = true
                    Bridge.ShowText(GARAGE_TEXT, '[E] Garaje de Empresa')
                end

                if IsControlJustReleased(0, 38) then -- Tecla E
                    if IsPedInAnyVehicle(ped, false) then
                        -- GUARDAR: solo la furgoneta de la empresa (antes borraba cualquier vehículo)
                        local veh = GetVehiclePedIsIn(ped, false)
                        local isCompany = veh == companyVehicle
                            or (GetVehicleNumberPlateText(veh) or ""):find("^%s*GROW") ~= nil
                        if not isCompany then
                            Bridge.Notify(PlayerId(), "Solo puedes guardar la furgoneta de la empresa.", "error")
                        else
                            savedDamage = SaveVehicleDamage(veh)
                            TaskLeaveVehicle(ped, veh, 0)
                            Wait(1500)
                            if DoesEntityExist(veh) then DeleteVehicle(veh) end
                            companyVehicle = nil
                            Bridge.Notify(PlayerId(), "Vehículo guardado en el garaje.", "success")
                        end
                    elseif companyVehicle and DoesEntityExist(companyVehicle) then
                        Bridge.Notify(PlayerId(), "La furgoneta ya está fuera.", "error")
                    else
                        -- SACAR la furgoneta
                        Bridge.SpawnVehicle(Config.GrowShop.Garage.Vehicle, garagePos, Config.GrowShop.Garage.Heading, function(veh)
                            if not veh then
                                Bridge.Notify(PlayerId(), "No se pudo sacar el vehículo.", "error")
                                return
                            end
                            companyVehicle = veh
                            local plate = "GROW" .. tostring(math.random(1000, 9999))
                            SetVehicleNumberPlateText(veh, plate)
                            SetEntityHeading(veh, Config.GrowShop.Garage.Heading)
                            Bridge.SetFuel(veh, 100.0)
                            Bridge.GiveKeys(veh, plate)

                            SetVehicleCustomPrimaryColour(veh, 16, 185, 129)
                            SetVehicleCustomSecondaryColour(veh, 168, 85, 247)

                            if savedDamage then
                                ApplyVehicleDamage(veh, savedDamage)
                            end

                            SetPedIntoVehicle(ped, veh, -1)
                            Bridge.Notify(PlayerId(), "Vehículo de empresa retirado.", "success")
                        end)
                    end
                end
            elseif isNearGarage then
                isNearGarage = false
                Bridge.HideText(GARAGE_TEXT)
            end
        elseif isNearGarage then
            isNearGarage = false
            Bridge.HideText(GARAGE_TEXT)
        end
        Wait(sleep)
    end
end)

-- ============================================================
-- NPC COURIER for El Cocinero Crafting
-- ============================================================
RegisterNetEvent('JGR_IlegalSystem:Client:RunNPCSequence', function(isDelivery)
    local hash = GetHashKey('s_m_y_dealer_01')
    if not pcall(lib.requestModel, hash, 10000) then
        if isDelivery then TriggerServerEvent('JGR_IlegalSystem:Server:CookFinished') end
        return
    end

    local shopLoc = Config.GrowShop.Location
    local stashLoc = Config.GrowShop.Stash.Location
    local npcSpawn = vector4(shopLoc.x + 15.0, shopLoc.y + 10.0, shopLoc.z, 180.0)
    local targetCoords = stashLoc

    local ped = CreatePed(4, hash, npcSpawn.x, npcSpawn.y, npcSpawn.z, npcSpawn.w, false, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    local boxHash = GetHashKey("prop_paper_box_02")
    pcall(lib.requestModel, boxHash, 5000)
    local prop = CreateObject(boxHash, 0, 0, 0, false, true, true)
    SetModelAsNoLongerNeeded(boxHash)
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)

    TaskGoStraightToCoord(ped, targetCoords.x, targetCoords.y, targetCoords.z, 1.0, -1, 0.0, 0.0)

    CreateThread(function()
        waitForArrival(ped, targetCoords)

        if DoesEntityExist(prop) then DeleteEntity(prop) end
        TaskGoStraightToCoord(ped, npcSpawn.x, npcSpawn.y, npcSpawn.z, 1.0, -1, 0.0, 0.0)

        Wait(8000)
        if DoesEntityExist(ped) then DeleteEntity(ped) end

        if isDelivery then
            TriggerServerEvent('JGR_IlegalSystem:Server:CookFinished')
        end
    end)
end)
