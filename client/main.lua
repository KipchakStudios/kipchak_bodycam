Bodycam = {
    on = false,
    info = nil,
    hidden = false
}

local nuiReady = false
local serverTime = nil
local loopRunning = false
local lastFrame = nil
local timecycleActive = false

local LABEL_KEYS = {
    Rec = 'ui_rec',
    Dashcam = 'ui_dashcam',
    Live = 'ui_live',
    Officer = 'ui_officer',
    Badge = 'ui_badge',
    Unit = 'ui_unit',
    Speed = 'ui_speed',
    Lights = 'ui_lights',
    Siren = 'ui_siren',
    On = 'ui_on',
    Off = 'ui_off'
}

local NOTIFY_KEYS = {
    restore = 'notify_resumed',
    item_removed = 'notify_item_removed',
    unauthorized = 'notify_unauthorized',
    dead = 'notify_dead',
    cuffed = 'notify_cuffed'
}

function Nui(action, data)
    data = data or {}
    data.action = action
    SendNUIMessage(data)
end

local function buildLabels()
    local labels = {}
    for key, localeKey in pairs(LABEL_KEYS) do
        local custom = Config.Overlay.Labels[key]
        labels[key] = type(custom) == 'string' and custom or L(localeKey)
    end
    labels.SpeedUnit = Config.Dashcam.SpeedUnit == 'mph' and L('ui_mph') or L('ui_kmh')
    labels.Hint = L('ui_hint')
    labels.NoSignal = L('ui_no_signal')
    labels.Connecting = L('ui_connecting')
    return labels
end

local function buildNuiConfig()
    local effects = Config.Effects
    return {
        overlay = Config.Overlay,
        logo = Config.Logo,
        departments = Config.Departments,
        defaultDepartment = Config.DefaultDepartment,
        dateTime = Config.DateTime,
        serial = Config.Serial.Enabled,
        labels = buildLabels(),
        effects = {
            Vignette = effects.Vignette,
            Grain = effects.Grain,
            Frame = effects.Frame
        }
    }
end

function Bodycam.SetTimecycle(state)
    local tc = Config.Effects.Timecycle
    if state and tc.Enabled and not timecycleActive then
        SetTimecycleModifier(tc.Modifier)
        SetTimecycleModifierStrength(tc.Strength)
        timecycleActive = true
    elseif not state and timecycleActive then
        ClearTimecycleModifier()
        timecycleActive = false
    end
end

function Bodycam.GameClock()
    if Config.DateTime.Source ~= 'game' then return nil end
    return {
        y = GetClockYear(),
        mo = GetClockMonth() + 1,
        d = GetClockDayOfMonth(),
        h = GetClockHours(),
        mi = GetClockMinutes(),
        s = GetClockSeconds()
    }
end

function Bodycam.Refresh()
    lastFrame = nil
end

local function isFirstPerson(ped)
    if Dashcam.CameraActive() then return true end
    if IsPedInAnyVehicle(ped, false) then
        return GetFollowVehicleCamViewMode() == 4
    end
    return GetFollowPedCamViewMode() == 4
end

local function isVisible(ped)
    if not Bodycam.on or Bodycam.hidden or Liveview.active then return false end
    if Config.HideInPauseMenu and IsPauseMenuActive() then return false end
    if not Config.ShowInThirdPerson and not isFirstPerson(ped) then return false end
    return true
end

local function frameKey(frame)
    local v = frame.vehicle
    if not frame.visible then return 'hidden' end
    return ('%s|%s|%s|%s|%s|%s'):format(frame.mode, v and v.unit or '', v and v.speed or '', v and tostring(v.lights) or '', v and tostring(v.siren) or '', frame.game and frame.game.s or '')
end

local function startLoop()
    if loopRunning then return end
    loopRunning = true
    CreateThread(function()
        while Bodycam.on do
            if not Liveview.active then
                local ped = PlayerPedId()
                local visible = isVisible(ped)
                local frame = { visible = visible, mode = 'bodycam' }
                if visible then
                    local veh = (Config.Dashcam.OverlayMode == 'vehicle' or Dashcam.CameraActive()) and Dashcam.GetVehicle(ped)
                    if veh then
                        frame.mode = 'dashcam'
                        frame.vehicle = Dashcam.GetData(veh, Bodycam.info and Bodycam.info.badge)
                    end
                    frame.game = Bodycam.GameClock()
                end
                local key = frameKey(frame)
                if key ~= lastFrame then
                    lastFrame = key
                    Nui('frame', frame)
                end
                Bodycam.SetTimecycle(visible)
            end
            Wait(200)
        end
        lastFrame = nil
        if not Liveview.active then
            Nui('frame', { visible = false })
            Bodycam.SetTimecycle(false)
        end
        loopRunning = false
    end)
end

local function feedback(state, reason)
    if Config.Sound.Enabled and reason ~= 'restore' and reason ~= 'unload' then
        Nui('beep', { kind = state and 'on' or 'off', volume = Config.Sound.Volume })
    end
    if Config.Notify.Enabled and reason ~= 'unload' then
        local key = NOTIFY_KEYS[reason] or (state and 'notify_on' or 'notify_off')
        if state and reason ~= 'restore' then key = 'notify_on' end
        lib.notify({ description = L(key), type = state and 'success' or 'inform' })
    end
end

local function applyState(state, info, time, reason)
    local changed = Bodycam.on ~= state
    Bodycam.on = state
    if info then Bodycam.info = info end
    if time then
        serverTime = time
        Nui('time', { epoch = time })
    end
    Nui('info', { info = Bodycam.info })
    if state then
        startLoop()
    else
        Dashcam.StopCamera()
    end
    if changed and reason then
        feedback(state, reason)
    end
end

RegisterNetEvent('kipchak_bodycam:client:state', function(state, payload)
    payload = payload or {}
    applyState(state == true, payload.info, payload.time, payload.reason or 'item')
end)

RegisterNetEvent('kipchak_bodycam:client:info', function(info)
    Bodycam.info = info
    Nui('info', { info = info })
end)

RegisterNetEvent('kipchak_bodycam:client:beep', function(state, distance)
    local sound = Config.Sound
    if not sound.Enabled or not sound.Nearby.Enabled then return end
    distance = tonumber(distance) or 0
    if distance > sound.Nearby.Distance then return end
    local volume = sound.Volume * math.max(0.15, 1.0 - distance / sound.Nearby.Distance)
    Nui('beep', { kind = state and 'on' or 'off', volume = volume })
end)

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    Nui('config', buildNuiConfig())
    if serverTime then Nui('time', { epoch = serverTime }) end
    Nui('info', { info = Bodycam.info })
    Bodycam.Refresh()
    cb('ok')
end)

if Config.HideOverlayKey.Enabled then
    lib.addKeybind({
        name = 'kipchak_bodycam_hide',
        description = L('keybind_hide'),
        defaultKey = Config.HideOverlayKey.Key or '',
        onPressed = function()
            if not Bodycam.on then return end
            Bodycam.hidden = not Bodycam.hidden
        end
    })
end

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(250) end
    local timeout = GetGameTimer() + 10000
    while not nuiReady and GetGameTimer() < timeout do Wait(100) end
    local state, info, time = lib.callback.await('kipchak_bodycam:sync', false)
    if state ~= nil then
        applyState(state == true, info, time, nil)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Bodycam.SetTimecycle(false)
end)

exports('IsBodycamOn', function()
    return Bodycam.on
end)
