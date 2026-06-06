--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage:FindFirstChild("Assets")
local Config = require(Assets:FindFirstChild("Modules"):WaitForChild("Configuration"))
local Packets = require(ReplicatedStorage.Remotes.Packets)

local CachedModules: { [string]: any } = {}

local function SearchPaths(paths: { Instance }, name: string): ModuleScript?
	for _, path in ipairs(paths) do
		for _, descendant in ipairs(path:GetDescendants()) do
			if descendant:IsA("ModuleScript") and descendant.Name == name then
				return descendant
			end
		end
	end
	return nil
end

local function GetModule(name: string, isNamespace: boolean): any?
	if CachedModules[name] then return CachedModules[name] end

	local searchName = isNamespace and ("C_" .. name) or name
	local paths = isNamespace and Config.ClientModulePaths or Config.UtilityPaths
	local modScript = SearchPaths(paths, searchName)

	if modScript then
		local ok, result = pcall(require, modScript)
		if ok then
			CachedModules[name] = result
			return result
		end
	end

	return nil
end

Packets.ReplicateRemote.OnClientEvent:Connect(function(params: any, data: any)
	local pms = params :: Packets.Params
	if not pms then return end

	local moduleName = pms.Module or pms.Utility or ""
	local isNamespace = pms.Module ~= nil
	local module = GetModule(moduleName, isNamespace)
	if not module then return end

	local func = module[pms.Function]
	if typeof(func) ~= "function" then return end

	local callData: { [any]: any } = if typeof(data) == "table" then data else {}


	if pms.Character then
		callData.Character = pms.Character
	end

	func(callData)
end :: any)

return {}