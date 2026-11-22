Liveview = {
    active = false
}

local cfg = Config.LiveView
local session = nil

local KEY_EXIT = 177
local KEY_PREV = 174
local KEY_NEXT = 175
local KEY_CHAT = 245
local KEY_TALK = 249

local function notify(key, notifyType)
    lib.notify({ description = L(key), type = notifyType or 'inform' })
end

local function resolvePed(s)
    local player = GetPlayerFromServerId(s.target)
    if player ~= -1 then
        local ped = GetPlayerPed(player)
        if ped ~= 0 and DoesEntityExist(ped) then return ped end
    end
    if s.netId and NetworkDoesNetworkIdExist(s.netId) then
        local entity = NetworkGetEntityFromNetworkId(s.netId)
        if entity ~= 0 and DoesEntityExist(entity) then return entity end
    end
end

local function attach(s, ped)
    local vehicle = Dashcam.GetVehicle(ped) or 0
    local anchor = vehicle ~= 0 and vehicle or ped
    if s.anchor == anchor then return vehicle end
    DetachCam(s.cam)
    if vehicle ~= 0 then
        local offset = Dashcam.GetOffset(vehicle)
        HardAttachCamToEntity(s.cam, vehicle, 0.0, 0.0, 0.0, offset.x, offset.y, offset.z, true)
        SetCamFov(s.cam, Config.Dashcam.Camera.Fov)
    else
        local offset = cfg.BodyOffset
        HardAttachCamToEntity(s.cam, ped, cfg.BodyPitch, 0.0, 0.0, offset.x, offset.y, offset.z, true)
        SetCamFov(s.cam, cfg.Fov)
    end
    SetFocusEntity(ped)
    s.anchor = anchor
    return vehicle
end

local function holdAt(s)
    if s.anchor then
        DetachCam(s.cam)
        s.anchor = nil
    end
    local c = s.coords
    if not c then return end
    SetCamCoord(s.cam, c.x, c.y, c.z + 1.0)
    SetFocusPosAndVel(c.x, c.y, c.z, 0.0, 0.0, 0.0)
end

local function sendViewer(s)
    Nui('viewer', {
        active = true,
        info = s.info,
        index = s.index,
        total = s.total,
        time = s.time
    })
end

local function stop(tellServer, reasonKey)
    local s = session
    if not s then return end
    session = nil
    Liveview.active = false
    if tellServer then
        TriggerServerEvent('kipchak_bodycam:server:liveviewStop')
    end
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(s.cam, false)
    ClearFocus()
    FreezeEntityPosition(PlayerPedId(), false)
    Nui('viewer', { active = false })
    Nui('frame', { visible = false })
    if not Bodycam.on then Bodycam.SetTimecycle(false) end
    Bodycam.Refresh()
    if not IsScreenFadedIn() and not IsScreenFadingIn() then
        DoScreenFadeIn(250)
    end
    if reasonKey then notify(reasonKey) end
end

local function switchTo(s, data)
    s.target = data.target
    s.netId = data.netId
    s.coords = data.coords
    s.info = data.info
    s.index = data.index
    s.total = data.total
    s.time = data.time
    s.lostAt = nil
    s.anchor = nil
    s.signal = nil
    s.connected = nil
    Nui('switch')
    sendViewer(s)
end

local function cycle(s, direction)
    if s.cycling then return end
    s.cycling = true
    lib.callback('kipchak_bodycam:liveview:cycle', false, function(data)
        s.cycling = false
        if session ~= s or not data then return end
        switchTo(s, data)
    end, direction)
end

local function poll(s)
    s.polling = true
    lib.callback('kipchak_bodycam:liveview:status', false, function(data)
        s.polling = false
        if session ~= s then return end
        if not data then
            stop(false, 'liveview_ended')
            return
        end
        if data.target ~= s.target then return end
        if data.coords then s.coords = data.coords end
        if data.netId then s.netId = data.netId end
    end)
end

local function setSignal(s, ok)
    if s.signal == ok then return end
    s.signal = ok
    Nui('signal', { ok = ok, connecting = not s.connected })
    if ok then s.connected = true end
