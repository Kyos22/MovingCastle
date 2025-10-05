--!nocheck
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
export type PropertyArray = { [string]: any }
export type InstancePropertyArray = { [Instance]: PropertyArray }

local BASE_PART_PROPERTIES = {
	"Anchored",
	"CanCollide",
	"Transparency",
	"Orientation",
	"Color",
	"Size",
	"Reflectance",
	"Rotation",
	"CFrame",
	"Position",
	"PivotOffset",
}

function HasProperty(instance: Instance, property: string): boolean
	local hasProperty: boolean = false

	pcall(function()
		local _ = instance[property]
		hasProperty = true -- This line only runs if the previous line didn't error
	end)

	return hasProperty
end

function ConvertPartToProperties(part: BasePart): PropertyArray
	local dictEntry: PropertyArray = {}

	for _, property: string in BASE_PART_PROPERTIES do
		if HasProperty(part, property) then
			dictEntry[property] = part[property]
		end
	end

	return dictEntry
end

function ApplyPropertiesToPart(part: BasePart, properties: PropertyArray)
	for k, v in pairs(properties) do
		pcall(function()
			part[k] = v
		end)
	end
end

function GetDescendantsWhichAre(ancestor: Instance, className: string): { Instance }
	local descendants = {}

	for _, descendant in pairs(ancestor:GetDescendants()) do
		if descendant:IsA(className) then
			table.insert(descendants, descendant)
		end
	end

	return descendants
end

function GetPrimaryPart(model: Model): BasePart?
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

function GetMass(instance: Instance): number
	local mass = 0

	if instance:IsA("Model") then
		local primaryPart = GetPrimaryPart(instance)
		mass = primaryPart and primaryPart.Mass or 0
	elseif instance:IsA("BasePart") then
		mass = instance.Mass
	end

	return mass
end

function GetLongestAxis(model: Model): number
	local longest = 0
	local size = model:GetExtentsSize()

	if size.X > longest then
		longest = size.X
	end

	if size.Z > longest then
		longest = size.Z
	end

	if size.Y / 2 > longest then
		longest = size.Y / 2
	end

	return longest
end

function GetVolume(model: Model, scale: number?): number
	local size = model:GetExtentsSize()

	return size.Z * size.X * size.Y * (scale or 1)
end

function CountDict(dict: { [string]: any }): number
	local count = 0
	for _ in pairs(dict) do
		count += 1
	end

	return count
end

function CloneTable(t: { [any]: any }, deep: boolean?)
	if not deep then
		return (table.clone(t))
	end

	local function DeepCopy(tbl)
		local tCopy = table.clone(tbl)
		for k, v in tCopy do
			if type(v) == "table" then
				tCopy[k] = DeepCopy(v)
			end
		end
		return tCopy
	end
	return DeepCopy(t)
end

function KeysMatch(table1, table2, key)
	if table2[key] == nil then
		return
	end

	if typeof(table1[key]) ~= typeof(table2[key]) then
		return
	end

	if typeof(table1[key]) == "table" then
		if not CheckKeys(table1[key], table2[key]) then
			return
		end
	elseif table1[key] ~= table2[key] then
		return
	end

	return true
end

function CheckKeys(table1, table2)
	if not table1 then
		return
	end

	for key in pairs(table1) do
		if not KeysMatch(table1, table2, key) then
			return
		end
	end

	return true
end

function AreTablesSame(table1, table2)
	if not CheckKeys(table1, table2) then
		return
	end

	if not CheckKeys(table2, table1) then
		return
	end

	return true
end

local NUMBER_SUFFIXES = {
	"",
	"K", -- Thousand
	"M", -- Million
	"B", -- Billion
	"T", -- Trillion
	"Q", -- Quadrillion
	"Qu", -- Quintillion (Q already used, so Qu)
	"S", -- Sextillion
	"Se", -- Septillion (S already used, so Se)
	"O", -- Octillion
	"N", -- Nonillion
	"D", -- Decillion
	"U", -- Undecillion
	"Do", -- Duodecillion (D already used, so Do)
	"Tr", -- Tredecillion (T already used, so Tr)
	"Qa", -- Quattuordecillion (Q and Qu used, so Qa)
	"Qi", -- Quindecillion (Q, Qu, Qa used, so Qi)
	"Sx", -- Sexdecillion (S and Se used, so Sx)
	"Sp", -- Septendecillion (S, Se, Sx used, so Sp)
	"Oc", -- Octodecillion (O already used, so Oc)
	"No", -- Novemdecillion (N already used, so No)
	"V", -- Vigintillion
	"Uv", -- Unvigintillion (U already used, so Uv)
	"Dv", -- Duovigintillion (D, Do used, so Dv)
	"Tv", -- Trevigintillion (T, Tr used, so Tv)
	"Qv", -- Quattuorvigintillion (Q, Qu, Qa, Qi used, so Qv)
	"Qw", -- Quinvigintillion (Q, Qu, Qa, Qi, Qv used, so Qw)
	"Sy", -- Sexvigintillion (S, Se, Sx, Sp used, so Sy)
	"Sz", -- Septenvigintillion (S, Se, Sx, Sp, Sy used, so Sz)
	"Ov", -- Octovigintillion (O, Oc used, so Ov)
	"Nw", -- Novemvigintillion (N, No used, so Nw)
}

