--!strict

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
	local _, bounds = character:GetBoundingBox()
	if bounds.Y <= 0 then
		error("Ran Online character has an invalid bounding-box height")
	end

	local currentScale = character:GetScale()
	if currentScale <= 0 then
		error("Ran Online character has an invalid model scale")
	end

	-- ScaleTo takes an absolute canonical scale. Recover the unscaled asset
	-- height first so a previously scaled model is never multiplied again.
	local originalHeight = bounds.Y / currentScale
	local targetScale = TARGET_HEIGHT / originalHeight
	character:ScaleTo(targetScale)

	local _, normalizedBounds = character:GetBoundingBox()
	print(string.format(
		"[RanCharacterBootstrap] Scale normalized | currentHeight=%.2f | currentScale=%.4f | originalHeight=%.4f | targetScale=%.4f | finalHeight=%.2f",
		bounds.Y,
		currentScale,
		originalHeight,
		targetScale,
		normalizedBounds.Y
	))
end

local function ensureRoot(character: Model, mesh: MeshPart, player: Player): BasePart
	local existing = character:FindFirstChild("HumanoidRootPart")
	if existing and existing:IsA("BasePart") then
		return existing
	end

	local _, bounds = character:GetBoundingBox()
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(
		math.max(bounds.X * 0.70, 0.8),
		math.max(bounds.Y * 0.50, 1.0),
		math.max(bounds.Z * 0.70, 0.8)
	)
	root.CFrame = mesh.CFrame
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
	pcall(function()
		root:SetNetworkOwner(player)
	end)

	return root
end

local function ensureHumanoid(character: Model, root: BasePart, player: Player): Humanoid
	local existing = character:FindFirstChildOfClass("Humanoid")
	local humanoid = existing or Instance.new("Humanoid")

	if not existing then
		humanoid.Parent = character
	end

	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.AutoRotate = true
	humanoid.PlatformStand = false
	humanoid.Sit = false
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

	local root = ensureRoot(character, mesh, player)
	local humanoid = ensureHumanoid(character, root, player)

	character.PrimaryPart = root
	character:SetAttribute("RanCharacterBootstrapDone", true)
	humanoid:ChangeState(Enum.HumanoidStateType.Running)

	print(string.format(
		"[RanCharacterBootstrap] Ready %s | height=%.2f | scale=%.4f | Humanoid=%s | HRP=%s | root=%s",
		player.Name,
		character:GetExtentsSize().Y,
		character:GetScale(),
		tostring(humanoid.Parent ~= nil),
		tostring(root.Parent ~= nil),
		root.Name
	))
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		prepareCharacter(player, character)
	end)
	if player.Character then
		prepareCharacter(player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
