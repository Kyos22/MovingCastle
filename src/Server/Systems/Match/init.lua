--!strict
--service
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService   = game:GetService("CollectionService")
local Players             = game:GetService("Players")
local TweenService        = game:GetService("TweenService")
--refs
local WORLDS = game.Workspace:WaitForChild("Worlds")
--Matchs
local ZonePlus = require(ReplicatedStorage.Packages.ZonePlus)
local Yumi = require(ReplicatedStorage.Shared.Core.Yumi)
local Server = require(ReplicatedStorage.Shared.Network.Server)
--observers
local PlayerObserver = require(ServerScriptService.Observers.PlayerProfileObserver)
-- interfaces
local PlayerInterface = require(ServerScriptService.Interfaces.PlayerProfile)
-- templates
local ProfileTemplate = require(ServerScriptService.Systems.PlayerProfile.ProfileTemplate)

export type APIsType = {
    waitingMatch: {
        -- [string] : {
        --     [Player] : boolean
        -- }
        [string] : {
            Players: {
                [Player] : boolean
            },
            SelectMap: number 
        }
    },
    tasks : {[string]: thread},

    -- functions
    InitZone: (self: APIsType) -> (),
    Zones: {[Instance]: typeof(ZonePlus.new())},
}

-- Players.CharacterAutoLoads = false

local Match = {} :: APIsType & Yumi.System
local connections = {} :: {}


-- apis
Match._Setup = function()
    Match.waitingMatch = {}
    Match.tasks = {}
    Match.Zones = {}
end

Match._Start = function()

    Match:InitZone()


    connections["Player_CheckWorld"] = 
       PlayerObserver.ListenEvent(PlayerObserver.Event.Loaded, function(event: PlayerObserver.LoadedEventArgs)
            if not connections[event.Player] then connections[event.Player] = {} end
            
            local data = event.Data :: ProfileTemplate.Profile
            local player = event.Player :: Player
            if not data then warn("data is nil")
                return
            end
            print("data",data)
            local world = data.CurrentWorld :: number 
            if world and typeof(world) == "number" and world > 0 then
                local worldFolder = WORLDS:FindFirstChild(world)  :: Folder
                local lobby = worldFolder:FindFirstChild("Lobby") :: Folder
                local SpawnLocation = lobby:FindFirstChild("SpawnLocation") :: SpawnLocation
                SpawnLocation.Enabled = true
                print("SpawnLocation",SpawnLocation)

                local character = player.Character or player.CharacterAdded:Wait()
                if not character then
                    return
                end
                character:PivotTo(SpawnLocation.CFrame + Vector3.new(0,5,0))
                
            end

            Match:CheckZone(event.Player)

        end)
    
    connections["Player_Removing"] = Players.PlayerRemoving:Connect(function(player:Player)
        Match:Destroy(player)
    end)

    connections["API_Select_Map"] =
        Server.Select_Map.SetCallback(function(player:Player, world: number, map: number)
            return Match:SelectMap(player,world,map)
        end)

    --init all zone
    -- Match:CheckZone()
    Match:CreateRoom()

end

Match.InitZone = function(self:APIsType)
    local FireZones = CollectionService:GetTagged("FIRE_ZONE")

    self.tasks["InitZone"] = task.spawn(function()
            for _,zone in pairs(FireZones) do
                local zonePlus = ZonePlus.new(zone)
                self.Zones[zone] = zonePlus
            end   
    end)
end

local function GetRoom(zoneInstance,zone) : string
        local zoneIns = zoneInstance.Parent :: Instance
        local zoneNumber = zoneIns.Parent :: Model
        local matchZone = zoneNumber.Parent :: Folder
        local lobby = matchZone.Parent :: Folder
        local world = lobby.Parent :: Folder

        local tierZone = zoneNumber.Name
        local stringCombine = tostring("World".. world.Name .. "_" .. tierZone)
        print("stringCombine",stringCombine)
        return stringCombine
end

