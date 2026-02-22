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
local SCATTER_PAD = 300

local function generateScrambledPositions(puzzleDef: any, config: any): { [number]: any }
	local pieces: { [number]: any } = {}
	local margin = 20

	-- Board area in virtual coords
	local boardX = 0
	local boardY = 0
	local boardW = VIRTUAL_W
	local boardH = VIRTUAL_H

	-- Scatter area extends beyond the virtual canvas so pieces land outside the board
	local scatterXMin = -SCATTER_PAD
	local scatterXMax = VIRTUAL_W + SCATTER_PAD
	local scatterYMin = -SCATTER_PAD
	local scatterYMax = VIRTUAL_H + SCATTER_PAD

	-- Scatter pieces around the edges of the board
	type Zone = { xMin: number, xMax: number, yMin: number, yMax: number }
	local zones: { Zone } = {}
	local gap = 10

	-- Top zone
	local topYMax = boardY - gap
	if topYMax > scatterYMin + margin then
		table.insert(zones, { xMin = scatterXMin + margin, xMax = scatterXMax - margin, yMin = scatterYMin + margin, yMax = topYMax })
	end
	-- Bottom zone
	local bottomYMin = boardY + boardH + gap
	if scatterYMax - margin > bottomYMin then
		table.insert(zones, { xMin = scatterXMin + margin, xMax = scatterXMax - margin, yMin = bottomYMin, yMax = scatterYMax - margin })
	end
	-- Left zone
	local leftXMax = boardX - gap
	if leftXMax > scatterXMin + margin then
		table.insert(zones, { xMin = scatterXMin + margin, xMax = leftXMax, yMin = scatterYMin + margin, yMax = scatterYMax - margin })
	end
	-- Right zone
	local rightXMin = boardX + boardW + gap
	if scatterXMax - margin > rightXMin then
		table.insert(zones, { xMin = rightXMin, xMax = scatterXMax - margin, yMin = scatterYMin + margin, yMax = scatterYMax - margin })
	end

	-- Fallback: scatter in the padded area but avoid the board
	if #zones == 0 then
		table.insert(zones, { xMin = scatterXMin + margin, xMax = math.max(scatterXMin + margin + 1, boardX - gap), yMin = scatterYMin + margin, yMax = scatterYMax - margin })
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
			groupId = nil,
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

-- Reusable leave-room logic
local function leavePlayer(player: Player)
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

-- Internal API: create room without going through remotes
function RoomManager.CreateRoomInternal(player: Player): string?
	local userId = player.UserId

	if playerRooms[userId] then
		return nil
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
		groups = {},
		nextGroupId = 1,
	}
	playerRooms[userId] = roomId

	print(string.format("[RoomManager] %s created room %s (internal)", player.Name, roomId))
	return roomId
end

-- Internal API: join room without going through remotes
function RoomManager.JoinRoomInternal(player: Player, roomId: string): boolean
	local userId = player.UserId

	if playerRooms[userId] then
		return false
	end

	local room = rooms[roomId]
	if not room then
		return false
	end

	if room.state ~= "lobby" then
		return false
	end

	-- Count players
	local count = 0
	for _ in room.players do count += 1 end
	if count >= MAX_PLAYERS then
		return false
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

	print(string.format("[RoomManager] %s joined room %s (internal)", player.Name, roomId))
	return true
end

-- Internal API: leave room
function RoomManager.LeaveRoomInternal(player: Player)
	leavePlayer(player)
end

-- Internal API: leave player (also used by Players.PlayerRemoving)
function RoomManager.LeavePlayer(player: Player)
	leavePlayer(player)
end

-- Internal API: get room info for a given roomId
function RoomManager.GetRoomInfo(roomId: string): any
	local room = rooms[roomId]
	if not room then return nil end
	return getRoomInfo(room)
end

-- Internal API: get the roomId for a player
function RoomManager.GetPlayerRoom(player: Player): string?
	return playerRooms[player.UserId]
end

