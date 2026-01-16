local inZone                 = false
local currentZoneId          = nil
local currentZoneCfg         = nil
local isMenuOpen             = false
local vehEntity              = nil
local vehPlate               = nil
local originalWheelsJSON     = nil
local uiHasFocus             = false
local performVehicleCheck    = true

local vehiclesToCheckFitment = {}

DecorRegister("ug_fit_applied", 2)

DecorRegister("ug_fit_width", 1)

DecorRegister("ug_fit_off_fl", 1)
DecorRegister("ug_fit_off_fr", 1)
DecorRegister("ug_fit_off_rl", 1)
DecorRegister("ug_fit_off_rr", 1)

DecorRegister("ug_fit_cam_fl", 1)
DecorRegister("ug_fit_cam_fr", 1)
DecorRegister("ug_fit_cam_rl", 1)
DecorRegister("ug_fit_cam_rr", 1)

DecorRegister("ug_fit_size", 1)

DecorRegister("ug_fit_height", 1)

DecorRegister("ug_fit_tire_fl", 1)
DecorRegister("ug_fit_tire_fr", 1)
DecorRegister("ug_fit_tire_rl", 1)
DecorRegister("ug_fit_tire_rr", 1)

DecorRegister("ug_fit_rim_fl", 1)
DecorRegister("ug_fit_rim_fr", 1)
DecorRegister("ug_fit_rim_rl", 1)
DecorRegister("ug_fit_rim_rr", 1)

local WIDTH_MIN = 0.10

local SIZE_MIN  = 0.50
local SIZE_MAX  = 1.50

local SUSP_MIN  = -0.20
local SUSP_MAX  = 0.20

local function dbg(...)
    if Config and Config.Debug then
        print("[ug_wheel_station:client]", ...)
    end
end

local function notify(msg)
    msg = tostring(msg or "nil")
    if lib and lib.notify then
        pcall(function()
            lib.notify({ description = msg })
        end)
    else
        TriggerEvent('chat:addMessage', { args = { '^5WheelTuning^7: ' .. msg } })
    end
end

local function clamp(n, a, b)
    if n < a then return a end
    if n > b then return b end
    return n
end

local function isFinite(n)
    return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function requestControl(ent, timeoutMs)
    if not ent or ent == 0 then return false end
    if NetworkHasControlOfEntity(ent) then return true end

    NetworkRequestControlOfEntity(ent)
    local endAt = GetGameTimer() + (timeoutMs or 1500)
    while GetGameTimer() < endAt do
        if NetworkHasControlOfEntity(ent) then return true end
        Wait(0)
        NetworkRequestControlOfEntity(ent)
    end
    return NetworkHasControlOfEntity(ent)
end

local function showLeftHint()
    local ok = false
    if lib then
        pcall(function()
            if lib.showTextUI then
                lib.showTextUI(("Wheel station - \nuse /%s"):format(Config.OpenCommand or "wheels"))
                ok = true
            end
        end)
    end
    if not ok then
        notify(("Stand on the station and use /%s (or radial)."):format(Config.OpenCommand or "wheels"))
    end
end

local function getZoneCoords(cfg)
    if not cfg then return nil end
    local c = cfg.coords
    if not c then return nil end

    local t = type(c)
    if t == "vector3" or t == "vector4" then
        return vector3(c.x, c.y, c.z)
    elseif t == "table" then
        if c.x and c.y and c.z then
            return vector3(c.x, c.y, c.z)
        elseif c[1] and c[2] and c[3] then
            return vector3(c[1], c[2], c[3])
        end
    end
    return nil
end

local function isNear(pos1, pos2, dist)
    return #(pos2 - pos1) < dist
end

local function ReadWheelSizeSafe(veh)
    local s = 1.0
    pcall(function()
        s = GetVehicleWheelSize(veh) or 1.0
    end)
    if not isFinite(s) or s == 0.0 then s = 1.0 end
    return s
end

local function ReadTireColliderSafe(veh, idx)
    local v
    pcall(function()
        v = GetVehicleWheelTireColliderSize(veh, idx)
    end)
    if not isFinite(v) then return 0.0 end
    return v
end

