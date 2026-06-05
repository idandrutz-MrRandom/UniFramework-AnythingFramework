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

	if typeof(pms.Function) ~= "string" then return end

	-- Only functions the module explicitly publishes in `Remotes` are callable
	-- from a client. Without this, an exploiter can invoke any function on the
	-- module table, including internal helpers never meant to cross the network.
	local remotes = module.Remotes
	if typeof(remotes) ~= "table" or not remotes[pms.Function] then
		warn("[UniHandler]: '" .. tostring(pms.Function) .. "' is not a published remote on '" .. moduleName .. "'")
		return
	end

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

	local rejected = func(callData, player) :: any
	if rejected then
		warn("[UniHandler]: rejected " .. moduleName .. "." .. pms.Function)
		-- Route the correction back using the server-resolved module name, never
		-- the raw client value: otherwise a client could make the server fire
		-- Correction on any C_ module it names, unrelated to the rejected action.
		if isNamespace then
			Packets.ReplicateRemote:FireClient(player, { Module = moduleName, Function = "Correction", Character = callData.Character })
		else
			Packets.ReplicateRemote:FireClient(player, { Utility = moduleName, Function = "Correction", Character = callData.Character })
		end
	end
end :: any)

return {}