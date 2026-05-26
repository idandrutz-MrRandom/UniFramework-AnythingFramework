--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Packets = require(Remotes:WaitForChild("Packets"))
local ClientSkills = ReplicatedStorage:WaitForChild("ClientSkills")
local ClientModules = ReplicatedStorage.Assets.Modules.Client

type Params = {
	Skill: string?,
	Key: string?,
	Function: string
}

local CachedModules: { [string]: any } = {}

local function GetModule(name: string, isSkill: boolean): any?
	if CachedModules[name] then return CachedModules[name] end

	local moduleScript: ModuleScript? = nil

	if isSkill then
		local searchName = "C_" .. name
		for _, descendant in ipairs(ClientSkills:GetDescendants()) do
			if descendant:IsA("ModuleScript") and descendant.Name == searchName then
				moduleScript = descendant
				break
			end
		end
	else
		moduleScript = ClientModules:FindFirstChild(name, true) :: ModuleScript?
	end

	if moduleScript then
		local ok, result = pcall(require, moduleScript)
		if ok then
			CachedModules[name] = result
			return result
		end
	end

	return nil
end

Packets.ReplicateRemote.OnClientEvent:Connect(function(character: Model, params: any, ...: any)
	local pms = params :: Params
	if not pms or not character then return end

	local name = pms.Skill or pms.Key
	if not name then return end

	local module = GetModule(name, pms.Skill ~= nil)
	if not module then return end

	local func = module[pms.Function]
	if typeof(func) == "function" then
		local extraArgs = {...}
		local mainArgs = extraArgs[1] or {}
		
		if typeof(mainArgs) == "table" then
			mainArgs["Character"] = character
		end

		task.spawn(func, mainArgs, unpack(extraArgs, 2))
	end
end :: any)
