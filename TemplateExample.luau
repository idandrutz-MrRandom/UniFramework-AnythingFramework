--!strict
local Tool = script.Parent
local SkillMod = require(game.ReplicatedStorage.ClientSkills.Template.C_Template) :: any

Tool.Activated:Connect(function()
	local Character = Tool.Parent :: any

	SkillMod.Start(Character)


end)