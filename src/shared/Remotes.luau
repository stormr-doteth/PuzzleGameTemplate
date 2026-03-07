local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "PuzzleRemotes"

local REMOTE_EVENTS = {
	"PuzzleCompleted",  -- client → server: { imageId, difficultyId, completionTime }
	"XPAwarded",        -- server → client: { cashGained, isPersonalBest, isSpeedBonus, previousBest? }
	"HintPurchased",    -- server → client: notifies that a Robux hint was granted
	"SetPendingUnlock", -- client → server: sets imageId before Robux purchase
	"ImageUnlockedRobux", -- server → client: { imageId } notifies Robux unlock succeeded

	-- Multiplayer room events (server → client)
	"RoomPlayerJoined",   -- server → clients: { player: RoomPlayer }
	"RoomPlayerLeft",     -- server → clients: { userId, newHostUserId? }
	"RoomConfigUpdated",  -- server → clients: { config: RoomConfig }
	"RoomPuzzleStarted",  -- server → clients: { puzzleDef, pieces, config }
	"RoomPieceMoved",     -- server → clients: { id, x, y, userId }
	"RoomPieceSnapped",   -- server → all: { id, x, y }
	"RoomPieceClaimed",   -- server → others: { id, userId }
	"RoomPieceReleased",  -- server → others: { id }
	"RoomGroupFormed",    -- server → all: { groupId, pieces: { { id, x, y } } }
	"RoomPiecesSnapped",  -- server → all: { pieces: { { id, x, y } } } (batch grid lock)
	"RoomCompleted",      -- server → all: room complete
	"RoomDestroyed",      -- server → all: room was closed
	"RoomReturnedToLobby", -- server → all: { config: RoomConfig? } (room reset to lobby)

	-- Multiplayer piece events (client → server)
	"PieceMove",          -- client → server: { id, x, y } (throttled drag position)
	"PieceDragStart",     -- client → server: { id }
	"PieceDragEnd",       -- client → server: { id, x, y }

	-- Cafe seating events (server → client)
	"PlayerSeated",           -- server → client: { tableId, tableType, seatIndex, roomId? }
	"PlayerUnseated",         -- server → client: {}
	"TableOccupancyChanged",  -- server → all: { tableId, occupants }

	-- Daily puzzle events
	"DailyPuzzleCompleted",   -- client → server: { imageId, difficultyId, completionTime }
}

local REMOTE_FUNCTIONS = {
	"GetPlayerData",    -- returns { cash, unlockedImages, personalBests, titleName, equipped/owned data }
	"GetLeaderboard",   -- returns { { userId, displayName, time, badge? } }
	"SavePuzzle",       -- client → server: SavedPuzzleData, returns { success, slotIndex }
	"LoadSavedPuzzles", -- client → server: returns { SavedPuzzleData }
	"DeleteSavedPuzzle", -- client → server: slotIndex (number), returns { success }
	"EquipItem",        -- client → server: (itemId, category), returns { success, message }
	"UseHint",          -- client → server: returns { success, hintsRemaining }
	"UnlockImage",      -- client → server: (imageId) → { success, newCash }

	-- Multiplayer room functions (client → server)
	"CreateRoom",       -- returns { roomId } or { error }
	"JoinRoom",         -- (roomId) → { roomInfo } or { error }
	"LeaveRoom",        -- returns { success }
	"ConfigureRoom",    -- (config) → { success }
	"StartRoom",        -- returns { success } or { error }
	"RestartRoom",      -- (sameConfig: boolean) → { success } or { error }

	-- Cafe table functions
	"GetTableInfo",     -- (tableId) → { tableType, occupants, roomId? }

	-- Daily features
	"ClaimDailyReward",       -- returns { success, reward }
	"GetDailyRewardStatus",   -- returns { streak, canClaim, rewards }
	"GetDailyPuzzle",         -- returns { puzzle, completed, leaderboard }
	"GetDailyPuzzleLeaderboard", -- returns top 20 times
	"SpinWheel",              -- returns { success, segmentIndex, reward }
	"GetSpinWheelStatus",     -- returns { canFreeSpin, extraSpinCost }
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
