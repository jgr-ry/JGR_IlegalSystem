CreateThread(function()
    Wait(2500)

    local rawUrl = 'https://raw.githubusercontent.com/jgr-ry/Check_Versions_scripts/main/versions.json'
    local resourceName = GetCurrentResourceName()
    local currentVersion = GetResourceMetadata(resourceName, 'version', 0) or '0.0.0'

    local function normalizeVersion(value)
        if not value then return nil end
        value = tostring(value):gsub('^%s+', ''):gsub('%s+$', ''):gsub('^v', '')
        if value == '' then return nil end
        return value
    end

    local function compareVersions(a, b)
        local partsA, partsB = {}, {}
        for piece in (normalizeVersion(a) .. '.'):gmatch('([^.]+)%.') do
            partsA[#partsA + 1] = tonumber(piece) or piece
        end
        for piece in (normalizeVersion(b) .. '.'):gmatch('([^.]+)%.') do
            partsB[#partsB + 1] = tonumber(piece) or piece
        end

        for i = 1, math.max(#partsA, #partsB) do
            local va, vb = partsA[i], partsB[i]
            if va == nil then return -1 end
            if vb == nil then return 1 end
            if type(va) == 'number' and type(vb) == 'number' then
                if va < vb then return -1 end
                if va > vb then return 1 end
            else
                va, vb = tostring(va), tostring(vb)
                if va < vb then return -1 end
                if va > vb then return 1 end
            end
        end
        return 0
    end

    PerformHttpRequest(rawUrl, function(code, body)
        if code ~= 200 or not body then return end

        local ok, data = pcall(function() return json.decode(body) end)
        if not ok or type(data) ~= 'table' then return end

        local entry = data[resourceName]
        if not entry then return end

        local remoteVersion = type(entry) == 'string' and entry or (entry.version or entry.ver or entry.v)
        remoteVersion = normalizeVersion(remoteVersion)
        currentVersion = normalizeVersion(currentVersion) or '0.0.0'
        if not remoteVersion then return end

        if compareVersions(currentVersion, remoteVersion) < 0 then
            print(('[%s] ^1Nueva version disponible: %s (actual: %s)^0'):format(resourceName, remoteVersion, currentVersion))
            print(('[%s] ^3Versiones: %s^0'):format(resourceName, rawUrl))
        end
    end, 'GET', '', { ['User-Agent'] = resourceName .. '-VersionCheck' })
end)
