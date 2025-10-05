--!strict
--service
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
--refs
--modules
local Yumi = require(ReplicatedStorage.Shared.Core.Yumi)
----interface

local PlayerProfileInterface = require(ServerScriptService.Interfaces.PlayerProfile)
----test modules
--variables
local developerCommands = {
	-- StateDown = "StateDown",
	
}
local developerCommandAlias = {
	-- [developerCommands.StateDown] = {
	-- 	PrimaryAlias = "/stateDown",
	-- 	SecondaryAlias = ""
	-- },
	
}
local devCommandFolder:Folder = nil
local connections = {}
--custom type
type DeveloperCommandAlias = {
	PrimaryAlias: string,
	SecondaryAlias: string
}
--
export type APIsType = {}

local module = {} :: APIsType & Yumi.System

--private functions
local function IsDeveloperCommandAlias(word:string,key: string)
	local alias:DeveloperCommandAlias = developerCommandAlias[key]
	if not key then
		return false
	end
	return word == alias.PrimaryAlias or word == alias.SecondaryAlias
end
local function IsAValidTester(player: Player)
	return true
	-- if RunService:IsStudio() then
	-- 	return true
	-- end
	-- local allowedIds = {
	-- 	3970973864, --sorik
	-- 	2323177417, --sector
	-- }
	-- for _,id in ipairs(allowedIds) do
	-- 	if player.UserId == id then
	-- 		return true
	-- 	end
	-- end
	-- return false
end
local function OnDeveloperCommandTrigger(textSource: TextSource, text: string)
	local player = Players:GetPlayerByUserId(textSource.UserId)
	if not player or not IsAValidTester(player) then
		return
	end
	local words = string.split(text, " ")
	local commandWord = words[1]
	-- if IsDeveloperCommandAlias(commandWord,developerCommands.StateDown) then
	-- 	local class = ClassInterface.GetClass(player)
    --     if not class then
    --         return
    --     end
    --     class:SwitchState("Downed")
	-- elseif IsDeveloperCommandAlias(commandWord,developerCommands.StateCombat) then
	-- 	local class = ClassInterface.GetClass(player)
    --     if not class then
    --         return
    --     end
    --     class:SwitchState("Combat")
	-- elseif IsDeveloperCommandAlias(commandWord,developerCommands.Revive) then
	-- 	local class = ClassInterface.GetClass(player)
    --     if not class then
    --         return
    --     end
	-- 	class:Revived(class,true)
	-- elseif IsDeveloperCommandAlias(commandWord,developerCommands.Kill) then
	-- 	local class = ClassInterface.GetClass(player)
    --     if not class then
    --         return
    --     end
	-- 	class:SwitchState("Killed")
	-- elseif IsDeveloperCommandAlias(commandWord,developerCommands.Heal) then
	-- 	local class = ClassInterface.GetClass(player)
    --     if not class then
    --         return
    --     end
	-- 	class:Heal(nil,100,true)
	-- elseif IsDeveloperCommandAlias(commandWord,developerCommands.FillUltimate) then
	-- 	local class = ClassInterface.GetClass(player)
    --     if not class then
    --         return
    --     end
	-- 	class:AddUltimateCharge(100)
	-- elseif IsDeveloperCommandAlias(commandWord,developerCommands.TakeDamage) then
	-- 	local class = ClassInterface.GetClass(player)
    --     if not class then
    --         return
    --     end
	-- 	class:TakeDamage(nil,if words[2] then tonumber(words[2]) else 0)
	-- elseif IsDeveloperCommandAlias(commandWord,developerCommands.EndMatch) then
	-- 	RoundInterface.EndMatch()
	-- elseif IsDeveloperCommandAlias(commandWord,developerCommands.SkipMatch) then
	-- 	RoundInterface.Skip()
	-- elseif IsDeveloperCommandAlias(commandWord,developerCommands.SpawnDummy) then
	-- 	local char = player.Character
	-- 	if not char or not char.PrimaryPart then
	-- 		return
	-- 	end
	-- 	local isEnemy = if words[2] and words[2] == "false" then false else true
	-- 	local spawnCFrame = char.PrimaryPart.CFrame:ToWorldSpace(
	-- 		CFrame.new(Vector3.new(0,0,-10))*CFrame.fromEulerAnglesYXZ(0, math.pi, 0))
	-- 	TraningDummy.new(player, spawnCFrame, isEnemy)
	-- elseif IsDeveloperCommandAlias(commandWord,developerCommands.AddRank) then
	-- 	RankInterface.Add(player,tonumber(words[2]))
	-- end
	
end
local function DeveloperCommandInitialize()
	devCommandFolder = Instance.new("Folder")
	devCommandFolder.Name = "DeveloperCommands"
	devCommandFolder.Parent = TextChatService
	for key,value: DeveloperCommandAlias in pairs(developerCommandAlias) do
		local textCommand = Instance.new("TextChatCommand")
		textCommand.PrimaryAlias = value.PrimaryAlias
		textCommand.SecondaryAlias = value.SecondaryAlias
		textCommand.Name = key
		connections["TextCommand_"..key] = 
			textCommand.Triggered:Connect(OnDeveloperCommandTrigger)
		textCommand.Parent = devCommandFolder
	end
end
--yumi
module._Setup = function()
    DeveloperCommandInitialize()
	
	
end
--apis

return module



