-- Client logic for Admin Panel

JGR.RegisterModule("gang_admin_client", function()
    -- Command to open the Admin Panel
    RegisterCommand('ilegalpanel', function()
        -- Ask server to verify if we are admin and get gang list
        if Config.Framework == "qbcore" then
            Bridge.Core.Functions.TriggerCallback('JGR_IlegalSystem:server:GetAdminPanelData', function(gangsData)
                if gangsData then
                    OpenAdminPanel(gangsData)
                else
                    Bridge.Notify(PlayerId(), _L('no_permission'), "error")
                end
            end)
        elseif Config.Framework == "esx" then
            Bridge.Core.TriggerServerCallback('JGR_IlegalSystem:server:GetAdminPanelData', function(gangsData)
                if gangsData then
                    OpenAdminPanel(gangsData)
                else
                    Bridge.Notify(PlayerId(), _L('no_permission'), "error")
                end
            end)
        else
            -- Standalone fallback
            Bridge.Notify(PlayerId(), "Command unsupported in standalone currently.", "error")
        end
    end, false)

    -- NUI Callbacks for Admin Panel
    RegisterNUICallback('closeAdminPanel', function(data, cb)
        SetNuiFocus(false, false)
        cb('ok')
    end)

    RegisterNUICallback('adminEditGang', function(data, cb)
        -- Ask user for input via dialog or simply send NUI value to server
        -- If data just contains gangName and newMax, send to server
        TriggerServerEvent('JGR_IlegalSystem:server:AdminEditGang', data.gangName, data.newMax)
        cb('ok')
    end)

    RegisterNUICallback('adminDeleteGang', function(data, cb)
        -- Delete gang entirely
        TriggerServerEvent('JGR_IlegalSystem:server:AdminDeleteGang', data.gangName)
        cb('ok')
    end)
    
    -- Refresh event
    RegisterNetEvent('JGR_IlegalSystem:client:RefreshAdminPanel')
    AddEventHandler('JGR_IlegalSystem:client:RefreshAdminPanel', function()
        -- Re-fetch and update if panel is open (Optional enhancement)
    end)
end)

function OpenAdminPanel(gangsData)
    SetNuiFocus(true, true)
    
    SendNUIMessage({
        action = 'open_admin_panel',
        gangs = gangsData,
        translations = {
            panel_title = _L('admin_panel_title'),
            panel_desc = _L('admin_panel_desc'),
            btn_close = _L('ui_cancel'),
            table_name = _L('table_name'),
            table_members = _L('table_members'),
            table_max = _L('table_max'),
            table_actions = _L('table_actions'),
            action_edit = _L('action_edit'),
            action_delete = _L('action_delete')
        }
    })
end
