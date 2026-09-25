--!strict

-- Runtime bootstrap for the imported Ran Online character.
-- The checked-in .rbxm is the visual/skinned character asset. It does not
-- contain the Roblox movement body, so we construct the minimal physics
-- shell here before the client locomotion controller starts.

local Players = game:GetService("Players")

local TARGET_HEIGHT = 5
local MESH_NAME = "tripo_node_d2795b5d"

local function removeLegacyControllers(character: Model)
	for _, child in character:GetChildren() do
		if child:IsA("AnimationController") then
			child:Destroy()
		elseif child:IsA("Script") or child:IsA("LocalScript") then
			if child.Name == "Animate"
				or child.Name == "RanAnimationController"
				or child.Name == "Health"
				or child.Name == "_TEMP_AnimTest" then
				child:Destroy()
			end
		end
	end
end

local function getMesh(character: Model): MeshPart
	local mesh = character:FindFirstChild(MESH_NAME, true)
	assert(mesh and mesh:IsA("MeshPart"), "Ran Online character mesh is missing: " .. MESH_NAME)
	return mesh
end

local function normalizeVisualScale(character: Model)
	if character:GetAttribute("RanCharacterNormalized") == true then
		return
	end

	local _, bounds = character:GetBoundingBox()
	if bounds.Y <= 0 then
		error("Ran Online character has an invalid bounding-box height")
	end

	local scaleFactor = TARGET_HEIGHT / bounds.Y
	character:ScaleTo(character:GetScale() * scaleFactor)
	character:SetAttribute("RanCharacterNormalized", true)
end

local function ensureRoot(character: Model, mesh: MeshPart): BasePart
	local existing = character:FindFirstChild("HumanoidRootPart")
	if existing and existing:IsA("BasePart") then
		return existing
	end

	local boundsCFrame, bounds = character:GetBoundingBox()

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(
		math.max(bounds.X * 0.70, 0.8),
		math.max(bounds.Y * 0.50, 1.0),
		math.max(bounds.Z * 0.70, 0.8)
	)
	root.CFrame = boundsCFrame
	root.Transparency = 1
	root.CanCollide = true
	root.CanTouch = false
	root.CanQuery = false
	root.Anchored = false
	root.Massless = false
	root.Parent = character

	mesh.Anchored = false
	mesh.CanCollide = false
	mesh.CanTouch = false
	mesh.Massless = true

	local weld = Instance.new("WeldConstraint")
	weld.Name = "HRP_MeshWeld"
	weld.Part0 = root
	weld.Part1 = mesh
	weld.Parent = character

	character.PrimaryPart = root
	return root
end

local function ensureHumanoid(character: Model, root: BasePart, player: Player): Humanoid
	local existing = character:FindFirstChildOfClass("Humanoid")
	local humanoid: Humanoid

	if existing then
		humanoid = existing
	else
		humanoid = Instance.new("Humanoid")
		humanoid.Parent = character
	end

	-- This is a custom skinned mesh, not an R6/R15 body. Prevent the
	-- standard neck requirement from killing the Humanoid immediately.
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.AutoRotate = true
	humanoid.WalkSpeed = 16
	humanoid.JumpPower = 50
	humanoid.UseJumpPower = true
	humanoid.MaxHealth = 100
	humanoid.Health = humanoid.MaxHealth
	humanoid.DisplayName = player.DisplayName

	local _, bounds = character:GetBoundingBox()
	humanoid.HipHeight = math.max((bounds.Y - root.Size.Y) * 0.5, 0)

	return humanoid
end

local function prepareCharacter(player: Player, character: Model)
	if character:GetAttribute("RanCharacterBootstrapDone") == true then
		return
	end

	removeLegacyControllers(character)

	local mesh = getMesh(character)
	normalizeVisualScale(character)
	mesh = getMesh(character)

	local root = ensureRoot(character, mesh)
	local humanoid = ensureHumanoid(character, root, player)

	character.PrimaryPart = root
	character:SetAttribute("RanCharacterBootstrapDone", true)

	print(string.format(
		"[RanCharacterBootstrap] Ready %s | height=%.2f | Humanoid=%s | HRP=%s",
		player.Name,
		character:GetExtentsSize().Y,
		tostring(humanoid.Parent ~= nil),
		tostring(root.Parent ~= nil)
	))
end

local function onCharacterAdded(player: Player, character: Model)
	-- CharacterAdded fires after the model is assigned. Construct the
	-- movement shell immediately; StarterCharacterScripts can safely wait
	-- for Humanoid/HRP while this runs.
	prepareCharacter(player, character)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
