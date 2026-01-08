--// Services
local ServerScriptService = game:GetService("ServerScriptService")

--// Modules
local CastleSystem = require(ServerScriptService.Systems.Castle)

--// Interface
local interface: CastleSystem.APIsType = {} :: any

interface.StartDrive = function(...)
	return CastleSystem.StartDrive(...)
end
	
return interface