local function ReadRimColliderSafe(veh, idx)
    local v
    pcall(function()
        v = GetVehicleWheelRimColliderSize(veh, idx)
    end)
    if not isFinite(v) then return 0.0 end
    return v
end

local function BuildWheelDataFromVehicle(veh)
    local out = {
        stance  = { fl = 0.0, fr = 0.0, rl = 0.0, rr = 0.0, front = 0.0, rear = 0.0 },
        camber  = { fl = 0.0, fr = 0.0, rl = 0.0, rr = 0.0, front = 0.0, rear = 0.0 },
        width   = 0.0,
        size    = 1.0,
        height  = 0.0,
        physics = { tire = { 0, 0, 0, 0 }, rim = { 0, 0, 0, 0 } }
    }

    if not veh or veh == 0 then return out end

    local numWheels  = GetVehicleNumberOfWheels(veh)

    out.stance.fl    = (numWheels > 0) and GetVehicleWheelXOffset(veh, 0) or 0.0
    out.stance.fr    = (numWheels > 1) and GetVehicleWheelXOffset(veh, 1) or 0.0
    out.stance.rl    = (numWheels > 2) and GetVehicleWheelXOffset(veh, 2) or 0.0
    out.stance.rr    = (numWheels > 3) and GetVehicleWheelXOffset(veh, 3) or 0.0
    out.stance.front = (out.stance.fl + out.stance.fr) / 2.0
    out.stance.rear  = (out.stance.rl + out.stance.rr) / 2.0

    out.camber.fl    = (numWheels > 0) and GetVehicleWheelYRotation(veh, 0) or 0.0
    out.camber.fr    = (numWheels > 1) and GetVehicleWheelYRotation(veh, 1) or 0.0
    out.camber.rl    = (numWheels > 2) and GetVehicleWheelYRotation(veh, 2) or 0.0
    out.camber.rr    = (numWheels > 3) and GetVehicleWheelYRotation(veh, 3) or 0.0
    out.camber.front = (out.camber.fl + out.camber.fr) / 2.0
    out.camber.rear  = (out.camber.rl + out.camber.rr) / 2.0

    out.width        = GetVehicleWheelWidth(veh) or 0.0
    out.size         = ReadWheelSizeSafe(veh)

    local h          = GetVehicleSuspensionHeight(veh) or 0.0
    out.height       = isFinite(h) and h or 0.0

    for i = 0, math.min(numWheels - 1, 3) do
        out.physics.tire[i + 1] = ReadTireColliderSafe(veh, i)
        out.physics.rim[i + 1]  = ReadRimColliderSafe(veh, i)
    end

    return out
end

