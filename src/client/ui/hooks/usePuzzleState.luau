local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

local SNAP_THRESHOLD = 25

export type PieceState = {
	x: number,
	y: number,
	zIndex: number,
	locked: boolean,
}

export type PuzzleState = {
	pieces: { [number]: PieceState },
	isComplete: boolean,
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
}

local function usePuzzleState(): (PuzzleState, PuzzleActions)
	local pieces, setPieces = React.useState({} :: { [number]: PieceState })
	local zCounter, setZCounter = React.useState(1)
	local isComplete, setIsComplete = React.useState(false)

	local function checkComplete(currentPieces: { [number]: PieceState })
		for _, piece in currentPieces do
			if not piece.locked then
				return false
			end
		end
		return true
	end

	local function scramblePieces(
		pieceIds: { number },
		areaWidth: number,
		areaHeight: number,
		cellW: number,
		cellH: number,
		boardX: number,
		boardY: number,
		boardW: number,
		boardH: number
	)
		local newPieces: { [number]: PieceState } = {}
		local margin = 20
		local gap = 10

		-- Build edge zones that avoid the board rectangle
		type Zone = { xMin: number, xMax: number, yMin: number, yMax: number }
		local zones: { Zone } = {}

		-- Top zone: full width, above the board
		local topYMax = boardY - cellH - gap
		if topYMax >= margin then
			table.insert(zones, {
				xMin = margin,
				xMax = math.max(margin, areaWidth - cellW - margin),
				yMin = margin,
				yMax = topYMax,
			})
		end

		-- Bottom zone: full width, below the board
		local bottomYMin = boardY + boardH + gap
		local bottomYMax = areaHeight - cellH - margin
		if bottomYMax >= bottomYMin then
			table.insert(zones, {
				xMin = margin,
				xMax = math.max(margin, areaWidth - cellW - margin),
				yMin = bottomYMin,
				yMax = bottomYMax,
			})
		end

		-- Left zone: left of board, between top and bottom board edges
		local leftXMax = boardX - cellW - gap
		if leftXMax >= margin then
			table.insert(zones, {
				xMin = margin,
				xMax = leftXMax,
				yMin = margin,
				yMax = math.max(margin, areaHeight - cellH - margin),
			})
		end

		-- Right zone: right of board, between top and bottom board edges
		local rightXMin = boardX + boardW + gap
		local rightXMax = areaWidth - cellW - margin
		if rightXMax >= rightXMin then
			table.insert(zones, {
				xMin = rightXMin,
				xMax = rightXMax,
				yMin = margin,
				yMax = math.max(margin, areaHeight - cellH - margin),
			})
		end

		-- Fallback: if no zones available, use full area
		if #zones == 0 then
			table.insert(zones, {
				xMin = margin,
				xMax = math.max(margin + 1, areaWidth - cellW - margin),
				yMin = margin,
				yMax = math.max(margin + 1, areaHeight - cellH - margin),
			})
		end

		for _, id in pieceIds do
			local zone = zones[math.random(1, #zones)]
			newPieces[id] = {
				x = math.random(zone.xMin, zone.xMax),
				y = math.random(zone.yMin, zone.yMax),
				zIndex = 1,
				locked = false,
			}
		end

		setPieces(newPieces)
		setIsComplete(false)
		setZCounter(2)
	end

	local function movePiece(id: number, x: number, y: number)
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

	local function trySnap(
		id: number,
		x: number,
		y: number,
		correctX: number,
		correctY: number
	): boolean
		local dx = x - correctX
		local dy = y - correctY
		local dist = math.sqrt(dx * dx + dy * dy)

		if dist <= SNAP_THRESHOLD then
			setPieces(function(prev)
				local updated = table.clone(prev)
				updated[id] = {
					x = correctX,
					y = correctY,
					zIndex = 1, -- locked pieces sit just above the grid
					locked = true,
				}
				-- Check completion
				local complete = true
				for _, piece in updated do
					if not piece.locked then
						complete = false
						break
					end
				end
				if complete then
					task.defer(function()
						setIsComplete(true)
					end)
				end
				return updated
			end)
			return true
		end
		return false
	end

	local function restorePieces(savedPieces: { { id: number, x: number, y: number, zIndex: number, locked: boolean } })
		local restored: { [number]: PieceState } = {}
		local maxZ = 1
		for _, p in savedPieces do
			restored[p.id] = { x = p.x, y = p.y, zIndex = p.zIndex, locked = p.locked }
			if p.zIndex > maxZ then maxZ = p.zIndex end
		end
		setPieces(restored)
		setZCounter(maxZ + 1)
		setIsComplete(false)
	end

	local function snapPiece(id: number, x: number, y: number)
		setPieces(function(prev)
			local updated = table.clone(prev)
			updated[id] = { x = x, y = y, zIndex = 1, locked = true }
			local complete = true
			for _, piece in updated do
				if not piece.locked then
					complete = false
					break
				end
			end
			if complete then
				task.defer(function()
					setIsComplete(true)
				end)
			end
			return updated
		end)
	end

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
	}

	local actions: PuzzleActions = {
		scramblePieces = scramblePieces,
		movePiece = movePiece,
		trySnap = trySnap,
		bringToFront = bringToFront,
		restorePieces = restorePieces,
		snapPiece = snapPiece,
	}

	return state, actions
end

return usePuzzleState
