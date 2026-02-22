local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

local THROTTLE_INTERVAL = 0.1 -- 100ms

export type PieceState = {
	x: number,
	y: number,
	zIndex: number,
	locked: boolean,
	groupId: number?,
}

export type PuzzleState = {
	pieces: { [number]: PieceState },
	isComplete: boolean,
	claimedPieces: { [number]: number }, -- pieceId → userId
	groups: { [number]: { number } },
}

export type PuzzleActions = {
	scramblePieces: (
		pieceIds: { number },
		areaWidth: number,
		areaHeight: number,
		cellW: number,
		cellH: number,
		boardX: number,
		boardY: number,
		boardW: number,
		boardH: number
	) -> (),
	movePiece: (id: number, x: number, y: number) -> (),
	movePieceLocal: (id: number, x: number, y: number) -> (),
	trySnap: (
		id: number,
		x: number,
		y: number,
		correctX: number,
		correctY: number
	) -> boolean,
	bringToFront: (id: number) -> (),
	restorePieces: (savedPieces: { { id: number, x: number, y: number, zIndex: number, locked: boolean } }) -> (),
	snapPiece: (id: number, x: number, y: number) -> (),
	claimPiece: (id: number) -> (),
	releasePiece: (id: number, x: number, y: number) -> (),
}

