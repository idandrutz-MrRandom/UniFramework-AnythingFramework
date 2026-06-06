--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local Packets           = require(ReplicatedStorage.Remotes.Packets)
local Muchacho          = require(ServerStorage:WaitForChild("MuchachoHitbox"))
local CDManager 		= require(ReplicatedStorage.Assets:WaitForChild("Modules").Shared.Util.Cooldowns)
local AnimationManager  = require(ReplicatedStorage.Assets.Modules.Shared.Util.AnimationManager)
local AnimationFolder   = ReplicatedStorage.Assets.Animations:FindFirstChild("PunchAnims")
local Packet            = Packets.ReplicateRemote

local HITBOX_SIZE       = Vector3.new(8, 6, 8)
local PUNCH_DAMAGE      = 10
local COMBO_RESET_TIME  = 1.5 -- Seconds to reset combo

local module: { [any]: any } = {}
module.Combo = {} 

module.Activate = function(args: Packets.Args, player: Player?): string?
	local char = args.Character
	if not char then return "Fail" end

	-- Checks
	if char:GetAttribute("Action") then return "Fail" end
	if CDManager:IsOnCooldown(char, "Punch") then return  "Fail"  end

	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return "Fail" end


	module.Combo[char] = (module.Combo[char] or 0) + 1
	local currentCombo = module.Combo[char]

	-- Handle Non-Player (NPC) replication
	if not player then
		Packet:FireCloseClients({ Module = "Punch", Function = "Start", Character = char })
	end

	char:SetAttribute("Action", true)

	-- Visual Effects
	Packet:FireCloseClients({ Module = "Punch", Function = "Effects", Character = char }, { Type = "Highlight" }) -- PLAY EFFECT AFTER VALIDATION

	-- Get Animation Metadata
	local AnimationByCombo = AnimationFolder:WaitForChild(tostring(currentCombo)) :: Animation
	local Hitreg = AnimationManager:GetTimeToMarker(char, AnimationByCombo, "hitreg")
	local AnimLength = AnimationManager:GetLength(char, AnimationByCombo)
	--warn(Hitreg)
	--warn(AnimLength)
	--warn(currentCombo)
	--Logic Threading
	task.spawn(function()
		-- Hitbox Delay
		task.delay(Hitreg, function()
			module.Attack(args)
		end)

		-- Cleanup Delay
		task.delay(AnimLength, function()
			module.Cleanup(args)
		end)
	end)




	--// Combo Reset Timer
	task.spawn(function()
		local oldCombo = module.Combo[char]
		task.wait(COMBO_RESET_TIME)

		if oldCombo == module.Combo[char] then
			module.Combo[char] = 0
		end
	end)

	--// Auto Reset at 5
	if module.Combo[char] == 5 then
		module.Combo[char] = 0
		return nil
	end
	return nil
end

module.Attack = function(args : Packets.Args)
	local char = args.Character

	if not char then return end
	local hrp = char:WaitForChild("HumanoidRootPart") :: BasePart?
	if not hrp then return end
	--warn("THIS CHARACTER IS SPAWNING HITBOX!"..tostring(char))
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { char }

	local hitbox = Muchacho.CreateHitbox() :: any
	hitbox.VisualizerTransparency = 0.6
	hitbox.Size                   = HITBOX_SIZE
	hitbox.CFrame                 = hrp :: any
	hitbox.Offset                 = CFrame.new(0, 0, -HITBOX_SIZE.Z / 2 + 1)
	hitbox.VelocityPrediction     = true
	hitbox.VelocityPredictionTime = 0.1
	hitbox.OverlapParams          = overlapParams
	
	
	hitbox.Touched:Connect(function(_, humanoid: Humanoid)
		humanoid:TakeDamage(PUNCH_DAMAGE)
	end :: any)

	hitbox:Start()
	--warn("STARTED!")
	task.delay(0.15, function()
		hitbox:Stop()
	end)
end



module.Cleanup = function(args: Packets.Args)
	local char = args.Character
	if not char then return end
	char:SetAttribute("Action", false)
	Packet:FireCloseClients({ Module = "Punch", Function = "Finish", Character = char }, { Type = "Finish" })
	-- Apply cooldown only on the final hit of the combo
	if module.Combo[char] == 0 then
		CDManager:Set(char, "Punch", 1)
	end
end

return module