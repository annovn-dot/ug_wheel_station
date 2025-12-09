local inZone             = false
local currentZoneId      = nil
local currentZoneCfg     = nil
local isMenuOpen         = false
local vehEntity          = nil
local vehPlate           = nil
local originalWheelsJSON = nil
local uiHasFocus         = false

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
DecorRegister("ug_fit_height", 1)

local vehiclesToCheckFitment = {}
local ActiveTuning           = {}
local performVehicleCheck    = true

local function dbg(...)
    if Config and Config.Debug then
        print("[ug_wheel_tuning:client]", ...)
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

local function trimPlateClient(p)
    if not p then return nil end
    return (p:gsub("^%s*(.-)%s*$", "%1"))
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

local function BuildWheelDataFromVehicle(veh)
    if not veh or veh == 0 then
        return {
            stance = { fl = 0.0, fr = 0.0, rl = 0.0, rr = 0.0, front = 0.0, rear = 0.0 },
            camber = { fl = 0.0, fr = 0.0, rl = 0.0, rr = 0.0, front = 0.0, rear = 0.0 },
            width  = 0.0,
            height = 0.0,
        }
    end

    local numWheels = GetVehicleNumberOfWheels(veh)

    local off_fl    = (numWheels > 0) and GetVehicleWheelXOffset(veh, 0) or 0.0
    local off_fr    = (numWheels > 1) and GetVehicleWheelXOffset(veh, 1) or 0.0
    local off_rl    = (numWheels > 2) and GetVehicleWheelXOffset(veh, 2) or 0.0
    local off_rr    = (numWheels > 3) and GetVehicleWheelXOffset(veh, 3) or 0.0

    local cam_fl    = (numWheels > 0) and GetVehicleWheelYRotation(veh, 0) or 0.0
    local cam_fr    = (numWheels > 1) and GetVehicleWheelYRotation(veh, 1) or 0.0
    local cam_rl    = (numWheels > 2) and GetVehicleWheelYRotation(veh, 2) or 0.0
    local cam_rr    = (numWheels > 3) and GetVehicleWheelYRotation(veh, 3) or 0.0

    local width     = GetVehicleWheelWidth(veh) or 0.0
    local height    = GetVehicleSuspensionHeight(veh) or 0.0

    local stance    = {
        fl    = off_fl,
        fr    = off_fr,
        rl    = off_rl,
        rr    = off_rr,
        front = (off_fl + off_fr) / 2.0,
        rear  = (off_rl + off_rr) / 2.0,
    }

    local camber    = {
        fl    = cam_fl,
        fr    = cam_fr,
        rl    = cam_rl,
        rr    = cam_rr,
        front = (cam_fl + cam_fr) / 2.0,
        rear  = (cam_rl + cam_rr) / 2.0,
    }

    return {
        stance = stance,
        camber = camber,
        width  = width,
        height = height,
    }
end

CreateThread(function()
    Wait(500)

    if not Config or not Config.FitmentZones then
        print("^1[ug_wheel_tuning] ERROR: Config.FitmentZones is nil. Check cfg_settings.lua & fxmanifest.^0")
    else
        local count = 0
        for id, cfg in pairs(Config.FitmentZones) do
            local c = getZoneCoords(cfg)
            if c then
                count = count + 1
                dbg(("Zone '%s' at %.2f %.2f %.2f (r=%.2f)"):format(
                    id, c.x, c.y, c.z, cfg.radius or 2.5
                ))
            else
                print(("^1[ug_wheel_tuning] Zone '%s' has invalid coords^0"):format(id))
            end
        end
        print(("[ug_wheel_tuning] Loaded %d wheel fitment zones."):format(count))
    end

    while true do
        local ped               = PlayerPedId()
        local pos               = GetEntityCoords(ped)
        local foundId, foundCfg = nil, nil

        for id, cfg in pairs(Config.FitmentZones or {}) do
            local c = getZoneCoords(cfg)
            if c then
                local dist = #(pos - c)
                if dist <= (cfg.radius or 2.5) then
                    foundId  = id
                    foundCfg = cfg
                    break
                end
            end
        end

        if foundId and not inZone then
            inZone         = true
            currentZoneId  = foundId
            currentZoneCfg = foundCfg
            dbg("Entered zone:", currentZoneId)
            showLeftHint()
        elseif (not foundId) and inZone then
            dbg("Left zone:", currentZoneId or "nil")
            inZone         = false
            currentZoneId  = nil
            currentZoneCfg = nil
            if lib and lib.hideTextUI then pcall(lib.hideTextUI) end
        end

        Wait(700)
    end
end)

