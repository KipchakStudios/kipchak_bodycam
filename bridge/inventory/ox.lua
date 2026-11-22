if Bridge.Inventory ~= 'ox' then return end

InventoryBridge = {}

function InventoryBridge.HasItem(src, name)
    local ok, count = pcall(exports.ox_inventory.GetItemCount, exports.ox_inventory, src, name)
    if not ok then
        ok, count = pcall(exports.ox_inventory.Search, exports.ox_inventory, src, 'count', name)
    end
    return ok and (tonumber(count) or 0) > 0
end

function InventoryBridge.RegisterUsable(name, cb)
    exports(name, function(event, _, inventory)
        if event == 'usingItem' and inventory and inventory.id then
            cb(inventory.id)
            return false
        end
    end)
end

function InventoryBridge.ItemExists(name)
    return exports.ox_inventory:Items(name) ~= nil
end
