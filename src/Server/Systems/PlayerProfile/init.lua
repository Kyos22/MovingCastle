--!strict
--services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
--modules
local PlayerProfileObserver = require(ServerScriptService.Observers.PlayerProfileObserver)
local Yumi = require(ReplicatedStorage.Shared.Core.Yumi)
local ProfileStore = require(ServerScriptService.Packages.ProfileStore)
local VersionResolver = require(script.VersionResolver)
local ProfileTemplate = require(script.ProfileTemplate)
-- local ProfileTemplate = require(ReplicatedStorage.Shared.ProfileTemplate)

----network
local Server = require(ReplicatedStorage.Shared.Network.Server)
--constants
local DATASTORE_VERSION = 1
local SAVED = true
--variables
local playerStore = ProfileStore.New("PlayerStore" .. tostring(DATASTORE_VERSION), ProfileTemplate.Template)
local profileCache: { [Player]: typeof(playerStore:StartSessionAsync(table.unpack(...))) } = {}
local tasks = {}

local module = {} :: APIsType & Yumi.System
--private function
local function UpdateClientProfile(player: Player)
	local UPDATE_TASK_NAME = "UpdateClientProfile_DeferTask" .. tostring(player.UserId)
	--only update client profile one time at the end of frame to prevent multiple remote events fired
	if tasks[UPDATE_TASK_NAME] then
		return
	end
	tasks[UPDATE_TASK_NAME] = task.defer(function()
		local success, message = pcall(function()
			local profile = profileCache[player]
			if profile then
				Server.Player_Update_Profile.Fire(player, profile.Data)
			end
		end)
		tasks[UPDATE_TASK_NAME] = nil
		if not success then
			task.spawn(function()
				error(message)
			end)
		end
	end)
end

local function OnPlayerAdded(player: Player)
	-- Start a profile session for this player's data:
	local profile = playerStore:StartSessionAsync(`{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	-- Handling new profile session or failure to start it:

	if profile ~= nil then
		profile:AddUserId(player.UserId) -- GDPR compliance
		--profile:Reconcile() -- Fill in missing variables from PROFILE_TEMPLATE (optional)

		profile.OnSessionEnd:Connect(function()
			profileCache[player] = nil
			player:Kick(`Profile session end - Please rejoin`)
		end)
		if player.Parent == Players then
			VersionResolver.Resolve(profile.Data, ProfileTemplate.CurrentVersion) --resolve version conflict
			profileCache[player] = profile
			PlayerProfileObserver.CallEvent(
				PlayerProfileObserver.Event.Loaded,
				{
					Player = player,
					Data = module.GetEditablePlayerProfile(player) :: ProfileTemplate.Profile,
				} :: PlayerProfileObserver.LoadedEventArgs
			)
			print('profile',profile.Data)
			UpdateClientProfile(player)
		else
			-- The player has left before the profile session started
			profile:EndSession()
		end
	else
		-- This condition should only happen when the Roblox server is shutting down
		player:Kick(`Profile load fail - Please rejoin`)
	end
end
local function OnPlayerRemoving(player: Player)
	local profile = profileCache[player]
	if profile ~= nil then
		profile:EndSession()
	end
end
local function TableDeepCopy(t: { [any]: any })
	local copy = {}
	for k, v in pairs(t) do
		if type(v) == "table" then
			v = TableDeepCopy(v)
		end
		copy[k] = v
	end
	return copy
end
local function TableDeepFreeze(tbl: { [any]: any })
	if not table.isfrozen(tbl) then
		table.freeze(tbl)
	end
	for _, v in pairs(tbl) do
		if type(v) == "table" and not table.isfrozen(v) then
			TableDeepFreeze(v)
		end
	end
end

--
export type APIsType = {
	--apis
	GetPlayerProfile: (player: Player) -> ProfileTemplate.Profile?,
	GetEditablePlayerProfile: (player: Player) -> ProfileTemplate.Profile?,
	GetPlayerProfileAsync: (player: Player, timeout: number?) -> ProfileTemplate.Profile?,
	GetEditablePlayerProfileAsync: (player: Player, timeout: number?) -> ProfileTemplate.Profile?,
	UpdateClientProfile: (player: Player) -> (),
}

--yumi
module._Start = function()
	Players.PlayerAdded:Connect(function(player: Player)
		OnPlayerAdded(player)
		if not SAVED then
			module.ResetData(player)
		end
	end)
	for _, player in Players:GetPlayers() do
		OnPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		OnPlayerRemoving(player)
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			OnPlayerRemoving(player)
		end
	end)
	Server.Get_Player_Data.SetCallback(function(player: Player)
		local data = module.GetPlayerProfileAsync(player)
		return data
	end)
end

module.ResetData = function(player: Player)
	local profile = profileCache[player]
	if not profile then
		return
	end

	profile.Data = TableDeepCopy(ProfileTemplate.Template)
	VersionResolver.Resolve(profile.Data, ProfileTemplate.CurrentVersion) --resolve version conflict
	UpdateClientProfile(player)
	PlayerProfileObserver.CallEvent(
		PlayerProfileObserver.Event.Loaded,
		{
			Player = player,
			Data = module.GetEditablePlayerProfile(player),
		} :: PlayerProfileObserver.LoadedEventArgs
	)
end

--apis
module.GetPlayerProfile = function(player: Player): ProfileTemplate.Profile?
	local data = module.GetEditablePlayerProfile(player)
	if not data then
		return nil
	end
	local copy = TableDeepCopy(data) :: ProfileTemplate.Profile
	TableDeepFreeze(copy)
	return copy
end
module.GetEditablePlayerProfile = function(player: Player): ProfileTemplate.Profile?
	local profile = profileCache[player]
	if not profile then
		return nil
	end
	return (profile :: any).Data :: ProfileTemplate.Profile
end
module.GetPlayerProfileAsync = function(player: Player, timeout: number?): ProfileTemplate.Profile?
	local data = module.GetEditablePlayerProfileAsync(player, timeout)
	if not data then
		return nil
	end
	local copy = TableDeepCopy(data) :: ProfileTemplate.Profile
	TableDeepFreeze(copy)
	return copy
end
module.GetEditablePlayerProfileAsync = function(player: Player, timeout: number?): ProfileTemplate.Profile?
	local profile = profileCache[player]

	local warningCounter = 0
	local counter = 0
	local traceback = debug.traceback()
	timeout = timeout or 30
	while not profile or not profile.Data do
		local delta = task.wait()
		warningCounter += delta
		counter += delta
		if warningCounter > 5 then
			warn(`Infinite yield possible when getting player profile {player.Name} at \n {traceback}`)
			warningCounter = 0
		end
		if timeout and counter > timeout then
			return nil
		end
		profile = profileCache[player]
	end
	return (profile :: any).Data :: ProfileTemplate.Profile
end
module.UpdateClientProfile = function(player: Player)
	UpdateClientProfile(player)
end

return module
