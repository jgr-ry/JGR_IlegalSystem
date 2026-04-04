local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================================
-- LOCAL PLANT CACHE (synced from server)
-- ============================================================
local LocalPlants = {}  -- { [id] = { id, seed_type, coords, stage, water, propHandle } }
local currentHudPlantId = nil

-- ============================================================
-- PROP MANAGEMENT
-- ============================================================
local function GetPropForPlant(seedType, stage)
    local seedCfg = Config.Growing.Seeds[seedType]
    if not seedCfg then return nil end
    local stageCfg = seedCfg.stages[stage]
    if not stageCfg then return nil end
    return stageCfg.prop
end

local function SpawnPlantProp(plant)
    local propName = GetPropForPlant(plant.seed_type, plant.stage)
    if not propName then return end

    local hash = GetHashKey(propName)
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 50 do Wait(10); timeout = timeout + 1 end

    if HasModelLoaded(hash) then
        local obj = CreateObject(hash, plant.coords.x, plant.coords.y, plant.coords.z - 0.3, false, false, false)
        PlaceObjectOnGroundProperly(obj)
        FreezeEntityPosition(obj, true)
        SetEntityCollision(obj, false, false)
        plant.propHandle = obj
    end
end

local function DeletePlantProp(plant)
    if plant.propHandle and DoesEntityExist(plant.propHandle) then
        DeleteEntity(plant.propHandle)
    end
    plant.propHandle = nil
end

local function UpdatePlantProp(plant)
    local expectedProp = GetPropForPlant(plant.seed_type, plant.stage)
    if not expectedProp then return end

    if plant.propHandle and DoesEntityExist(plant.propHandle) then
        local currentModel = GetEntityModel(plant.propHandle)
        if currentModel ~= GetHashKey(expectedProp) then
            DeletePlantProp(plant)
            SpawnPlantProp(plant)
        end
    else
        SpawnPlantProp(plant)
    end
end

-- ============================================================
-- SYNC FROM SERVER
-- ============================================================
RegisterNetEvent('JGR_Drugs:Client:SyncPlants', function(plants)
    for _, p in pairs(LocalPlants) do
        DeletePlantProp(p)
    end
    LocalPlants = {}

    for _, p in ipairs(plants) do
        LocalPlants[p.id] = {
            id = p.id,
            owner = p.owner,
            seed_type = p.seed_type,
            coords = p.coords,
            stage = p.stage,
            water = p.water,
            elapsed = p.elapsed or 0,
            stageTime = p.stageTime or 1
        }
        SpawnPlantProp(LocalPlants[p.id])
    end
end)

RegisterNetEvent('JGR_Drugs:Client:UpdatePlant', function(plantData)
    local existing = LocalPlants[plantData.id]
    if existing then
        existing.stage = plantData.stage
        existing.water = plantData.water
        existing.seed_type = plantData.seed_type
        existing.coords = plantData.coords
        existing.elapsed = plantData.elapsed
        existing.stageTime = plantData.stageTime
        UpdatePlantProp(existing)
    else
        LocalPlants[plantData.id] = plantData
        SpawnPlantProp(plantData)
    end
end)

RegisterNetEvent('JGR_Drugs:Client:RemovePlant', function(plantId)
    local plant = LocalPlants[plantId]
    if plant then
        DeletePlantProp(plant)
        LocalPlants[plantId] = nil
    end
    if currentHudPlantId == plantId then
        SendNUIMessage({ action = "hide_plant_hud" })
        currentHudPlantId = nil
    end
end)

-- Request plants when player loads
CreateThread(function()
    Wait(5000)
    TriggerServerEvent('JGR_Drugs:Server:RequestPlants')
end)

-- ============================================================
-- TERRAIN VALIDATION (RAYCAST)
-- ============================================================
local function GetGroundMaterial(coords)
    local startPos = vector3(coords.x, coords.y, coords.z + 2.0)
    local endPos = vector3(coords.x, coords.y, coords.z - 2.0)

    local handle = StartExpensiveSynchronousShapeTestLosProbe(
        startPos.x, startPos.y, startPos.z,
        endPos.x, endPos.y, endPos.z,
        1, PlayerPedId(), 0
    )

    local _, hit, endCoords, _, materialHash = GetShapeTestResultIncludingMaterial(handle)

    if hit == 1 then
        return materialHash, endCoords
    end

    return nil, coords
end

local function IsValidPlantingSurface(materialHash)
    if not materialHash then return false end
    -- Mask to 32 bits (FiveM natives can return 64-bit sign-extended hashes)
    materialHash = materialHash & 0xFFFFFFFF
    return Config.Growing.AllowedMaterials[materialHash] == true
end

