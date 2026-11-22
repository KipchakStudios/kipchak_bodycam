if Bridge.Framework ~= 'esx' then return end

local ESX = exports.es_extended:getSharedObject()

local function getPlayer(src)
    return ESX.GetPlayerFromId(src)
end

local function readField(xPlayer, key)
    if type(xPlayer.getMeta) == 'function' then
        local ok, value = pcall(xPlayer.getMeta, key)
        if ok and value ~= nil then return value end
    end
    if type(xPlayer.get) == 'function' then
        local ok, value = pcall(xPlayer.get, key)
        if ok then return value end
    end
end

function Bridge.IsLoaded(src)
    return getPlayer(src) ~= nil
end

function Bridge.GetIdentifier(src)
    local xPlayer = getPlayer(src)
    return xPlayer and xPlayer.identifier
end

function Bridge.GetCharName(src)
    local xPlayer = getPlayer(src)
    if not xPlayer then return Bridge.SplitName(GetPlayerName(src)) end
    local first, last = readField(xPlayer, 'firstName'), readField(xPlayer, 'lastName')
    if type(first) == 'string' and first ~= '' then
        return first, type(last) == 'string' and last or ''
    end
    return Bridge.SplitName(xPlayer.getName and xPlayer.getName() or GetPlayerName(src))
end

function Bridge.GetJob(src)
    local xPlayer = getPlayer(src)
    if not xPlayer or not xPlayer.job then return end
    local job = xPlayer.job
    return job.name, tonumber(job.grade) or 0, job.onDuty ~= false, job.label or job.name
end

function Bridge.GetCallsign(src)
    local xPlayer = getPlayer(src)
    if not xPlayer then return end
    return readField(xPlayer, Config.Badge.MetadataKey)
end

function Bridge.IsDead(src)
    if Player(src).state.isDead then return true end
    local ped = GetPlayerPed(src)
    return ped == 0 or GetEntityHealth(ped) <= 0
end

function Bridge.IsCuffed(src)
    return Bridge.StateCuffed(src)
end

function Bridge.Notify(src, message, notifyType)
    TriggerClientEvent('ox_lib:notify', src, { description = message, type = notifyType or 'inform' })
end

function Bridge.OnLoaded(cb)
    AddEventHandler('esx:playerLoaded', function(playerId)
        if playerId then cb(tonumber(playerId)) end
    end)
end

function Bridge.OnUnload(cb)
    AddEventHandler('esx:playerLogout', function(playerId)
        cb(tonumber(playerId) or source)
    end)
end