local function useMultiplayerPuzzle(initialPieces: { [string]: any }?): (PuzzleState, PuzzleActions)
	local pieces, setPieces = React.useState({} :: { [number]: PieceState })
	local zCounter, setZCounter = React.useState(1)
	local isComplete, setIsComplete = React.useState(false)
	local claimedPieces, setClaimedPieces = React.useState({} :: { [number]: number })
	local groups, setGroups = React.useState({} :: { [number]: { number } })
	local lastSendTime = React.useRef(0)

	-- Initialize pieces from server data
	React.useEffect(function()
		if not initialPieces then return end
		local newPieces: { [number]: PieceState } = {}
		for idStr, pieceData in initialPieces do
			local id = tonumber(idStr)
			if id then
				newPieces[id] = {
					x = pieceData.x,
					y = pieceData.y,
					zIndex = pieceData.zIndex or 1,
					locked = pieceData.locked or false,
					groupId = nil,
				}
			end
		end
		setPieces(newPieces)
		setIsComplete(false)
		setZCounter(2)
		setGroups({})
	end, { initialPieces } :: { any })

	-- Listen for server events
	React.useEffect(function()
		local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
		if not remotes then return end

		local connections: { RBXScriptConnection } = {}

		-- RoomPieceMoved — other player dragging a piece
		local movedEvent = remotes:FindFirstChild("RoomPieceMoved")
		if movedEvent and movedEvent:IsA("RemoteEvent") then
			table.insert(connections, movedEvent.OnClientEvent:Connect(function(data)
				if type(data) ~= "table" or type(data.id) ~= "number" then return end
				setPieces(function(prev)
					local updated = table.clone(prev)
					if updated[data.id] and not updated[data.id].locked then
						updated[data.id] = table.clone(updated[data.id])
						updated[data.id].x = data.x
						updated[data.id].y = data.y
					end
					return updated
				end)
			end))
		end

		-- RoomPieceSnapped — single piece locked in place
		local snappedEvent = remotes:FindFirstChild("RoomPieceSnapped")
		if snappedEvent and snappedEvent:IsA("RemoteEvent") then
			table.insert(connections, snappedEvent.OnClientEvent:Connect(function(data)
				if type(data) ~= "table" or type(data.id) ~= "number" then return end
				local snappedId = data.id
				setPieces(function(prev)
					local updated = table.clone(prev)
					local oldPiece = updated[snappedId]
					local oldGroupId = oldPiece and oldPiece.groupId
					updated[snappedId] = {
						x = data.x,
						y = data.y,
						zIndex = 1,
						locked = true,
						groupId = nil,
					}
					-- If piece was in a group, remove it
					if oldGroupId then
						setGroups(function(prevGroups)
							local newGroups = table.clone(prevGroups)
							local members = newGroups[oldGroupId]
							if members then
								local newMembers = {}
								for _, mid in members do
									if mid ~= snappedId then
										table.insert(newMembers, mid)
									end
								end
								if #newMembers <= 1 then
									-- Dissolve group
									if #newMembers == 1 then
										-- Clear groupId on remaining piece
										setPieces(function(prev2)
											local u = table.clone(prev2)
											local remainId = newMembers[1]
											if u[remainId] then
												u[remainId] = table.clone(u[remainId])
												u[remainId].groupId = nil
											end
											return u
										end)
									end
									newGroups[oldGroupId] = nil
								else
									newGroups[oldGroupId] = newMembers
								end
							end
							return newGroups
						end)
					end
					return updated
				end)
				setClaimedPieces(function(prev)
					local updated = table.clone(prev)
					updated[snappedId] = nil
					return updated
				end)
			end))
		end

		-- RoomGroupFormed — group created/merged
		local groupFormedEvent = remotes:FindFirstChild("RoomGroupFormed")
		if groupFormedEvent and groupFormedEvent:IsA("RemoteEvent") then
			table.insert(connections, groupFormedEvent.OnClientEvent:Connect(function(data)
				if type(data) ~= "table" or type(data.groupId) ~= "number" or type(data.pieces) ~= "table" then return end
				local groupId = data.groupId
				local memberIds = {}

				setPieces(function(prev)
					local updated = table.clone(prev)
					for _, pieceData in data.pieces do
						if type(pieceData) == "table" and type(pieceData.id) == "number" then
							updated[pieceData.id] = table.clone(updated[pieceData.id] or { x = 0, y = 0, zIndex = 1, locked = false })
							updated[pieceData.id].x = pieceData.x
							updated[pieceData.id].y = pieceData.y
							updated[pieceData.id].groupId = groupId
							table.insert(memberIds, pieceData.id)
						end
					end
					return updated
				end)

				setGroups(function(prevGroups)
					local newGroups = table.clone(prevGroups)
					newGroups[groupId] = memberIds
					return newGroups
				end)

				-- Clear claims on all members
				setClaimedPieces(function(prev)
					local updated = table.clone(prev)
					for _, pieceData in data.pieces do
						if type(pieceData) == "table" and type(pieceData.id) == "number" then
							updated[pieceData.id] = nil
						end
					end
					return updated
				end)
			end))
		end

		-- RoomPiecesSnapped — batch grid lock
		local piecesSnappedEvent = remotes:FindFirstChild("RoomPiecesSnapped")
		if piecesSnappedEvent and piecesSnappedEvent:IsA("RemoteEvent") then
			table.insert(connections, piecesSnappedEvent.OnClientEvent:Connect(function(data)
				if type(data) ~= "table" or type(data.pieces) ~= "table" then return end

				-- Collect group IDs to remove
				local groupsToRemove: { [number]: boolean } = {}

				setPieces(function(prev)
					local updated = table.clone(prev)
					for _, pieceData in data.pieces do
						if type(pieceData) == "table" and type(pieceData.id) == "number" then
							local oldPiece = updated[pieceData.id]
							if oldPiece and oldPiece.groupId then
								groupsToRemove[oldPiece.groupId] = true
							end
							updated[pieceData.id] = {
								x = pieceData.x,
								y = pieceData.y,
								zIndex = 1,
								locked = true,
								groupId = nil,
							}
						end
					end
					return updated
				end)

				setGroups(function(prevGroups)
					local newGroups = table.clone(prevGroups)
					for gid in groupsToRemove do
						newGroups[gid] = nil
					end
					return newGroups
				end)

				-- Clear claims
				setClaimedPieces(function(prev)
					local updated = table.clone(prev)
					for _, pieceData in data.pieces do
						if type(pieceData) == "table" and type(pieceData.id) == "number" then
							updated[pieceData.id] = nil
						end
					end
					return updated
				end)
			end))
		end

		-- RoomPieceClaimed — another player grabbed a piece
		local claimedEvent = remotes:FindFirstChild("RoomPieceClaimed")
		if claimedEvent and claimedEvent:IsA("RemoteEvent") then
			table.insert(connections, claimedEvent.OnClientEvent:Connect(function(data)
				if type(data) ~= "table" or type(data.id) ~= "number" then return end
				setClaimedPieces(function(prev)
					local updated = table.clone(prev)
					updated[data.id] = data.userId
					return updated
				end)
			end))
		end

		-- RoomPieceReleased — piece no longer claimed
		local releasedEvent = remotes:FindFirstChild("RoomPieceReleased")
		if releasedEvent and releasedEvent:IsA("RemoteEvent") then
			table.insert(connections, releasedEvent.OnClientEvent:Connect(function(data)
				if type(data) ~= "table" or type(data.id) ~= "number" then return end
				setClaimedPieces(function(prev)
					local updated = table.clone(prev)
					updated[data.id] = nil
					return updated
				end)
			end))
		end

		-- RoomCompleted
		local completedEvent = remotes:FindFirstChild("RoomCompleted")
		if completedEvent and completedEvent:IsA("RemoteEvent") then
			table.insert(connections, completedEvent.OnClientEvent:Connect(function()
				setIsComplete(true)
			end))
		end

		return function()
			for _, conn in connections do
				conn:Disconnect()
			end
		end
	end, {} :: { any })

	-- Actions
	local function claimPiece(id: number)
		local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
		if not remotes then return end
		local event = remotes:FindFirstChild("PieceDragStart")
		if event and event:IsA("RemoteEvent") then
			event:FireServer({ id = id })
		end
		-- Optimistic local claim (piece + group members)
		local localPlayer = game:GetService("Players").LocalPlayer
		if localPlayer then
			setClaimedPieces(function(prev)
				local updated = table.clone(prev)
				updated[id] = localPlayer.UserId
				-- Also claim group members
				local currentPieces = pieces
				local p = currentPieces[id]
				if p and p.groupId then
					local currentGroups = groups
					local members = currentGroups[p.groupId]
					if members then
						for _, mid in members do
							updated[mid] = localPlayer.UserId
						end
					end
				end
				return updated
			end)
		end
	end

	local function movePiece(id: number, x: number, y: number)
		-- Update local state immediately
		setPieces(function(prev)
			local updated = table.clone(prev)
			if updated[id] and not updated[id].locked then
				updated[id] = table.clone(updated[id])
				updated[id].x = x
				updated[id].y = y
			end
			return updated
		end)

		-- Throttled send to server (x, y are already in virtual coords)
		local now = os.clock()
		if now - lastSendTime.current >= THROTTLE_INTERVAL then
			lastSendTime.current = now
			local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
			if remotes then
				local event = remotes:FindFirstChild("PieceMove")
				if event and event:IsA("RemoteEvent") then
					event:FireServer({ id = id, x = x, y = y })
				end
			end
		end
	end

	-- Local-only move (no server send) — used for group followers during drag
	local function movePieceLocal(id: number, x: number, y: number)
		setPieces(function(prev)
			local updated = table.clone(prev)
			if updated[id] and not updated[id].locked then
				updated[id] = table.clone(updated[id])
				updated[id].x = x
				updated[id].y = y
			end
			return updated
		end)
	end

	local function releasePiece(id: number, x: number, y: number)
		-- x, y are already in virtual coords
		local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
		if remotes then
			local event = remotes:FindFirstChild("PieceDragEnd")
			if event and event:IsA("RemoteEvent") then
				event:FireServer({ id = id, x = x, y = y })
			end
		end
		-- Clear local claim on piece and group members
		setClaimedPieces(function(prev)
			local updated = table.clone(prev)
			updated[id] = nil
			local currentPieces = pieces
			local p = currentPieces[id]
			if p and p.groupId then
				local currentGroups = groups
				local members = currentGroups[p.groupId]
				if members then
					for _, mid in members do
						updated[mid] = nil
					end
				end
			end
			return updated
		end)
	end

	-- trySnap: in multiplayer, server handles snapping. We just relay to releasePiece.
	-- Return false so PuzzleBoard doesn't play snap sound (server event will handle it).
	local function trySnap(id: number, x: number, y: number, _correctX: number, _correctY: number): boolean
		releasePiece(id, x, y)
		return false
	end

	-- scramblePieces: no-op in multiplayer (server provides positions)
	local function scramblePieces() end

	-- restorePieces: no-op in multiplayer
	local function restorePieces() end

	-- snapPiece: no-op in multiplayer (server handles)
	local function snapPiece() end

	local function bringToFront(id: number)
		setZCounter(function(prev)
			local newZ = prev + 1
			setPieces(function(prevPieces)
				local updated = table.clone(prevPieces)
				local piece = updated[id]
				if piece and not piece.locked then
					updated[id] = table.clone(piece)
					updated[id].zIndex = newZ

					-- Also bring all group members to front
					if piece.groupId then
						for pid, ps in updated do
							if pid ~= id and ps.groupId == piece.groupId and not ps.locked then
								updated[pid] = table.clone(ps)
								updated[pid].zIndex = newZ
							end
						end
					end
				end
				return updated
			end)
			return newZ
		end)
	end

	local state: PuzzleState = {
		pieces = pieces,
		isComplete = isComplete,
		claimedPieces = claimedPieces,
		groups = groups,
	}

	local actions: PuzzleActions = {
		scramblePieces = scramblePieces,
		movePiece = movePiece,
		movePieceLocal = movePieceLocal,
		trySnap = trySnap,
		bringToFront = bringToFront,
		restorePieces = restorePieces,
		snapPiece = snapPiece,
		claimPiece = claimPiece,
		releasePiece = releasePiece,
	}

	return state, actions
end

return useMultiplayerPuzzle
