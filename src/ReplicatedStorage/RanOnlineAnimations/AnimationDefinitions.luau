--!strict

-- Source-controlled animation definitions for the Ran Online-inspired character.
--
-- IMPORTANT:
-- These are logical animation definitions, not Roblox asset IDs.
-- Published asset IDs will be added only after the corresponding animations
-- are created/verified on the actual character rig in Roblox Studio.

export type AnimationDefinition = {
    AssetId: string?,
    Loop: boolean,
    Priority: Enum.AnimationPriority,
}

export type CharacterAnimationSet = {
    Idle: AnimationDefinition,
    Walk: AnimationDefinition,
    Run: AnimationDefinition,
    Sprint: AnimationDefinition,
}

local Animations: { [string]: CharacterAnimationSet } = {
    Swordsman = {
        Idle = {
            AssetId = nil,
            Loop = true,
            Priority = Enum.AnimationPriority.Idle,
        },
        Walk = {
            AssetId = nil,
            Loop = true,
            Priority = Enum.AnimationPriority.Movement,
        },
        Run = {
            AssetId = nil,
            Loop = true,
            Priority = Enum.AnimationPriority.Movement,
        },
        Sprint = {
            AssetId = nil,
            Loop = true,
            Priority = Enum.AnimationPriority.Movement,
        },
    },
}

return Animations
