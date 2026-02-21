local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

local THROTTLE_INTERVAL = 0.1 -- 100ms

export type PieceState = {
	x: number,
	y: number,
	zIndex: number,
	locked: boolean,
}

export type PuzzleState = {
	pieces: { [number]: PieceState },
	isComplete: boolean,
	claimedPieces: { [number]: number }, -- pieceId → userId
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
				}
			end
		end
		setPieces(newPieces)
		setIsComplete(false)
		setZCounter(2)
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

		-- RoomPieceSnapped — piece locked in place
		local snappedEvent = remotes:FindFirstChild("RoomPieceSnapped")
		if snappedEvent and snappedEvent:IsA("RemoteEvent") then
			table.insert(connections, snappedEvent.OnClientEvent:Connect(function(data)
				if type(data) ~= "table" or type(data.id) ~= "number" then return end
				setPieces(function(prev)
					local updated = table.clone(prev)
					updated[data.id] = {
						x = data.x,
						y = data.y,
						zIndex = 1,
						locked = true,
					}
					return updated
				end)
				setClaimedPieces(function(prev)
					local updated = table.clone(prev)
					updated[data.id] = nil
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
		-- Optimistic local claim
		local localPlayer = game:GetService("Players").LocalPlayer
		if localPlayer then
			setClaimedPieces(function(prev)
				local updated = table.clone(prev)
				updated[id] = localPlayer.UserId
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

	local function releasePiece(id: number, x: number, y: number)
		-- x, y are already in virtual coords
		local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
		if remotes then
			local event = remotes:FindFirstChild("PieceDragEnd")
			if event and event:IsA("RemoteEvent") then
				event:FireServer({ id = id, x = x, y = y })
			end
		end
		-- Clear local claim (server will confirm snap or release)
		setClaimedPieces(function(prev)
			local updated = table.clone(prev)
			updated[id] = nil
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
				if updated[id] and not updated[id].locked then
					updated[id] = table.clone(updated[id])
					updated[id].zIndex = newZ
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
	}

	local actions: PuzzleActions = {
		scramblePieces = scramblePieces,
		movePiece = movePiece,
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