Match.Teleport = function(self:APIsType, roomName: string)
    if self.waitingMatch[roomName] and #self.waitingMatch[roomName].Players == 2 then
        -- zap handle
        -- Server.
        task.wait(5)
    end
end


Match.CheckZone = function(self:APIsType,player:Player)
    local zones = self.Zones
    task.spawn(function()
        for zoneInstance,zone in pairs(zones) do
            -- local conn = 
            --     zone.playerEntered:Connect(function(player:Player)
            --         print("touch", player)
            --     end)
            -- table.insert(connections[player],conn)
            local room = GetRoom(zoneInstance,zone) :: string
            local waitingRoom = self.waitingMatch[room]

            connections[player]["TouchZone"] = 
                zone.playerEntered:Connect(function(player:Player)                    
                    if waitingRoom then
                        if not next(waitingRoom.Players) then -- check if room not exist player
                           waitingRoom.Players[player] = true
                            Server.Open_Select_Map.Fire(player,true)
                        elseif #waitingRoom.Players < 2 then -- check if already 1 playerr in room
                            waitingRoom[player] = true

                            -- local zoneParent = zoneInstance.Parent :: Instance 
                            -- local Box = zoneParent:FindFirstChild("Box") :: Model
                            -- local PrimaryBox = Box.PrimaryPart :: Part
                            -- TweenService:Create(PrimaryBox,TweenInfo.new(1,Enum.EasingStyle.Linear),{Position = Vector3.new(PrimaryBox.Position.X,16.2,PrimaryBox.Position.Z)}):Play()
                        elseif waitingRoom.Players and #waitingRoom.Players == 2 then -- check if 2 player in room
                            task.wait(5)
                        end
                    end
                end)
            connections[player]["LeaveZone"] = 
                zone.playerExited:Connect(function(player:Player)
                    -- print("leave", player)
                    -- local room = GetRoom(zoneInstance,zone) :: string
                    if waitingRoom then
                        if waitingRoom.Players[player] then
                            waitingRoom.Players[player] = nil
                        else
                            warn("full not found")
                        end
                    end
                    Server.Open_Select_Map.Fire(player,false)

                    -- print("room 1",waitingRoom[room])
                end)
        end
    end)
end

-- Match.WaitingRoom = function(self:APIsType,player:Player)
--     if self.waitingMatch[]
-- end

Match.CreateRoom = function(self:APIsType)
    print("room",self.waitingMatch)
    task.spawn(function()
        for _,k in pairs(WORLDS:GetChildren()) do
            print("world",k)
            print("world",k.Name)
            local lobby = k:FindFirstChild("Lobby") :: Folder
            print("lobby",lobby)
            local matchZones = lobby:FindFirstChild("MatchZone") :: Folder
            for _,zone in pairs(matchZones:GetChildren()) do
                self.waitingMatch["World".. k.Name .. "_" .. zone.Name ] = {
                    Players = {},
                    SelectMap = 0
                }
                print("zone",zone)
                print("zone",zone.Name)
            end
        end
    end)

    print("room",self.waitingMatch)
end

Match.Destroy = function(self:APIsType,player:Player)
    if connections[player] then
        for _, conn in ipairs(connections[player]) do
            if conn then
                conn:Disconnect()
            end
        end
        connections[player] = nil
    end
    print("conn 1",connections)
end 

--yumi

--apis

Match.SelectMap = function(self:APIsType,player:Player, world: number, map: number): boolean
    if typeof(world) == "number" and typeof(map) == "number" and world > 0 and map > 0 then
        for roomName,roomData in pairs(Match.waitingMatch) do
            -- print("room haha",roomData)
            if roomData.Players[player] then
                self.waitingMatch[tostring(roomName)].SelectMap = map
            end
        end
        print("result",Match.waitingMatch)
        return true
    else
        return false
    end
end

return Match


-- check vào zone, kiểm tra zone còn lại có người nào join hay không 
-- nếu có 2 người vào thì bắt đầu đếm ngược để teleport 2 thằng này vào một map
-- làm luôn cơ chế mời người chơi ( hiển thị gui )