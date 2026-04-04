local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent("JGR_IlegalSystem:Client:UseConsumable", function(itemName, data)
    local playerPed = PlayerPedId()

    -- Decide the animation based on item type
    local animDict, animName, propModel, propBone, propPlacement
    
    if string.find(itemName, "joint") or string.find(itemName, "blunt") then
        -- Smoking animation
        animDict = "amb@world_human_smoking_pot@male@base"
        animName = "base"
        propModel = "p_cs_joint_02"
        propBone = 28422
        propPlacement = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0}
    elseif string.find(itemName, "cookie") or string.find(itemName, "brownie") or string.find(itemName, "gummies") then
        -- Eating animation
        animDict = "mp_player_inteat@burger"
        animName = "mp_player_int_eat_burger"
        propModel = "prop_cs_burger_01" -- default fallback, can be changed later
        if string.find(itemName, "cookie") then propModel = "prop_choc_ego" end
        propBone = 18905
        propPlacement = {0.12, 0.028, 0.001, 10.0, 175.0, 0.0}
    end

    -- Play animation using ox_lib progress bar if available, or just standard playAnim
    if lib then
        lib.progressBar({
            duration = 5000,
            label = ("Consumiendo %s"):format(itemName),
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = false,
                move = false,
                combat = true
            },
            anim = {
                dict = animDict,
                clip = animName,
                flags = 49
            },
            prop = {
                model = propModel,
                bone = propBone,
                pos = vector3(propPlacement[1], propPlacement[2], propPlacement[3]),
                rot = vector3(propPlacement[4], propPlacement[5], propPlacement[6])
            }
        })
    else
        -- Fallback if ox_lib not present
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do Wait(10) end
        TaskPlayAnim(playerPed, animDict, animName, 8.0, 8.0, -1, 49, 0, false, false, false)
        Wait(5000)
        ClearPedTasks(playerPed)
    end

    -- Apply Effects
    -- Health
    if data.health > 0 then
        local maxHealth = GetEntityMaxHealth(playerPed)
        local newHealth = GetEntityHealth(playerPed) + data.health
        if newHealth > maxHealth then newHealth = maxHealth end
        SetEntityHealth(playerPed, newHealth)
    end

    -- Armor
    if data.armor > 0 then
        local maxArmor = 100
        local newArmor = GetPedArmor(playerPed) + data.armor
        if newArmor > maxArmor then newArmor = maxArmor end
        SetPedArmor(playerPed, newArmor)
    end

    -- Apply Screen Visual Effects using GTAV Timecycle Modifiers
    if data.effect == "weed" then
        SetTimecycleModifier("Spectator6")
        SetTimecycleModifierStrength(0.5)
    elseif data.effect == "cbd" then
        SetTimecycleModifier("Spectator8")
        SetTimecycleModifierStrength(0.3)
    elseif data.effect == "kush" then
        SetTimecycleModifier("drug_drive_blend01")
        SetTimecycleModifierStrength(0.8)
    elseif data.effect == "amnesia" then
        SetTimecycleModifier("DrugsMichaelAliensFightIn")
        SetTimecycleModifierStrength(1.0)
    elseif data.effect == "cookie" or data.effect == "brownie" then
        -- Delayed effect for edibles
        SetTimeout(15000, function()
            SetTimecycleModifier("drug_wobbly")
            SetTimecycleModifierStrength(0.8)
        end)
    elseif data.effect == "gummies" then
        SetTimecycleModifier("TrevorColorCode")
        SetTimecycleModifierStrength(0.6)
    end

    -- Clear effect after some time
    local effectDuration = 30000 -- 30 seconds default
    if string.find(itemName, "blunt") or string.find(itemName, "brownie") then
        effectDuration = 60000 -- 1 minute
    end

    SetTimeout(effectDuration, function()
        ClearTimecycleModifier()
    end)
end)

-- Rolling Custom Joints (Phase 3.5)
RegisterNetEvent("JGR_IlegalSystem:Client:OpenRollingMenu", function()
    local options = {}
    local pData = QBCore.Functions.GetPlayerData()
    
    local hasWeed = false
    local hasCbd = false
    local hasKush = false
    local hasAmnesia = false
    local paperCount = 0
    
    if pData.items then
        for _, item in pairs(pData.items) do
            if item.name == "bud_standard" and item.amount >= 1 then hasWeed = true end
            if item.name == "bud_cbd" and item.amount >= 1 then hasCbd = true end
            if item.name == "bud_kush" and item.amount >= 1 then hasKush = true end
            if item.name == "bud_amnesia" and item.amount >= 1 then hasAmnesia = true end
            if item.name == "rolling_paper" then paperCount = item.amount end
        end
    end

    if hasWeed then
        table.insert(options, {
            title = 'Liar un Porro Clásico',
            description = 'Requiere: 1x Cogollo Standard, 1x Papel',
            icon = 'cannabis',
            onSelect = function()
                RollJoint('bud_standard', 'joint_weed', 1)
            end
        })
    end

    if hasCbd then
        table.insert(options, {
            title = 'Liar un Porro de CBD',
            description = 'Requiere: 1x Cogollo CBD, 1x Papel',
            icon = 'leaf',
            onSelect = function()
                RollJoint('bud_cbd', 'joint_cbd', 1)
            end
        })
    end

    if hasKush then
        table.insert(options, {
            title = 'Liar un Purple Kush',
            description = 'Requiere: 1x Cogollo Kush, 1x Papel',
            icon = 'star',
            onSelect = function()
                RollJoint('bud_kush', 'joint_kush', 1)
            end
        })
    end
    
    if hasAmnesia and paperCount >= 2 then
        table.insert(options, {
            title = 'Liar un Blunt Amnesia',
            description = 'Requiere: 1x Cogollo Amnesia, 2x Papel',
            icon = 'fire',
            onSelect = function()
                RollJoint('bud_amnesia', 'blunt_amnesia', 2)
            end
        })
    elseif hasAmnesia and paperCount < 2 then
        table.insert(options, {
            title = 'Liar un Blunt Amnesia (Bloqueado)',
            description = 'Requiere 2x Papel de Liar. Tienes ' .. paperCount,
            icon = 'lock',
            disabled = true
        })
    end

    if #options == 0 then
        QBCore.Functions.Notify("No tienes cogollos para liar.", "error")
        return
    end

    lib.registerContext({ id = 'rolling_menu', title = 'Liar un Porro', options = options })
    lib.showContext('rolling_menu')
end)

function RollJoint(reqItem, rewardItem, paperReq)
    if lib.progressBar({
        duration = 6000,
        label = 'Liando artesanalmente...',
        useWhileDead = false,
        canCancel = true,
        disable = { car = true, move = true, combat = true },
        anim = { dict = 'amb@world_human_smoking@male@male_a@enter', clip = 'enter' },
    }) then
        TriggerServerEvent('JGR_IlegalSystem:Server:FinishRolling', reqItem, rewardItem, paperReq)
    else
        QBCore.Functions.Notify("Has parado de liar.", "error")
    end
end
