Dashcam = {}

local cfg = Config.Dashcam
local classes, models, unitNames, offsets = {}, {}, {}, {}

local function toHash(model)
    return type(model) == 'number' and model or GetHashKey(model)
end

for _, class in ipairs(cfg.VehicleClasses or {}) do
    classes[class] = true
end
for _, model in ipairs(cfg.Models or {}) do
    models[toHash(model)] = true
end
for model, name in pairs(cfg.UnitNames or {}) do
    unitNames[toHash(model)] = name
end
for model, offset in pairs(cfg.Camera.Offsets or {}) do
    offsets[toHash(model)] = offset
end

local cam = nil
local camVehicle = nil

function Dashcam.IsEligible(vehicle)
    if not cfg.Enabled or not vehicle or vehicle == 0 then return false end
    return classes[GetVehicleClass(vehicle)] == true or models[GetEntityModel(vehicle)] == true
end

function Dashcam.GetVehicle(ped)
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 and Dashcam.IsEligible(vehicle) then
        return vehicle
    end
end

function Dashcam.GetOffset(vehicle)
    return offsets[GetEntityModel(vehicle)] or cfg.Camera.DefaultOffset
end

function Dashcam.GetData(vehicle, badge)
    local multiplier = cfg.SpeedUnit == 'mph' and 2.236936 or 3.6
    local model = GetEntityModel(vehicle)
    local unit = unitNames[model]
    if not unit then
        if cfg.UnitSource == 'callsign' and badge and badge ~= '' then
            unit = badge
        else
            unit = (GetVehicleNumberPlateText(vehicle) or ''):gsub('^%s+', ''):gsub('%s+$', '')
        end
    end
    return {
        unit = unit,
        speed = math.floor(GetEntitySpeed(vehicle) * multiplier + 0.5),
        lights = IsVehicleSirenOn(vehicle),
        siren = IsVehicleSirenAudioOn(vehicle)
    }
end

function Dashcam.CameraActive()
    return cam ~= nil
end

function Dashcam.StopCamera()
    if not cam then return end
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(cam, false)
    cam = nil
    camVehicle = nil
    Bodycam.Refresh()
end

local function startCamera(vehicle)
    local offset = Dashcam.GetOffset(vehicle)
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    HardAttachCamToEntity(cam, vehicle, 0.0, 0.0, 0.0, offset.x, offset.y, offset.z, true)
    SetCamFov(cam, cfg.Camera.Fov)
    RenderScriptCams(true, false, 0, true, true)
    camVehicle = vehicle
    Bodycam.Refresh()
    CreateThread(function()
        while cam do
            if not Bodycam.on or Liveview.active or not DoesEntityExist(camVehicle) or GetVehiclePedIsIn(PlayerPedId(), false) ~= camVehicle then
                Dashcam.StopCamera()
                break
            end
            Wait(250)
        end
    end)
end

if cfg.Enabled and cfg.Camera.Enabled then
    lib.addKeybind({
        name = 'kipchak_bodycam_dashcam',
        description = L('keybind_dashcam'),
        defaultKey = cfg.Camera.Key or '',
        onPressed = function()
            if cam then
                Dashcam.StopCamera()
                return
            end
            if not Bodycam.on or Liveview.active then return end
            local vehicle = Dashcam.GetVehicle(PlayerPedId())
            if vehicle then startCamera(vehicle) end
        end
    })
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Dashcam.StopCamera()
end)
