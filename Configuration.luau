--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type Config = {
	ServerModulePaths: { Instance },
	ClientModulePaths: { Instance },
	UtilityPaths: { Instance },
	RemoteDistance: number,
}

local Configuration: Config = {
	ServerModulePaths = {},
	ClientModulePaths = {},
	UtilityPaths = {},
	RemoteDistance = 650,
}

-- Shared utilities accessible by both sides
table.insert(Configuration.UtilityPaths, ReplicatedStorage.Assets.Modules.Shared.Util)

if RunService:IsServer() then
	local ServerScriptService = game:GetService("ServerScriptService")
	table.insert(Configuration.ServerModulePaths, ServerScriptService:WaitForChild("ServerSkills"))

	local serverUtil = ReplicatedStorage.Assets.Modules.Server:FindFirstChild("Util")
	if serverUtil then
		table.insert(Configuration.UtilityPaths, serverUtil)
	end
else
	table.insert(Configuration.ClientModulePaths, ReplicatedStorage:WaitForChild("ClientSkills"))

	local clientUtil = ReplicatedStorage.Assets.Modules.Client:FindFirstChild("Util")
	if clientUtil then
		table.insert(Configuration.UtilityPaths, clientUtil)
	end
end

return Configuration