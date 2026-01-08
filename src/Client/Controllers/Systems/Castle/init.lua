--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")

local Client = require(ReplicatedStorage.Shared.Network.Client)

local throttle, steer = 0, 0

export type APIsType = {
	Connections: {RBXScriptConnection},
	IsDriving: boolean,

	_Start: () -> (),
	StartDrive: () -> (),
	StopDrive: () -> (),
	SetDriveEnabled: (enabled: boolean) -> (),
}

local module = {} :: APIsType
module.Connections = {}
module.IsDriving = false

local function send()
	-- Optional: chỉ gửi khi đang drive
	if not module.IsDriving then return end
	Client.car_move.Fire(throttle, steer)
end

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed or not module.IsDriving then return end

	local kc = input.KeyCode
	if kc == Enum.KeyCode.W then throttle = 1
	elseif kc == Enum.KeyCode.S then throttle = -1
	elseif kc == Enum.KeyCode.A then steer = -1
	elseif kc == Enum.KeyCode.D then steer = 1
	else
		return
	end

	send()
end

local function onInputEnded(input: InputObject, gameProcessed: boolean)
	if gameProcessed or not module.IsDriving then return end

	local kc = input.KeyCode
	if kc == Enum.KeyCode.W or kc == Enum.KeyCode.S then
		throttle = 0
	elseif kc == Enum.KeyCode.A or kc == Enum.KeyCode.D then
		steer = 0
	else
		return
	end

	send()
end

local function disconnectAll()
	for _, c in ipairs(module.Connections) do
		if c.Connected then
			c:Disconnect()
		end
	end
	table.clear(module.Connections)
end

function module._Start()
	-- connect đúng 1 lần trong vòng đời module
	disconnectAll()

	table.insert(module.Connections, UIS.InputBegan:Connect(onInputBegan))
	table.insert(module.Connections, UIS.InputEnded:Connect(onInputEnded))

	-- table.insert(module.Connections, UIS.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	-- 	if input.KeyCode == Enum.KeyCode.W then
	-- 		print("press F")
	-- 		Client.Start_Drive.Fire()
	-- 		module.SetDriveEnabled(true)
	-- 	end
	-- end))

	Client.Castle_Setup_Client.SetCallback(function(player: Player) 
		module.SetDriveEnabled(true)
	end)
end

function module.StartDrive()
	module.IsDriving = true
	-- reset tránh kẹt phím
	throttle, steer = 0, 0
	send()
end

function module.StopDrive()
	module.IsDriving = false
	throttle, steer = 0, 0
	send()
end

function module.SetDriveEnabled(enabled: boolean)
	if enabled then
		module.StartDrive()
	else
		module.StopDrive()
	end
end

return module
