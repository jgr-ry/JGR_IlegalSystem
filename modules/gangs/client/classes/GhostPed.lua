-- Class implementation for placing an NPC in the 3D world (OOP)

GhostPed = {}
GhostPed.__index = GhostPed

function GhostPed.new(models)
    local self = setmetatable({}, GhostPed)
    self.models = models or Config.GangSystem.CreatorModels
    self.currentModelIndex = 1
    self.handle = nil
    self.active = false
    self.heading = 0.0
    self.coords = vector3(0.0, 0.0, 0.0)
    return self
end

function GhostPed:Initialize()
    self.active = true
    self:SpawnCurrentModel()
    
    Citizen.CreateThread(function()
        while self.active do
            Citizen.Wait(0)
            -- Logic to do a raycast and place the ped at the hit coordinates
            local hit, hitCoords, entityHit = self:RayCastGamePlayCamera(10.0)
            
            if hit then
                self.coords = hitCoords
                SetEntityCoords(self.handle, hitCoords.x, hitCoords.y, hitCoords.z, false, false, false, false)
                SetEntityHeading(self.handle, self.heading)
                SetEntityAlpha(self.handle, 150, false) -- Ghost effect
                SetEntityCollision(self.handle, false, false)
                FreezeEntityPosition(self.handle, true)
            end
            
            -- UI Prompts handled by NUI now
            
            -- Handle Inputs
            if IsControlJustPressed(0, 174) then -- Left Arrow
                self:ChangeModel(-1)
            elseif IsControlJustPressed(0, 175) then -- Right Arrow
                self:ChangeModel(1)
            end
            
            if IsControlJustPressed(0, 14) then -- Scroll up
                self.heading = self.heading + 15.0
            elseif IsControlJustPressed(0, 15) then -- Scroll down
                self.heading = self.heading - 15.0
            end
            
            if IsControlJustPressed(0, 191) then -- Enter
                self:ConfirmPlacement()
            end
        end
    end)
end

function GhostPed:SpawnCurrentModel()
    if self.handle then
        DeleteEntity(self.handle)
    end
    
    local model = GetHashKey(self.models[self.currentModelIndex])
    lib.requestModel(model)
    
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    self.handle = CreatePed(4, model, coords.x, coords.y, coords.z, 0.0, false, false)
    
    SetEntityAlpha(self.handle, 150, false)
    SetEntityCollision(self.handle, false, false)
    FreezeEntityPosition(self.handle, true)
    SetBlockingOfNonTemporaryEvents(self.handle, true)
    TaskSetBlockingOfNonTemporaryEvents(self.handle, true)
    
    -- Open floating UI controls for step 2
    SendNUIMessage({ action = 'open_step_2_controls' })
end

function GhostPed:ChangeModel(direction)
    self.currentModelIndex = self.currentModelIndex + direction
    if self.currentModelIndex > #self.models then
        self.currentModelIndex = 1
    elseif self.currentModelIndex < 1 then
        self.currentModelIndex = #self.models
    end
    self:SpawnCurrentModel()
end

function GhostPed:ConfirmPlacement()
    self.active = false
    SendNUIMessage({ action = 'close_step_2_controls' })
    
    local finalData = {
        model = self.models[self.currentModelIndex],
        coords = self.coords,
        heading = self.heading
    }
    
    if self.handle then
        -- Restore original appearance for the UI transition
        SetEntityAlpha(self.handle, 255, false)
        SetEntityCollision(self.handle, true, true)
        FreezeEntityPosition(self.handle, false)
        TaskStartScenarioInPlace(self.handle, "WORLD_HUMAN_STAND_GUARD", 0, true)
        
        -- We no longer detach it, so currentCreator:Destroy() can properly nuke it on Step 4 Finish
    end

    -- Trigger Event to return to UI (Step 3)
    TriggerEvent("JGR_IlegalSystem:client:ReturnToCreatorUI", finalData)
end

function GhostPed:Destroy()
    self.active = false
    SendNUIMessage({ action = 'close_step_2_controls' })
    
    if self.handle then
        DeleteEntity(self.handle)
        self.handle = nil
    end
end

-- Raycast logic
function GhostPed:RayCastGamePlayCamera(distance)
    local cameraRotation = GetGameplayCamRot()
    local cameraCoord = GetGameplayCamCoord()
    local direction = self:RotationToDirection(cameraRotation)
    local destination = {
        x = cameraCoord.x + direction.x * distance,
        y = cameraCoord.y + direction.y * distance,
        z = cameraCoord.z + direction.z * distance
    }
    local a, b, c, d, e = GetShapeTestResult(StartShapeTestRay(cameraCoord.x, cameraCoord.y, cameraCoord.z, destination.x, destination.y, destination.z, -1, PlayerPedId(), 0))
    return b, c, e
end

function GhostPed:RotationToDirection(rotation)
    local adjustedRotation = {
        x = (math.pi / 180) * rotation.x,
        y = (math.pi / 180) * rotation.y,
        z = (math.pi / 180) * rotation.z
    }
    local direction = {
        x = -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        y = math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        z = math.sin(adjustedRotation.x)
    }
    return direction
end
