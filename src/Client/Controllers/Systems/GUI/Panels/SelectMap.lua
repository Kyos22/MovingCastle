local module = {}
module.constructors = {}
module.methods = {}
module.metatable = { __index = module.methods }

--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
--// Modules
local Shared = ReplicatedStorage.Shared
local SignalModule = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Signal"))
local ProfileTemplate = require(ReplicatedStorage.Controllers.Systems.PlayerProfile.ProfileTemplate)
local Button = require(ReplicatedStorage.Controllers.Components.Buttons)
-- local ClassInterface = require(ReplicatedStorage.Controllers.Interface.ClassInterface)
---->> Network
local Network = Shared.Network
local Client = require(Network.Client)
---->> Libraries
local Worlds_Lib = require(ReplicatedStorage.Shared.Libraries.Worlds)
local CONSTANTS = require(Shared.CONSTANT)
---->> Interfaces
local PlayerProfileInterface = require(ReplicatedStorage.Controllers.Interface.PlayerProfileInterface)
---->> Helper

--// Constants & Enums
local _TWEEN_EXP_ENABLE = TweenInfo.new(1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local _TWEEN_EXP_DISABLE = TweenInfo.new(0.25, Enum.EasingStyle.Exponential, Enum.EasingDirection.In)
--// Types & Enums
type Signal = typeof(SignalModule.new())


export type PrivateField = {
    enabled: BoolValue,
    worlds : NumberValue,
	
	tasks: { [string]: thread },
	connections: { [string]: RBXScriptConnection },
	
	Player: ProfileTemplate.Profile?,

}
--//Private Functions

--// Constructor
local function prototype(self: Type, ui: ScreenGui)
	---->> Public Properties
	self.UI         	= ui :: ScreenGui
	self.Frame      	= self.UI.Frame :: Frame
	self.MainFrame      = self.Frame.MainFrame :: Frame
	self.WorldLabel     = self.MainFrame.World :: TextLabel
	self.ScrollingFrame = self.MainFrame.ScrollingFrame :: ScrollingFrame
	self.TemplateCard   = self.ScrollingFrame.Template :: Frame
    
	---->> Private Properties
	self._private = {
		tasks = {},
		connections = {},
		Player = nil,
		
	} :: PrivateField

	return self
end

function module.methods.Initialize(self: Type)
	local _p = self._private

    _p.enabled = Instance.new("BoolValue")
    _p.enabled.Name = "Enabled"
    _p.enabled.Value = false
    _p.enabled.Parent = self.UI

    _p.worlds = Instance.new("NumberValue")
    _p.worlds.Name = "Worlds"
    _p.worlds.Parent = self.UI
    print("worlds",Players.LocalPlayer:GetAttribute(CONSTANTS.PLAYER_ATTRIBUTE_CLIENT._WORLD)
)
	_p.worlds.Value = Players.LocalPlayer:GetAttribute(CONSTANTS.PLAYER_ATTRIBUTE_CLIENT._WORLD)

    _p.enabled.Changed:Connect(function(newValue)
        self.UI.Enabled = newValue
    end)

    --hanlde click close button
    -- _p.connections["Close"] = 
    --     self.CloseBtn.Activated:Connect(function()
    --         _p.enabled.Value = false
    --     end)

	_p.Player = self:GetPlayer()
	self:Load(self._private.worlds.Value)
end

function module.methods.Load(self: Type, world: number)
	local _mapUnlocked = self.GetPlayer().Unlock.Worlds[world].MapsUnlock
	print("mapUnlocked",_mapUnlocked)
	self.WorldLabel.Text = tostring("World" .. world)

	local worldNum = Worlds_Lib[world]
	print('worldNum',worldNum)
	for k, map in pairs(worldNum.Maps) do
		print('map',map)
		local card = self.TemplateCard:Clone()

		-- if _mapUnlocked[k] then

		-- 	card.Name = map.Name
		-- 	card.Parent = self.ScrollingFrame
		-- 	card.Visible = true
		-- 	card:WaitForChild("Name").Text = map.Name
		-- 	card:WaitForChild("Overlay").Visible = false
		-- 	Button.Button(card, false)
		-- else
		-- 	card.Name = map.Name
		-- 	card.Parent = self.ScrollingFrame
		-- 	card.Visible = true
		-- 	card:WaitForChild("Name").Text = map.Name
		-- 	card:WaitForChild("Overlay").Visible = true
		-- 	Button.Button(card, true)

		-- end


			card.Name = map.Name
			card.Parent = self.ScrollingFrame
			card.Visible = true
			card.NameMap.Text = map.Name
			card.Overlay.Visible = false
			Button.Button(card, _mapUnlocked[k] and true or false):Connect(function()
				print("button")
				Client.Select_Map.Call(world, k)
			end)
		

		-- self:Button(card)

		--content :
	end
end

function module.methods.GetPlayer(self: Type) : ProfileTemplate.Profile
	return PlayerProfileInterface.RequestProfileDataAsync()
end



function module.methods.Open(self: Type, isAnimated: boolean?)
	local _p = self._private
	self._private.enabled.Value = true
	self._private.isActive = true
end

function module.methods.Close(self: Type, isAnimated: boolean?)
	local _p = self._private
	self._private.enabled.Value = false
	self._private.isActive = false

end

--// Private Functions
--// Destructor
module.constructors.metatable = module.metatable
module.constructors.methods = module.methods
module.constructors.private = {
}


function module.constructors.new(ui: ScreenGui)
	local self = setmetatable(prototype({}, ui), module.metatable)
	
	return self :: Type
end

function module.methods.Destroy(self: Type)
	local _p = self._private
	for _,task_ in pairs(_p.tasks) do
		if coroutine.status(task_) == "suspended" then
			task.cancel(task_)
		else
			task.defer(function()
				task.cancel(task_)
			end)
		end
	end
	for _, connection in pairs(_p.connections) do
		connection:Disconnect()
	end

    local temp = self :: {}
	for k in pairs(temp) do
        temp[k] = nil
	end
end


export type Type = typeof(prototype(...)) & typeof(module.methods)

return module.constructors