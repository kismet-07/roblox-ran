--!strict

-- Custom locomotion controller for the Ran Online-inspired skinned character.
-- The default Roblox Animate script is intentionally disabled/replaced because
-- this character is a custom skinned mesh and does not have R6 body parts.
--
-- This controller currently provides deterministic procedural Idle/Walk/Run
-- bone motion. It does not require published Animation asset IDs.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid") :: Humanoid

-- Roblox may inject the default Animate LocalScript into the spawned character.
-- Disable it so it cannot wait forever for R6 parts such as Torso or compete
-- with this controller.
local animate = character:FindFirstChild("Animate")
if animate and animate:IsA("LocalScript") then
    animate.Enabled = false
end

local mesh = character:FindFirstChildWhichIsA("MeshPart")
if not mesh then
    warn("[RanAnimationController] No MeshPart found")
    return
end

local function findBone(name: string): Bone?
    local instance = mesh:FindFirstChild(name, true)
    if instance and instance:IsA("Bone") then
        return instance
    end
    return nil
end

local hips = findBone("mixamorig:Hips")
local spine = findBone("mixamorig:Spine")
local spine1 = findBone("mixamorig:Spine1")
local spine2 = findBone("mixamorig:Spine2")
local neck = findBone("mixamorig:Neck")
local head = findBone("mixamorig:Head")

local leftUpperLeg = findBone("mixamorig:LeftUpLeg")
local leftLeg = findBone("mixamorig:LeftLeg")
local leftFoot = findBone("mixamorig:LeftFoot")
local rightUpperLeg = findBone("mixamorig:RightUpLeg")
local rightLeg = findBone("mixamorig:RightLeg")
local rightFoot = findBone("mixamorig:RightFoot")

local leftArm = findBone("mixamorig:LeftArm")
local leftForeArm = findBone("mixamorig:LeftForeArm")
local rightArm = findBone("mixamorig:RightArm")
local rightForeArm = findBone("mixamorig:RightForeArm")

local tracked = {
    hips, spine, spine1, spine2, neck, head,
    leftUpperLeg, leftLeg, leftFoot,
    rightUpperLeg, rightLeg, rightFoot,
    leftArm, leftForeArm, rightArm, rightForeArm,
}

local rest: {[Bone]: CFrame} = {}
for _, bone in tracked do
    if bone then
        rest[bone] = bone.Transform
    end
end

local function apply(bone: Bone?, transform: CFrame)
    if bone then
        local base = rest[bone]
        if base then
            bone.Transform = base * transform
        end
    end
end

local phase = 0

RunService.RenderStepped:Connect(function(dt)
    if humanoid.Health <= 0 then
        return
    end

    local velocity = humanoid.MoveDirection.Magnitude
    local speed = humanoid.WalkSpeed

    -- No movement: clean neutral pose.
    if velocity < 0.05 then
        phase = 0
        for bone, base in rest do
            bone.Transform = base
        end
        return
    end

    -- Use actual horizontal velocity when available. Fall back to WalkSpeed.
    local horizontalVelocity = Vector3.new(
        humanoid.RootPart and humanoid.RootPart.AssemblyLinearVelocity.X or 0,
        0,
        humanoid.RootPart and humanoid.RootPart.AssemblyLinearVelocity.Z or 0
    ).Magnitude

    local movementSpeed = math.max(horizontalVelocity, speed * velocity)
    local running = movementSpeed >= 18
    local stride = running and math.rad(30) or math.rad(20)
    local armSwing = running and math.rad(25) or math.rad(18)
    local frequency = running and 9.0 or 6.5

    phase += dt * frequency
    local swing = math.sin(phase)
    local opposite = math.sin(phase + math.pi)
    local bounce = math.abs(math.sin(phase * 2))

    -- Legs: alternating forward/backward swing with a small knee bend.
    apply(leftUpperLeg, CFrame.Angles(opposite * stride, 0, 0))
    apply(rightUpperLeg, CFrame.Angles(swing * stride, 0, 0))
    apply(leftLeg, CFrame.Angles(math.max(0, swing) * stride * 0.55, 0, 0))
    apply(rightLeg, CFrame.Angles(math.max(0, opposite) * stride * 0.55, 0, 0))
    apply(leftFoot, CFrame.Angles(-opposite * stride * 0.25, 0, 0))
    apply(rightFoot, CFrame.Angles(-swing * stride * 0.25, 0, 0))

    -- Arms counter-swing against the legs.
    apply(leftArm, CFrame.Angles(swing * armSwing, 0, 0))
    apply(rightArm, CFrame.Angles(opposite * armSwing, 0, 0))
    apply(leftForeArm, CFrame.Angles(math.max(0, -swing) * armSwing * 0.25, 0, 0))
    apply(rightForeArm, CFrame.Angles(math.max(0, -opposite) * armSwing * 0.25, 0, 0))

    -- Subtle torso/head stabilization and vertical body rhythm.
    apply(hips, CFrame.Angles(0, 0, swing * math.rad(2.0)))
    apply(spine, CFrame.Angles(-math.rad(3.0), 0, swing * math.rad(1.0)))
    apply(spine1, CFrame.Angles(-math.rad(2.0), 0, swing * math.rad(0.7)))
    apply(spine2, CFrame.Angles(-math.rad(1.0), 0, swing * math.rad(0.5)))
    apply(neck, CFrame.Angles(0, 0, -swing * math.rad(1.0)))
    apply(head, CFrame.Angles(0, 0, -swing * math.rad(0.5)))

    -- Small bob through the hips. Transform position is relative to the bone.
    if hips then
        local base = rest[hips]
        if base then
            hips.Transform = base
                * CFrame.new(0, bounce * (running and 0.018 or 0.010), 0)
                * CFrame.Angles(0, 0, swing * math.rad(2.0))
        end
    end
end)

print("[RanAnimationController] Custom locomotion controller active for " .. player.Name)
