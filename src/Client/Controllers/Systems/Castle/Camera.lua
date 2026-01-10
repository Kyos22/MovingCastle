local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local camera = workspace.CurrentCamera
local Camera = {}

-- Biến lưu trữ
local currentCastleModel = nil
local cameraConnection = nil
local isCameraActive = false

-- Cài đặt camera FIXED (không thay đổi theo model)
local CAMERA_SETTINGS = {
    FixedHeight = 50,           -- Độ cao camera cố định so với ground
    FixedDistance = 60,         -- Khoảng cách cố định
    FOV = 70,                   -- Góc nhìn camera
    Smoothness = 0.2,           -- Độ mượt
    MinSmoothness = 0.05,       -- Độ mượt tối thiểu
    MaxSmoothness = 0.4,        -- Độ mượt tối đa
    UseFixedCamera = true,      -- Camera cố định, không follow
    FixedPosition = nil,        -- Vị trí camera cố định
    LookAtOffset = Vector3.new(0, 10, 0) -- Nhìn vào điểm cao hơn model
}

-- Hàm lấy vị trí ground dưới model (tránh rung do physics)
local function getGroundPositionBelowModel(model)
    if not model or not model.PrimaryPart then
        return Vector3.new(0, 0, 0)
    end
    
    local root = model.PrimaryPart
    local rayOrigin = root.Position + Vector3.new(0, 100, 0) -- Bắt đầu từ trên cao
    local rayDirection = Vector3.new(0, -200, 0) -- Chiếu xuống 200 studs
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {workspace.Terrain}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    
    local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    
    if raycastResult then
        return raycastResult.Position
    else
        -- Nếu không tìm thấy ground, dùng vị trí model - 10 studs
        return Vector3.new(root.Position.X, 0, root.Position.Z)
    end
end

-- Hàm tính toán camera position FIXED (tránh rung)
local function calculateFixedCameraPosition(model)
    if not model or not model.PrimaryPart then
        return nil, nil
    end
    
    local root = model.PrimaryPart
    
    -- OPTION 1: Camera cố định dựa trên ground position
    local groundPos = getGroundPositionBelowModel(model)
    
    -- Camera position: CỐ ĐỊNH dựa trên ground, không phải model position
    local cameraPosition = Vector3.new(
        groundPos.X, 
        groundPos.Y + CAMERA_SETTINGS.FixedHeight, 
        groundPos.Z + CAMERA_SETTINGS.FixedDistance
    )
    
    -- Look at position: Nhìn vào điểm trên model (giảm rung)
    local lookAtPosition = Vector3.new(
        root.Position.X,
        root.Position.Y + CAMERA_SETTINGS.LookAtOffset.Y,
        root.Position.Z
    )
    
    return cameraPosition, lookAtPosition
end

-- Hàm lấy vị trí model đã được smoothed (giảm rung network)
local lastSmoothedPosition = nil
local smoothingAlpha = 0.1

local function getSmoothedModelPosition(model)
    if not model or not model.PrimaryPart then
        return nil
    end
    
    local currentPos = model.PrimaryPart.Position
    
    if not lastSmoothedPosition then
        lastSmoothedPosition = currentPos
        return currentPos
    end
    
    -- Exponential smoothing để giảm rung
    local smoothedPos = lastSmoothedPosition + (currentPos - lastSmoothedPosition) * smoothingAlpha
    lastSmoothedPosition = smoothedPos
    
    return smoothedPos
end