function FloorToDecimal(num: number, decimalPlaces: number): number
	local factor = 10 ^ decimalPlaces
	return math.floor(num * factor) / factor
end

function FormatNumber(n: number, decimalPoints: number?): string
	local decimalRegex = "%." .. (decimalPoints or 2) .. "f%s"
	local magnitude = 0
	while n >= 1000 and magnitude < #NUMBER_SUFFIXES - 1 do
		n = n / 1000
		magnitude = magnitude + 1
	end
	if magnitude > 0 then
		return string
			.format(decimalRegex, n, NUMBER_SUFFIXES[magnitude + 1])
			:gsub("%.?0+%" .. NUMBER_SUFFIXES[magnitude + 1], "" .. NUMBER_SUFFIXES[magnitude + 1])
	else
		return tostring(n):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
	end
end

local function Lerp(num, goal, i)
	return num + (goal - num) * i
end

local _Logs = {}
local function TweenModelCFrame(model: Model, targetCFrame: CFrame, providedTweenInfo: TweenInfo?)
	if not model or not targetCFrame then
		warn("Invalid Model or NewCFrame")
		return
	end

	local tweenInfo = providedTweenInfo or TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
	local startCFrame = model:GetPivot()

	local cframeValue = model:FindFirstChild("CFrameValue")
	if not cframeValue then
		local value = Instance.new("CFrameValue")
		value.Value = startCFrame
		value.Name = "CFrameValue"
		value.Parent = model
		cframeValue = value

		_Logs[value] = value.Changed:Connect(function()
			model:PivotTo(targetCFrame)
		end)
	end

	local tween = TweenService:Create(cframeValue, tweenInfo, { Value = targetCFrame })
	tween.Completed:Once(function(result: Enum.PlaybackState)
		if result == Enum.PlaybackState.Completed then
			if _Logs[cframeValue] then
				_Logs[cframeValue]:Disconnect()
				_Logs[cframeValue] = nil
				cframeValue:Destroy()
			end
		end
	end)
	tween:Play()
end

local function TweenModelSize(
	model: Model,
	startScale: number,
	endScale: number,
	tweenInfo: TweenInfo?,
	callback: ((stats: "Completed" | "Cancelled") -> ())?
): (() -> ())?
	if not model or not startScale or not endScale then
		warn("Invalid Model or startScale or endScale")
		if callback then
			callback("Cancelled")
		end
		return
	end

	local elapsed = 0
	local scale = startScale

	model:ScaleTo(startScale)
	local info = tweenInfo or TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.In)

	local tweenConnection

	local function onStep(dt)
		elapsed = math.min(elapsed + dt, info.Time)
		local alpha = TweenService:GetValue(elapsed / info.Time, info.EasingStyle, info.EasingDirection)

		if info.Reverses then
			if alpha < 0.5 then
				scale = math.abs(startScale + alpha * (endScale - startScale))
			else
				scale = math.abs(endScale + alpha * (startScale - endScale))
			end
		else
			scale = math.abs(startScale + alpha * (endScale - startScale))
		end

		model:ScaleTo(scale)
		if elapsed >= info.Time then
			if info.Reverses then
				model:ScaleTo(startScale)
			else
				model:ScaleTo(endScale)
			end

			tweenConnection:Disconnect()

			if callback then
				callback("Completed")
			end
		end
	end
	tweenConnection = RunService.Heartbeat:Connect(onStep)

	return function()
		if callback then
			callback("Cancelled")
		end
		tweenConnection:Disconnect()
	end
end

local function WrapDebounce(self: Type, func)
    return function(...)
        if self.Debounce then return end
        self.Debounce = true
        func(...)
        self.Debounce = false
    end
end

return {
	CountDict = CountDict,
	TweenModelCFrame = TweenModelCFrame,
	TweenModelSize = TweenModelSize,
	HasProperty = HasProperty,
	ConvertPartToProperties = ConvertPartToProperties,
	ApplyPropertiesToPart = ApplyPropertiesToPart,
	GetPrimaryPart = GetPrimaryPart,
	GetLongestAxis = GetLongestAxis,
	GetVolume = GetVolume,
	GetMass = GetMass,
	GetRandomPositionNearModel = require(script.RandomPosNearModel),
	GetDescendantsWhichAre = GetDescendantsWhichAre,
	CloneTable = CloneTable,
	KeysMatch = KeysMatch,
	CheckKeys = CheckKeys,
	AreTablesSame = AreTablesSame,
	Lerp = Lerp,
	FLoorToDecimal = FloorToDecimal,
	FormatNumber = FormatNumber,
	NUMBER_SUFFIXES = NUMBER_SUFFIXES,

	WrapDebounce = WrapDebounce,
}
