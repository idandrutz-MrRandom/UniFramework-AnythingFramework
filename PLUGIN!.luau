-- Services --

local SelectionService = game:GetService('Selection')

local HttpService = game:GetService('HttpService')
local KeyframeSequenceProvider = game:GetService('KeyframeSequenceProvider')

-- Plugin UI --

local ToolBar = plugin:CreateToolbar('Animation Marker Exporter')

local SerializeSelected = ToolBar:CreateButton('Export Selected','Exports markers and keyframes as a JSON attribute.','rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Animation.png')
SerializeSelected.ClickableWhenViewportHidden = true
local AutoSerializeInside = ToolBar:CreateButton('Automaticly Exports Every Animation','Exports markers and keyframes as a JSON attribute.','rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Animation.png')
AutoSerializeInside.ClickableWhenViewportHidden = true

-- State --

local enabled = plugin:GetSetting("AutoSerializeEnabled") or false
local Connection

-- Methods/Functions --

local function GetOrCreate<T>(Container:{[string]:{T}},Key:string):{T}
	local Existing = Container[Key]
	if Existing then return Existing end
	local New = {}
	Container[Key] = New
	return New
end

local function ExtractAnimationData(AnimationID:string)
	local Success,Response = pcall(KeyframeSequenceProvider.GetKeyframeSequenceAsync,KeyframeSequenceProvider,AnimationID)
	if not Success or not Response then 
		warn(`[Animation Marker Exporter] Failed to fetch KeyframeSequence for AssetId {AnimationID}`)
		return {Markers = {},Keyframes = {}} 
	end
	Response = Response :: KeyframeSequence
	local Data:ExportedData = {Markers = {},Keyframes = {}}
	for _,Keyframe in Response:GetKeyframes() do
		local KeyName = Keyframe.Name
		if KeyName ~= 'Keyframe' then
			local KeyList = GetOrCreate(Data.Keyframes,KeyName)
			table.insert(KeyList,{Time = Keyframe.Time})
		end
		for _,Marker in Keyframe:GetMarkers() do
			local MarkerList = GetOrCreate(Data.Markers,Marker.Name)
			table.insert(MarkerList,{
				Time = Keyframe.Time,
				Parameter = if Marker.Value then Marker.Value else nil
			})
		end
	end
	return Data
end

local function EncodeAttribute(Animation:Animation,MarkerTimes:ExportedData)
	Animation:SetAttribute('Data',HttpService:JSONEncode(MarkerTimes))
end

local function ExportAnimation(Animation:Animation)
	EncodeAttribute(Animation,ExtractAnimationData(Animation.AnimationId))
end

local function ExportFolder(Parent:Folder)
	for _,Animation in Parent:QueryDescendants('Animation') :: {Animation} do
		ExportAnimation(Animation)
	end
end

local function Start()
	if Connection then return end
	AutoSerializeInside:SetActive(true)
	Connection = game.DescendantAdded:Connect(function(Child)
		if Child:IsA("Animation") then
			warn(`[Animation Auto Export] Animation Added {Child.Name}`)
			Child:GetPropertyChangedSignal("AnimationId"):Connect(function()
				warn(`[Animation Auto Export] Property changed for animation: {Child.Name}`)
				if Child.AnimationId ~= "" then
					ExportAnimation(Child)
				end
			end)
			if Child.AnimationId ~= "" then
				ExportAnimation(Child)
			end
		end
	end)
end

local function Stop()
	if Connection then
		AutoSerializeInside:SetActive(false)
		Connection:Disconnect()
		Connection = nil
	end
end

-- Connections --

SerializeSelected.Click:Connect(function()
	local Selections = SelectionService:Get()
	if #Selections == 0 then warn('[Animation Marker Exporter] Nothing selected!') return end
	for _,Selected in Selections do
		if Selected:IsA('Folder') then
			ExportFolder(Selected)
		elseif Selected:IsA('Animation') then
			ExportAnimation(Selected)
		end
	end
	print('[Animation Marker Exporter] Export complete!')
end)

if enabled then
	Start()
	warn("[Animation Marker Auto Export is On!]")
else
	warn("[Animation Marker Auto Export is Off, to continue enable it.]")
end

AutoSerializeInside.Click:Connect(function()
	if enabled == false then
		warn("[Animation Marker Auto Export is On!]")
		enabled = true
		plugin:SetSetting("AutoSerializeEnabled", true)
		Start()
	else
		warn("[Animation Marker Auto Export is Off!]")
		enabled = false
		plugin:SetSetting("AutoSerializeEnabled", false)
		Stop()
	end
end)

-- Types --

type KeyframeEntry = {
	Time:number
}
type MarkerEntry = {
	Time: number,
	Parameter:string?
}
type ExportedKeyframes = {
	[string]:{KeyframeEntry}
}
type ExportedMarkers = {
	[string]:{MarkerEntry}
}
type ExportedData = {
	Markers:ExportedMarkers,
	Keyframes:ExportedKeyframes
}