-- Base Client Architecture for JGR_IlegalSystem

JGR = JGR or {}
JGR.Modules = {}

-- Function to register modules (For future expansion)
function JGR.RegisterModule(name, initFunc)
    JGR.Modules[name] = initFunc
end

-- Initialize modules
Citizen.CreateThread(function()
    Wait(100) -- Wait for all modules to register themselves
    for name, initFunc in pairs(JGR.Modules) do
        if Config.Debug then print("[JGR_IlegalSystem] Initializing client module: " .. name) end
        initFunc()
    end
end)
