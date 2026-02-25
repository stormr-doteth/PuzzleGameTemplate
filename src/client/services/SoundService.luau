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
local hoverSound: Sound? = nil

function PuzzleSoundService.playSnap()
	if not snapSound then
		snapSound = createSound("rbxassetid://123690431798959", 0.35)
	end
	snapSound:Play()
end

function PuzzleSoundService.playPickup()
	if not pickupSound then
		pickupSound = createSound("rbxassetid://122502346223377", 0.25)
		pickupSound.PlaybackSpeed = 1.3
	end
	pickupSound:Play()
end

function PuzzleSoundService.playHover()
	if not hoverSound then
		hoverSound = createSound("rbxassetid://122502346223377", 0.15)
		hoverSound.PlaybackSpeed = 1.5
	end
	hoverSound:Play()
end

function PuzzleSoundService.playComplete()
	if not completeSound then
		completeSound = createSound("rbxassetid://80691547303377", 0.6)
	end
	completeSound:Play()
end

return PuzzleSoundService
