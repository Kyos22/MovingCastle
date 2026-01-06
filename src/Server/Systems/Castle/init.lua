--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Yumi = require(ReplicatedStorage.Shared.Core.Yumi)
local Server = require(ReplicatedStorage.Shared.Network.Server)

local car = workspace:WaitForChild("Car") :: Model
local root = car.PrimaryPart :: BasePart
assert(root, "Car.PrimaryPart is nil")

local SPEED = 50
local TURN_SPEED = 120

type CarState = {
	throttle: number,
	steer: number,
	driverUserId: number?, -- nil nếu không ai lái
	lastInputAt: number,
}

local state: CarState = {
	throttle = 0,
	steer = 0,
	driverUserId = nil,
	lastInputAt = 0,
}

export type APIsType = {
	StartDriving: (userId: number) -> (),
	StopDriving: () -> (),
    _Stop: () -> (),
}

local module = {} :: APIsType & Yumi.System
local hbConn: RBXScriptConnection? = nil
local inputConn: any = nil -- tùy Server.car_move.On trả về gì

local function clamp(v: number)
	if v < -1 then return -1 end
	if v > 1 then return 1 end
	return v
end

local function setDriver(userId: number?)
	state.driverUserId = userId
	state.throttle = 0
	state.steer = 0
	state.lastInputAt = os.clock()
end

function module.StartDriving(userId: number)
	setDriver(userId)
end

function module.StopDriving()
	setDriver(nil)
end

module._Setup = function()
	-- optional: bind seat events ở đây nếu bạn có DriveSeat
end

module._Start = function()
	-- chống leak: nếu Start lại thì disconnect cái cũ
	if hbConn and hbConn.Connected then
		hbConn:Disconnect()
	end

	-- Nếu Server.car_move.On trả về connection/disconnectable thì nhớ lưu để cleanup.
	-- (Nếu lib bạn không trả về, vẫn ok—ít nhất Heartbeat không leak.)
	inputConn = Server.car_move.On(function(player: Player, t: number, s: number)
		-- only accept input from current driver
        module.StartDriving(player.UserId)

		if state.driverUserId == nil then return end
		if player.UserId ~= state.driverUserId then return end

		state.throttle = clamp(t)
		state.steer = clamp(s)
		state.lastInputAt = os.clock()
	end)

	hbConn = RunService.Heartbeat:Connect(function(dt: number)
		-- Không có driver thì không chạy
		if state.driverUserId == nil then return end

		-- Fail-safe: nếu mất input quá lâu thì dừng (anti-stuck/anti-exploit)
		if os.clock() - state.lastInputAt > 1.0 then
			state.throttle = 0
			state.steer = 0
            module.StopDriving()
		end

		-- rotate then move (CFrame-based)
		root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(TURN_SPEED) * state.steer * dt, 0)
		root.CFrame = root.CFrame + (root.CFrame.LookVector * (SPEED * state.throttle * dt))
	end)
end

-- Optional cleanup hook nếu framework Yumi có _Stop
module._Stop = function()
	if hbConn and hbConn.Connected then
		hbConn:Disconnect()
	end
	hbConn = nil

	-- Nếu inputConn có Disconnect:
	if typeof(inputConn) == "RBXScriptConnection" and inputConn.Connected then
		inputConn:Disconnect()
	end
	inputConn = nil

	setDriver(nil)
end

return module
