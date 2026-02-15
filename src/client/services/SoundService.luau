local SoundServiceGame = game:GetService("SoundService")

local PuzzleSoundService = {}

local function createSound(soundId: string, volume: number): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.Parent = SoundServiceGame
	return sound
end

local snapSound: Sound? = nil
local pickupSound: Sound? = nil
local completeSound: Sound? = nil

function PuzzleSoundService.playSnap()
	if not snapSound then
		snapSound = createSound("rbxassetid://9114727610", 0.5)
	end
	snapSound:Play()
end

function PuzzleSoundService.playPickup()
	if not pickupSound then
		pickupSound = createSound("rbxassetid://9114727610", 0.25)
		pickupSound.PlaybackSpeed = 1.3
	end
	pickupSound:Play()
end

function PuzzleSoundService.playComplete()
	if not completeSound then
		completeSound = createSound("rbxassetid://9064916719", 0.6)
	end
	completeSound:Play()
end

return PuzzleSoundService
