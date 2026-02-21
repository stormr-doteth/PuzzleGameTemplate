local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local PuzzleGenerator = require(Shared.PuzzleGenerator)
local ProgressionConfig = require(Shared.ProgressionConfig)
local RoomTypes = require(Shared.RoomTypes)

local ProfileService = require(script.Parent.Parent.data.ProfileService)

local VIRTUAL_W = RoomTypes.VIRTUAL_CANVAS_WIDTH
local VIRTUAL_H = RoomTypes.VIRTUAL_CANVAS_HEIGHT
local MAX_PLAYERS = 4
local SNAP_THRESHOLD = 25 -- in virtual canvas coords
local CLAIM_EXPIRE_SECONDS = 10
local LOBBY_TIMEOUT = 30 * 60  -- 30 minutes
local PLAYING_TIMEOUT = 3 * 60 * 60  -- 3 hours
local HEARTBEAT_INTERVAL = 30

local CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" -- no I/O/0/1 to avoid confusion

-- In-memory room data
local rooms: { [string]: any } = {}
local playerRooms: { [number]: string } = {}

local RoomManager = {}

-- Generate a unique 6-char room code
local function generateRoomCode(): string
	for _ = 1, 100 do
		local code = ""
		for _ = 1, 6 do
			local idx = math.random(1, #CODE_CHARS)
			code ..= string.sub(CODE_CHARS, idx, idx)
		end
		if not rooms[code] then
			return code
		end
	end
	error("Failed to generate unique room code")
end

-- Get list of players in a room as RoomPlayer objects
local function getPlayerList(room: any): { any }
	local list = {}
	for userId, playerData in room.players do
		table.insert(list, {
			userId = userId,
			displayName = playerData.displayName,
			isHost = userId == room.hostUserId,
		})
	end
	return list
end

-- Get RoomInfo for a room
local function getRoomInfo(room: any): any
	return {
		roomId = room.roomId,
		state = room.state,
		players = getPlayerList(room),
		config = room.config,
		hostUserId = room.hostUserId,
	}
end

-- Fire an event to all players in a room
local function fireToRoom(room: any, eventName: string, data: any, excludeUserId: number?)
	local event = Remotes.GetEvent(eventName)
	for userId in room.players do
		if userId ~= excludeUserId then
			local player = Players:GetPlayerByUserId(userId)
			if player then
				event:FireClient(player, data)
			end
		end
	end
end

-- Fire an event to all players in a room (no exclusion)
local function fireToAll(room: any, eventName: string, data: any)
	fireToRoom(room, eventName, data, nil)
end

-- Destroy a room and notify players
local function destroyRoom(roomId: string)
	local room = rooms[roomId]
	if not room then return end

	fireToAll(room, "RoomDestroyed", { roomId = roomId })

	for userId in room.players do
		playerRooms[userId] = nil
	end
	rooms[roomId] = nil
end

-- Generate scrambled piece positions in virtual canvas coordinates
local function generateScrambledPositions(puzzleDef: any, config: any): { [number]: any }
	local pieces: { [number]: any } = {}
	local cellW = VIRTUAL_W / config.cols
	local cellH = VIRTUAL_H / config.rows
	local margin = 20

	-- Board area in virtual coords (centered)
	local boardW = cellW * config.cols
	local boardH = cellH * config.rows
	local boardX = (VIRTUAL_W - boardW) / 2
	local boardY = (VIRTUAL_H - boardH) / 2

	-- Scatter pieces around the edges of the virtual canvas
	type Zone = { xMin: number, xMax: number, yMin: number, yMax: number }
	local zones: { Zone } = {}
	local gap = 10

	local topYMax = boardY - cellH - gap
	if topYMax >= margin then
		table.insert(zones, { xMin = margin, xMax = math.max(margin, VIRTUAL_W - cellW - margin), yMin = margin, yMax = topYMax })
	end
	local bottomYMin = boardY + boardH + gap
	local bottomYMax = VIRTUAL_H - cellH - margin
	if bottomYMax >= bottomYMin then
		table.insert(zones, { xMin = margin, xMax = math.max(margin, VIRTUAL_W - cellW - margin), yMin = bottomYMin, yMax = bottomYMax })
	end
	local leftXMax = boardX - cellW - gap
	if leftXMax >= margin then
		table.insert(zones, { xMin = margin, xMax = leftXMax, yMin = margin, yMax = math.max(margin, VIRTUAL_H - cellH - margin) })
	end
	local rightXMin = boardX + boardW + gap
	local rightXMax = VIRTUAL_W - cellW - margin
	if rightXMax >= rightXMin then
		table.insert(zones, { xMin = rightXMin, xMax = rightXMax, yMin = margin, yMax = math.max(margin, VIRTUAL_H - cellH - margin) })
	end

	-- Fallback
	if #zones == 0 then
		table.insert(zones, { xMin = margin, xMax = math.max(margin + 1, VIRTUAL_W - cellW - margin), yMin = margin, yMax = math.max(margin + 1, VIRTUAL_H - cellH - margin) })
	end

	for _, pieceDef in puzzleDef.pieces do
		local zone = zones[math.random(1, #zones)]
		pieces[pieceDef.id] = {
			x = math.random(math.floor(zone.xMin), math.floor(zone.xMax)),
			y = math.random(math.floor(zone.yMin), math.floor(zone.yMax)),
			zIndex = 1,
			locked = false,
			claimedBy = nil,
			claimedAt = nil,
		}
	end

	return pieces
end

-- Get the correct virtual position for a piece
local function getCorrectPosition(pieceDef: any, config: any): (number, number)
	local cellW = VIRTUAL_W / config.cols
	local cellH = VIRTUAL_H / config.rows
	local boardW = cellW * config.cols
	local boardH = cellH * config.rows
	local boardX = (VIRTUAL_W - boardW) / 2
	local boardY = (VIRTUAL_H - boardH) / 2
	return boardX + (pieceDef.col - 1) * cellW, boardY + (pieceDef.row - 1) * cellH
end

-- Check if all pieces in a room are locked
local function checkCompletion(room: any): boolean
	if not room.pieces then return false end
	for _, piece in room.pieces do
		if not piece.locked then
			return false
		end
	end
	return true
end

-- Award XP to a player (reuses PuzzleHandler logic pattern)
local function awardCompletion(player: Player, room: any)
	local config = room.config
	if not config then return end

	local startTime = room.startTime or os.clock()
	local completionTime = os.clock() - startTime

	local profileData = ProfileService.GetData(player)
	if not profileData then return end

	local baseXP = ProgressionConfig.XP_BY_DIFFICULTY[config.difficultyId] or 0
	local parTime = ProgressionConfig.PAR_TIMES[config.difficultyId]
	local isSpeedBonus = parTime and completionTime <= parTime
	local xpGained = baseXP
	if isSpeedBonus then
		xpGained = math.floor(baseXP * ProgressionConfig.SPEED_BONUS_MULTIPLIER)
	end
	local cashGained = math.floor(xpGained * ProgressionConfig.CASH_PER_XP)

	local oldLevel = profileData.Level
	profileData.XP = profileData.XP + xpGained
	profileData.Cash = profileData.Cash + cashGained
	profileData.TotalPuzzlesCompleted = (profileData.TotalPuzzlesCompleted or 0) + 1
	profileData.TotalPlayTime = (profileData.TotalPlayTime or 0) + completionTime

	local grid = ProgressionConfig.DIFFICULTY_GRID[config.difficultyId]
	if grid then
		profileData.TotalPiecesPlaced = (profileData.TotalPiecesPlaced or 0) + (grid.rows * grid.cols)
	end
	if not profileData.PuzzlesCompletedByDifficulty then
		profileData.PuzzlesCompletedByDifficulty = {}
	end
	profileData.PuzzlesCompletedByDifficulty[config.difficultyId] = (profileData.PuzzlesCompletedByDifficulty[config.difficultyId] or 0) + 1

	local newLevel = ProgressionConfig.getLevelFromXP(profileData.XP)
	profileData.Level = newLevel

	local newlyUnlocked = {}
	if newLevel > oldLevel then
		if not profileData.UnlockedImages then
			profileData.UnlockedImages = {}
		end
		local allUnlocked = ProgressionConfig.getUnlockedImagesAtLevel(newLevel)
		for _, imgId in allUnlocked do
			if not profileData.UnlockedImages[imgId] then
				profileData.UnlockedImages[imgId] = true
				table.insert(newlyUnlocked, imgId)
			end
		end
	end

	local xpAwarded = Remotes.GetEvent("XPAwarded")
	xpAwarded:FireClient(player, {
		xpGained = xpGained,
		cashGained = cashGained,
		newLevel = if newLevel > oldLevel then newLevel else nil,
		unlockedImages = if #newlyUnlocked > 0 then newlyUnlocked else nil,
		isPersonalBest = false,
		isSpeedBonus = isSpeedBonus,
	})
end

-- Release all claims held by a user in a room
local function releaseAllClaims(room: any, userId: number)
	if not room.pieces then return end
	for pieceId, piece in room.pieces do
		if piece.claimedBy == userId then
			piece.claimedBy = nil
			piece.claimedAt = nil
			fireToRoom(room, "RoomPieceReleased", { id = pieceId }, nil)
		end
	end
end

function RoomManager.Init()
	-- RemoteFunctions
	local createRoom = Remotes.GetFunction("CreateRoom")
	local joinRoom = Remotes.GetFunction("JoinRoom")
	local leaveRoom = Remotes.GetFunction("LeaveRoom")
	local configureRoom = Remotes.GetFunction("ConfigureRoom")
	local startRoom = Remotes.GetFunction("StartRoom")

	-- RemoteEvents (client → server)
	local pieceDragStart = Remotes.GetEvent("PieceDragStart")
	local pieceMove = Remotes.GetEvent("PieceMove")
	local pieceDragEnd = Remotes.GetEvent("PieceDragEnd")

	-- CreateRoom
	createRoom.OnServerInvoke = function(player)
		local userId = player.UserId

		-- Player can only be in one room at a time
		if playerRooms[userId] then
			return { error = "Already in a room" }
		end

		local roomId = generateRoomCode()
		rooms[roomId] = {
			roomId = roomId,
			state = "lobby",
			hostUserId = userId,
			players = {
				[userId] = {
					displayName = player.DisplayName,
				},
			},
			config = nil,
			pieces = nil,
			puzzleDef = nil,
			zCounter = 1,
			startTime = nil,
			createdAt = os.clock(),
		}
		playerRooms[userId] = roomId

		print(string.format("[RoomManager] %s created room %s", player.Name, roomId))
		return { roomId = roomId, roomInfo = getRoomInfo(rooms[roomId]) }
	end

	-- JoinRoom
	joinRoom.OnServerInvoke = function(player, roomId)
		local userId = player.UserId

		if playerRooms[userId] then
			return { error = "Already in a room" }
		end

		if type(roomId) ~= "string" then
			return { error = "Invalid room code" }
		end

		roomId = string.upper(roomId)
		local room = rooms[roomId]
		if not room then
			return { error = "Room not found" }
		end

		if room.state ~= "lobby" then
			return { error = "Room is already in progress" }
		end

		-- Count players
		local count = 0
		for _ in room.players do count += 1 end
		if count >= MAX_PLAYERS then
			return { error = "Room is full" }
		end

		room.players[userId] = {
			displayName = player.DisplayName,
		}
		playerRooms[userId] = roomId

		-- Broadcast to existing players
		fireToRoom(room, "RoomPlayerJoined", {
			player = {
				userId = userId,
				displayName = player.DisplayName,
				isHost = false,
			},
		}, userId)

		print(string.format("[RoomManager] %s joined room %s", player.Name, roomId))
		return { roomInfo = getRoomInfo(room) }
	end

	-- LeaveRoom
	leaveRoom.OnServerInvoke = function(player)
		local userId = player.UserId
		local roomId = playerRooms[userId]
		if not roomId then
			return { success = false }
		end

		local room = rooms[roomId]
		if not room then
			playerRooms[userId] = nil
			return { success = false }
		end

		-- Release any claims
		releaseAllClaims(room, userId)

		-- Remove player
		room.players[userId] = nil
		playerRooms[userId] = nil

		-- Check if room is empty
		local hasPlayers = false
		for _ in room.players do
			hasPlayers = true
			break
		end

		if not hasPlayers then
			destroyRoom(roomId)
			print(string.format("[RoomManager] Room %s destroyed (empty)", roomId))
		else
			-- Promote new host if needed
			local newHostUserId = nil
			if userId == room.hostUserId then
				for nextUserId in room.players do
					room.hostUserId = nextUserId
					newHostUserId = nextUserId
					break
				end
			end

			fireToAll(room, "RoomPlayerLeft", {
				userId = userId,
				newHostUserId = newHostUserId,
			})

			print(string.format("[RoomManager] %s left room %s", player.Name, roomId))
		end

		return { success = true }
	end

	-- ConfigureRoom
	configureRoom.OnServerInvoke = function(player, config)
		local userId = player.UserId
		local roomId = playerRooms[userId]
		if not roomId then return { success = false } end

		local room = rooms[roomId]
		if not room then return { success = false } end
		if room.hostUserId ~= userId then return { success = false } end
		if room.state ~= "lobby" then return { success = false } end

		if type(config) ~= "table" then return { success = false } end
		if type(config.imageAssetId) ~= "string" or type(config.imageId) ~= "string" then
			return { success = false }
		end
		if type(config.difficultyId) ~= "string" or type(config.rows) ~= "number" or type(config.cols) ~= "number" then
			return { success = false }
		end

		room.config = {
			imageAssetId = config.imageAssetId,
			imageId = config.imageId,
			difficultyId = config.difficultyId,
			rows = config.rows,
			cols = config.cols,
		}

		fireToRoom(room, "RoomConfigUpdated", { config = room.config }, nil)
		return { success = true }
	end

	-- StartRoom
	startRoom.OnServerInvoke = function(player)
		local userId = player.UserId
		local roomId = playerRooms[userId]
		if not roomId then return { error = "Not in a room" } end

		local room = rooms[roomId]
		if not room then return { error = "Room not found" } end
		if room.hostUserId ~= userId then return { error = "Only the host can start" } end
		if room.state ~= "lobby" then return { error = "Room already started" } end
		if not room.config then return { error = "No puzzle configured" } end

		-- Generate puzzle on server
		local config = room.config
		local puzzleDef = PuzzleGenerator.generatePuzzle(config.rows, config.cols)
		room.puzzleDef = puzzleDef
		room.pieces = generateScrambledPositions(puzzleDef, config)
		room.state = "playing"
		room.startTime = os.clock()
		room.zCounter = 2

		-- Build serializable pieces table
		local piecesData = {}
		for pieceId, piece in room.pieces do
			piecesData[tostring(pieceId)] = {
				x = piece.x,
				y = piece.y,
				zIndex = piece.zIndex,
				locked = piece.locked,
			}
		end

		fireToAll(room, "RoomPuzzleStarted", {
			puzzleDef = puzzleDef,
			pieces = piecesData,
			config = config,
		})

		print(string.format("[RoomManager] Room %s started (%dx%d)", roomId, config.rows, config.cols))
		return { success = true }
	end

	-- PieceDragStart — claim a piece
	pieceDragStart.OnServerEvent:Connect(function(player, data)
		local userId = player.UserId
		local roomId = playerRooms[userId]
		if not roomId then return end

		local room = rooms[roomId]
		if not room or room.state ~= "playing" or not room.pieces then return end

		if type(data) ~= "table" or type(data.id) ~= "number" then return end
		local pieceId = data.id
		local piece = room.pieces[pieceId]
		if not piece then return end
		if piece.locked then return end

		-- Check if already claimed by someone else
		if piece.claimedBy and piece.claimedBy ~= userId then
			return
		end

		piece.claimedBy = userId
		piece.claimedAt = os.clock()

		-- Bring to front
		room.zCounter += 1
		piece.zIndex = room.zCounter

		fireToRoom(room, "RoomPieceClaimed", { id = pieceId, userId = userId }, userId)
	end)

	-- PieceMove — relay drag position
	pieceMove.OnServerEvent:Connect(function(player, data)
		local userId = player.UserId
		local roomId = playerRooms[userId]
		if not roomId then return end

		local room = rooms[roomId]
		if not room or room.state ~= "playing" or not room.pieces then return end

		if type(data) ~= "table" or type(data.id) ~= "number" then return end
		if type(data.x) ~= "number" or type(data.y) ~= "number" then return end

		local pieceId = data.id
		local piece = room.pieces[pieceId]
		if not piece then return end
		if piece.locked then return end
		if piece.claimedBy ~= userId then return end

		-- Update server-side position
		piece.x = data.x
		piece.y = data.y

		-- Relay to other clients
		fireToRoom(room, "RoomPieceMoved", {
			id = pieceId,
			x = data.x,
			y = data.y,
			userId = userId,
		}, userId)
	end)

	-- PieceDragEnd — check snap or release
	pieceDragEnd.OnServerEvent:Connect(function(player, data)
		local userId = player.UserId
		local roomId = playerRooms[userId]
		if not roomId then return end

		local room = rooms[roomId]
		if not room or room.state ~= "playing" or not room.pieces or not room.puzzleDef then return end

		if type(data) ~= "table" or type(data.id) ~= "number" then return end
		if type(data.x) ~= "number" or type(data.y) ~= "number" then return end

		local pieceId = data.id
		local piece = room.pieces[pieceId]
		if not piece then return end
		if piece.locked then return end
		if piece.claimedBy ~= userId then return end

		-- Find piece definition
		local pieceDef = nil
		for _, p in room.puzzleDef.pieces do
			if p.id == pieceId then
				pieceDef = p
				break
			end
		end
		if not pieceDef then return end

		local correctX, correctY = getCorrectPosition(pieceDef, room.config)
		local dx = data.x - correctX
		local dy = data.y - correctY
		local dist = math.sqrt(dx * dx + dy * dy)

		if dist <= SNAP_THRESHOLD then
			-- Snap!
			piece.x = correctX
			piece.y = correctY
			piece.locked = true
			piece.claimedBy = nil
			piece.claimedAt = nil
			piece.zIndex = 1

			fireToAll(room, "RoomPieceSnapped", { id = pieceId, x = correctX, y = correctY })

			-- Check completion
			if checkCompletion(room) then
				room.state = "complete"
				fireToAll(room, "RoomCompleted", {})

				-- Award XP to each player
				for pUserId in room.players do
					local p = Players:GetPlayerByUserId(pUserId)
					if p then
						task.spawn(function()
							awardCompletion(p, room)
						end)
					end
				end

				print(string.format("[RoomManager] Room %s completed!", roomId))
			end
		else
			-- No snap, release
			piece.x = data.x
			piece.y = data.y
			piece.claimedBy = nil
			piece.claimedAt = nil

			fireToRoom(room, "RoomPieceReleased", { id = pieceId }, nil)
		end
	end)

	-- Player disconnect handling
	Players.PlayerRemoving:Connect(function(player)
		local userId = player.UserId
		local roomId = playerRooms[userId]
		if not roomId then return end

		local room = rooms[roomId]
		if not room then
			playerRooms[userId] = nil
			return
		end

		releaseAllClaims(room, userId)
		room.players[userId] = nil
		playerRooms[userId] = nil

		local hasPlayers = false
		for _ in room.players do
			hasPlayers = true
			break
		end

		if not hasPlayers then
			destroyRoom(roomId)
		else
			local newHostUserId = nil
			if userId == room.hostUserId then
				for nextUserId in room.players do
					room.hostUserId = nextUserId
					newHostUserId = nextUserId
					break
				end
			end

			fireToAll(room, "RoomPlayerLeft", {
				userId = userId,
				newHostUserId = newHostUserId,
			})
		end
	end)

	-- Heartbeat cleanup
	task.spawn(function()
		while true do
			task.wait(HEARTBEAT_INTERVAL)
			local now = os.clock()

			for roomId, room in rooms do
				-- Expire stale claims
				if room.pieces then
					for pieceId, piece in room.pieces do
						if piece.claimedBy and piece.claimedAt and (now - piece.claimedAt) > CLAIM_EXPIRE_SECONDS then
							piece.claimedBy = nil
							piece.claimedAt = nil
							fireToAll(room, "RoomPieceReleased", { id = pieceId })
						end
					end
				end

				-- Destroy stale rooms
				local age = now - room.createdAt
				if room.state == "lobby" and age > LOBBY_TIMEOUT then
					print(string.format("[RoomManager] Room %s expired (lobby timeout)", roomId))
					destroyRoom(roomId)
				elseif room.state == "playing" and age > PLAYING_TIMEOUT then
					print(string.format("[RoomManager] Room %s expired (playing timeout)", roomId))
					destroyRoom(roomId)
				end

				-- Destroy empty rooms
				local hasPlayers = false
				if rooms[roomId] then -- might have been destroyed above
					for _ in room.players do
						hasPlayers = true
						break
					end
					if not hasPlayers then
						destroyRoom(roomId)
					end
				end
			end
		end
	end)

	print("[RoomManager] Initialized")
end

return RoomManager
