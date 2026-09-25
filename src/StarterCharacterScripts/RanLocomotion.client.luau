--!strict

-- Canonical Ran Online locomotion controller.
-- The custom character is a Mixamo-style skinned mesh, not an R6 body.
-- We deliberately do not use Roblox's default Animate script.
--
-- This controller owns the bone transforms while the character is moving.
-- It uses the imported skeleton directly so locomotion does not depend on
-- unpublished Animation asset IDs.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local root = character:WaitForChild("HumanoidRootPart") :: BasePart
local mesh = character:WaitForChild("tripo_node_d2795b5d") :: MeshPart

humanoid.AutoRotate = true

local function bone(name: string): Bone
	local value = mesh:FindFirstChild(name, true)
	assert(value and value:IsA("Bone"), "Missing required Ran Online bone: " .. name)
	return value
end

local hips = bone("mixamorig:Hips")
local spine = bone("mixamorig:Spine")
local spine1 = bone("mixamorig:Spine1")
local spine2 = bone("mixamorig:Spine2")
local neck = bone("mixamorig:Neck")
local head = bone("mixamorig:Head")

local leftUpperLeg = bone("mixamorig:LeftUpLeg")
local leftLowerLeg = bone("mixamorig:LeftLeg")
local leftFoot = bone("mixamorig:LeftFoot")
local leftToe = bone("mixamorig:LeftToeBase")

local rightUpperLeg = bone("mixamorig:RightUpLeg")
local rightLowerLeg = bone("mixamorig:RightLeg")
local rightFoot = bone("mixamorig:RightFoot")
local rightToe = bone("mixamorig:RightToeBase")

local leftUpperArm = bone("mixamorig:LeftArm")
local leftForeArm = bone("mixamorig:LeftForeArm")
local rightUpperArm = bone("mixamorig:RightArm")
local rightForeArm = bone("mixamorig:RightForeArm")

local animatedBones = {
	hips, spine, spine1, spine2, neck, head,
	leftUpperLeg, leftLowerLeg, leftFoot, leftToe,
	rightUpperLeg, rightLowerLeg, rightFoot, rightToe,
	leftUpperArm, leftForeArm, rightUpperArm, rightForeArm,
}

-- Capture the actual imported rest transforms once. Never use a transform
-- produced by the locomotion loop as a future baseline.
local rest: {[Bone]: CFrame} = {}
for _, currentBone in animatedBones do
	rest[currentBone] = currentBone.Transform
end

local function setTransform(currentBone: Bone, offset: CFrame)
	currentBone.Transform = rest[currentBone] * offset
end

local function reset()
	for _, currentBone in animatedBones do
		currentBone.Transform = rest[currentBone]
	end
end

local function damp(current: number, target: number, dt: number, response: number): number
	return current + (target - current) * (1 - math.exp(-response * dt))
end

local phase = 0
local blend = 0
local targetBlend = 0
local state = "Idle"

RunService.RenderStepped:Connect(function(dt)
	if humanoid.Health <= 0 then
		reset()
		return
	end

	local velocity = root.AssemblyLinearVelocity
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	local speed = horizontal.Magnitude
	local hasInput = humanoid.MoveDirection.Magnitude > 0.05

	if not hasInput or speed < 0.15 then
		targetBlend = 0
	else
		targetBlend = math.clamp(speed / math.max(humanoid.WalkSpeed, 1), 0, 1)
		state = if speed >= 12 then "Run" else "Walk"
	end

	blend = damp(blend, targetBlend, dt, 12)

	if blend < 0.005 then
		phase = 0
		reset()
		return
	end

	-- A complete cycle is two steps. Running simply advances the same gait
	-- faster and with slightly larger motion.
	local cycleSpeed = if state == "Run" then 10.0 else 7.0
	local intensity = if state == "Run" then 1.18 else 1.0
	phase = (phase + dt * cycleSpeed) % (math.pi * 2)

	local s = math.sin(phase)
	local c = math.cos(phase)
	local stepA = math.max(0, s)
	local stepB = math.max(0, -s)
	local bob = math.abs(c)

	-- Legs: strong alternating thigh swing, controlled knee bend, and
	-- compensating ankle/toe motion to keep the feet visually planted.
	local thigh = math.rad(27) * intensity * blend
	local knee = math.rad(24) * intensity * blend
	local ankle = math.rad(12) * intensity * blend
	local toe = math.rad(7) * intensity * blend

	setTransform(leftUpperLeg, CFrame.Angles(-s * thigh, 0, 0))
	setTransform(rightUpperLeg, CFrame.Angles(s * thigh, 0, 0))

	setTransform(leftLowerLeg, CFrame.Angles(stepA * knee, 0, 0))
	setTransform(rightLowerLeg, CFrame.Angles(stepB * knee, 0, 0))

	setTransform(leftFoot, CFrame.Angles(s * ankle, 0, 0))
	setTransform(rightFoot, CFrame.Angles(-s * ankle, 0, 0))
	setTransform(leftToe, CFrame.Angles(-s * toe, 0, 0))
	setTransform(rightToe, CFrame.Angles(s * toe, 0, 0))

	-- Arms counter the legs and bend slightly at the elbows.
	local arm = math.rad(22) * intensity * blend
	local elbow = math.rad(10) * intensity * blend
	setTransform(leftUpperArm, CFrame.Angles(s * arm, 0, 0))
	setTransform(rightUpperArm, CFrame.Angles(-s * arm, 0, 0))
	setTransform(leftForeArm, CFrame.Angles(stepB * elbow, 0, 0))
	setTransform(rightForeArm, CFrame.Angles(stepA * elbow, 0, 0))

	-- Subtle pelvis/torso motion. The translation is intentionally tiny;
	-- the HumanoidRootPart remains the sole physics body.
	local hipBob = math.rad(2.5) * intensity * blend
	setTransform(hips,
		CFrame.Angles(0, c * math.rad(2.0) * intensity * blend, 0)
			* CFrame.new(0, bob * 0.025 * blend, 0))
	setTransform(spine, CFrame.Angles(-c * hipBob, 0, 0))
	setTransform(spine1, CFrame.Angles(-c * hipBob * 0.65, 0, 0))
	setTransform(spine2, CFrame.Angles(-c * hipBob * 0.4, 0, 0))
	setTransform(neck, CFrame.Angles(c * math.rad(0.8) * blend, 0, 0))
	setTransform(head, CFrame.Angles(-c * math.rad(0.5) * blend, 0, 0))
end)

print("[RanLocomotion] Active for " .. player.Name)