local function normalizeWheelPayload(payload, base, veh)
    payload          = payload or {}
    base             = base or BuildWheelDataFromVehicle(veh)

    local stance     = payload.stance or {}
    local camber     = payload.camber or {}

    local offFL      = isFinite(stance.fl) and stance.fl or
        (isFinite(stance.front) and stance.front or (base.stance and base.stance.fl or 0.0))
    local offFR      = isFinite(stance.fr) and stance.fr or
        (isFinite(stance.front) and stance.front or (base.stance and base.stance.fr or 0.0))
    local offRL      = isFinite(stance.rl) and stance.rl or
        (isFinite(stance.rear) and stance.rear or (base.stance and base.stance.rl or 0.0))
    local offRR      = isFinite(stance.rr) and stance.rr or
        (isFinite(stance.rear) and stance.rear or (base.stance and base.stance.rr or 0.0))

    local camFL      = isFinite(camber.fl) and camber.fl or
        (isFinite(camber.front) and camber.front or (base.camber and base.camber.fl or 0.0))
    local camFR      = isFinite(camber.fr) and camber.fr or
        (isFinite(camber.front) and camber.front or (base.camber and base.camber.fr or 0.0))
    local camRL      = isFinite(camber.rl) and camber.rl or
        (isFinite(camber.rear) and camber.rear or (base.camber and base.camber.rl or 0.0))
    local camRR      = isFinite(camber.rr) and camber.rr or
        (isFinite(camber.rear) and camber.rear or (base.camber and base.camber.rr or 0.0))

    local finalWidth = isFinite(payload.width) and payload.width or
        (isFinite(base.width) and base.width or (GetVehicleWheelWidth(veh) or 0.0))
    if (not isFinite(finalWidth)) or finalWidth < WIDTH_MIN then finalWidth = WIDTH_MIN end

    local baseSize = isFinite(base.size) and base.size or ReadWheelSizeSafe(veh)
    if not isFinite(baseSize) or baseSize == 0.0 then baseSize = 1.0 end

    local finalSize = isFinite(payload.size) and payload.size or baseSize
    if not isFinite(finalSize) then finalSize = baseSize end
    finalSize         = clamp(finalSize, SIZE_MIN, SIZE_MAX)

    local baseHeight  = isFinite(base.height) and base.height or 0.0
    local finalHeight = isFinite(payload.height) and payload.height or baseHeight
    finalHeight       = clamp(finalHeight, SUSP_MIN, SUSP_MAX)

    local sizeScale   = finalSize / baseSize

    local tireBase    = (base.physics and base.physics.tire) or { 0, 0, 0, 0 }
    local rimBase     = (base.physics and base.physics.rim) or { 0, 0, 0, 0 }

    local tireFinal   = { 0, 0, 0, 0 }
    local rimFinal    = { 0, 0, 0, 0 }

    for i = 1, 4 do
        local baseT = tireBase[i]
        local baseR = rimBase[i]
        if not isFinite(baseT) or baseT <= 0.0 then baseT = 0.0 end
        if not isFinite(baseR) or baseR <= 0.0 then baseR = 0.0 end

        tireFinal[i] = (baseT > 0.0) and ((baseT * sizeScale)) or 0.0
        rimFinal[i]  = (baseR > 0.0) and ((baseR * sizeScale)) or 0.0

        if tireFinal[i] < 0.05 then tireFinal[i] = 0.05 end
        if rimFinal[i] < 0.05 then rimFinal[i] = 0.05 end
    end

    return {
        stance  = { fl = offFL, fr = offFR, rl = offRL, rr = offRR },
        camber  = { fl = camFL, fr = camFR, rl = camRL, rr = camRR },
        width   = finalWidth,
        size    = finalSize,
        height  = finalHeight,
        physics = { tire = tireFinal, rim = rimFinal },
    }
end

local function ApplyWheelsClientside(payload, vehicleOverride, baseOverride)
    if not payload then return end

    local veh = vehicleOverride or vehEntity
    if not veh or veh == 0 then return end

    local base = baseOverride or BuildWheelDataFromVehicle(veh)
    local data = normalizeWheelPayload(payload, base, veh)

    local numWheels = GetVehicleNumberOfWheels(veh)
    if numWheels <= 0 then return end

    requestControl(veh, 1500)

    if numWheels >= 1 then
        SetVehicleWheelXOffset(veh, 0, data.stance.fl)
        SetVehicleWheelYRotation(veh, 0, data.camber.fl)
    end
    if numWheels >= 2 then
        SetVehicleWheelXOffset(veh, 1, data.stance.fr)
        SetVehicleWheelYRotation(veh, 1, data.camber.fr)
    end
    if numWheels >= 3 then
        SetVehicleWheelXOffset(veh, 2, data.stance.rl)
        SetVehicleWheelYRotation(veh, 2, data.camber.rl)
    end
    if numWheels >= 4 then
        SetVehicleWheelXOffset(veh, 3, data.stance.rr)
        SetVehicleWheelYRotation(veh, 3, data.camber.rr)
    end

    SetVehicleWheelWidth(veh, data.width)

    pcall(function()
        SetVehicleWheelSize(veh, data.size)
    end)

    pcall(function()
        SetVehicleSuspensionHeight(veh, data.height)
    end)

    pcall(function()
        for i = 0, math.min(numWheels - 1, 3) do
            SetVehicleWheelTireColliderSize(veh, i, data.physics.tire[i + 1])
            SetVehicleWheelRimColliderSize(veh, i, data.physics.rim[i + 1])
        end
    end)

    DecorSetBool(veh, "ug_fit_applied", true)

    DecorSetFloat(veh, "ug_fit_width", data.width)

    DecorSetFloat(veh, "ug_fit_off_fl", data.stance.fl)
    DecorSetFloat(veh, "ug_fit_off_fr", data.stance.fr)
    DecorSetFloat(veh, "ug_fit_off_rl", data.stance.rl)
    DecorSetFloat(veh, "ug_fit_off_rr", data.stance.rr)

    DecorSetFloat(veh, "ug_fit_cam_fl", data.camber.fl)
    DecorSetFloat(veh, "ug_fit_cam_fr", data.camber.fr)
    DecorSetFloat(veh, "ug_fit_cam_rl", data.camber.rl)
    DecorSetFloat(veh, "ug_fit_cam_rr", data.camber.rr)

    DecorSetFloat(veh, "ug_fit_size", data.size)
    DecorSetFloat(veh, "ug_fit_height", data.height)

    DecorSetFloat(veh, "ug_fit_tire_fl", data.physics.tire[1])
    DecorSetFloat(veh, "ug_fit_tire_fr", data.physics.tire[2])
    DecorSetFloat(veh, "ug_fit_tire_rl", data.physics.tire[3])
    DecorSetFloat(veh, "ug_fit_tire_rr", data.physics.tire[4])

    DecorSetFloat(veh, "ug_fit_rim_fl", data.physics.rim[1])
    DecorSetFloat(veh, "ug_fit_rim_fr", data.physics.rim[2])
    DecorSetFloat(veh, "ug_fit_rim_rl", data.physics.rim[3])
    DecorSetFloat(veh, "ug_fit_rim_rr", data.physics.rim[4])
