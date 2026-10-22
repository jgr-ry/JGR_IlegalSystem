-- Cliente: panel de administración de bandas (/ilegalpanel)

local function OpenAdminPanel(gangsData)
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

JGR.RegisterModule("gang_admin_client", function()
    -- El servidor comprueba si eres admin y devuelve la lista de bandas
    RegisterCommand('ilegalpanel', function()
        lib.callback('JGR_IlegalSystem:server:GetAdminPanelData', false, function(gangsData)
            if gangsData then
                OpenAdminPanel(gangsData)
            else
                Bridge.Notify(PlayerId(), _L('no_permission'), "error")
            end
        end)
    end, false)

    RegisterNUICallback('closeAdminPanel', function(data, cb)
        SetNuiFocus(false, false)
        cb('ok')
    end)

    RegisterNUICallback('adminEditGang', function(data, cb)
        cb('ok')
        if type(data) == "table" then
            TriggerServerEvent('JGR_IlegalSystem:server:AdminEditGang', data.gangName, data.newMax)
        end
    end)

    RegisterNUICallback('adminDeleteGang', function(data, cb)
        cb('ok')
        if type(data) == "table" then
            TriggerServerEvent('JGR_IlegalSystem:server:AdminDeleteGang', data.gangName)
        end
    end)

    RegisterNetEvent('JGR_IlegalSystem:client:RefreshAdminPanel', function()
        -- La NUI ya actualiza la fila editada/borrada; no hace falta recargar.
    end)
end)
