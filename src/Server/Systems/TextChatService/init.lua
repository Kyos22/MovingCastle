--!strict
--// Service
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
--// Modules
local Interfaces = ServerScriptService.Interfaces
local DataModifiers = ServerScriptService.Systems.Profile.DataModifier
local Template = require("./Profile/Template")
local Yumi = require(ReplicatedStorage.Shared.Core.Yumi)
local Server = require(ReplicatedStorage.Shared.Network.Server)
---->> Interfaces
local ProfileInterface = require(Interfaces.Profile)
local CastleInterface = require(Interfaces.Castle)

---->> Data Modifier
-- local BalanceData = require(DataModifiers.Balance)

---->> Libraries
--// Constants & Enums
local GroupDataList = {
	{
		GroupId = 35478076, -- kyos
		DevRank = 253,
	},
}
--// Variables
local DeveloperCommands = {
	ResetData = "ResetData",
	RunCastle = "RunCastle",
}
local DeveloperCommandAlias = {
	[DeveloperCommands.ResetData] = {
		PrimaryAlias = "/resetData",
		SecondaryAlias = "",
	},
	[DeveloperCommands.RunCastle] = {
		PrimaryAlias = "/runCastle",
		SecondaryAlias = "",
	},
	
}
local DevCommandFolder: Folder = nil
local Connections = {}
--// Type
type DeveloperCommandAlias = {
	PrimaryAlias: string,
	SecondaryAlias: string,
}
--
export type APIsType = {}

local module = {} :: APIsType & Yumi.System

--// Private Functions
local function IsDeveloperCommandAlias(word: string, key: string)
	local alias: DeveloperCommandAlias = DeveloperCommandAlias[key]
	if not key then
		return false
	end
	return word == alias.PrimaryAlias or word == alias.SecondaryAlias
end
local function IsAValidTester(player: Player)
	if RunService:IsStudio() then
		return true
	end
	for _, data in ipairs(GroupDataList) do
		if not player:IsInGroup(data.GroupId) then
			continue
		end
		local rank = player:GetRankInGroup(data.GroupId)
		if rank >= data.DevRank then
			return true
		end
	end
	return false
end
local function OnDeveloperCommandTrigger(textSource: TextSource, text: string)
	local player = Players:GetPlayerByUserId(textSource.UserId)
	if not player or not IsAValidTester(player) then
		return
	end
	local words = string.split(text, " ")
	local commandWord = words[1]
	if IsDeveloperCommandAlias(commandWord, DeveloperCommands.ResetData) then
		ProfileInterface.Reset(player)
	elseif IsDeveloperCommandAlias(commandWord, DeveloperCommands.RunCastle) then
		-- ProfileInterface.Reset(player)
		CastleInterface.StartDrive(player)
	end
end
local function DeveloperCommandInitialize()
	DevCommandFolder = Instance.new("Folder")
	DevCommandFolder.Name = "DeveloperCommands"
	DevCommandFolder.Parent = TextChatService
	for key, value: DeveloperCommandAlias in pairs(DeveloperCommandAlias) do
		local textCommand = Instance.new("TextChatCommand")
		textCommand.PrimaryAlias = value.PrimaryAlias
		textCommand.SecondaryAlias = value.SecondaryAlias
		textCommand.Name = key
		Connections["TextCommand_" .. key] = textCommand.Triggered:Connect(OnDeveloperCommandTrigger)
		textCommand.Parent = DevCommandFolder
	end
end
--// Yumi
module._Setup = function()
	DeveloperCommandInitialize()
end
--// Apis

return module