local function ApplyWheelsClientside(payload, vehicleOverride)
    if not payload then
        dbg("ApplyWheelsClientside: no payload")
        return
    end

    local veh = vehicleOverride or vehEntity
    if not veh or veh == 0 then
        dbg("ApplyWheelsClientside: no vehicle")
        return
    end

    local numWheels   = GetVehicleNumberOfWheels(veh)
    local stance      = payload.stance or {}
    local camber      = payload.camber or {}

    local offFL       = stance.fl or stance.front or 0.0
    local offFR       = stance.fr or stance.front or 0.0
    local offRL       = stance.rl or stance.rear or 0.0
    local offRR       = stance.rr or stance.rear or 0.0

    local camFL       = camber.fl or camber.front or 0.0
    local camFR       = camber.fr or camber.front or 0.0
    local camRL       = camber.rl or camber.rear or 0.0
    local camRR       = camber.rr or camber.rear or 0.0

    local finalWidth  = payload.width or GetVehicleWheelWidth(veh)
    local finalHeight = payload.height or GetVehicleSuspensionHeight(veh)

    dbg(("ApplyWheelsClientside veh=%s wheels=%d | stance=%s | camber=%s | width=%s | height=%s"):format(
        tostring(veh),
        numWheels,
        json.encode(stance),
        json.encode(camber),
        tostring(finalWidth),
        tostring(finalHeight)
    ))

    if numWheels >= 1 then
        SetVehicleWheelXOffset(veh, 0, offFL)
        SetVehicleWheelYRotation(veh, 0, camFL)
    end
    if numWheels >= 2 then
        SetVehicleWheelXOffset(veh, 1, offFR)
        SetVehicleWheelYRotation(veh, 1, camFR)
    end
    if numWheels >= 3 then
        SetVehicleWheelXOffset(veh, 2, offRL)
        SetVehicleWheelYRotation(veh, 2, camRL)
    end
    if numWheels >= 4 then
        SetVehicleWheelXOffset(veh, 3, offRR)
        SetVehicleWheelYRotation(veh, 3, camRR)
    end

    SetVehicleWheelWidth(veh, finalWidth)
    SetVehicleSuspensionHeight(veh, finalHeight)

    DecorSetBool(veh, "ug_fit_applied", true)
    DecorSetFloat(veh, "ug_fit_width", finalWidth)
    DecorSetFloat(veh, "ug_fit_off_fl", offFL)
    DecorSetFloat(veh, "ug_fit_off_fr", offFR)
    DecorSetFloat(veh, "ug_fit_off_rl", offRL)
    DecorSetFloat(veh, "ug_fit_off_rr", offRR)
    DecorSetFloat(veh, "ug_fit_cam_fl", camFL)
    DecorSetFloat(veh, "ug_fit_cam_fr", camFR)
    DecorSetFloat(veh, "ug_fit_cam_rl", camRL)
    DecorSetFloat(veh, "ug_fit_cam_rr", camRR)
    DecorSetFloat(veh, "ug_fit_height", finalHeight)
end

local function RevertOriginal()
    if not originalWheelsJSON or originalWheelsJSON == "" then
        dbg("RevertOriginal: nothing stored")
        return
    end

    local ok, parsed = pcall(function()
        return json.decode(originalWheelsJSON)
    end)
    if not ok or not parsed then
        dbg("RevertOriginal: JSON decode failed")
        return
    end

    dbg("RevertOriginal: applying stored data")
    ApplyWheelsClientside(parsed)
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

    vehEntity = veh
    vehPlate  = GetVehicleNumberPlateText(vehEntity) or "UNKNOWN"

    dbg("Opening tuning for", vehPlate, "zone", currentZoneId)

    local data = BuildWheelDataFromVehicle(vehEntity)

    originalWheelsJSON = json.encode(data or {})

    OpenNUI(data)
end

