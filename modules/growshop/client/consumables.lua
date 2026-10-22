-- Cliente: efectos de consumibles y menú de liado del Grow Shop

local RollJointGrowShop

RegisterNetEvent("JGR_IlegalSystem:Client:UseConsumable", function(itemName, data)
    if type(itemName) ~= "string" or type(data) ~= "table" then return end
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

    -- Animación con la barra de progreso de ox_lib
    if lib and animDict then
        lib.progressBar({
            duration = 5000,
            label = ("Consumiendo %s"):format(Bridge.GetItemLabel(itemName, itemName)),
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
        Wait(5000)
    end

    -- Apply Effects
    -- Vida
    if (tonumber(data.health) or 0) > 0 then
        local maxHealth = GetEntityMaxHealth(playerPed)
        local newHealth = GetEntityHealth(playerPed) + data.health
        if newHealth > maxHealth then newHealth = maxHealth end
        SetEntityHealth(playerPed, newHealth)
    end

    -- Chaleco
    if (tonumber(data.armor) or 0) > 0 then
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
    local counts = Bridge.GetItemCounts({ "bud_standard", "bud_cbd", "bud_kush", "bud_amnesia", "rolling_paper" })

    local hasWeed = (counts.bud_standard or 0) >= 1
    local hasCbd = (counts.bud_cbd or 0) >= 1
    local hasKush = (counts.bud_kush or 0) >= 1
    local hasAmnesia = (counts.bud_amnesia or 0) >= 1
    local paperCount = counts.rolling_paper or 0

    if hasWeed then
        table.insert(options, {
            title = 'Liar un Porro Clásico',
            description = 'Requiere: 1x Cogollo Standard, 1x Papel',
            icon = 'cannabis',
            onSelect = function()
                RollJointGrowShop('bud_standard', 'joint_weed', 1)
            end
        })
    end

    if hasCbd then
        table.insert(options, {
            title = 'Liar un Porro de CBD',
            description = 'Requiere: 1x Cogollo CBD, 1x Papel',
            icon = 'leaf',
            onSelect = function()
                RollJointGrowShop('bud_cbd', 'joint_cbd', 1)
            end
        })
    end

    if hasKush then
        table.insert(options, {
            title = 'Liar un Purple Kush',
            description = 'Requiere: 1x Cogollo Kush, 1x Papel',
            icon = 'star',
            onSelect = function()
                RollJointGrowShop('bud_kush', 'joint_kush', 1)
            end
        })
    end
    
    if hasAmnesia and paperCount >= 2 then
        table.insert(options, {
            title = 'Liar un Blunt Amnesia',
            description = 'Requiere: 1x Cogollo Amnesia, 2x Papel',
            icon = 'fire',
            onSelect = function()
                RollJointGrowShop('bud_amnesia', 'blunt_amnesia', 2)
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
        Bridge.Notify(PlayerId(), "No tienes cogollos para liar.", "error")
        return
    end

    lib.registerContext({ id = 'rolling_menu', title = 'Liar un Porro', options = options })
    lib.showContext('rolling_menu')
end)

-- Antes se llamaba RollJoint (global) y chocaba con la función del mismo nombre de modules/drugs/client/processing.lua.
function RollJointGrowShop(reqItem, rewardItem, paperReq)
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
        Bridge.Notify(PlayerId(), "Has parado de liar.", "error")
    end
end
