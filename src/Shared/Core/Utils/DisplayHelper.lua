--// Services
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

--// References
local DefaultSource = ReplicatedStorage.Shared.Assets.UI

--// Public Functions
local module = {}
module.PlayerGui = nil
module.Singletons = {}

function module:CloneSingleton(target: any, source_: Folder?, destination: any?, enabled: boolean?) --Useful for one-time ScreenGui creation
    if not module.PlayerGui then
        module.PlayerGui = Player:WaitForChild("PlayerGui")
    end

    local existing = module.Singletons[target]
    if existing then return existing end

    local source = source_ or DefaultSource
    local template = if typeof(target) == "string" then source:FindFirstChild(target) else target

    if not template then return end

    local gui = template:Clone()
    gui.Parent = destination or module.PlayerGui

    if gui:IsA("ScreenGui") then
        gui.Enabled = not not enabled
    elseif gui:IsA("GuiObject") then
        gui.Visible = not not enabled
    end

    module.Singletons[target] = gui
    return gui
end

return module