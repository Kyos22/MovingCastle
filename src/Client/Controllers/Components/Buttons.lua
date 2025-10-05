local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Signal = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Signal"))
local Ripple = require(ReplicatedStorage.Shared.Core.Utils.Ripple)


local Buttons = {}

local function Button(frame: Frame, isLocked: boolean) :  (Signal.Signal<nil>)
	print("isLocked",isLocked,frame)
    local activated = Signal.new()

	local enabled = Instance.new("BoolValue")
	enabled.Name = "Enabled"
	enabled.Value = true
	enabled.Parent = frame

	local hovered = Instance.new("BoolValue")
	hovered.Name = "Hovered"
	hovered.Value = false
	hovered.Parent = frame

	local clicked = Instance.new("BoolValue")
	clicked.Name = "Clicked"
	clicked.Value = false
	clicked.Parent = frame

    local locked = Instance.new("BoolValue")
    locked.Name = "Locked"
    locked.Value = isLocked
    locked.Parent = frame

	local uiScaleNumber = Instance.new("NumberValue")
	uiScaleNumber.Name = "UIScale"
	uiScaleNumber.Parent = frame
	uiScaleNumber.Value = 1

	local btn = frame:WaitForChild("TextButton") :: GuiButton
    local overlay = frame:WaitForChild("Overlay") :: Frame

	local uiScale = Instance.new("UIScale")
	uiScale.Name = "UIScale"
	uiScale.Parent = frame


	local on = Ripple.new({
        function()
            -- Bắt đầu tween lên 1.1
        end,
        TweenService:Create(uiScaleNumber, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Value = 1.1,
        }),
        -- Thêm tween quay về 1 (chỉ chạy nếu cần)
        -- TweenService:Create(uiScaleNumber, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
        --     Value = 1,
        -- })
    }, false)

	enabled.Changed:Connect(function()
		if enabled.Value then
			TweenService:Create(uiScaleNumber, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Value = 1,
			}):Play()
		else
			TweenService:Create(uiScaleNumber, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
				Value = 0,
			}):Play()
		end
	end)

	hovered.Changed:Connect(function()
		-- if hovered.Value then
		-- 	-- Sounds.Hovered:Play()

		-- 	TweenService:Create(uiScaleNumber, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		-- 		Value = 1.1,
		-- 	}):Play()
		-- else
		-- 	TweenService:Create(uiScaleNumber, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		-- 		Value = 1,
		-- 	}):Play()
		-- end
		if hovered.Value then
		on:Play()

		else
			print("stop")
			on:Stop()
		end
	end)

	clicked.Changed:Connect(function()
		if clicked.Value then
			-- Sounds.Clicked:Play()

			TweenService:Create(uiScaleNumber, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Value = 0.95,
			}):Play()
		else
			TweenService:Create(uiScaleNumber, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Value = hovered.Value and 1.1 or 1,
			}):Play()
		end
	end)
	uiScaleNumber.Changed:Connect(function()
		uiScale.Scale = uiScaleNumber.Value
		-- uiScale1.Scale = uiScaleNumber.Value
	end)

    local function SetLock(isLocked: boolean?)
        if locked.Value then
            overlay.Visible = false
        else
            overlay.Visible = true
        end
    end
	SetLock(isLocked)
    locked.Changed:Connect(function()
        SetLock(locked.Value)
    end)
	-- local button = frame:FindFirstChildWhichIsA("GuiButton", true)
	if frame then
		local cooldown: boolean = false
		btn.Activated:Connect(function()
			if cooldown then
				return
			end
			cooldown = true
			activated:Fire()
			task.wait(0.2)
			cooldown = false
		end)

		btn.MouseEnter:Connect(function()
			hovered.Value = true
		end)

		btn.MouseLeave:Connect(function()
			hovered.Value = false
			clicked.Value = false
		end)

		btn.MouseButton1Down:Connect(function()
			clicked.Value = true
		end)

		btn.MouseButton1Up:Connect(function()
			clicked.Value = false
		end)
	end

	return activated, enabled
end

return {
    Button = Button,
}