-- sv_main.lua - ug_wheel_tuning / ug_wheel_station

local framework     = Config.Framework
local ActiveFitment = {} -- [plate] = { data = <table>, lastNetIds = { [netId] = true } }

---------------------------------------------------------------
-- SMALL HELPERS
---------------------------------------------------------------

local function trimPlate(plate)
    if not plate then return nil end
    return (plate:gsub("^%s*(.-)%s*$", "%1"))
end

local function getZoneConfig(zoneId)
    return Config.FitmentZones and Config.FitmentZones[zoneId] or nil
end

local function isIdentifierAllowed(identifier, list)
    if not identifier or not list or type(list) ~= 'table' then return false end
    for _, id in ipairs(list) do
        if id == identifier then return true end
    end
    return false
end

local function resolveAccessMode(cfg)
    if not cfg then return 'public' end
    if cfg.accessMode then return cfg.accessMode end

    if cfg.allowedIdentifiers and next(cfg.allowedIdentifiers) ~= nil then
        return 'identifiersOnly'
    elseif cfg.job and cfg.job ~= '' and cfg.job ~= false then
        return 'jobOnly'
    else
        return 'public'
    end
end

local function debugPrint(...)
    if Config.Debug then
        print("[ug_wheel_tuning:server]", ...)
    end
end

---------------------------------------------------------------
-- ACCESS CHECK FOR ZONE
---------------------------------------------------------------

lib.callback.register('ug_wheel_tuning:canUseZone', function(source, zoneId)
    local player = Framework.GetPlayer(source)
    if not player then
        return false, 'Player not found.'
    end

    local cfg = getZoneConfig(zoneId)
    if not cfg then
        -- no special restriction => public
        return true, nil
    end

    local identifier = Framework.GetIdentifier(player)
    local job        = Framework.GetJob(player)
    local mode       = resolveAccessMode(cfg)

    if mode == 'public' then
        return true, nil
    elseif mode == 'jobOnly' then
        if cfg.job and job == cfg.job then
            return true, nil
        end
        return false, ('Only %s can use this station.'):format(cfg.job or 'this job')
    elseif mode == 'identifiersOnly' then
        if isIdentifierAllowed(identifier, cfg.allowedIdentifiers) then
            return true, nil
        end
        return false, 'You are not allowed to use this station.'
    elseif mode == 'jobOrIdentifier' then
        local okJob = cfg.job and job == cfg.job
        local okId  = isIdentifierAllowed(identifier, cfg.allowedIdentifiers)
        if okJob or okId then
            return true, nil
        end
        return false, ('You need to be %s or specifically whitelisted.'):format(cfg.job or 'the correct job')
    end

    return false, 'Invalid access mode.'
end)

---------------------------------------------------------------
-- DB HELPERS (LOAD / SAVE)
---------------------------------------------------------------

local function getVehicleTableInfo()
    return
        Config.VehicleTable[framework],
        Config.OwnerColumn[framework],
        Config.PlateColumn[framework],
        Config.WheelsColumn
end

-- returns decoded wheels table or nil
local function loadWheelsFor(identifier, plate)
    if not identifier or not plate then return nil end

    local tableName, ownerCol, plateCol, wheelsCol = getVehicleTableInfo()
    if not tableName or not ownerCol or not plateCol or not wheelsCol then
        debugPrint("Config for vehicle table/columns is missing.")
        return nil
    end

    plate = trimPlate(plate)

    local row = MySQL.single.await(([[SELECT `%s` FROM `%s` WHERE `%s` = ? AND `%s` = ?]]):format(
        wheelsCol, tableName, ownerCol, plateCol
    ), { identifier, plate })

    if not row or not row[wheelsCol] or row[wheelsCol] == '' then
        return nil
    end

    local ok, data = pcall(json.decode, row[wheelsCol])
    if not ok then
        debugPrint("JSON decode failed for plate", plate)
        return nil
    end

    return data
end