end

local function RevertOriginal()
    if not originalWheelsJSON or originalWheelsJSON == "" then return end
    local ok, parsed = pcall(function() return json.decode(originalWheelsJSON) end)
    if not ok or not parsed then return end
    ApplyWheelsClientside(parsed, nil, parsed)
end

local function OpenNUI(data)
    if isMenuOpen then return end

    isMenuOpen          = true
    uiHasFocus          = true
    vehEntity           = vehEntity or GetVehiclePedIsIn(PlayerPedId(), false)
    originalWheelsJSON  = json.encode(data or {})

    performVehicleCheck = false

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "open",
        data   = {
            plate  = vehPlate or "UNKNOWN",
            wheels = data or {}
        },
        ui     = {}
    })
end

local function CloseNUI()
    if not isMenuOpen then return end

    isMenuOpen = false
    uiHasFocus = false

    SendNUIMessage({ action = "close" })
    SetNuiFocus(false, false)

    vehEntity           = nil
    vehPlate            = nil

    performVehicleCheck = true
end

CreateThread(function()
    Wait(500)

    while true do
        local ped               = PlayerPedId()
        local pos               = GetEntityCoords(ped)
        local foundId, foundCfg = nil, nil

        for id, cfg in pairs(Config.FitmentZones or {}) do
            local c = getZoneCoords(cfg)
            if c then
                if #(pos - c) <= (cfg.radius or 2.5) then
                    foundId, foundCfg = id, cfg
                    break
                end
            end
        end

        if foundId and not inZone then
            inZone         = true
            currentZoneId  = foundId
            currentZoneCfg = foundCfg
            showLeftHint()
        elseif (not foundId) and inZone then
            inZone         = false
            currentZoneId  = nil
            currentZoneCfg = nil
            if lib and lib.hideTextUI then pcall(lib.hideTextUI) end
        end

        Wait(700)
    end
end)

CreateThread(function()
    while true do
        if isMenuOpen then
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 23, true)
            DisableControlAction(0, 75, true)
            Wait(0)
        else
            Wait(500)
        end
    end
end)

local function OpenTuning()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    if veh == 0 then
        notify("You must be in a vehicle.")
        return
    end

    if not inZone or not currentZoneId or not currentZoneCfg then
        notify("You must be on a wheel tuning pad.")
        return
    end

    local ok, reason = lib.callback.await('ug_wheel_tuning:canUseZone', false, currentZoneId)
    if not ok then
        notify(reason or "You are not allowed to use this station.")
        return
    end

    vehEntity          = veh
    vehPlate           = GetVehicleNumberPlateText(vehEntity) or "UNKNOWN"

    local data         = BuildWheelDataFromVehicle(vehEntity)
    originalWheelsJSON = json.encode(data or {})

    OpenNUI(data)
end

RegisterCommand('ug_wheel_open', function()
    if isMenuOpen then return end
    OpenTuning()
end, false)

