JGR.RegisterModule("gang_menu_client", function()
    -- Triggers NUI to open the Dashboard
    function OpenGangMenu(gangName)
        if Config.Framework == "qbcore" then
            Bridge.Core.Functions.TriggerCallback('JGR_IlegalSystem:server:GetGangMenuData', function(data)
                if data then
                    SetNuiFocus(true, true)
                    SendNUIMessage({
                        action = "open_gang_menu",
                        gang = data.gang,
                        permissions = data.permissions
                    })
                end
            end, gangName)
        elseif Config.Framework == "esx" then
            Bridge.Core.TriggerServerCallback('JGR_IlegalSystem:server:GetGangMenuData', function(data)
                if data then
                    SetNuiFocus(true, true)
                    SendNUIMessage({
                        action = "open_gang_menu",
                        gang = data.gang,
                        permissions = data.permissions
                    })
                end
            end, gangName)
        end
    end

    -- Helper: Close the gang menu NUI properly
    local function CloseGangMenuNUI()
        SetNuiFocus(false, false)
        SendNUIMessage({ action = "hide_gang_menu" })
    end

    -- =============================================
    -- RAYCAST PLACEMENT SYSTEM
    -- =============================================
    local isPlacing = false
    local placingType = nil
    local placingMarker = nil

    local function StartRaycastPlacement(pointType)
        isPlacing = true
        placingType = pointType

        local typeLabels = {
            stash = "~b~ALMACÉN~w~",
            garage = "~g~GARAJE~w~",
            boss = "~p~PUNTO DE JEFE~w~"
        }
        local label = typeLabels[pointType] or pointType

        Bridge.Notify(PlayerId(), "Apunta al suelo para colocar el " .. pointType .. ". Pulsa [E] para confirmar o [ESC] para cancelar.", "primary")

        Citizen.CreateThread(function()
            while isPlacing do
                Citizen.Wait(0)

                -- Draw help text
                SetTextComponentFormat("STRING")
                AddTextComponentString("~INPUT_CONTEXT~ Colocar " .. label .. "  |  ~INPUT_FRONTEND_CANCEL~ Cancelar")
                DisplayHelpTextFromStringLabel(0, false, true, -1)

                -- Raycast from camera
                local camCoords = GetGameplayCamCoord()
                local camRot = GetGameplayCamRot(2)
                local forwardVec = RotationToDirection(camRot)
                local endCoords = camCoords + forwardVec * 30.0

                local rayHandle = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, endCoords.x, endCoords.y, endCoords.z, 1 + 16, PlayerPedId(), 0)
                local _, hit, hitCoords, surfaceNormal, _ = GetShapeTestResult(rayHandle)

                if hit == 1 then
                    -- Draw marker at hit position
                    DrawMarker(
                        25, -- cylinder
                        hitCoords.x, hitCoords.y, hitCoords.z + 0.03,
                        0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0,
                        1.0, 1.0, 0.5,
                        100, 200, 255, 150,
                        false, true, 2, false, nil, nil, false
                    )

                    -- Confirm with E
                    if IsControlJustReleased(0, 38) then -- E key
                        local heading = GetEntityHeading(PlayerPedId())
                        TriggerServerEvent('JGR_IlegalSystem:server:SaveGangPoint', placingType, hitCoords, heading)
                        Bridge.Notify(PlayerId(), "Punto " .. placingType .. " guardado correctamente.", "success")
                        isPlacing = false
                        placingType = nil
                        break
                    end
                end

                -- Cancel with ESC or Backspace
                if IsControlJustReleased(0, 200) or IsControlJustReleased(0, 177) then
                    Bridge.Notify(PlayerId(), "Colocación cancelada.", "error")
                    isPlacing = false
                    placingType = nil
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
    local CurrentGangData = nil
    local NearPoint = nil

    -- Refresh gang data for markers/interactions periodically or on event
    function RefreshGangPoints()
        if Config.Framework == "qbcore" then
            Bridge.Core.Functions.TriggerCallback('JGR_IlegalSystem:server:GetGangMenuData', function(data)
                if data then CurrentGangData = data.gang end
            end)
        elseif Config.Framework == "esx" then
            Bridge.Core.TriggerServerCallback('JGR_IlegalSystem:server:GetGangMenuData', function(data)
                if data then CurrentGangData = data.gang end
            end)
        end
    end

    -- Initial fetch
    Citizen.CreateThread(function()
        Citizen.Wait(1000)
        RefreshGangPoints()
    end)

    -- Main Interaction Loop
    Citizen.CreateThread(function()
        while true do
            local sleep = 1000
            if CurrentGangData and CurrentGangData.stats and CurrentGangData.stats.points then
                local ped = PlayerPedId()
                local coords = GetEntityCoords(ped)
                NearPoint = nil

                for pType, pCoords in pairs(CurrentGangData.stats.points) do
                    local dist = #(coords - vector3(pCoords.x, pCoords.y, pCoords.z))
                    if dist < 10.0 then
                        sleep = 0
                        local markerColor = {r = 100, g = 200, b = 255}
                        if pType == "stash" then markerColor = {r = 50, g = 150, b = 255} 
                        elseif pType == "garage" then markerColor = {r = 50, g = 255, b = 150} 
                        elseif pType == "boss" then markerColor = {r = 200, g = 100, b = 255} end

                        DrawMarker(2, pCoords.x, pCoords.y, pCoords.z + 0.2, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.35, 0.35, 0.35, markerColor.r, markerColor.g, markerColor.b, 150, true, true, 2, false, nil, nil, false)

                        if dist < 1.5 then
                            NearPoint = { type = pType, coords = pCoords }
                            local label = "Interaccionar"
                            if pType == "stash" then label = "Abrir Almacén"
                            elseif pType == "garage" then label = "Abrir Garaje"
                            elseif pType == "boss" then label = "Gestión de Banda" end

                            SetTextComponentFormat("STRING")
                            AddTextComponentString("~INPUT_CONTEXT~ " .. label)
                            DisplayHelpTextFromStringLabel(0, false, true, -1)

                            if IsControlJustReleased(0, 38) then
                                HandlePointInteraction(pType)
                            end
                        end
                    end
                end
            end
            Citizen.Wait(sleep)
        end
    end)

    function HandlePointInteraction(type)
        if type == "boss" then
            OpenGangMenu(CurrentGangData.name)
        elseif type == "stash" then
            -- Trigger Stash (QB/OX)
            if Config.Framework == "qbcore" then
                TriggerServerEvent("inventory:server:OpenInventory", "stash", "gangstash_" .. CurrentGangData.name, {
                    maxweight = 1000000,
                    slots = 100,
                })
                TriggerEvent("inventory:client:SetCurrentStash", "gangstash_" .. CurrentGangData.name)
            else
                -- ESX / OX logic placeholder
                Bridge.Notify(PlayerId(), "Funcionalidad de almacén no configurada para este framework", "error")
            end
        elseif type == "garage" then
            -- Trigger Garage logic
            Bridge.Notify(PlayerId(), "Abriendo garaje de banda...", "primary")
            -- This would typically call a garage menu event
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
        Bridge.Notify(PlayerId(), data.msg, "error")
        cb('ok')
    end)

    RegisterNUICallback('notifySuccess', function(data, cb)
        Bridge.Notify(PlayerId(), data.msg, "success")
        cb('ok')
    end)

    -- Config: Place Point (raycast)
    RegisterNUICallback('placePoint', function(data, cb)
        CloseGangMenuNUI()
        StartRaycastPlacement(data.type)
        cb('ok')
    end)

    -- Config: Invite Member
    RegisterNUICallback('inviteMemberReq', function(data, cb)
        CloseGangMenuNUI()
        
        local input = lib.inputDialog("INVITAR MIEMBRO", {
            {type = 'number', label = 'ID del Jugador', description = 'ID de servidor del jugador a invitar', required = true, min = 1},
            {type = 'input', label = 'Nombre del Rango', description = 'Escribe exactamente el nombre de un rango existente', required = true}
        })

        if not input then return cb('ok') end
        local targetId = input[1]
        local rankName = input[2]

        TriggerServerEvent('JGR_IlegalSystem:server:InviteMember', targetId, rankName)
        cb('ok')
    end)

    -- Config: Kick Member
    RegisterNUICallback('kickMemberReq', function(data, cb)
        local targetId = data.id
        TriggerServerEvent('JGR_IlegalSystem:server:KickMember', targetId)
        cb('ok')
    end)

    -- Documents: Save
    RegisterNUICallback('saveDocument', function(data, cb)
        TriggerServerEvent('JGR_IlegalSystem:server:SaveDocument', data.id, data.title, data.content)
        Bridge.Notify(PlayerId(), "Petición de guardado enviada...", "primary")
        cb('ok')
    end)

    -- Documents: Delete
    RegisterNUICallback('deleteDocument', function(data, cb)
        TriggerServerEvent('JGR_IlegalSystem:server:DeleteDocument', data.id)
        cb('ok')
    end)

    -- Config: Create Rank
    RegisterNUICallback('manageRanksReq', function(data, cb)
        CloseGangMenuNUI()
        
        local input = lib.inputDialog("CREAR NUEVO RANGO", {
            {type = 'input', label = 'Nombre del Rango', description = 'Nombre del nuevo rango a crear', required = true}
        })

        if not input then return cb('ok') end
        local newRankName = input[1]

        if newRankName and newRankName ~= "" then
            TriggerServerEvent('JGR_IlegalSystem:server:CreateRank', newRankName)
        end
        cb('ok')
    end)

    -- Config: Delete Rank
    RegisterNUICallback('deleteRankReq', function(data, cb)
        local rankName = data.rank
        if rankName and rankName ~= "" then
            TriggerServerEvent('JGR_IlegalSystem:server:DeleteRank', rankName)
        end
        cb('ok')
    end)

    -- Config: Update Rank Permissions
    RegisterNUICallback('updateRankPermsReq', function(data, cb)
        TriggerServerEvent('JGR_IlegalSystem:server:UpdateRankPermissions', data.rank, data.permissions)
        cb('ok')
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
end)

