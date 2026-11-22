if Bridge.Inventory ~= 'qb' then return end

InventoryBridge = {}

local QBCore = Bridge.Framework == 'qbcore' and exports['qb-core']:GetCoreObject() or nil

local function getPlayer(src)
    if Bridge.Framework == 'qbox' then
        return exports.qbx_core:GetPlayer(src)
    end
    return QBCore and QBCore.Functions.GetPlayer(src)
end

function InventoryBridge.HasItem(src, name)
    if GetResourceState('qb-inventory') == 'started' then
        local ok, has = pcall(exports['qb-inventory'].HasItem, exports['qb-inventory'], src, name, 1)
        if ok and has ~= nil then return has == true end
    end
    local player = getPlayer(src)
    if not player then return false end
    if player.Functions and player.Functions.GetItemByName then
        local item = player.Functions.GetItemByName(name)
        return item ~= nil and (tonumber(item.amount or item.count) or 0) > 0
    end
    for _, item in pairs(player.PlayerData.items or {}) do
        if item and item.name == name and (tonumber(item.amount or item.count) or 0) > 0 then
            return true
        end
    end
    return false
end

function InventoryBridge.RegisterUsable(name, cb)
    if Bridge.Framework == 'qbox' then
        exports.qbx_core:CreateUseableItem(name, function(src) cb(src) end)
    elseif QBCore then
        QBCore.Functions.CreateUseableItem(name, function(src) cb(src) end)
    end
end

function InventoryBridge.ItemExists(name)
    if not QBCore then return true end
    return QBCore.Shared.Items[name] ~= nil
end
