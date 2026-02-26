local SoundServiceGame = game:GetService("SoundService")

local MusicService = {}

local DEFAULT_PLAYLIST = { "rbxassetid://129922561211527" }
local DEFAULT_VOLUME = 0.3

local playlist: { string } = DEFAULT_PLAYLIST
local currentIndex: number = 1
local sound: Sound? = nil
local endedConnection: RBXScriptConnection? = nil

local function playCurrentTrack()
	if not sound then
		return
	end
	sound.SoundId = playlist[currentIndex]
	sound:Play()
end

local function onTrackEnded()
	currentIndex = currentIndex % #playlist + 1
	playCurrentTrack()
end

function MusicService.Init(customPlaylist: { string }?)
	if customPlaylist and #customPlaylist > 0 then
		playlist = customPlaylist
	end

	currentIndex = 1

	sound = Instance.new("Sound")
	sound.Volume = DEFAULT_VOLUME
	sound.Looped = false
	sound.Name = "BackgroundMusic"
	sound.Parent = SoundServiceGame

	endedConnection = sound.Ended:Connect(onTrackEnded)

	playCurrentTrack()
end

function MusicService.setPlaylist(newPlaylist: { string })
	playlist = newPlaylist
	currentIndex = 1
	playCurrentTrack()
end

function MusicService.setVolume(volume: number)
	if sound then
		sound.Volume = volume
	end
end

function MusicService.pause()
	if sound then
		sound:Pause()
	end
end

function MusicService.resume()
	if sound then
		sound:Resume()
	end
end

return MusicService
