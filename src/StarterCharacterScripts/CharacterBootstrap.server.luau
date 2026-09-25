--!strict

-- Builds the physics shell required by Roblox around the imported Ran Online
-- skinned mesh. The .rbxm intentionally remains the visual/skeleton source.

local character = script.Parent
assert(character:IsA("Model"), "CharacterBootstrap must be parented to the character model")

local mesh = character:FindFirstChild("tripo_node_d2795b5d")
if not mesh or not mesh:IsA("MeshPart") then
    mesh = character:FindFirstChildWhichIsA("MeshPart", true)
end
assert(mesh, "Ran Online character MeshPart was not found")

-- The imported asset currently contains an AnimationController. Player
-- characters use the Humanoid Animator instead, so remove the controller.
local animationController = character:FindFirstChildOfClass("AnimationController")
if animationController then
    animationController:Destroy()
end

local humanoid = character:FindFirstChildOfClass("Humanoid")
if not humanoid then
    humanoid = Instance.new("Humanoid")
    humanoid.Parent = character
end

humanoid.Name = "Humanoid"
humanoid.RequiresNeck = false
humanoid.BreakJointsOnDeath = false
humanoid.AutoRotate = true
humanoid.WalkSpeed = 16
humanoid.UseJumpPower = true
humanoid.JumpPower = 50
humanoid.MaxHealth = 100
humanoid.Health = 100
humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

local root = character:FindFirstChild("HumanoidRootPart")
if root and not root:IsA("BasePart") then
    root:Destroy()
    root = nil
end

if not root then
    local newRoot = Instance.new("Part")
    newRoot.Name = "HumanoidRootPart"
    newRoot.Size = Vector3.new(0.4, 0.5, 0.3)
    newRoot.Transparency = 1
    newRoot.CanCollide = true
    newRoot.CanTouch = false
    newRoot.CanQuery = false
    newRoot.Anchored = false
    newRoot.Massless = false
    newRoot.CFrame = mesh.CFrame
    newRoot.Parent = character
    root = newRoot
end

assert(root and root:IsA("BasePart"))

-- Keep the skinned mesh visual-only. The root part is the physical body.
mesh.CanCollide = false
mesh.CanTouch = false
mesh.Massless = true
mesh.Anchored = false

local weld = character:FindFirstChild("HRP_MeshWeld")
if weld and not weld:IsA("WeldConstraint") then
    weld:Destroy()
    weld = nil
end

if not weld then
    local newWeld = Instance.new("WeldConstraint")
    newWeld.Name = "HRP_MeshWeld"
    newWeld.Part0 = root
    newWeld.Part1 = mesh
    newWeld.Parent = character
end

character.PrimaryPart = root

-- The imported source is approximately 1 stud tall. Normalize it to the
-- previously established 5-stud target without changing its proportions.
if math.abs(character:GetScale() - 5) > 0.01 then
    character:ScaleTo(5)
end

-- Root was scaled with the model. This matches the 5-stud visual character.
root = character:FindFirstChild("HumanoidRootPart") :: BasePart
humanoid.HipHeight = 1.25

-- Ensure the character starts upright and the mesh/root remain one assembly.
root.AssemblyAngularVelocity = Vector3.zero
root.AssemblyLinearVelocity = Vector3.zero

print("[RanCharacter] Character bootstrap complete: Humanoid + HRP + 5-stud scale")
