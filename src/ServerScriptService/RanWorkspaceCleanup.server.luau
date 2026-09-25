--!strict

-- The character was manually imported into Workspace while the new baseplate
-- was being prepared. It is only an authoring copy and must not coexist with
-- the actual Player.Character spawned from StarterCharacter.

local Workspace = game:GetService("Workspace")

local template = Workspace:FindFirstChild("RanOnlineCharacter")
if template and template:IsA("Model") then
	template:Destroy()
	print("[RanWorkspaceCleanup] removed authoring copy Workspace.RanOnlineCharacter")
end
