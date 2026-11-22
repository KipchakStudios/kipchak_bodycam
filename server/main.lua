if not Bridge.GetJob then
    print('^1[kipchak_bodycam] No supported framework detected, set Config.Framework^7')
    return
end

Bodycam = {}

local Active = {}
local Info = {}
local LastUse = {}

local function kvpKey(identifier)
    return 'state:' .. identifier
end

local function remember(src, state)
    if not Config.RememberState then return end
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end
    if state then
        SetResourceKvpInt(kvpKey(identifier), 1)
    else
        DeleteResourceKvp(kvpKey(identifier))
    end
end

local function remembered(src)
    if not Config.RememberState then return false end
    local identifier = Bridge.GetIdentifier(src)
    return identifier ~= nil and GetResourceKvpInt(kvpKey(identifier)) == 1
end

local function serialFor(seed)
    local hash = 5381
    seed = tostring(seed)
    for i = 1, #seed do
        hash = (hash * 33 + seed:byte(i)) % 2147483647
    end
    return ('%s %05d'):format(Config.Serial.Prefix, hash % 100000)
end

local function firstChar(text)
    if text == '' then return '' end
    local stop = utf8.offset(text, 2)
    return stop and text:sub(1, stop - 1) or text
end

local function formatName(first, last)
    first, last = first or '', last or ''
    local mode = Config.Overlay.NameFormat
    if mode == 'last' and last ~= '' then return last end
    if mode == 'initial' and first ~= '' and last ~= '' then
        return ('%s. %s'):format(firstChar(first), last)
    end
    if last == '' then return first end
    return ('%s %s'):format(first, last)
end

local function buildInfo(src)
    local job, _, _, jobLabel = Bridge.GetJob(src)
    local badge = Bridge.GetCallsign(src)
    if badge == nil or tostring(badge) == '' then badge = Config.Badge.HideWhenEmpty and '' or Config.Badge.Fallback end
    return {
        name = formatName(Bridge.GetCharName(src)),
        badge = tostring(badge),
        job = job or 'unknown',
        jobLabel = jobLabel or job or '',
        serial = serialFor(Bridge.GetIdentifier(src) or GetPlayerName(src) or src)
    }
end

local function infoSignature(info)
    return table.concat({ info.name, info.badge, info.job, info.jobLabel, info.serial }, '|')
end

local function checkAccess(src)
    if next(Config.AllowedJobs) == nil then return true end
    local job, grade, onDuty = Bridge.GetJob(src)
    local minGrade = job and Config.AllowedJobs[job]
    if not minGrade or (grade or 0) < minGrade then return false, 'no_permission' end
    if Config.RequireOnDuty and not onDuty then return false, 'off_duty' end
    return true
end

local function describe(src)
    local info = Info[src]
    local name = info and info.name or formatName(Bridge.GetCharName(src))
    return ('%s (%s | ID %s)'):format(name, GetPlayerName(src) or '?', src)
end

function SendLog(kind, message)
    if SvConfig.Webhook == '' or not SvConfig.Logs[kind] then return end
    local title = kind == 'LiveView' and L('log_title_view') or L('log_title_toggle')
    PerformHttpRequest(SvConfig.Webhook, function() end, 'POST', json.encode({
        username = SvConfig.BotName,
        embeds = {
            {
                title = title,
                description = message,
                color = kind == 'LiveView' and 5214975 or 16722731,
                footer = { text = 'kipchak_bodycam' },
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
            }
        }
    }), { ['Content-Type'] = 'application/json' })
end

local function beepNearby(src, state)
    local sound = Config.Sound
    if not sound.Enabled or not sound.Nearby.Enabled then return end
    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local origin = GetEntityCoords(ped)
    local bucket = GetPlayerRoutingBucket(src)
    for _, id in ipairs(GetPlayers()) do
        local target = tonumber(id)
        if target and target ~= src and GetPlayerRoutingBucket(target) == bucket then
            local targetPed = GetPlayerPed(target)
            if targetPed ~= 0 then
                local distance = #(GetEntityCoords(targetPed) - origin)
                if distance <= sound.Nearby.Distance then
                    TriggerClientEvent('kipchak_bodycam:client:beep', target, state, distance)
                end
            end
        end
    end
end

local function setActive(src, state, reason)
    state = state == true
    if (Active[src] == true) == state then return false end
    local who = describe(src)
    if state then
        Info[src] = buildInfo(src)
        Active[src] = true
    else
        Active[src] = nil
    end
    Player(src).state:set('bodycam', state, true)
    TriggerClientEvent('kipchak_bodycam:client:state', src, state, {
        info = Info[src],
        time = os.time(),
        reason = reason
    })
    if reason ~= 'restore' and reason ~= 'unload' then
        beepNearby(src, state)
    end
    if not state then
        Info[src] = nil
        if LiveView then LiveView.OnTargetOff(src) end
    end
    TriggerEvent('kipchak_bodycam:toggled', src, state, reason)
    SendLog('Toggle', L(state and 'log_on' or 'log_off', who, reason))
    return true