-- Hàm tính dynamic smoothness dựa trên velocity
local lastPositions = {}
local function calculateDynamicSmoothness(model)
    if not model or not model.PrimaryPart then
        return CAMERA_SETTINGS.Smoothness
    end
    
    local currentPos = model.PrimaryPart.Position
    table.insert(lastPositions, {time = os.clock(), position = currentPos})
    
    -- Chỉ giữ 5 frame gần nhất
    while #lastPositions > 5 do
        table.remove(lastPositions, 1)
    end
    
    if #lastPositions < 2 then
        return CAMERA_SETTINGS.Smoothness
    end
    
    -- Tính velocity
    local oldest = lastPositions[1]
    local newest = lastPositions[#lastPositions]
    local timeDiff = newest.time - oldest.time
    
    if timeDiff <= 0 then
        return CAMERA_SETTINGS.Smoothness
    end
    
    local distance = (newest.position - oldest.position).Magnitude
    local velocity = distance / timeDiff
    
    -- Điều chỉnh smoothness dựa trên velocity
    local dynamicSmoothness = CAMERA_SETTINGS.Smoothness
    
    if velocity < 5 then
        -- Di chuyển chậm: tăng smoothness để giảm rung
        dynamicSmoothness = math.min(CAMERA_SETTINGS.MaxSmoothness, CAMERA_SETTINGS.Smoothness * 1.5)
    elseif velocity > 20 then
        -- Di chuyển nhanh: giảm smoothness để theo kịp
        dynamicSmoothness = math.max(CAMERA_SETTINGS.MinSmoothness, CAMERA_SETTINGS.Smoothness * 0.7)
    end
    
    return dynamicSmoothness
end

-- Hàm cập nhật camera với anti-jitter
local lastCameraCFrame = nil
local function updateCameraAntiJitter()
    if not isCameraActive or not currentCastleModel then 
        return 
    end
    
    if not currentCastleModel.PrimaryPart or not currentCastleModel.PrimaryPart:IsDescendantOf(workspace) then
        Camera.Destroy()
        return
    end
    
    local cameraPosition, lookAtPosition = calculateFixedCameraPosition(currentCastleModel)
    if not cameraPosition or not lookAtPosition then return end
    
    -- Tạo target CFrame
    local targetCFrame = CFrame.lookAt(cameraPosition, lookAtPosition)
    
    -- Tính dynamic smoothness
    local dynamicSmoothness = calculateDynamicSmoothness(currentCastleModel)
    
    -- Áp dụng smoothing
    local currentCFrame = lastCameraCFrame or camera.CFrame
    local smoothedCFrame
    
    -- Sử dụng exponential smoothing thay vì lerp đơn giản
    if lastCameraCFrame then
        smoothedCFrame = currentCFrame:Lerp(targetCFrame, dynamicSmoothness)
    else
        smoothedCFrame = targetCFrame
    end
    
    -- Anti-jitter: So sánh với frame trước
    if lastCameraCFrame then
        local positionDelta = (smoothedCFrame.Position - lastCameraCFrame.Position).Magnitude
        local rotationDelta = math.deg((smoothedCFrame.Rotation - lastCameraCFrame.Rotation).Magnitude)
        
        -- Nếu thay đổi quá nhỏ, giữ nguyên frame trước (dead zone)
        if positionDelta < 0.01 and rotationDelta < 0.1 then
            smoothedCFrame = lastCameraCFrame
        end
    end
    
    -- Áp dụng camera
    camera.CFrame = smoothedCFrame
    camera.FieldOfView = CAMERA_SETTINGS.FOV
    
    -- Lưu frame hiện tại
    lastCameraCFrame = smoothedCFrame
end

-- Bật camera castle
function Camera.Setup(model, offset: CFrame)
    if not model or not model.PrimaryPart then
        warn("Invalid model for camera")
        return
    end
    
    print('Setting up ANTI-JITTER camera for model:', model.Name)
    
    -- Reset tất cả biến
    currentCastleModel = model
    isCameraActive = true
    lastSmoothedPosition = nil
    lastPositions = {}
    lastCameraCFrame = nil
    
    -- Đặt camera type
    camera.CameraType = Enum.CameraType.Scriptable
    
    -- Tính vị trí camera ban đầu
    local cameraPosition, lookAtPosition = calculateFixedCameraPosition(model)
    if cameraPosition and lookAtPosition then
        camera.CFrame = CFrame.lookAt(cameraPosition, lookAtPosition)
        lastCameraCFrame = camera.CFrame
    end
    
    camera.FieldOfView = CAMERA_SETTINGS.FOV
    
    -- Dừng kết nối cũ
    if cameraConnection then
        cameraConnection:Disconnect()
        cameraConnection = nil
    end
    
    -- Dùng PreRender thay vì RenderStepped để tránh conflict với physics
    cameraConnection = RunService.PreRender:Connect(updateCameraAntiJitter)
    
    print("Anti-jitter camera activated")
end

-- Tắt camera castle
function Camera.Destroy()
    print("Destroying castle camera")
    isCameraActive = false
    currentCastleModel = nil
    
    -- Reset tất cả biến
    lastSmoothedPosition = nil
    lastPositions = {}
    lastCameraCFrame = nil
    
    -- Dừng kết nối
    if cameraConnection then
        cameraConnection:Disconnect()
        cameraConnection = nil
    end
    
    -- Reset về camera mặc định
    camera.CameraType = Enum.CameraType.Custom
    
    local player = Players.LocalPlayer
    if player and player.Character then
        local humanoid = player.Character:FindFirstChild("Humanoid")
        if humanoid then
            camera.CameraSubject = humanoid
        end
    end
    
    print("Camera reset to default")
end

-- Điều chỉnh cài đặt camera
function Camera.UpdateSettings(newSettings)
    for key, value in pairs(newSettings) do
        if CAMERA_SETTINGS[key] ~= nil then
            CAMERA_SETTINGS[key] = value
        end
    end
    print("Camera settings updated")
end

-- Thử nghiệm các mode camera khác nhau
function Camera.SetMode(mode)
    if mode == "FIXED" then
        CAMERA_SETTINGS.UseFixedCamera = true
        print("Camera mode: FIXED (anti-jitter)")
    elseif mode == "SMOOTH" then
        CAMERA_SETTINGS.UseFixedCamera = false
        CAMERA_SETTINGS.Smoothness = 0.1
        print("Camera mode: SMOOTH")
    elseif mode == "DYNAMIC" then
        CAMERA_SETTINGS.UseFixedCamera = false
        CAMERA_SETTINGS.Smoothness = 0.15
        print("Camera mode: DYNAMIC")
    end
end

-- Debug function
function Camera.GetDebugInfo()
    if not currentCastleModel or not currentCastleModel.PrimaryPart then
        return "No active model"
    end
    
    local pos = currentCastleModel.PrimaryPart.Position
    local velocity = 0
    
    if #lastPositions >= 2 then
        local oldest = lastPositions[1]
        local newest = lastPositions[#lastPositions]
        local timeDiff = newest.time - oldest.time
        if timeDiff > 0 then
            local distance = (newest.position - oldest.position).Magnitude
            velocity = distance / timeDiff
        end
    end
    
    return string.format("Pos: (%.1f, %.1f, %.1f) | Vel: %.1f | Smooth: %.3f", 
        pos.X, pos.Y, pos.Z, velocity, calculateDynamicSmoothness(currentCastleModel))
end

return Camera