-- ============================================================
-- PLANTING FLOW
-- ============================================================
RegisterNetEvent('JGR_Drugs:Client:StartPlanting', function(seedType)
    if Config.Debug then print('[JGR_Drugs] Client received StartPlanting for: ' .. tostring(seedType)) end

    local seedCfg = Config.Growing.Seeds[seedType]
    if not seedCfg then
        if Config.Debug then print('[JGR_Drugs] ERROR: seed config not found for ' .. tostring(seedType)) end
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local materialHash, groundCoords = GetGroundMaterial(coords)

    if Config.Debug then
        local masked = (materialHash or 0) & 0xFFFFFFFF
        print(('[JGR_Drugs] Material hash: 0x%08X, requiresPot: %s'):format(masked, tostring(seedCfg.requiresPot)))
    end

    -- CBD exception: no ground check, uses pot
    if not seedCfg.requiresPot then
        if not IsValidPlantingSurface(materialHash) then
            if Config.Debug then
                print(('[JGR_Drugs] REJECTED material: 0x%08X'):format((materialHash or 0) & 0xFFFFFFFF))
            end
            QBCore.Functions.Notify("No puedes plantar aquí, necesitas tierra fértil.", "error", 5000)
            return
        end
    end

    -- Planting animation
    local animComplete = false
    if lib then
        animComplete = lib.progressBar({
            duration = 7000,
            label = 'Plantando ' .. seedCfg.label .. '...',
            useWhileDead = false,
            canCancel = true,
            disable = { car = true, move = true, combat = true },
            anim = {
                dict = 'anim@gangops@facility@servers@bodysearch@',
                clip = 'player_search',
                flags = 1
            },
        })
    else
        Wait(7000)
        animComplete = true
    end

    if animComplete then
        TriggerServerEvent('JGR_Drugs:Server:PlantSeed', seedType, groundCoords or coords)
    else
        QBCore.Functions.Notify("Has cancelado la plantación.", "error")
    end
end)

-- ============================================================
-- WATERING FROM INVENTORY (triggered by server when watercan is used)
-- ============================================================
RegisterNetEvent('JGR_Drugs:Client:UseWatercan', function()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)

    -- Find closest plant within 3m
    local closestId = nil
    local closestDist = 999

    for id, plant in pairs(LocalPlants) do
        local plantPos = vector3(plant.coords.x, plant.coords.y, plant.coords.z)
        local dist = #(pos - plantPos)
        if dist < 3.0 and dist < closestDist then
            closestDist = dist
            closestId = id
        end
    end

    if not closestId then
        QBCore.Functions.Notify("No hay ninguna planta cerca para regar.", "error", 3000)
        return
    end

    local plant = LocalPlants[closestId]
    if plant.water >= 100 then
        QBCore.Functions.Notify("Esta planta ya tiene suficiente agua.", "info", 3000)
        return
    end

    -- Watering animation
    local watered = false
    if lib then
        watered = lib.progressBar({
            duration = 4000,
            label = 'Regando planta...',
            useWhileDead = false,
            canCancel = true,
            disable = { car = true, move = true, combat = true },
            anim = {
                dict = 'timetable@gardener@filling_can',
                clip = 'gar_ig_5_filling_can',
                flags = 49
            },
        })
    else
        Wait(4000)
        watered = true
    end

    if watered then
        TriggerServerEvent('JGR_Drugs:Server:WaterPlant', closestId)
    end
end)

-- ============================================================
-- NUI HUD + E-KEY INTERACTION LOOP
-- ============================================================
CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)

        local closestId = nil
        local closestDist = 999

        for id, plant in pairs(LocalPlants) do
            local plantPos = vector3(plant.coords.x, plant.coords.y, plant.coords.z)
            local dist = #(pos - plantPos)

            if dist < closestDist then
                closestDist = dist
                closestId = id
            end
        end

        -- Show NUI HUD when near a plant (< 5m)
        if closestId and closestDist < 2.5 then
            sleep = 0
            local plant = LocalPlants[closestId]
            local seedCfg = Config.Growing.Seeds[plant.seed_type]

            if seedCfg then
                -- Show or update HUD
                if currentHudPlantId ~= closestId then
                    currentHudPlantId = closestId
                    SendNUIMessage({
                        action = "show_plant_hud",
                        name = seedCfg.label,
                        stage = plant.stage,
                        water = plant.water or 0,
                        elapsed = plant.elapsed or 0,
                        stageTime = plant.stageTime or 1
                    })
                else
                    SendNUIMessage({
                        action = "update_plant_hud",
                        stage = plant.stage,
                        water = plant.water or 0,
                        elapsed = plant.elapsed or 0,
                        stageTime = plant.stageTime or 1
                    })
                end

                -- E-key to Harvest (within 2m)
                if closestDist < 2.0 then
                    if IsControlJustReleased(0, 38) then -- E key
                        -- Check for scissors FIRST before animation
                        local hasScissors = QBCore.Functions.HasItem("trimming_scissors")
                        if not hasScissors then
                            QBCore.Functions.Notify("Necesitas tijeras de podar para recoger.", "error", 3000)
                        else
                            local harvested = false
                            if lib then
                                harvested = lib.progressBar({
                                    duration = 6000,
                                    label = 'Recogiendo ' .. seedCfg.label .. '...',
                                    useWhileDead = false,
                                    canCancel = true,
                                    disable = { car = true, move = true, combat = true },
                                    anim = {
                                        dict = 'anim@gangops@facility@servers@bodysearch@',
                                        clip = 'player_search',
                                        flags = 1
                                    },
                                })
                            else
                                Wait(6000)
                                harvested = true
                            end

                            if harvested then
                                TriggerServerEvent('JGR_Drugs:Server:HarvestPlant', closestId)
                            end
                        end
                    end
                end
            end
        else
            -- Hide HUD when moving away
            if currentHudPlantId then
                currentHudPlantId = nil
                SendNUIMessage({ action = "hide_plant_hud" })
            end
        end

        Wait(sleep)
    end
end)

-- ============================================================
-- CLEANUP ON RESOURCE STOP
-- ============================================================
AddEventHandler('onResourceStop', function(resName)
    if GetCurrentResourceName() ~= resName then return end
    for _, plant in pairs(LocalPlants) do
        DeletePlantProp(plant)
    end
    SendNUIMessage({ action = "hide_plant_hud" })
end)