RegisterCommand('ug_wheel_open', function()
    if isMenuOpen then return end

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

    vehEntity = veh
    vehPlate  = GetVehicleNumberPlateText(vehEntity) or "UNKNOWN"

    dbg("Opening tuning for", vehPlate, "zone", currentZoneId)

    local data = BuildWheelDataFromVehicle(vehEntity)
    originalWheelsJSON = json.encode(data or {})

    OpenNUI(data)
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
    dbg("NUI preview payload:", json.encode(payload))
    ApplyWheelsClientside(payload)
end)

RegisterNUICallback('apply', function(payload, cb)
    cb({ ok = true })

    if not vehEntity or vehEntity == 0 then
        notify("No vehicle found.")
        RevertOriginal()
        CloseNUI()
        return
    end

    dbg("NUI apply payload:", json.encode(payload))

    local progressed = true
    if lib and lib.progressBar then
        local r = lib.progressBar({
            duration = 5000,
            label    = "Applying changes..."
        })
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

    ApplyWheelsClientside(payload)

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

    if uiHasFocus then
        notify("UI focus: ON (mouse controls menu)")
    else
        notify("UI focus: OFF (mouse controls camera) - use /focus to get it back")
    end
end)

RegisterNetEvent('ug_wheel_tuning:applyOnSpawn', function(netId, data)
    if not netId or not data then return end

    local veh = NetToVeh(netId)
    if not veh or veh == 0 then
        veh = NetToEnt(netId)
    end
    if not veh or veh == 0 then return end

    dbg("Applying wheels on spawn for netId", netId)
    ApplyWheelsClientside(data, veh)
end)

function IsInWheelZone()
    return inZone, currentZoneId, currentZoneCfg
end

exports('IsInWheelZone', IsInWheelZone)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        SetNuiFocus(false, false)
    end
end)

CreateThread(function()
    while true do
        if isMenuOpen then
            local ped = PlayerPedId()
            if GetVehiclePedIsIn(ped, false) == 0 then
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

    if uiHasFocus then
        notify("UI focus: ON (mouse controls menu)")
    else
        notify("UI focus: OFF (mouse controls camera) - use /focus to get it back")
    end
end, false)

RegisterKeyMapping('focus', 'Toggle Wheel Tuning UI focus / camera', 'keyboard', 'F2')

local function isNear(pos1, pos2, dist)
    return #(pos2 - pos1) < dist
end

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
                    height  = DecorGetFloat(veh, "ug_fit_height"),
                }
            end
        end
    end
end

CreateThread(function()
    local tick = Config.FitmentTick or 25
    while true do
        if performVehicleCheck and #vehiclesToCheckFitment > 0 then
            for _, data in ipairs(vehiclesToCheckFitment) do
                local veh = data.vehicle
                if veh and DoesEntityExist(veh) then
                    local curWidth = GetVehicleWheelWidth(veh)
                    if math.abs(curWidth - data.width) > 0.001 then
                        SetVehicleWheelWidth(veh, data.width)
                    end

                    local curOff = GetVehicleWheelXOffset(veh, 0)
                    if math.abs(curOff - data.off_fl) > 0.001 then
                        SetVehicleWheelXOffset(veh, 0, data.off_fl)
                        SetVehicleWheelXOffset(veh, 1, data.off_fr)
                        SetVehicleWheelXOffset(veh, 2, data.off_rl)
                        SetVehicleWheelXOffset(veh, 3, data.off_rr)
                    end

                    local curCam = GetVehicleWheelYRotation(veh, 0)
                    if math.abs(curCam - data.cam_fl) > 0.001 then
                        SetVehicleWheelYRotation(veh, 0, data.cam_fl)
                        SetVehicleWheelYRotation(veh, 1, data.cam_fr)
                        SetVehicleWheelYRotation(veh, 2, data.cam_rl)
                        SetVehicleWheelYRotation(veh, 3, data.cam_rr)
                    end

                    local curH = GetVehicleSuspensionHeight(veh)
                    if math.abs(curH - data.height) > 0.001 then
                        SetVehicleSuspensionHeight(veh, data.height)
                    end
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
        if performVehicleCheck then
            refreshFitmentVehicles()
        end
        Wait(scanTimer)
    end
end)
