if not Bridge.GetJob or not Bodycam then return end

LiveView = {}

local Sessions = {}
local cfg = Config.LiveView

local function inLocation(src)
    if not cfg.Locations or #cfg.Locations == 0 then return true end
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    local coords = GetEntityCoords(ped)
    for _, entry in ipairs(cfg.Locations) do
        local point, radius = entry, cfg.LocationRadius
        if type(entry) == 'table' then
            point, radius = entry.coords, entry.radius or cfg.LocationRadius
        end
        if point and #(coords - vec3(point.x, point.y, point.z)) <= radius then
            return true
        end
    end
    return false
end

local function canView(src)
    if not cfg.Enabled then return false, 'liveview_disabled' end
    local job, grade, onDuty = Bridge.GetJob(src)
    local rule = job and cfg.Jobs[job]
    if not rule then return false, 'liveview_no_permission' end
    local minGrade = type(rule) == 'number' and rule or cfg.MinGrade
    if (grade or 0) < minGrade then return false, 'liveview_no_permission' end
    if cfg.RequireOnDuty and not onDuty then return false, 'liveview_off_duty' end
    local ped = GetPlayerPed(src)
    if ped == 0 then return false, 'liveview_unavailable' end
    if GetVehiclePedIsIn(ped, false) ~= 0 then return false, 'liveview_vehicle' end
    if not inLocation(src) then return false, 'liveview_location' end
    return true
end

local function eligible(viewer)
    local list = {}
    local bucket = GetPlayerRoutingBucket(viewer)
    local viewerJob = cfg.SameJobOnly and Bridge.GetJob(viewer)
    for _, src in ipairs(Bodycam.GetActive()) do
        local allowed = src ~= viewer or (cfg.AllowSelfView and Config.Debug == true)
        if allowed and GetPlayerRoutingBucket(src) ~= bucket then allowed = false end
        if allowed and viewerJob then
            local info = Bodycam.GetInfo(src)
            allowed = info ~= nil and info.job == viewerJob
        end
        if allowed and GetPlayerPed(src) ~= 0 then
            list[#list + 1] = src
        end
    end
    return list
end

local function indexOf(list, value)
    for i, v in ipairs(list) do
        if v == value then return i end
    end
end

local function buildPayload(target, list)
    local ped = GetPlayerPed(target)
    if ped == 0 then return end
    return {
        target = target,
        netId = NetworkGetNetworkIdFromEntity(ped),
        coords = GetEntityCoords(ped),
        info = Bodycam.GetInfo(target),
        index = indexOf(list, target) or 1,
        total = #list,
        time = os.time()
    }
end

local function endSession(viewer, reason, tellViewer)
    local target = Sessions[viewer]
    if not target then return end
    Sessions[viewer] = nil
    SendLog('LiveView', L('log_view_end', Bodycam.Describe(viewer), Bodycam.Describe(target)))
    if tellViewer then
        TriggerClientEvent('kipchak_bodycam:client:liveviewEnd', viewer, reason)
    end
end

local function beginSession(viewer, target)
    local previous = Sessions[viewer]
    if previous == target then return end
    if previous then
        SendLog('LiveView', L('log_view_end', Bodycam.Describe(viewer), Bodycam.Describe(previous)))
    end
    Sessions[viewer] = target
    SendLog('LiveView', L('log_view_start', Bodycam.Describe(viewer), Bodycam.Describe(target)))
    if cfg.NotifyTarget and target ~= viewer then
        Bridge.Notify(target, L('being_watched'), 'inform')
    end
end

function LiveView.OnTargetOff(target)
    for viewer, watched in pairs(Sessions) do
        if watched == target then
            endSession(viewer, 'liveview_target_off', true)
        end
    end
end

function LiveView.OnViewerDrop(viewer)
    endSession(viewer, nil, false)
end

function LiveView.OnInfo(target, info)
    for viewer, watched in pairs(Sessions) do
        if watched == target then
            TriggerClientEvent('kipchak_bodycam:client:liveviewInfo', viewer, target, info)
        end
    end
end

if not cfg.Enabled then return end

lib.addCommand(cfg.Command, { help = L('cmd_liveview') }, function(source)
    local ok, reason = canView(source)
    if not ok then
        Bridge.Notify(source, L(reason), 'error')
        return
    end
    local list = eligible(source)
    if #list == 0 then
        Bridge.Notify(source, L('liveview_none'), 'inform')
        return
    end
    local entries = {}
    for _, target in ipairs(list) do
        local info = Bodycam.GetInfo(target)
        local ped = GetPlayerPed(target)
        if info then
            entries[#entries + 1] = {
                id = target,
                name = info.name,
                badge = info.badge,
                job = info.job,
                jobLabel = info.jobLabel,
                inVehicle = ped ~= 0 and GetVehiclePedIsIn(ped, false) ~= 0
            }
        end
    end
    TriggerClientEvent('kipchak_bodycam:client:liveviewList', source, entries)
end)

lib.callback.register('kipchak_bodycam:liveview:start', function(src, target)
    target = tonumber(target)
    local ok, reason = canView(src)
    if not ok then return nil, reason end
    if Sessions[src] then return nil, 'liveview_unavailable' end
    local list = eligible(src)
    if not target or not indexOf(list, target) then return nil, 'liveview_unavailable' end
    local payload = buildPayload(target, list)
    if not payload then return nil, 'liveview_unavailable' end
    beginSession(src, target)
    return payload
end)

lib.callback.register('kipchak_bodycam:liveview:cycle', function(src, direction)
    local current = Sessions[src]
    if not current then return end
    local ok, reason = canView(src)
    if not ok then
        endSession(src, reason, true)
        return
    end
    local list = eligible(src)
    if #list == 0 then
        endSession(src, 'liveview_target_off', true)
        return
    end
    local index = indexOf(list, current)
    local step = direction == -1 and -1 or 1
    local nextIndex = index and ((index - 1 + step) % #list) + 1 or 1
    local target = list[nextIndex]
    local payload = buildPayload(target, list)
    if not payload then return end
    beginSession(src, target)
    return payload
end)

lib.callback.register('kipchak_bodycam:liveview:status', function(src)
    local target = Sessions[src]
    if not target then return end
    local ok, reason = canView(src)
    if not ok then
        endSession(src, reason, true)
        return
    end
    if not Bodycam.IsActive(target) or not GetPlayerName(target) then
        endSession(src, 'liveview_target_off', true)
        return
    end
    if GetPlayerRoutingBucket(target) ~= GetPlayerRoutingBucket(src) then
        endSession(src, 'liveview_signal_lost', true)
        return
    end
    local ped = GetPlayerPed(target)
    if ped == 0 then return { target = target } end
    return {
        target = target,
        netId = NetworkGetNetworkIdFromEntity(ped),
        coords = GetEntityCoords(ped)
    }
end)

RegisterNetEvent('kipchak_bodycam:server:liveviewStop', function()
    endSession(source, nil, false)
end)
