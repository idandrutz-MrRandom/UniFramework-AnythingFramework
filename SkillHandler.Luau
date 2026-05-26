--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Packets = require(ReplicatedStorage.Remotes:WaitForChild("Packets"))
local ServerSkills = ServerScriptService:WaitForChild("ServerSkills")
local SharedUtil = ReplicatedStorage.Assets.Modules.Shared.Util

type Params = { Skill: string?, Key: string?, Function: string }
local CachedModules: { [string]: any } = {}

local function GetModule(name: string, isSkill: boolean): any?
	if CachedModules[name] then return CachedModules[name] end
	
	local moduleScript: ModuleScript? = nil
	if isSkill then
		local searchName = "S_" .. name
		for _, descendant in ipairs(ServerSkills:GetDescendants()) do
			if descendant:IsA("ModuleScript") and descendant.Name == searchName then
				moduleScript = descendant break
			end
		end
	else
		moduleScript = SharedUtil:FindFirstChild(name, true) :: ModuleScript?
	end
	
	if moduleScript then
		local ok, result = pcall(require, moduleScript)
		if ok then CachedModules[name] = result return result end
	end
	return nil
end

Packets.ServerRemote.OnServerEvent:Connect(function(player: Player, character: any, params: any, extraData: any)
	local char = character :: Model
	local pms = params :: Params
	if not pms or not char then return end
	
	local name = pms.Skill or pms.Key
	if not name then return end
	
	local module = GetModule(name, pms.Skill ~= nil)
	if not module then return end
	
	local func = module[pms.Function]
	if typeof(func) == "function" then
		task.spawn(func, char, extraData)
	end
	
end :: any)

return {}
