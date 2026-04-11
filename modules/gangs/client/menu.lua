JGR.RegisterModule("gang_menu_client", function()
    local CurrentGangData = nil
    local NearPoint = nil

    local function qbDrawPointHint(text)
        if Config.Framework ~= "qbcore" then return end
        pcall(function()
            exports["qb-core"]:DrawText(text)
        end)
    end

    local function qbClearPointHint()
        if Config.Framework ~= "qbcore" then return end
        pcall(function()
            exports["qb-core"]:HideText()
        end)
    end

    local function showPlacementNui(title, subtitle)
        SendNUIMessage({
            action = "show_placement_hint",
            title = title or "Colocar punto",
            subtitle = subtitle,
        })
    end

    local function hidePlacementNui()
        SendNUIMessage({ action = "hide_placement_hint" })
    end

    -- Triggers NUI to open the Dashboard
    function OpenGangMenu(gangName)
        if Config.Framework == "qbcore" then
            Bridge.Core.Functions.TriggerCallback('JGR_IlegalSystem:server:GetGangMenuData', function(data)
                if data then
                    CurrentGangData = data.gang
                    SetNuiFocus(true, true)
                    SendNUIMessage({
                        action = "open_gang_menu",
                        gang = data.gang,
                        permissions = data.permissions,
                        translations = data.translations
                    })
                else
                    Bridge.Notify(PlayerId(), _L('gang_menu_no_data'), "error")
                end
            end, gangName)
        elseif Config.Framework == "esx" then
            Bridge.Core.TriggerServerCallback('JGR_IlegalSystem:server:GetGangMenuData', function(data)
                if data then
                    CurrentGangData = data.gang
                    SetNuiFocus(true, true)
                    SendNUIMessage({
                        action = "open_gang_menu",
                        gang = data.gang,
                        permissions = data.permissions,
                        translations = data.translations
                    })
                else
                    Bridge.Notify(PlayerId(), _L('gang_menu_no_data'), "error")
                end
            end, gangName)
        end
    end

    _G.OpenGangMenu = OpenGangMenu

    --- Carga sede/puntos/stats sin abrir el menú (marcadores en mundo siempre que tengas banda).
    local function SyncGangWorldDataFromServer()
        if Config.Framework == "qbcore" then
            Bridge.Core.Functions.TriggerCallback("JGR_IlegalSystem:server:GetMyGang", function(gangName)
                if type(gangName) == "string" then
                    gangName = gangName:match("^%s*(.-)%s*$")
                end
                if not gangName or gangName == "" then
                    CurrentGangData = nil
                    return
                end
                Bridge.Core.Functions.TriggerCallback("JGR_IlegalSystem:server:GetGangMenuData", function(data)
                    if data and data.gang then
                        CurrentGangData = data.gang
                    end
                end, gangName)
            end)
        elseif Config.Framework == "esx" then
            Bridge.Core.TriggerServerCallback("JGR_IlegalSystem:server:GetMyGang", function(gangName)
                if type(gangName) == "string" then
                    gangName = gangName:match("^%s*(.-)%s*$")
                end
                if not gangName or gangName == "" then
                    CurrentGangData = nil
                    return
                end
                Bridge.Core.TriggerServerCallback("JGR_IlegalSystem:server:GetGangMenuData", function(data)
                    if data and data.gang then
                        CurrentGangData = data.gang
                    end
                end, gangName)
            end)
        else
            CurrentGangData = nil
        end
    end

    _G.JGR_SyncGangWorldData = SyncGangWorldDataFromServer

    -- Helper: Close the gang menu NUI properly
    local function CloseGangMenuNUI()
        SetNuiFocus(false, false)
        SendNUIMessage({ action = "hide_gang_menu" })
    end

    local function ReopenGangMenuAfterWorldAction()
        local gn = CurrentGangData and CurrentGangData.name
        if not gn then return end
        Citizen.SetTimeout(150, function()
            OpenGangMenu(gn)
        end)
    end

    local function DoShapeTestRay(camCoords, endCoords, ped)
        local rayHandle = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, endCoords.x, endCoords.y, endCoords.z, 1 + 16, ped, 0)
        local retval, hit, hitCoords = 1, 0, nil
        local tries = 0
        while retval == 1 and tries < 10 do
            Citizen.Wait(0)
            retval, hit, hitCoords = GetShapeTestResult(rayHandle)
            tries = tries + 1
        end
        return hit, hitCoords
    end

    -- =============================================
    -- RAYCAST PLACEMENT SYSTEM
    -- =============================================
    local isPlacing = false
    local placingType = nil
    local placingMarker = nil
    local pendingTerritory = nil

    local function StartRaycastPlacement(pointType)
        isPlacing = true
        placingType = pointType

        local titles = {
            stash = "Colocar almacén",
            boss = "Colocar punto de gestión",
            garage_menu = "Colocar menú de garaje",
            garage_spawn = "Colocar punto de aparición del vehículo",
            garage_store = "Colocar punto de guardado de vehículo",
            garage = "Colocar menú de garaje (legacy)",
        }
        showPlacementNui(titles[pointType] or ("Colocar: " .. tostring(pointType)), nil)
        Bridge.Notify(PlayerId(), "Apunta y confirma con [E] o cancela con [ESC].", "primary")

        Citizen.CreateThread(function()
            while isPlacing do
                Citizen.Wait(0)

                local camCoords = GetGameplayCamCoord()
                local camRot = GetGameplayCamRot(2)
                local forwardVec = RotationToDirection(camRot)
                local endCoords = camCoords + forwardVec * 30.0

                local ped = PlayerPedId()
                local hit, hitCoords = DoShapeTestRay(camCoords, endCoords, ped)

                if hit == 1 and hitCoords then
                    local mz = hitCoords.z + 1.05
                    DrawMarker(2, hitCoords.x, hitCoords.y, mz, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.28, 0.28, 0.28, 15, 15, 15, 220, false, true, 2, false, nil, nil, false)

                    if IsControlJustPressed(0, 38) or IsDisabledControlJustPressed(0, 38)
                        or IsControlJustReleased(0, 38) or IsDisabledControlJustReleased(0, 38) then
                        local heading = GetEntityHeading(ped)
                        TriggerServerEvent('JGR_IlegalSystem:server:SaveGangPoint', placingType, hitCoords, heading)
                        Bridge.Notify(PlayerId(), "Punto " .. placingType .. " guardado correctamente.", "success")
                        isPlacing = false
                        placingType = nil
                        hidePlacementNui()
                        RefreshGangPoints()
                        ReopenGangMenuAfterWorldAction()
                        break
                    end
                end

                if IsControlJustReleased(0, 200) or IsControlJustReleased(0, 177) then
                    Bridge.Notify(PlayerId(), "Colocación cancelada.", "error")
                    isPlacing = false
                    placingType = nil
                    hidePlacementNui()
                    ReopenGangMenuAfterWorldAction()
                    break
                end
            end
        end)
    end

    local function StartRaycastTerritoryPlacement()
        if not pendingTerritory then return end
        isPlacing = true
        placingType = "territory"

        showPlacementNui("Fijar territorio en el mapa", nil)
        Bridge.Notify(PlayerId(), "Apunta al suelo para fijar el territorio en el mapa. [E] confirmar, [ESC] cancelar.", "primary")

        Citizen.CreateThread(function()
            while isPlacing and placingType == "territory" do
                Citizen.Wait(0)

                local camCoords = GetGameplayCamCoord()
                local camRot = GetGameplayCamRot(2)
                local forwardVec = RotationToDirection(camRot)
                local endCoords = camCoords + forwardVec * 30.0
                local ped = PlayerPedId()
                local hit, hitCoords = DoShapeTestRay(camCoords, endCoords, ped)

                if hit == 1 and hitCoords then
                    local mz = hitCoords.z + 1.05
                    DrawMarker(2, hitCoords.x, hitCoords.y, mz, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.28, 0.28, 0.28, 15, 15, 15, 220, false, true, 2, false, nil, nil, false)
                    if IsControlJustPressed(0, 38) or IsDisabledControlJustPressed(0, 38)
                        or IsControlJustReleased(0, 38) or IsDisabledControlJustReleased(0, 38) then
                        TriggerServerEvent('JGR_IlegalSystem:server:SaveTerritory',
                            pendingTerritory.id,
                            pendingTerritory.title,
                            pendingTerritory.content,
                            pendingTerritory.influence,
                            { x = hitCoords.x, y = hitCoords.y, z = hitCoords.z }
                        )
                        Bridge.Notify(PlayerId(), "Territorio guardado en el mapa.", "success")
                        pendingTerritory = nil
                        isPlacing = false
                        placingType = nil
                        hidePlacementNui()
                        RefreshGangPoints()
                        ReopenGangMenuAfterWorldAction()
                        break
                    end
                end

                if IsControlJustReleased(0, 200) or IsControlJustReleased(0, 177) then
                    Bridge.Notify(PlayerId(), "Colocación cancelada.", "error")
                    pendingTerritory = nil
                    isPlacing = false
                    placingType = nil
                    hidePlacementNui()
                    ReopenGangMenuAfterWorldAction()
                    break
                end
            end
        end)
    end

    -- Helper for raycast direction calculation
    function RotationToDirection(rotation)
        local adjustedRotation = {
            x = (math.pi / 180) * rotation.x,
            y = (math.pi / 180) * rotation.y,
            z = (math.pi / 180) * rotation.z
        }
        local direction = vector3(
            -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
            math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
            math.sin(adjustedRotation.x)
        )
        return direction
    end

    -- =============================================
    -- GANG POINTS INTERACTION SYSTEM
    -- =============================================
    -- Refresh gang data for markers/interactions periodically or on event
    function RefreshGangPoints()
        local gn = CurrentGangData and CurrentGangData.name
        if not gn then
            SyncGangWorldDataFromServer()
            return
        end
        if Config.Framework == "qbcore" then
            Bridge.Core.Functions.TriggerCallback('JGR_IlegalSystem:server:GetGangMenuData', function(data)
                if data then CurrentGangData = data.gang end
            end, gn)
        elseif Config.Framework == "esx" then
            Bridge.Core.TriggerServerCallback('JGR_IlegalSystem:server:GetGangMenuData', function(data)
                if data then CurrentGangData = data.gang end
            end, gn)
        end
    end

    -- Puntos en mundo: sincronizar al entrar (sin tener que abrir el menú del NPC antes).
    Citizen.CreateThread(function()
        Citizen.Wait(2500)
        SyncGangWorldDataFromServer()
    end)

    if Config.Framework == "qbcore" then
        RegisterNetEvent("QBCore:Client:OnPlayerLoaded", function()
            Citizen.SetTimeout(2000, SyncGangWorldDataFromServer)
        end)
    elseif Config.Framework == "esx" then
        RegisterNetEvent("esx:playerLoaded", function()
            Citizen.SetTimeout(2000, SyncGangWorldDataFromServer)
        end)
    end

    -- RefreshNPCs también dispara Sync (ver npc.lua: tras respawn de NPCs).

    -- Main Interaction Loop
    Citizen.CreateThread(function()
        while true do
            local sleep = 1000
            if CurrentGangData and CurrentGangData.stats and CurrentGangData.stats.points then
                local ped = PlayerPedId()
                local coords = GetEntityCoords(ped)
                NearPoint = nil
                local best = nil
                local bestDist = 9999.0

                for pType, pCoords in pairs(CurrentGangData.stats.points) do
                    local dist = #(coords - vector3(pCoords.x, pCoords.y, pCoords.z))
                    if dist < 12.0 then
                        sleep = 0
                        local mz = pCoords.z + 1.05
                        DrawMarker(2, pCoords.x, pCoords.y, mz, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.28, 0.28, 0.28, 15, 15, 15, 210, false, true, 2, false, nil, nil, false)

                        if pType ~= "garage_spawn" then
                            local interactDist = 1.6
                            if pType == "garage_store" then
                                interactDist = 6.0
                            elseif pType == "garage_menu" or pType == "garage" then
                                interactDist = 2.2
                            end

                            if dist < interactDist and dist < bestDist then
                                bestDist = dist
                                best = { type = pType, coords = pCoords }
                            end
                        end
                    end
                end

                if best then
                    NearPoint = best
                    local pType = best.type
                    local label = "Interaccionar"
                    if pType == "stash" then
                        label = "Abrir almacén"
                    elseif pType == "boss" then
                        label = "Panel de banda"
                    elseif pType == "garage_menu" or pType == "garage" then
                        label = "Garaje de banda"
                    elseif pType == "garage_store" then
                        if IsPedInAnyVehicle(ped, false) then
                            label = "Guardar vehículo en garaje"
                        else
                            label = "Entra en un vehículo para guardarlo"
                        end
                    end
                    qbDrawPointHint("[E] " .. label)
                    if IsControlJustReleased(0, 38) then
                        HandlePointInteraction(pType)
                    end
                else
                    qbClearPointHint()
                end
            else
                qbClearPointHint()
            end
            Citizen.Wait(sleep)
        end
    end)

    function HandlePointInteraction(type)
        if type == "boss" then
            OpenGangMenu(CurrentGangData.name)
        elseif type == "stash" then
            if Config.GangInventory == "ox_inventory" and GetResourceState("ox_inventory") == "started" then
                TriggerServerEvent("JGR_IlegalSystem:server:RequestOpenGangStash")
            elseif Config.Framework == "qbcore" and Config.GangInventory ~= "ox_inventory" then
                TriggerServerEvent("inventory:server:OpenInventory", "stash", "gangstash_" .. CurrentGangData.name, {
                    maxweight = 1000000,
                    slots = 100,
                })
                TriggerEvent("inventory:client:SetCurrentStash", "gangstash_" .. CurrentGangData.name)
            else
                Bridge.Notify(PlayerId(), "Almacén no configurado para este servidor.", "error")
            end
        elseif type == "garage_menu" or type == "garage" then
            local mode = Config.GangGarageMenuMode or "ox_lib"
            if mode == "nui" then
                local vehicles = lib.callback.await("JGR_IlegalSystem:server:GetGangGarageVehicles", false)
                if vehicles == nil then vehicles = {} end
                SendNUIMessage({ action = "open_gang_garage_standalone", vehicles = vehicles })
                Citizen.SetTimeout(50, function()
                    SetNuiFocus(true, true)
                end)
                return
            end
            local vehicles
            local okCb = pcall(function()
                vehicles = lib.callback.await("JGR_IlegalSystem:server:GetGangGarageVehicles", false)
            end)
            if not okCb then
                Bridge.Notify(PlayerId(), "Error al cargar el garaje de la banda.", "error")
                return
            end
            if vehicles == nil then vehicles = {} end
            if #vehicles == 0 then
                Bridge.Notify(PlayerId(), "No hay vehículos guardados en el garaje de la banda.", "error")
                return
            end
            local options = {}
            for i, v in ipairs(vehicles) do
                local plate = (v.plate ~= nil and tostring(v.plate)) or "—"
                local model = v.model
                if type(model) == "number" then
                    model = tostring(model)
                else
                    model = tostring(model or "?")
                end
                options[#options + 1] = {
                    title = plate .. "  ·  " .. model,
                    description = "Sacar vehículo al punto de aparición",
                    icon = "car",
                    onSelect = function()
                        TriggerServerEvent("JGR_IlegalSystem:server:SpawnGangGarageVehicle", i)
                    end,
                }
            end
            local ctxId = "jgr_gang_garage_" .. tostring(GetGameTimer())
            lib.registerContext({
                id = ctxId,
                title = "Garaje de la banda",
                options = options,
            })
            lib.showContext(ctxId)
        elseif type == "garage_store" then
            local ped = PlayerPedId()
            if not IsPedInAnyVehicle(ped, false) then
                Bridge.Notify(PlayerId(), "Debes ir dentro del vehículo para guardarlo.", "error")
                return
            end
            local veh = GetVehiclePedIsIn(ped, false)
            if GetPedInVehicleSeat(veh, -1) ~= ped then
                Bridge.Notify(PlayerId(), "Debes ser el conductor.", "error")
                return
            end
            local props = lib.getVehicleProperties(veh)
            if not props or not props.model then
                Bridge.Notify(PlayerId(), "No se pudieron leer los datos del vehículo.", "error")
                return
            end
            TriggerServerEvent("JGR_IlegalSystem:server:SaveGangGarageVehicle", props)
        end
    end

    -- =============================================
    -- NUI CALLBACKS
    -- =============================================

    -- Close UI callbacks
    RegisterNUICallback('close', function(data, cb)
        SetNuiFocus(false, false)
        cb('ok')
    end)

    RegisterNUICallback('closeUI', function(data, cb)
        SetNuiFocus(false, false)
        cb('ok')
    end)

    RegisterNUICallback('closeGangMenu', function(data, cb)
        SetNuiFocus(false, false)
        cb('ok')
    end)

    -- Notifications from NUI
    RegisterNUICallback('notifyError', function(data, cb)
        cb('ok')
        if data and data.msg then
            Bridge.Notify(PlayerId(), data.msg, "error")
        end
    end)

    RegisterNUICallback('notifySuccess', function(data, cb)
        cb('ok')
        if data and data.msg then
            Bridge.Notify(PlayerId(), data.msg, "success")
        end
    end)

    -- Config: Place Point (raycast) — cb primero: si no, el fetch NUI puede quedar colgado
    RegisterNUICallback('placePoint', function(data, cb)
        cb('ok')
        local pType = data and data.type
        CloseGangMenuNUI()
        Citizen.SetTimeout(50, function()
            if pType then StartRaycastPlacement(pType) end
        end)
    end)

    RegisterNUICallback('saveTerritory', function(data, cb)
        cb('ok')
        TriggerServerEvent('JGR_IlegalSystem:server:SaveTerritory', data.id, data.title, data.content, data.influence, nil)
    end)

    RegisterNUICallback('deleteTerritory', function(data, cb)
        cb('ok')
        TriggerServerEvent('JGR_IlegalSystem:server:DeleteTerritory', data.id)
    end)

    RegisterNUICallback('placeTerritoryReq', function(data, cb)
        cb('ok')
        pendingTerritory = {
            id = data.id,
            title = data.title or "",
            content = data.content or "",
            influence = data.influence or 0
        }
        CloseGangMenuNUI()
        Citizen.SetTimeout(50, function()
            StartRaycastTerritoryPlacement()
        end)
    end)

    RegisterNUICallback('submitInvite', function(data, cb)
        cb('ok')
        local tid = data and tonumber(data.targetId)
        local rankName = data and data.rankName
        if tid and rankName and rankName ~= "" then
            TriggerServerEvent('JGR_IlegalSystem:server:InviteMember', tid, rankName)
        end
    end)

    RegisterNUICallback('kickMemberReq', function(data, cb)
        cb('ok')
        local cid = data and data.id
        if cid then
            TriggerServerEvent('JGR_IlegalSystem:server:KickMember', cid)
        end
    end)

    RegisterNUICallback('saveDocument', function(data, cb)
        cb('ok')
        TriggerServerEvent('JGR_IlegalSystem:server:SaveDocument', data.id, data.title, data.content)
        Bridge.Notify(PlayerId(), "Petición de guardado enviada...", "primary")
    end)

    RegisterNUICallback('deleteDocument', function(data, cb)
        cb('ok')
        TriggerServerEvent('JGR_IlegalSystem:server:DeleteDocument', data.id)
    end)

    RegisterNUICallback('submitNewRank', function(data, cb)
        cb('ok')
        local name = data and data.rankName
        if type(name) == "string" then
            name = name:match("^%s*(.-)%s*$")
        end
        if name and name ~= "" then
            TriggerServerEvent('JGR_IlegalSystem:server:CreateRank', name)
        end
    end)

    RegisterNUICallback('deleteRankReq', function(data, cb)
        cb('ok')
        local rankName = data and data.rank
        if rankName and rankName ~= "" then
            TriggerServerEvent('JGR_IlegalSystem:server:DeleteRank', rankName)
        end
    end)

    RegisterNUICallback('updateRankPermsReq', function(data, cb)
        cb('ok')
        if data and data.rank and data.permissions then
            TriggerServerEvent('JGR_IlegalSystem:server:UpdateRankPermissions', data.rank, data.permissions)
        end
    end)

    -- =============================================
    -- SERVER → CLIENT EVENTS (Visual Refresh)
    -- =============================================
    RegisterNetEvent('JGR_IlegalSystem:client:UpdateRanks')
    AddEventHandler('JGR_IlegalSystem:client:UpdateRanks', function(ranks)
        if CurrentGangData then CurrentGangData.ranks = ranks end
        SendNUIMessage({
            action = "update_ranks",
            ranks = ranks
        })
    end)

    RegisterNetEvent('JGR_IlegalSystem:client:UpdateDocuments')
    AddEventHandler('JGR_IlegalSystem:client:UpdateDocuments', function(docs)
        if CurrentGangData and CurrentGangData.stats then CurrentGangData.stats.documents = docs end
        SendNUIMessage({
            action = "update_documents",
            documents = docs
        })
    end)

    RegisterNetEvent('JGR_IlegalSystem:client:UpdateTerritories')
    AddEventHandler('JGR_IlegalSystem:client:UpdateTerritories', function(territories, count)
        if CurrentGangData then
            if not CurrentGangData.stats then CurrentGangData.stats = {} end
            CurrentGangData.stats.territories = territories
            CurrentGangData.territories = count
            CurrentGangData.territories_list = territories
        end
        SendNUIMessage({
            action = "update_territories",
            territories = territories,
            count = count
        })
    end)

    RegisterNetEvent('JGR_IlegalSystem:client:UpdateControlZone')
    AddEventHandler('JGR_IlegalSystem:client:UpdateControlZone', function(zone)
        if CurrentGangData then
            if not CurrentGangData.stats then CurrentGangData.stats = {} end
            CurrentGangData.stats.control_zone = zone
            CurrentGangData.control_zone = zone
            CurrentGangData.territories = zone and 1 or (CurrentGangData.territories or 0)
        end
        SendNUIMessage({
            action = "update_control_zone",
            zone = zone
        })
    end)

    RegisterNUICallback('requestPlayerCoords', function(_, cb)
        local c = GetEntityCoords(PlayerPedId())
        cb({ ok = true, x = c.x, y = c.y, z = c.z })
    end)

    RegisterNUICallback('saveControlZone', function(data, cb)
        cb('ok')
        local c = GetEntityCoords(PlayerPedId())
        local rad = data and tonumber(data.radius) or 100.0
        TriggerServerEvent('JGR_IlegalSystem:server:SaveControlZone', c.x, c.y, c.z, rad)
    end)

    RegisterNetEvent('JGR_IlegalSystem:client:RefreshGangPoints')
    AddEventHandler('JGR_IlegalSystem:client:RefreshGangPoints', function()
        RefreshGangPoints()
    end)

    RegisterNetEvent('JGR_IlegalSystem:client:RequestGangMenuResync')
    AddEventHandler('JGR_IlegalSystem:client:RequestGangMenuResync', function()
        local gn = CurrentGangData and CurrentGangData.name
        if not gn then
            SyncGangWorldDataFromServer()
            return
        end
        if Config.Framework == "qbcore" then
            Bridge.Core.Functions.TriggerCallback('JGR_IlegalSystem:server:GetGangMenuData', function(data)
                if not data or not data.gang then return end
                CurrentGangData = data.gang
                SendNUIMessage({
                    action = 'gang_menu_sync',
                    gang = data.gang,
                    permissions = data.permissions,
                    translations = data.translations,
                })
            end, gn)
        elseif Config.Framework == "esx" then
            Bridge.Core.TriggerServerCallback('JGR_IlegalSystem:server:GetGangMenuData', function(data)
                if not data or not data.gang then return end
                CurrentGangData = data.gang
                SendNUIMessage({
                    action = 'gang_menu_sync',
                    gang = data.gang,
                    permissions = data.permissions,
                    translations = data.translations,
                })
            end, gn)
        end
    end)

    RegisterNetEvent('JGR_IlegalSystem:client:OpenOxGangStash', function(gangName)
        if not gangName or GetResourceState("ox_inventory") ~= "started" then return end
        local stashId = "jgr_gang_" .. tostring(gangName):gsub("%s+", "_")
        exports.ox_inventory:openInventory("stash", stashId)
    end)

    RegisterNetEvent('JGR_IlegalSystem:client:DeleteGarageVehicleEntity', function()
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            if veh and veh ~= 0 then
                TaskLeaveVehicle(ped, veh, 0)
                Citizen.Wait(400)
                if DoesEntityExist(veh) then
                    DeleteEntity(veh)
                end
            end
        end
    end)

    RegisterNetEvent('JGR_IlegalSystem:client:SpawnGangGarageVehicle', function(props, spawn)
        if type(props) ~= "table" or type(spawn) ~= "table" or spawn.x == nil then return end
        local model = props.model
        if type(model) == "string" then
            model = joaat(model)
        end
        if not model or not IsModelAVehicle(model) then
            Bridge.Notify(PlayerId(), "Modelo de vehículo no válido.", "error")
            return
        end
        lib.requestModel(model, 10000)
        local h = spawn.h or 0.0
        local veh = CreateVehicle(model, spawn.x + 0.0, spawn.y + 0.0, spawn.z + 0.0, h + 0.0, true, false)
        if not veh or veh == 0 then
            Bridge.Notify(PlayerId(), "No se pudo crear el vehículo.", "error")
            return
        end
        SetEntityAsMissionEntity(veh, true, true)
        SetVehicleOnGroundProperly(veh)
        if lib.setVehicleProperties then
            lib.setVehicleProperties(veh, props)
        end
        local ped = PlayerPedId()
        TaskWarpPedIntoVehicle(ped, veh, -1)
        SetModelAsNoLongerNeeded(model)
    end)

    RegisterNUICallback('closeGangGarageStandalone', function(_, cb)
        SetNuiFocus(false, false)
        SendNUIMessage({ action = "hide_gang_garage_standalone" })
        cb('ok')
    end)

    RegisterNUICallback('takeGangGarageVehicle', function(data, cb)
        cb('ok')
        SetNuiFocus(false, false)
        SendNUIMessage({ action = "hide_gang_garage_standalone" })
        local idx = data and tonumber(data.index)
        if idx then
            TriggerServerEvent('JGR_IlegalSystem:server:SpawnGangGarageVehicle', idx)
        end
    end)
end)