end

local function run(s)
    local lastPoll, lastFrame = 0, 0
    while session == s do
        DisableAllControlActions(0)
        EnableControlAction(0, KEY_CHAT, true)
        EnableControlAction(0, KEY_TALK, true)
        if IsDisabledControlJustPressed(0, KEY_EXIT) then
            stop(true)
            return
        end
        if IsDisabledControlJustPressed(0, KEY_NEXT) then
            cycle(s, 1)
        elseif IsDisabledControlJustPressed(0, KEY_PREV) then
            cycle(s, -1)
        end
        if IsEntityDead(PlayerPedId()) then
            stop(true)
            return
        end

        local now = GetGameTimer()
        local ped = resolvePed(s)
        if ped then
            s.lostAt = nil
            setSignal(s, true)
            local vehicle = attach(s, ped)
            if now - lastFrame >= 200 then
                lastFrame = now
                local frame = { visible = true, mode = 'bodycam', game = Bodycam.GameClock() }
                if vehicle ~= 0 then
                    frame.mode = 'dashcam'
                    frame.vehicle = Dashcam.GetData(vehicle, s.info and s.info.badge)
                end
                Nui('frame', frame)
            end
        else
            setSignal(s, false)
            s.lostAt = s.lostAt or now
            holdAt(s)
            if now - s.lostAt > cfg.SignalTimeout * 1000 then
                stop(true, 'liveview_signal_lost')
                return
            end
        end

        if not s.polling and now - lastPoll >= 1000 then
            lastPoll = now
            poll(s)
        end
        Wait(0)
    end
end

function Liveview.Start(target)
    if session then return end
    local data, reason = lib.callback.await('kipchak_bodycam:liveview:start', false, target)
    if not data then
        notify(reason or 'liveview_unavailable', 'error')
        return
    end
    if session then return end
    Dashcam.StopCamera()
    DoScreenFadeOut(200)
    local timeout = GetGameTimer() + 1000
    while not IsScreenFadedOut() and GetGameTimer() < timeout do Wait(0) end

    local s = {
        cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true),
        target = data.target,
        netId = data.netId,
        coords = data.coords,
        info = data.info,
        index = data.index,
        total = data.total,
        time = data.time
    }
    session = s
    Liveview.active = true
    FreezeEntityPosition(PlayerPedId(), true)
    SetCamFov(s.cam, cfg.Fov)
    holdAt(s)
    RenderScriptCams(true, false, 0, true, true)
    Nui('frame', { visible = false })
    sendViewer(s)
    Bodycam.SetTimecycle(true)
    DoScreenFadeIn(300)
    CreateThread(function() run(s) end)
end

RegisterNetEvent('kipchak_bodycam:client:liveviewList', function(entries)
    if session or type(entries) ~= 'table' then return end
    local options = {}
    for _, entry in ipairs(entries) do
        local profile = Config.Departments[entry.job]
        local department = profile and profile.label or entry.jobLabel or ''
        options[#options + 1] = {
            title = entry.name,
            description = (entry.badge and entry.badge ~= '') and L('menu_entry', L('ui_badge'), entry.badge, department, entry.inVehicle and L('menu_in_vehicle') or L('menu_on_foot')) or (department .. ' · ' .. (entry.inVehicle and L('menu_in_vehicle') or L('menu_on_foot'))),
            icon = entry.inVehicle and 'car' or 'person-walking',
            onSelect = function()
                CreateThread(function() Liveview.Start(entry.id) end)
            end
        }
    end
    lib.registerContext({ id = 'kipchak_bodycam_feeds', title = L('menu_title'), options = options })
    lib.showContext('kipchak_bodycam_feeds')
end)

RegisterNetEvent('kipchak_bodycam:client:liveviewEnd', function(reason)
    stop(false, reason or 'liveview_ended')
end)

RegisterNetEvent('kipchak_bodycam:client:liveviewInfo', function(target, info)
    local s = session
    if not s or s.target ~= target then return end
    s.info = info
    sendViewer(s)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() or not session then return end
    stop(false)
end)

exports('IsViewingLive', function()
    return Liveview.active
end)
