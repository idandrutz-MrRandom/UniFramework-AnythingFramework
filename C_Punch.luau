--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local Packets           = require(ReplicatedStorage.Remotes.Packets)
local Assets            = ReplicatedStorage:WaitForChild("Assets")
local highlight         = require(Assets.Modules.Client.Util:WaitForChild("Highlight"))
local animationManager  = require(Assets.Modules.Shared.Util:WaitForChild("AnimationManager"))
local CDManager         = require(Assets.Modules.Shared.Util.Cooldowns)
local punchAnims        = Assets.Animations:WaitForChild("PunchAnims")

type CharData = {
	Combo:      number,
	DB:         boolean,
	AnimsTrack: Animation?, -- Store the track -- THATS JUST FOR THE DEMO CORRECTION
	PrevCombo:  number,
}

local module: {[any]: any} = {}

module.ResetCD = 1.5 -- HAS TO MATCH WITH THE SERVER RESET CD TO ENSURE PARRALLEL SYNC AND TIMING
local function getChar(args: Packets.Args)
	return if typeof(args) == "table" then args.Character else args
end

module.Start = function(args: Packets.Args) : any
	local char = getChar(args) -- CHECK THE CHARACTER
	if not char then return end




	if Players:GetPlayerFromCharacter(char) then
		--if char:GetAttribute("Action") then return end	-- Debounce Check                             
		--if CDManager:IsOnCooldown(char,"Punch") then return end                 --- uncomment line 34 and 35 to test the CORRECTION system
		Packets.ServerRemote:Fire({ Module = "Punch", Function = "Activate", Character = char }) -- IF ITS A PLAYER THEN ASK HIM TO REQUEST THE SERVER SIDE OF THE SKILL
	end
	
	-- Initialize Data
	module[char] = module[char] or {
		Combo      = 0,
		DB         = false,
		AnimsTrack = nil,
		PrevCombo  = 0,
	} -- INIT THE PUNCH DATA
	local data = module[char]

	-- Combo Calculation
	data.Combo = (data.Combo % 5) + 1
	data.PrevCombo = data.Combo
	local animation = punchAnims:FindFirstChild(tostring(data.Combo)) :: Animation
	if animation then
		data.AnimsTrack = animation
	end
	-- Play Animation
	animationManager:Play(char, animation) -- IT WONT PLAY UNLESS YOU SPOOF THE ANIMS AND USE THE ANIM MANAGER + PLUGIN 
	
	task.spawn(function()
		local oldCombo = data.Combo
		task.wait(module.ResetCD)

		if oldCombo == data.Combo then
			data.Combo = 0
		end
	end)
	return nil
end


module.Correction = function(args: Packets.Args)
	local char = getChar(args)
	if not char then return end
	--print("Client Correction")
	local data = module[char]
	-- Restore combo to what it was before this hit was predicted
	data.Combo = data.PrevCombo
	args.Type = "Correction"
	module.Finish(args)
	if data.AnimsTrack then
		animationManager:Stop(char, data.AnimsTrack)
	end
	data.AnimsTrack = nil
	module[char] = nil
end

-- Fixed Effects logic	to match the args structure
module.Effects = function(args: Packets.Args)
	local char = args.Character :: Packets.Character
	local effectType = args.Data and args.Data.Type or args.Type

	if effectType == "Highlight" then
		highlight.Create({ Character = char, Color = Color3.fromRGB(255, 0, 0), Transparency = 0.5, FadeDuration = 0.5 })
	elseif effectType == "Finish" then
		highlight.Create({ Character = char, Color = Color3.fromRGB(0, 0, 127), Transparency = 0.5, FadeDuration = 0.5 })
	elseif effectType == "Correction" then
		highlight.Create({ Character = char, Color = Color3.fromRGB(0, 255, 0), Transparency = 0.5, FadeDuration = 0.5 })
	end
end

module.Finish = function(args: Packets.Args)
	module.Effects(args)
end

return module