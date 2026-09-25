--!strict

-- Runtime locomotion for the Ran Online skinned character.
--
-- IMPORTANT:
-- Do not invent Bone.Transform axes for a Mixamo skeleton. The imported
-- skeleton has authored joint orientations, so arbitrary CFrame.Angles()
-- rotations can twist/stretch the mesh. Use the actual KeyframeSequences
-- authored for this rig instead.
--
-- Roblox supports localized Studio playback of a KeyframeSequence through
-- KeyframeSequenceProvider:RegisterActiveKeyframeSequence(). This avoids
-- requiring a published AnimationId while we are developing in Studio.

local Players = game:GetService("Players")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local root = character:WaitForChild("HumanoidRootPart") :: BasePart
local animator = humanoid:WaitForChild("Animator") :: Animator

-- Roblox may inject the legacy Animate LocalScript. It is incompatible with
-- this non-R6 rig, so disable it if present.
local animate = character:FindFirstChild("Animate")
if animate and animate:IsA("LocalScript") then
	animate.Enabled = false
end

local function findSequence(name: string): KeyframeSequence?
	local candidate = character:FindFirstChild(name, true)
	if candidate and candidate:IsA("KeyframeSequence") then
		return candidate
	end

	-- Saved Animation Editor data is commonly kept under AnimSaves.
	local animSaves = character:FindFirstChild("AnimSaves", true)
	if animSaves then
		candidate = animSaves:FindFirstChild(name, true)
		if candidate and candidate:IsA("KeyframeSequence") then
			return candidate
		end
	end

	return nil
end

local function makeTrack(sequence: KeyframeSequence, label: string): AnimationTrack?
	local ok, contentId = pcall(function()
		return KeyframeSequenceProvider:RegisterActiveKeyframeSequence(sequence)
	end)

	if not ok then
		warn("[RanLocomotion] Could not register " .. label .. ": " .. tostring(contentId))
		return nil
	end

	local animation = Instance.new("Animation")
	animation.Name = "Ran_" .. label .. "_Runtime"
	animation.AnimationId = contentId
	animation.Parent = script

	local loaded, result = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	if not loaded then
		warn("[RanLocomotion] Could not load " .. label .. ": " .. tostring(result))
		animation:Destroy()
		return nil
	end

	local track = result :: AnimationTrack
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Movement

	print(string.format(
		"[RanLocomotion] Loaded %s | length=%.3f | id=%s",
		label,
		track.Length,
		tostring(contentId)
	))

	return track
end

local walkSequence = findSequence("Swordsman_Walk")
local runSequence = findSequence("Swordsman_Run")

if not walkSequence then
	warn("[RanLocomotion] Swordsman_Walk KeyframeSequence is missing from the character")
end
if not runSequence then
	warn("[RanLocomotion] Swordsman_Run KeyframeSequence is missing from the character")
end

local walkTrack = if walkSequence then makeTrack(walkSequence, "Walk") else nil
local runTrack = if runSequence then makeTrack(runSequence, "Run") else nil

if not walkTrack and not runTrack then
	warn("[RanLocomotion] No authored locomotion sequences are available. No procedural bone deformation will be applied.")
	return
end

local active: AnimationTrack? = nil

local function stopTrack(track: AnimationTrack?)
	if track and track.IsPlaying then
		track:Stop(0.15)
	end
end

local function selectTrack(target: AnimationTrack?)
	if active == target then
		return
	end

	stopTrack(active)
	active = target

	if active then
		active:Play(0.15, 1, 1)
	end
end

RunService.RenderStepped:Connect(function()
	if humanoid.Health <= 0 then
		selectTrack(nil)
		return
	end

	local moveAmount = humanoid.MoveDirection.Magnitude
	local horizontalVelocity = Vector3.new(
		root.AssemblyLinearVelocity.X,
		0,
		root.AssemblyLinearVelocity.Z
	).Magnitude

	if moveAmount < 0.05 or horizontalVelocity < 0.15 then
		selectTrack(nil)
		return
	end

	-- WalkSpeed is 16. Keep run as the higher-speed state without changing
	-- the character's actual movement speed.
	local target = if horizontalVelocity >= 12 then runTrack else walkTrack

	-- If one authored clip is unavailable, use the other instead of applying
	-- unsafe procedural Bone.Transform rotations.
	if not target then
		target = if walkTrack then walkTrack else runTrack
	end

	selectTrack(target)

	if active then
		local baseSpeed = if active == runTrack then 1.10 else 1.0
		local scale = math.clamp(horizontalVelocity / math.max(humanoid.WalkSpeed, 1), 0.75, 1.35)
		active:AdjustSpeed(baseSpeed * scale)
	end
end)

print("[RanLocomotion] Authored locomotion controller active for " .. player.Name)
