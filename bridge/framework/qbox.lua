if Bridge.Framework ~= 'qbox' then return end

local function getPlayer(src)
    return exports.qbx_core:GetPlayer(src)
end

function Bridge.IsLoaded(src)
    return getPlayer(src) ~= nil
end

function Bridge.GetIdentifier(src)
    local player = getPlayer(src)
    return player and player.PlayerData.citizenid
end

function Bridge.GetCharName(src)
    local player = getPlayer(src)
    if not player then return Bridge.SplitName(GetPlayerName(src)) end
    local info = player.PlayerData.charinfo or {}
    return info.firstname or '', info.lastname or ''
end

function Bridge.GetJob(src)
    local player = getPlayer(src)
    if not player then return end
    local job = player.PlayerData.job or {}
    local grade = job.grade or {}
    return job.name, tonumber(grade.level) or 0, job.onduty == true, job.label or job.name
end

function Bridge.GetCallsign(src)
    local player = getPlayer(src)
    if not player then return end
    local value = player.PlayerData.metadata and player.PlayerData.metadata[Config.Badge.MetadataKey]
    if value == 'NO CALLSIGN' then return end
    return value
end

function Bridge.IsDead(src)
    local player = getPlayer(src)
    if player then
        local meta = player.PlayerData.metadata or {}
        if meta.isdead or meta.inlaststand then return true end
    end
    local ped = GetPlayerPed(src)
    return ped == 0 or GetEntityHealth(ped) <= 0
end

function Bridge.IsCuffed(src)
    local player = getPlayer(src)
    if player and player.PlayerData.metadata and player.PlayerData.metadata.ishandcuffed then return true end
    return Bridge.StateCuffed(src)
end

function Bridge.Notify(src, message, notifyType)
    TriggerClientEvent('ox_lib:notify', src, { description = message, type = notifyType or 'inform' })
end

function Bridge.OnLoaded(cb)
    AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
        local src = player and player.PlayerData and player.PlayerData.source
        if src then cb(src) end
    end)
end

function Bridge.OnUnload(cb)
    AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
        cb(tonumber(src) or source)
    end)
end
