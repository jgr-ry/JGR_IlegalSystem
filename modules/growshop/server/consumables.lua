local QBCore = exports['qb-core']:GetCoreObject()

local Consumables = {
    ["joint_weed"]   = { health = 10, armor = 0, effect = "weed" },
    ["joint_cbd"]    = { health = 30, armor = 0, effect = "cbd" },
    ["joint_kush"]   = { health = 20, armor = 10, effect = "kush" },
    ["blunt_amnesia"]= { health = 50, armor = 20, effect = "amnesia" },
    ["weed_cookie"]  = { health = 40, armor = 0, effect = "cookie" },
    ["weed_brownie"] = { health = 60, armor = 0, effect = "brownie" },
    ["thc_gummies"]  = { health = 15, armor = 5, effect = "gummies" }
}

Citizen.CreateThread(function()
    if Config.Framework == "qbcore" then
        for itemName, data in pairs(Consumables) do
            QBCore.Functions.CreateUseableItem(itemName, function(source, item)
                local src = source
                local Player = QBCore.Functions.GetPlayer(src)
                if not Player then return end
                
                if Player.Functions.RemoveItem(item.name, 1, item.slot) then
                    -- Trigger client event to play animation and screen effects
                    TriggerClientEvent("JGR_IlegalSystem:Client:UseConsumable", src, item.name, data)
                end
            end)
        end

        -- Rolling Paper (Phase 3.5)
        QBCore.Functions.CreateUseableItem("rolling_paper", function(source, item)
            local src = source
            TriggerClientEvent("JGR_IlegalSystem:Client:OpenRollingMenu", src)
        end)
    end
end)

RegisterNetEvent('JGR_IlegalSystem:Server:FinishRolling', function(reqItem, rewardItem, paperReq)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    paperReq = paperReq or 1

    local hasBud = Player.Functions.GetItemByName(reqItem)
    local hasPaper = Player.Functions.GetItemByName("rolling_paper")

    if hasBud and hasBud.amount >= 1 and hasPaper and hasPaper.amount >= paperReq then
        Player.Functions.RemoveItem(reqItem, 1)
        Player.Functions.RemoveItem("rolling_paper", paperReq)
        Player.Functions.AddItem(rewardItem, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[rewardItem], "add")
    else
        TriggerClientEvent('QBCore:Notify', src, "Te faltan materiales para liar esto.", "error")
    end
end)
