--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage:FindFirstChild("Assets")
local Config = require(Assets:FindFirstChild("Modules"):WaitForChild("Configuration"))
local Packets = require(ReplicatedStorage.Remotes.Packets)

local CachedModules: { [string]: any } = {}

local function SearchPaths(paths: {Instance}, name: string): ModuleScript?
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

	local searchName = isNamespace and ("S_" .. name) or name
	local paths = isNamespace and Config.ServerModulePaths or Config.UtilityPaths

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

Packets.ServerRemote.OnServerEvent:Connect(function(player: Player, character: any, params: any, extraData: any)
	local Character = character :: Packets.Character
	local pms = params :: Packets.Params
	if not pms or not Character then return end

	local name = pms.Module or pms.Utility
	if not name then return end

	local module = GetModule(name, pms.Module ~= nil)
	if not module then return end

	local func = module[pms.Function]
	if typeof(func) == "function" then
		task.spawn(func, Character, extraData or {}, player)
	end
end :: any)

return {}