Bridge = {}

-- Auto-detect or use Config.Framework
if Config.Framework == "qbcore" then
    Bridge.Core = exports['qb-core']:GetCoreObject()
elseif Config.Framework == "esx" then
    Bridge.Core = exports['es_extended']:getSharedObject()
end

-- Abstract get player by ID
function Bridge.GetPlayer(source)
    if Config.Framework == "qbcore" then
        return Bridge.Core.Functions.GetPlayer(source)
    elseif Config.Framework == "esx" then
        return Bridge.Core.GetPlayerFromId(source)
    end
    return nil
end

function Bridge.Notify(source, msg, type)
    if IsDuplicityVersion() then
        -- Server Side
        if Config.Framework == "qbcore" then
            TriggerClientEvent('QBCore:Notify', source, msg, type)
        elseif Config.Framework == "esx" then
            TriggerClientEvent('esx:showNotification', source, msg)
        else
            TriggerClientEvent('ox_lib:notify', source, { description = msg, type = type })
        end
    else
        -- Client Side
        if Config.Framework == "qbcore" then
            TriggerEvent('QBCore:Notify', msg, type)
        elseif Config.Framework == "esx" then
            TriggerEvent('esx:showNotification', msg)
        else
            TriggerEvent('ox_lib:notify', { description = msg, type = type })
        end
    end
end
