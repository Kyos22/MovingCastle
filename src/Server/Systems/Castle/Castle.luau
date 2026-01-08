--!strict

local module = {}
module.constructors = {}
module.methods = {}
module.metatable = { __index = module.methods}

-->> Services 
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Server = require(ReplicatedStorage.Shared.Network.Server)


local SPEED = 50
local TURN_SPEED = 120

type CastleConfig = {
    Speed : number,
    TurnSpeed : number,
    Player: Player,
}

type field = {
    tasks: {[string]: thread},
    connections : {[string]: RBXScriptConnection}
}

type MovingCastleState = {
	throttle: number,
	steer: number,
	driverUserId: number?, -- nil nếu không ai lái
	lastInputAt: number,
}

export type Config = {
    Player:Player,
    Humanoid: Humanoid,
    Model: Model,
}

local state: MovingCastleState = {
	throttle = 0,
	steer = 0,
	driverUserId = nil,
	lastInputAt = 0,
}

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

-- Private funtions
function module.methods.StartDriving(self:Type, userId: number)
    setDriver(userId)
end

function module.methods.StopDriving(self:Type)
    setDriver(nil)
end

function module.methods.Drive(self:Type)
    local _p = self._private

    Server.Castle_Setup_Client.Fire(self.Player)


    Server.car_move.On(function(player: Player, t: number, s: number)
        module.methods.StartDriving(self, player.UserId)

        if state.driverUserId == nil then return end
        if player.UserId ~= state.driverUserId then return end
        
        state.throttle = clamp(t)
        state.steer = clamp(s)
        state.lastInputAt = os.clock()
    end)

    _p.connections["HB"] = RunService.Heartbeat:Connect(function(dt: number)
        if state.driverUserId == nil then return end
        
        local root = self.Root :: BasePart
        root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(TURN_SPEED) * state.steer * dt, 0)
        root.CFrame = root.CFrame + (root.CFrame.LookVector * (SPEED * state.throttle * dt))
    end)

end

function module.constructors.new(config: Config)
    local self = setmetatable({}, module.metatable)

    local _private:field = {
        tasks = {},
        connections = {}
    }
    self.Model = config.Model
    self.Root = self.Model.PrimaryPart
    self.Player = config.Player

    self._private = _private

    return self
end

function module.methods.Destroy(self:Type)
    local _p = self._private
    for _, task_ in pairs(_p.tasks) do
        if coroutine.status(task_) == "suspended" then
            task.cancel(task_)
        else
            task.defer(function()
                task.cancel(task_)
            end)
        end
    end
    for _, conn in pairs(_p.connections) do
        conn:Disconnect()
    end
    -- table.clear(self)
end



export type Type = typeof(module.constructors.new(table.unpack(...)))

return module.constructors
