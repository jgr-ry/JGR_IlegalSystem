-- Base Server Architecture for JGR_IlegalSystem

JGR = JGR or {}
JGR.Modules = {}

function JGR.RegisterModule(name, initFunc)
    JGR.Modules[name] = initFunc
end

Citizen.CreateThread(function()
    Wait(100) -- Wait for all modules to register themselves
    for name, initFunc in pairs(JGR.Modules) do
        if Config.Debug then print("[JGR_IlegalSystem] Initializing server module: " .. name) end
        initFunc()
    end
end)
