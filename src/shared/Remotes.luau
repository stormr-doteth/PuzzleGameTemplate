local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "PuzzleRemotes"

local REMOTE_EVENTS = {
	"PuzzleCompleted",  -- client → server: { imageId, difficultyId, completionTime }
	"XPAwarded",        -- server → client: { xpGained, cashGained, newLevel?, unlockedImages?, isPersonalBest, previousBest? }
}

local REMOTE_FUNCTIONS = {
	"GetPlayerData",    -- returns { level, xp, cash, unlockedImages, personalBests, equipped/owned data }
	"GetLeaderboard",   -- returns { { userId, displayName, time, badge? } }
	"SavePuzzle",       -- client → server: SavedPuzzleData, returns { success, slotIndex }
	"LoadSavedPuzzles", -- client → server: returns { SavedPuzzleData }
	"DeleteSavedPuzzle", -- client → server: slotIndex (number), returns { success }
	"EquipItem",        -- client → server: (itemId, category), returns { success, message }
	"UseHint",          -- client → server: returns { success, hintsRemaining }
}

local Remotes = {}

function Remotes.Init()
	if RunService:IsServer() then
		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage

		for _, name in REMOTE_EVENTS do
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end

		for _, name in REMOTE_FUNCTIONS do
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	else
		ReplicatedStorage:WaitForChild(FOLDER_NAME)
	end
end

function Remotes.GetEvent(name: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.GetFunction(name: string): RemoteFunction
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name) :: RemoteFunction
end

return Remotes