end

local function tryRestore(src)
    if Active[src] then return 'done' end
    if not Bridge.IsLoaded(src) or not remembered(src) then return 'done' end
    if not checkAccess(src) then return 'done' end
    if not InventoryBridge.HasItem(src, Config.Item) then return 'retry' end
    setActive(src, true, 'restore')
    return 'done'
end

local function onUse(src)
    src = tonumber(src)
    if not src or not GetPlayerName(src) then return end
    local now = GetGameTimer()
    if LastUse[src] and now - LastUse[src] < 1000 then return end
    LastUse[src] = now
    if Active[src] then
        setActive(src, false, 'item')
        remember(src, false)
        return
    end
    local ok, reason = checkAccess(src)
    if not ok then
        Bridge.Notify(src, L(reason), 'error')
        return
    end
    if not InventoryBridge.HasItem(src, Config.Item) then return end
    setActive(src, true, 'item')
    remember(src, true)
end

if InventoryBridge then
    InventoryBridge.RegisterUsable(Config.Item, onUse)
else
    print('^1[kipchak_bodycam] No supported inventory detected, set Config.Inventory^7')
end

function Bodycam.IsActive(src)
    return Active[src] == true
end

function Bodycam.GetInfo(src)
    return Info[src]
end

function Bodycam.GetActive()
    local list = {}
    for src in pairs(Active) do
        list[#list + 1] = src
    end
    table.sort(list)
    return list
end

function Bodycam.Describe(src)
    return describe(src)
end

lib.callback.register('kipchak_bodycam:sync', function(src)
    if not Active[src] and InventoryBridge then
        tryRestore(src)
    end
    return Active[src] == true, Info[src], os.time()
end)

AddStateBagChangeHandler('bodycam', nil, function(bagName, _, value)
    local src = tonumber(bagName:match('^player:(%d+)$'))
    if not src then return end
    if (value == true) ~= (Active[src] == true) then
        SetTimeout(0, function()
            if GetPlayerName(src) then
                Player(src).state:set('bodycam', Active[src] == true, true)
            end
        end)
    end
end)

Bridge.OnLoaded(function(src)
    if not Config.RememberState or not InventoryBridge then return end
    CreateThread(function()
        for _ = 1, 6 do
            Wait(2000)
            if not GetPlayerName(src) then return end
            if tryRestore(src) == 'done' then return end
        end
    end)
end)

Bridge.OnUnload(function(src)
    if src and Active[src] then
        setActive(src, false, 'unload')
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    LastUse[src] = nil
    if LiveView then LiveView.OnViewerDrop(src) end
    if Active[src] then
        local who = describe(src)
        Active[src] = nil
        Info[src] = nil
        if LiveView then LiveView.OnTargetOff(src) end
        TriggerEvent('kipchak_bodycam:toggled', src, false, 'dropped')
        SendLog('Toggle', L('log_off', who, 'dropped'))
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for src in pairs(Active) do
        Player(src).state:set('bodycam', false, true)
    end
end)

CreateThread(function()
    while true do
        Wait(math.max(500, Config.CheckInterval))
        if InventoryBridge then
            for _, src in ipairs(Bodycam.GetActive()) do
                if Active[src] and GetPlayerName(src) then
                    local reason
                    if Config.TurnOffWhenItemRemoved and not InventoryBridge.HasItem(src, Config.Item) then
                        reason = 'item_removed'
                    elseif Config.TurnOffWhenUnauthorized and not checkAccess(src) then
                        reason = 'unauthorized'
                    elseif Config.TurnOffOnDeath and Bridge.IsDead(src) then
                        reason = 'dead'
                    elseif Config.TurnOffOnCuff and Bridge.IsCuffed(src) then
                        reason = 'cuffed'
                    end
                    if reason then
                        setActive(src, false, reason)
                        remember(src, false)
                    else
                        local info = buildInfo(src)
                        if infoSignature(info) ~= infoSignature(Info[src]) then
                            Info[src] = info
                            TriggerClientEvent('kipchak_bodycam:client:info', src, info)
                            if LiveView then LiveView.OnInfo(src, info) end
                        end
                    end
                end
            end
        end
    end
end)

exports('IsBodycamOn', function(src)
    return Active[tonumber(src)] == true
end)

exports('SetBodycam', function(src, state)
    src = tonumber(src)
    if not src or not GetPlayerName(src) then return false end
    local changed = setActive(src, state == true, 'export')
    if changed then remember(src, state == true) end
    return changed
end)
