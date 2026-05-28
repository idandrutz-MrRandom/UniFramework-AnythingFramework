--!strict
local Tool = script.Parent
local SkillMod = require(game.ReplicatedStorage.ClientSkills.Base.Punch.C_Punch) :: any

Tool.Activated:Connect(function()
	local Character = Tool.Parent :: any
	SkillMod.Start(Character)
end)