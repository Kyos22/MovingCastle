--!strict
--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
--// Modules

local Signal = require(ReplicatedStorage.Packages.Signal)
local Promise = require(ReplicatedStorage.Packages.Promise)
local Features = require(script:WaitForChild("Features"))
--// constants
local SERVER = RunService:IsServer()
--// Types
type Signal = typeof(Signal.new())
type Connection = typeof(Signal.new():Connect(table.unpack(...)))
type Promise = typeof(Promise.new(table.unpack(...)))

export type System = {
	_Name: string?,
	_Setup: (System, Yumi) -> (),
	_Start: (System, Yumi) -> (),
	_Priority: number?,
}

export type Observer = {
	_Name: string?,
	_Setup: (Observer, Yumi) -> (),
	_Priority: number?,

	Event: { [string]: string },
	Subscribe: (event: string, callback: (...any) -> ()) -> Connection?,
	Fire: (event: string, args: { [any]: any }, isDefered: boolean?) -> (),
}

--constants
local DEFAULT_PRIORITY = 10
--this module
export type Yumi = {
	_Observers: { [string]: Observer },
	_Systems: { [string]: System },

	isLoaded: boolean,
	Loaded: Signal,

	Add: (self: Yumi, storageType: "Systems" | "Observers", storage: Folder | Model, deep: boolean?) -> (),

	Start: (self: Yumi) -> Promise,
	OnStart: () -> (),
}

local Yumi = {} :: Yumi
Yumi._Systems = {}
Yumi._Observers = {}
Yumi.Loaded = Signal.new()
Yumi.isLoaded = false

local _Started: boolean = false
local _Completed: boolean = false
local _OnComplete: BindableEvent = Instance.new("BindableEvent")
local _ShouldPrintLog: boolean = Features.Yumi["PrintLog"]

function Yumi:Add(storageType: "Systems" | "Observers", storage: Folder | Model, deep: boolean?)
	if _Started then
		error("Cannot add" .. storageType .. "after Yumi has started", 2)
	end

	local array: { Instance } = deep and storage:GetDescendants() or storage:GetChildren()
	for _, object: Instance in array do
		if not object:IsA("ModuleScript") then
			continue
		end

		if storageType == "Systems" then
			local group = SERVER and Features.Systems.Server or Features.Systems.Client
			local featureGroup = group[object.Name]
			local valid = false
			if not featureGroup then
				warn("Cannot add system, feature is not defined:", object.Name)
			elseif featureGroup.Enabled == false then
				warn("Cannot add system, feature is disabled:", object.Name)
			elseif self._Systems[object.Name] then
				warn("Cannot add system, feature already exist:", object.Name)
			else
				valid = true
			end

			if not valid then
				continue
			end

			do
				local requireTime = os.clock()
				local stopClock = false

				local requireThread = task.spawn(function()
					local system = require(object) :: System
					if not system._Name then
						system._Name = object.Name
					end
					system._Priority = featureGroup.Priority or DEFAULT_PRIORITY
					self._Systems[object.Name] = system

					stopClock = true
				end)

				while not stopClock do
					local current = os.clock()
					if current - requireTime > 30 then
						warn("System", object.Name, "is taking too long to load, aborting...")
						break
					end
					task.wait()
				end

				task.defer(function()
					task.cancel(requireThread)
				end)
			end
		elseif storageType == "Observers" then
			local group = SERVER and Features.Observers.Server or Features.Observers.Client
			local featureGroup = group[object.Name]
			local valid = false
			if not featureGroup then
				warn("Cannot add observer, feature is not defined:", object.Name)
			elseif featureGroup.Enabled == false then
				warn("Cannot add observer, feature is disabled:", object.Name)
			elseif self._Observers[object.Name] then
				warn("Cannot add observer, feature already exist:", object.Name)
			else
				valid = true
			end

			if not valid then
				continue
			end

			do
				local requireTime = os.clock()
				local stopClock = false

				local requireThread = task.spawn(function()
					local observer = require(object) :: Observer
					if not observer._Name then
						observer._Name = object.Name
					end
					observer._Priority = featureGroup.Priority or DEFAULT_PRIORITY
					self._Observers[object.Name] = observer

					stopClock = true
				end)

				while not stopClock do
					local current = os.clock()
					if current - requireTime > 30 then
						warn("Observer", object.Name, "is taking too long to load, aborting...")
						break
					end
					task.wait()
				end

				task.defer(function()
					task.cancel(requireThread)
				end)
			end
		end
	end
end

function Yumi:Start(): Promise
	if _Started then
		return Promise.Reject("Yumi already started")
	end
	_Started = true

	local observerList: { { Name: string, Observer: Observer, Priority: number } } = {}
	local systemList: { { Name: string, System: System, Priority: number } } = {}

	do --sort
		--observers
		for name, observer: Observer in pairs(self._Observers) do
			table.insert(observerList, {
				Name = name,
				Observer = observer,
				Priority = observer._Priority :: number,
			})
		end
		table.sort(observerList, function(a, b)
			return a.Priority < b.Priority
		end)

		--systems
		for name, system: System in pairs(self._Systems) do
			table.insert(systemList, {
				Name = name,
				System = system,
				Priority = system._Priority :: number,
			})
		end
		table.sort(systemList, function(a, b)
			return a.Priority < b.Priority
		end)
	end

	return Promise.new(function(Resolve: (...any) -> (), _: (...any) -> ())
		--run observer synchronously, observer should run first because some systems might need it on _setup
		Promise.new(function(SetupResolve: (...any) -> (), _: (...any) -> ())
			for _, data in ipairs(observerList) do
				local name = data.Name
				local observer = data.Observer
				if typeof(observer._Setup) == "function" then
					debug.setmemorycategory(name)
					if _ShouldPrintLog then
						print(`Setting up observer {observer._Name}`)
					end
					local success, result = pcall(function()
						observer:_Setup(Yumi)
					end)
					if not success then
						task.spawn(function()
							error(result)
						end)
					end
				end
			end
			SetupResolve()
		end):Await()

		--run systems synchronously
		Promise.new(function(SetupResolve: (...any) -> (), _: (...any) -> ())
			for _, data in ipairs(systemList) do
				local name = data.Name
				local system = data.System
				if typeof(system._Setup) == "function" then
					debug.setmemorycategory(name)
					if _ShouldPrintLog then
						-- print(`Setting up system {system._Name}`)
					end
					local success, result = pcall(function()
						system:_Setup(Yumi)
					end)
					if not success then
						task.spawn(function()
							error(result)
						end)
					end
				end
			end
			SetupResolve()
		end):Await()

		Resolve()
	end):Then(function()
		for _, data in ipairs(systemList) do
			local system = data.System
			local name = data.Name
			if typeof(system._Start) == "function" then
				task.spawn(function()
					if _ShouldPrintLog then
						-- print(`Starting up system {name}`)
					end
					local success, result = pcall(function()
						system:_Start(Yumi)
					end)
					if not success then
						task.spawn(function()
							error(result)
						end)
					end
				end)
			end
		end

		_Completed = true
		_OnComplete:Fire()

		task.defer(function()
			_OnComplete:Destroy()
		end)
		self.isLoaded = true
		self.Loaded:Fire()
	end)
end

function Yumi.OnStart()
	if _Completed then
		return Promise.Resolve()
	else
		return Promise.new(function(Resolve, _)
			local connection: RBXScriptConnection?
			connection = _OnComplete.Event:Connect(function()
				Resolve()
				if connection then
					connection:Disconnect()
					connection = nil
				end
			end)
		end)
	end
end

return Yumi


