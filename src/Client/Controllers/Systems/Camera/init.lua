--!strict
--// Service
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules
local Yumi = require(ReplicatedStorage.Shared.Core.Yumi)

--
export type APIsType = {}

local module = {} :: APIsType & Yumi.System

module._Setup = function()

end

module._Start = function()
    
end

-- module.StartFly = function()

-- end
--// Yumi

--// APIs

return module
