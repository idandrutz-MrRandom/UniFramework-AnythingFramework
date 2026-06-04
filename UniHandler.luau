--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage:FindFirstChild("Assets")
local Config = require(Assets:FindFirstChild("Modules"):WaitForChild("Configuration"))
local Players = game:GetService("Players")
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

Packets.ServerRemote.OnServerEvent:Connect(function(player: Player, params: any, data: any)
	local pms = params :: Packets.Params
	if not pms then return end

	local moduleName = pms.Module or pms.Utility or ""
	local isNamespace = pms.Module ~= nil
	local module = GetModule(moduleName, isNamespace)
	if not module then return end

	local func = module[pms.Function]
	if typeof(func) ~= "function" then return end

	local callData: { [any]: any } = if typeof(data) == "table" then data else {}

	-- Only inject character if one was provided in the params
	if pms.Character then
		if Players:GetPlayerFromCharacter(pms.Character) == player  then
			callData.Character = pms.Character -- right call from Player
		else
			warn("Caller doesnt match the player...exploits?") -- Caller doesnt match the player...exploits?
			return
		end
	
	end

	local Function = func(callData, player) :: any
	--warn(tostring(Function).." MODULE RETURN!")
	if Function  then
		warn("[UniHandler]: Fail Validation: "..tostring(pms.Character).." | "..tostring(pms.Module))
		Packets.ReplicateRemote:FireClient(player,{Module = pms.Module,Function = "Correction",Character = pms.Character})

	end
end :: any)

return {}