RegisterKeyMapping('ug_wheel_open', 'Open Wheel Tuning at station', 'keyboard', 'F7')

local openCmd = Config.OpenCommand or 'wheels'
RegisterCommand(openCmd, function()
    if isMenuOpen then return end
    OpenTuning()
end, false)

RegisterNUICallback('preview', function(payload, cb)
    cb({ ok = true })
    if not isMenuOpen then return end

    local ok, base = pcall(function()
        return json.decode(originalWheelsJSON or "{}")
    end)
    if not ok or not base then base = BuildWheelDataFromVehicle(vehEntity) end

    ApplyWheelsClientside(payload, vehEntity, base)
end)

RegisterNUICallback('apply', function(payload, cb)
    cb({ ok = true })

    if not vehEntity or vehEntity == 0 then
        notify("No vehicle found.")
        RevertOriginal()
        CloseNUI()
        return
    end

    local progressed = true
    if lib and lib.progressBar then
        local r = lib.progressBar({ duration = 5000, label = "Applying changes..." })
        if not r then progressed = false end
    else
        Wait(5000)
    end

    if not progressed then
        notify("Cancelled.")
        RevertOriginal()
        CloseNUI()
        return
    end

    local ok, base = pcall(function()
        return json.decode(originalWheelsJSON or "{}")
    end)
    if not ok or not base then base = BuildWheelDataFromVehicle(vehEntity) end

    ApplyWheelsClientside(payload, vehEntity, base)

    TriggerServerEvent('ug_wheel_tuning:saveWheels', vehPlate, payload)

    local netId = VehToNet(vehEntity)
    TriggerServerEvent('ug_wheel_tuning:updateActiveVehicle', netId, vehPlate, payload)

    notify("Wheel changes applied & saved.")
    CloseNUI()
end)

RegisterNUICallback('cancel', function(_, cb)
    cb({ ok = true })
    RevertOriginal()
    CloseNUI()
end)

RegisterNUICallback('toggleFocus', function(_, cb)
    cb({ ok = true })
    if not isMenuOpen then return end
    uiHasFocus = not uiHasFocus
    SetNuiFocus(uiHasFocus, uiHasFocus)
end)

RegisterNetEvent('ug_wheel_tuning:applyOnSpawn', function(netId, data)
    if not netId or not data then return end

    local veh = NetToVeh(netId)
    if not veh or veh == 0 then veh = NetToEnt(netId) end
    if not veh or veh == 0 then return end

    ApplyWheelsClientside(data, veh, nil)
end)

exports('IsInWheelZone', function()
    return inZone, currentZoneId, currentZoneCfg
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        SetNuiFocus(false, false)
    end
end)

CreateThread(function()
    while true do
        if isMenuOpen then
            if GetVehiclePedIsIn(PlayerPedId(), false) == 0 then
                notify("You left the vehicle. Changes cancelled.")
                RevertOriginal()
                CloseNUI()
            end
            Wait(500)
        else
            Wait(1000)
        end
    end
end)

RegisterCommand('focus', function()
    if not isMenuOpen then return end
    uiHasFocus = not uiHasFocus
    SetNuiFocus(uiHasFocus, uiHasFocus)
end, false)

RegisterKeyMapping('focus', 'Toggle Wheel Tuning UI focus / camera', 'keyboard', 'F2')

