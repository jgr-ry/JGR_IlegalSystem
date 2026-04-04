-- Client logic for Gang Creation

local currentCreator = nil
local creationData = {}

JGR.RegisterModule("gang_creator_client", function()
    
    -- Command to open the UI
    RegisterCommand('creategang', function()
        -- Normally we would check the server first for a token, but for now we assume they have it 
        -- or we will implement a ServerCallback to verify token.
        
        if Config.Framework == "qbcore" then
            Bridge.Core.Functions.TriggerCallback('JGR_IlegalSystem:server:CheckToken', function(hasToken)
                if hasToken then
                    OpenCreatorUI()
                else
                    Bridge.Notify(PlayerId(), _L('no_permission'), "error")
                end
            end)
        elseif Config.Framework == "esx" then
            Bridge.Core.TriggerServerCallback('JGR_IlegalSystem:server:CheckToken', function(hasToken)
                if hasToken then
                    OpenCreatorUI()
                else
                    Bridge.Notify(PlayerId(), _L('no_permission'), "error")
                end
            end)
        else
            -- Standalone mock
            OpenCreatorUI()
        end
    end, false)

    -- Event returning from GhostPed placement
    RegisterNetEvent("JGR_IlegalSystem:client:ReturnToCreatorUI")
    AddEventHandler("JGR_IlegalSystem:client:ReturnToCreatorUI", function(npcData)
        creationData.npc = npcData
        
        local specs = {}
        for _, specKey in ipairs(Config.GangSystem.Specializations) do
            specs[specKey] = _L("spec_" .. specKey)
        end

        -- Re-open NUI for Step 3 (Specializations)
        SendNUIMessage({
            action = 'open_specialization_step',
            specializations = specs
        })
        SetNuiFocus(true, true)
    end)
    
    -- NUI Callbacks
    RegisterNUICallback('closeUI', function(data, cb)
        SetNuiFocus(false, false)
        if currentCreator then
            currentCreator:Destroy()
            currentCreator = nil
        end
        cb('ok')
    end)

    RegisterNUICallback('step1_config_complete', function(data, cb)
        -- Data contains name, color, ranks, permissions
        creationData.config = data
        SetNuiFocus(false, false)
        
        -- Start Step 2: GhostPed 3D Placement
        currentCreator = GhostPed.new()
        currentCreator:Initialize()
        
        cb('ok')
    end)

    RegisterNUICallback('finishCreation', function(data, cb)
        -- Data contains specialization and finalize info
        creationData.specialization = data.specialization
        
        SetNuiFocus(false, false)
        
        -- Send all data to server
        TriggerServerEvent('JGR_IlegalSystem:server:SaveGang', creationData)
        
        creationData = {} -- Reset
        if currentCreator then
            currentCreator:Destroy()
            currentCreator = nil
        end
        
        cb('ok')
    end)
end)

function OpenCreatorUI()
    SetNuiFocus(true, true)
    
    local uiConfig = {
        CreatorModels = Config.GangSystem.CreatorModels,
        MaxRoles = Config.GangSystem.MaxRoles,
        BasePermissions = {},
        Specializations = {},
        Translations = {
            ui_title = _L("ui_title"),
            ui_subtitle = _L("ui_subtitle"),
            ui_org_name = _L("ui_org_name"),
            ui_ranks = _L("ui_ranks"),
            ui_permissions = _L("ui_permissions"),
            ui_cancel = _L("ui_cancel"),
            ui_continue = _L("ui_continue"),
            ui_spec_title = _L("ui_spec_title"),
            ui_spec_subtitle = _L("ui_spec_subtitle"),
            ui_finish_title = _L("ui_finish_title"),
            ui_finish_desc = _L("ui_finish_desc"),
            ui_finish_btn = _L("ui_finish_btn"),
            ui_add_rank = "NUEVO RANGO"
        }
    }

    for _, permKey in ipairs(Config.GangSystem.BasePermissions) do
        table.insert(uiConfig.BasePermissions, {
            id = permKey,
            label = _L("perm_" .. permKey),
            desc = _L("desc_" .. permKey)
        })
    end
    
    for _, specKey in ipairs(Config.GangSystem.Specializations) do
        uiConfig.Specializations[specKey] = _L("spec_" .. specKey)
    end

    SendNUIMessage({
        action = 'open_gang_creator',
        config = uiConfig
    })
end
