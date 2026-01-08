--!strict

-->> Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--> Modules
local Yumi = require(ReplicatedStorage.Shared.Core.Yumi)
local Server = require(ReplicatedStorage.Shared.Network.Server)
local Castle = require(script.Castle)
-->> Ref
local ASSETS = ReplicatedStorage.Shared.Assets
-- local car = workspace:WaitForChild("Car") :: Model
-- local root = car.PrimaryPart :: BasePart
export type APIsType = {
	-- StartDriving: (userId: number) -> (),
	-- StopDriving: () -> (),
    -- _Stop: () -> (),

	StartDrive: (player: Player) -> (),
}

local module = {} :: APIsType & Yumi.System

module._Setup = function()
	-- optional: bind seat events ở đây nếu bạn có DriveSeat
end

module._Start = function()


	Server.Start_Drive.SetCallback(function(player:Player)
		module.StartDrive(player)

	end)

	
end

module.StartDrive = function(player: Player)
	-- Player:Player,
    -- Humanoid: Humanoid,
    -- Model: Model,

	local castleClone = ASSETS.Castle.Car:clone()
	castleClone.Parent = workspace
	castleClone.Name = "Car"
	if not player then return end
	local character = player.Character or player.CharacterAdded:Wait()
	if not character then return end

	local hum = character:FindFirstChild("Humanoid")

	local cfig = {
		Player = player,
		Humanoid = hum,
		Model = castleClone,
	} :: Castle.Config

	local castle = Castle.new(cfig)
	castle:Drive()
end

return module