local function refreshFitmentVehicles()
    vehiclesToCheckFitment = {}

    local ped              = PlayerPedId()
    local pPos             = GetEntityCoords(ped)
    local pool             = GetGamePool("CVehicle")
    local radius           = Config.FitmentCheckRadius or 40.0

    for _, veh in ipairs(pool) do
        if DoesEntityExist(veh) and DecorExistOn(veh, "ug_fit_applied") then
            if isNear(pPos, GetEntityCoords(veh), radius) then
                vehiclesToCheckFitment[#vehiclesToCheckFitment + 1] = {
                    vehicle = veh,

                    width   = DecorGetFloat(veh, "ug_fit_width"),

                    off_fl  = DecorGetFloat(veh, "ug_fit_off_fl"),
                    off_fr  = DecorGetFloat(veh, "ug_fit_off_fr"),
                    off_rl  = DecorGetFloat(veh, "ug_fit_off_rl"),
                    off_rr  = DecorGetFloat(veh, "ug_fit_off_rr"),

                    cam_fl  = DecorGetFloat(veh, "ug_fit_cam_fl"),
                    cam_fr  = DecorGetFloat(veh, "ug_fit_cam_fr"),
                    cam_rl  = DecorGetFloat(veh, "ug_fit_cam_rl"),
                    cam_rr  = DecorGetFloat(veh, "ug_fit_cam_rr"),

                    size    = DecorGetFloat(veh, "ug_fit_size"),
                    height  = DecorGetFloat(veh, "ug_fit_height"),

                    tire_fl = DecorGetFloat(veh, "ug_fit_tire_fl"),
                    tire_fr = DecorGetFloat(veh, "ug_fit_tire_fr"),
                    tire_rl = DecorGetFloat(veh, "ug_fit_tire_rl"),
                    tire_rr = DecorGetFloat(veh, "ug_fit_tire_rr"),

                    rim_fl  = DecorGetFloat(veh, "ug_fit_rim_fl"),
                    rim_fr  = DecorGetFloat(veh, "ug_fit_rim_fr"),
                    rim_rl  = DecorGetFloat(veh, "ug_fit_rim_rl"),
                    rim_rr  = DecorGetFloat(veh, "ug_fit_rim_rr"),
                }
            end
        end
    end
end

CreateThread(function()
    local tick = Config.FitmentTick or 25
    while true do
        if performVehicleCheck and #vehiclesToCheckFitment > 0 then
            for _, d in ipairs(vehiclesToCheckFitment) do
                local veh = d.vehicle
                if veh and DoesEntityExist(veh) then
                    local curW = GetVehicleWheelWidth(veh) or 0.0
                    if math.abs(curW - d.width) > 0.001 then
                        SetVehicleWheelWidth(veh, d.width)
                    end

                    local curOff = GetVehicleWheelXOffset(veh, 0)
                    if math.abs(curOff - d.off_fl) > 0.001 then
                        SetVehicleWheelXOffset(veh, 0, d.off_fl)
                        SetVehicleWheelXOffset(veh, 1, d.off_fr)
                        SetVehicleWheelXOffset(veh, 2, d.off_rl)
                        SetVehicleWheelXOffset(veh, 3, d.off_rr)
                    end

                    local curCam = GetVehicleWheelYRotation(veh, 0)
                    if math.abs(curCam - d.cam_fl) > 0.001 then
                        SetVehicleWheelYRotation(veh, 0, d.cam_fl)
                        SetVehicleWheelYRotation(veh, 1, d.cam_fr)
                        SetVehicleWheelYRotation(veh, 2, d.cam_rl)
                        SetVehicleWheelYRotation(veh, 3, d.cam_rr)
                    end

                    pcall(function()
                        local curS = GetVehicleWheelSize(veh) or 1.0
                        if math.abs(curS - d.size) > 0.001 then
                            SetVehicleWheelSize(veh, d.size)
                        end
                    end)

                    pcall(function()
                        local curH = GetVehicleSuspensionHeight(veh) or 0.0
                        if math.abs(curH - d.height) > 0.001 then
                            SetVehicleSuspensionHeight(veh, d.height)
                        end
                    end)

                    pcall(function()
                        SetVehicleWheelTireColliderSize(veh, 0, d.tire_fl)
                        SetVehicleWheelTireColliderSize(veh, 1, d.tire_fr)
                        SetVehicleWheelTireColliderSize(veh, 2, d.tire_rl)
                        SetVehicleWheelTireColliderSize(veh, 3, d.tire_rr)

                        SetVehicleWheelRimColliderSize(veh, 0, d.rim_fl)
                        SetVehicleWheelRimColliderSize(veh, 1, d.rim_fr)
                        SetVehicleWheelRimColliderSize(veh, 2, d.rim_rl)
                        SetVehicleWheelRimColliderSize(veh, 3, d.rim_rr)
                    end)
                end
            end
            Wait(tick)
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    local scanTimer = Config.FitmentScanTimer or 1500
    while true do
        if performVehicleCheck then refreshFitmentVehicles() end
        Wait(scanTimer)
    end
end)