function RoomManager.Init()
	-- RemoteFunctions
	local createRoom = Remotes.GetFunction("CreateRoom")
	local joinRoom = Remotes.GetFunction("JoinRoom")
	local leaveRoom = Remotes.GetFunction("LeaveRoom")
	local configureRoom = Remotes.GetFunction("ConfigureRoom")
	local startRoom = Remotes.GetFunction("StartRoom")
	local restartRoom = Remotes.GetFunction("RestartRoom")

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
			groups = {},
			nextGroupId = 1,
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
		return leavePlayer(player)
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

	-- RestartRoom — host resets room back to lobby after completion
	restartRoom.OnServerInvoke = function(player, sameConfig)
		local userId = player.UserId
		local roomId = playerRooms[userId]
		if not roomId then return { error = "Not in a room" } end

		local room = rooms[roomId]
		if not room then return { error = "Room not found" } end
		if room.hostUserId ~= userId then return { error = "Only the host can restart" } end
		if room.state ~= "complete" then return { error = "Room is not complete" } end

		-- Reset puzzle state
		room.state = "lobby"
		room.pieces = nil
		room.puzzleDef = nil
		room.groups = {}
		room.nextGroupId = 1
		room.zCounter = 1
		room.startTime = nil

		if sameConfig == false then
			room.config = nil
		end

		fireToAll(room, "RoomReturnedToLobby", { config = room.config })

		print(string.format("[RoomManager] Room %s returned to lobby (sameConfig=%s)", roomId, tostring(sameConfig ~= false)))
		return { success = true }
	end

	-- PieceDragStart — claim a piece (and all group members)
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

		-- Collect all pieces to claim (piece + group members)
		local piecesToClaim = { pieceId }
		if piece.groupId and room.groups[piece.groupId] then
			piecesToClaim = {}
			for _, memberId in room.groups[piece.groupId] do
				local memberPiece = room.pieces[memberId]
				if memberPiece and not memberPiece.locked then
					-- If any group member is claimed by someone else, reject
					if memberPiece.claimedBy and memberPiece.claimedBy ~= userId then
						return
					end
					table.insert(piecesToClaim, memberId)
				end
			end
		end

		local now = os.clock()
		room.zCounter += 1
		local newZ = room.zCounter

		for _, claimId in piecesToClaim do
			local p = room.pieces[claimId]
			p.claimedBy = userId
			p.claimedAt = now
			p.zIndex = newZ
			fireToRoom(room, "RoomPieceClaimed", { id = claimId, userId = userId }, userId)
		end
	end)

	-- PieceMove — relay drag position (with group movement)
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

		-- Capture old position for delta
		local oldX, oldY = piece.x, piece.y
		local dx = data.x - oldX
		local dy = data.y - oldY

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

		-- Move group members by the same delta
		if piece.groupId and room.groups[piece.groupId] then
			for _, memberId in room.groups[piece.groupId] do
				if memberId ~= pieceId then
					local memberPiece = room.pieces[memberId]
					if memberPiece and not memberPiece.locked then
						memberPiece.x = memberPiece.x + dx
						memberPiece.y = memberPiece.y + dy
						fireToRoom(room, "RoomPieceMoved", {
							id = memberId,
							x = memberPiece.x,
							y = memberPiece.y,
							userId = userId,
						}, userId)
					end
				end
			end
		end
	end)

	-- Helper: lock a group of pieces at their correct grid positions, broadcast, dissolve group, check completion
	local function lockGroupAtGrid(room: any, memberIds: { number }, roomId: string)
		local piecesSnappedData = {}
		for _, mid in memberIds do
			local mPiece = room.pieces[mid]
			if not mPiece then continue end
			-- Find definition
			local mDef = nil
			for _, p in room.puzzleDef.pieces do
				if p.id == mid then mDef = p break end
			end
			if not mDef then continue end
			local cx, cy = getCorrectPosition(mDef, room.config)
			mPiece.x = cx
			mPiece.y = cy
			mPiece.locked = true
			mPiece.claimedBy = nil
			mPiece.claimedAt = nil
			mPiece.zIndex = 1
			local gid = mPiece.groupId
			mPiece.groupId = nil
			-- Remove from group tracking
			if gid and room.groups[gid] then
				room.groups[gid] = nil
			end
			table.insert(piecesSnappedData, { id = mid, x = cx, y = cy })
		end
		fireToAll(room, "RoomPiecesSnapped", { pieces = piecesSnappedData })

		if checkCompletion(room) then
			room.state = "complete"
			fireToAll(room, "RoomCompleted", {})
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
	end

	-- Helper: release claims on a list of pieces
	local function releasePieces(room: any, pieceIds: { number })
		for _, pid in pieceIds do
			local p = room.pieces[pid]
			if p then
				p.claimedBy = nil
				p.claimedAt = nil
			end
			fireToRoom(room, "RoomPieceReleased", { id = pid }, nil)
		end
	end

	-- PieceDragEnd — three-phase snap: grid snap, neighbor snap, post-merge grid snap
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

		-- Update drop position (and sync group followers)
		local oldX, oldY = piece.x, piece.y
		piece.x = data.x
		piece.y = data.y

		if piece.groupId and room.groups[piece.groupId] then
			local dx = data.x - oldX
			local dy = data.y - oldY
			for _, memberId in room.groups[piece.groupId] do
				if memberId ~= pieceId then
					local memberPiece = room.pieces[memberId]
					if memberPiece and not memberPiece.locked then
						memberPiece.x += dx
						memberPiece.y += dy
					end
				end
			end
		end

		-- Build defById lookup
		local defById: { [number]: any } = {}
		for _, p in room.puzzleDef.pieces do
			defById[p.id] = p
		end

		local pieceDef = defById[pieceId]
		if not pieceDef then return end

		-- Collect all pieces to release on no-snap
		local allInvolved = { pieceId }
		if piece.groupId and room.groups[piece.groupId] then
			allInvolved = {}
			for _, mid in room.groups[piece.groupId] do
				table.insert(allInvolved, mid)
			end
		end

		local config = room.config
		local cellW = VIRTUAL_W / config.cols
		local cellH = VIRTUAL_H / config.rows

		-- ========== PHASE 1: Grid snap ==========
		local correctX, correctY = getCorrectPosition(pieceDef, config)
		local gdx = data.x - correctX
		local gdy = data.y - correctY
		local gdist = math.sqrt(gdx * gdx + gdy * gdy)

		if gdist <= SNAP_THRESHOLD then
			if piece.groupId and room.groups[piece.groupId] then
				-- Lock entire group
				local memberIds = room.groups[piece.groupId]
				lockGroupAtGrid(room, memberIds, roomId)
			else
				-- Single piece grid snap
				piece.x = correctX
				piece.y = correctY
				piece.locked = true
				piece.claimedBy = nil
				piece.claimedAt = nil
				piece.zIndex = 1

				fireToAll(room, "RoomPieceSnapped", { id = pieceId, x = correctX, y = correctY })

				if checkCompletion(room) then
					room.state = "complete"
					fireToAll(room, "RoomCompleted", {})
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
			end
			return
		end

		-- ========== PHASE 2: Neighbor snap ==========
		-- Build (row,col) → pieceId lookup
		local gridLookup: { [string]: number } = {}
		for _, pDef in room.puzzleDef.pieces do
			gridLookup[pDef.row .. "," .. pDef.col] = pDef.id
		end

		-- Collect dropped set
		local droppedSet: { number } = {}
		local droppedSetLookup: { [number]: boolean } = {}
		if piece.groupId and room.groups[piece.groupId] then
			for _, mid in room.groups[piece.groupId] do
				table.insert(droppedSet, mid)
				droppedSetLookup[mid] = true
			end
		else
			table.insert(droppedSet, pieceId)
			droppedSetLookup[pieceId] = true
		end

		local directions = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }
		local snappedNeighbor = false
		local mergedGroupId: number? = nil

		for _, memberId in droppedSet do
			local memberDef = defById[memberId]
			if not memberDef then continue end
			local memberPiece = room.pieces[memberId]
			if not memberPiece then continue end

			for _, dir in directions do
				local nRow = memberDef.row + dir[1]
				local nCol = memberDef.col + dir[2]
				local neighborId = gridLookup[nRow .. "," .. nCol]
				if not neighborId then continue end

				local neighborPiece = room.pieces[neighborId]
				if not neighborPiece or neighborPiece.locked then continue end
				if droppedSetLookup[neighborId] then continue end

				-- Skip if already in same group
				local neighborGid = neighborPiece.groupId
				local memberGid = memberPiece.groupId
				if memberGid and neighborGid and memberGid == neighborGid then continue end

				local neighborDef = defById[neighborId]
				if not neighborDef then continue end

				-- Expected relative position (virtual coords, no image offsets)
				local expectedDx = (neighborDef.col - memberDef.col) * cellW
				local expectedDy = (neighborDef.row - memberDef.row) * cellH

				local actualDx = neighborPiece.x - memberPiece.x
				local actualDy = neighborPiece.y - memberPiece.y

				local snapDx = actualDx - expectedDx
				local snapDy = actualDy - expectedDy
				local snapDist = math.sqrt(snapDx * snapDx + snapDy * snapDy)

				if snapDist <= SNAP_THRESHOLD then
					snappedNeighbor = true

					-- Correct dropped group positions by the snap delta
					local currentDroppedGid = room.pieces[pieceId].groupId
					local piecesToCorrect: { number } = {}
					if currentDroppedGid and room.groups[currentDroppedGid] then
						for _, pid in room.groups[currentDroppedGid] do
							table.insert(piecesToCorrect, pid)
						end
					else
						table.insert(piecesToCorrect, pieceId)
					end

					for _, pid in piecesToCorrect do
						local wp = room.pieces[pid]
						if wp then
							wp.x = wp.x + snapDx
							wp.y = wp.y + snapDy
						end
					end

					-- Merge groups
					local targetGroupMembers: { number } = {}
					if neighborGid and room.groups[neighborGid] then
						for _, pid in room.groups[neighborGid] do
							table.insert(targetGroupMembers, pid)
						end
					else
						table.insert(targetGroupMembers, neighborId)
					end

					local sourceGroupMembers: { number } = {}
					local sourceGid = room.pieces[pieceId].groupId
					if sourceGid and room.groups[sourceGid] then
						for _, pid in room.groups[sourceGid] do
							table.insert(sourceGroupMembers, pid)
						end
					else
						table.insert(sourceGroupMembers, pieceId)
					end

					-- Pick or create group ID
					local finalGid: number
					if neighborGid then
						finalGid = neighborGid
					elseif sourceGid then
						finalGid = sourceGid
					else
						finalGid = room.nextGroupId
						room.nextGroupId = room.nextGroupId + 1
					end

					-- Merge all into finalGid
					local finalSet: { [number]: boolean } = {}
					for _, pid in targetGroupMembers do finalSet[pid] = true end
					for _, pid in sourceGroupMembers do finalSet[pid] = true end

					local finalList: { number } = {}
					for pid in finalSet do table.insert(finalList, pid) end

					-- Remove old groups
					if neighborGid and neighborGid ~= finalGid then
						room.groups[neighborGid] = nil
					end
					if sourceGid and sourceGid ~= finalGid then
						room.groups[sourceGid] = nil
					end

					-- Set merged group
					room.groups[finalGid] = finalList

					-- Update all member pieces
					for _, pid in finalList do
						local wp = room.pieces[pid]
						if wp then
							wp.groupId = finalGid
						end
					end

					mergedGroupId = finalGid

					-- Build group formed payload
					local groupPieces = {}
					for _, pid in finalList do
						local wp = room.pieces[pid]
						if wp then
							table.insert(groupPieces, { id = pid, x = wp.x, y = wp.y })
						end
					end
					fireToAll(room, "RoomGroupFormed", { groupId = finalGid, pieces = groupPieces })

					-- Clear claims on all members
					for _, pid in finalList do
						local wp = room.pieces[pid]
						if wp then
							wp.claimedBy = nil
							wp.claimedAt = nil
						end
					end

					break -- stop checking after first merge
				end
			end

			if snappedNeighbor then break end
		end

		if snappedNeighbor then
			-- ========== PHASE 3: Post-merge grid snap ==========
			if mergedGroupId and room.groups[mergedGroupId] then
				-- Check if the dropped piece is near its correct grid position
				local testPiece = room.pieces[pieceId]
				local testDef = defById[pieceId]
				if testPiece and testDef then
					local cx, cy = getCorrectPosition(testDef, config)
					local pgdx = testPiece.x - cx
					local pgdy = testPiece.y - cy
					local pgdist = math.sqrt(pgdx * pgdx + pgdy * pgdy)

					if pgdist <= SNAP_THRESHOLD then
						lockGroupAtGrid(room, room.groups[mergedGroupId], roomId)
					end
				end
			end
			return
		end

		-- ========== No snap — release all involved pieces ==========
		piece.x = data.x
		piece.y = data.y
		releasePieces(room, allInvolved)
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