local function saveWheelsFor(identifier, plate, data)
    if not identifier or not plate or not data then return end

    local tableName, ownerCol, plateCol, wheelsCol = getVehicleTableInfo()
    if not tableName or not ownerCol or not plateCol or not wheelsCol then
        debugPrint("Config for vehicle table/columns is missing.")
        return
    end

    plate = trimPlate(plate)

    local payload = json.encode(data)

    if Config.Debug then
        print(("[ug_wheel_tuning] SAVE %s (%s) -> %s"):format(plate, identifier, payload))
    end

    MySQL.update.await(([[UPDATE `%s` SET `%s` = ? WHERE `%s` = ? AND `%s` = ?]]):format(
        tableName, wheelsCol, ownerCol, plateCol
    ), { payload, identifier, plate })
end

-- update server pool + broadcast to clients
local function updateActiveFitment(netId, plate, data)
    if not plate or not data then return end

    plate = trimPlate(plate)
    ActiveFitment[plate] = ActiveFitment[plate] or { lastNetIds = {} }
    ActiveFitment[plate].data = data
    ActiveFitment[plate].lastNetIds = ActiveFitment[plate].lastNetIds or {}
    if netId then
        ActiveFitment[plate].lastNetIds[netId] = true
    end

    if netId then
        -- sync to everyone
        TriggerClientEvent('ug_wheel_tuning:applyOnSpawn', -1, netId, data)
    end
end

---------------------------------------------------------------
-- CALLBACK: LOAD WHEEL DATA FOR UI
---------------------------------------------------------------

lib.callback.register('ug_wheel_tuning:getWheels', function(source, plate)
    plate = trimPlate(plate)
    local player = Framework.GetPlayer(source)
    if not player then return nil end

    local identifier = Framework.GetIdentifier(player)
    if not identifier then return nil end

    return loadWheelsFor(identifier, plate)
end)

---------------------------------------------------------------
-- EVENT: SAVE WHEEL DATA FROM UI
---------------------------------------------------------------

RegisterNetEvent('ug_wheel_tuning:saveWheels', function(plate, data)
    local src = source
    if not plate or not data then return end

    local player = Framework.GetPlayer(src)
    if not player then return end

    local identifier = Framework.GetIdentifier(player)
    if not identifier then return end

    saveWheelsFor(identifier, plate, data)

    -- update server-side active pool (we don't know netId here)
    updateActiveFitment(nil, plate, data)
end)

---------------------------------------------------------------
-- EVENT: CLIENT TELLS SERVER WHICH NETID HAS THIS FITMENT
---------------------------------------------------------------

RegisterNetEvent('ug_wheel_tuning:updateActiveVehicle', function(netId, plate, data)
    if not netId or not plate or not data then return end
    updateActiveFitment(netId, plate, data)
end)

---------------------------------------------------------------
-- EVENT: GARAGE CALLS THIS WHEN VEHICLE SPAWNS
---------------------------------------------------------------

RegisterNetEvent('ug_wheel_tuning:requestApplyOnSpawn', function(netId, plate)
    local src = source
    if not netId or not plate then return end

    local player = Framework.GetPlayer(src)
    if not player then return end

    local identifier = Framework.GetIdentifier(player)
    if not identifier then return end

    local data = loadWheelsFor(identifier, plate)
    if not data then return end

    updateActiveFitment(netId, plate, data)
end)

---------------------------------------------------------------
-- EXPORT: DIRECT APPLYONSPAWN (FOR OTHER GARAGE SCRIPTS)
---------------------------------------------------------------

-- Usage from other resources:
--   exports['ug_wheel_station']:ApplyOnSpawn(source, netId, plate)
exports('ApplyOnSpawn', function(source, netId, plate)
    if not source or not netId or not plate then return end

    local player = Framework.GetPlayer(source)
    if not player then return end

    local identifier = Framework.GetIdentifier(player)
    if not identifier then return end

    local data = loadWheelsFor(identifier, plate)
    if not data then return end

    updateActiveFitment(netId, plate, data)
end)

---------------------------------------------------------------
-- CALLBACK: LET CLIENTS FETCH ACTIVE POOL ON JOIN
---------------------------------------------------------------

lib.callback.register('ug_wheel_tuning:getActivePool', function(_source)
    local copy = {}
    for plate, entry in pairs(ActiveFitment) do
        copy[plate] = { data = entry.data }
    end
    return copy
end)
