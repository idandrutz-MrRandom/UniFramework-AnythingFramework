--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type Config = {
	ServerModulePaths: {Instance},
	ClientModulePaths: {Instance},
	UtilityPaths: {Instance}
}

-- Initialize empty tables
local Configuration: Config = {
	ServerModulePaths = {},
	ClientModulePaths = {},
	UtilityPaths = {}
}

-- Shared Utilities (Accessible by both)
table.insert(Configuration.UtilityPaths, ReplicatedStorage.Assets.Modules.Shared.Util)

if RunService:IsServer() then
	local ServerScriptService = game:GetService("ServerScriptService")
	--add server containter
	table.insert(Configuration.ServerModulePaths, ServerScriptService:WaitForChild("ServerSkills"))

	-- Add Server-specific utilities
	local serverUtil = ReplicatedStorage.Assets.Modules.Server:FindFirstChild("Util")
	if serverUtil then table.insert(Configuration.UtilityPaths, serverUtil) end
else
	--add client containter
	table.insert(Configuration.ClientModulePaths, ReplicatedStorage:WaitForChild("ClientSkills"))

	-- Add Client-specific utilities
	local clientUtil = ReplicatedStorage.Assets.Modules.Client:FindFirstChild("Util")
	if clientUtil then table.insert(Configuration.UtilityPaths, clientUtil) end
end

return Configuration