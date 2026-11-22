if Bridge.Inventory ~= 'esx' then return end

InventoryBridge = {}

local ESX = exports.es_extended:getSharedObject()

function InventoryBridge.HasItem(src, name)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    local item = xPlayer.getInventoryItem(name)
    return item ~= nil and (tonumber(item.count) or 0) > 0
end

function InventoryBridge.RegisterUsable(name, cb)
    ESX.RegisterUsableItem(name, function(src) cb(src) end)
end

function InventoryBridge.ItemExists(name)
    local items = ESX.Items
    if type(items) ~= 'table' or next(items) == nil then return true end
    return items[name] ~= nil
end
