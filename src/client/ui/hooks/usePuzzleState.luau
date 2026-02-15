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
		boardWidth: number,
		boardHeight: number,
		cellW: number,
		cellH: number
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
		boardWidth: number,
		boardHeight: number,
		cellW: number,
		cellH: number
	)
		local newPieces: { [number]: PieceState } = {}
		local margin = 20

		for _, id in pieceIds do
			newPieces[id] = {
				x = math.random(margin, math.max(margin + 1, boardWidth - cellW - margin)),
				y = math.random(margin, math.max(margin + 1, boardHeight - cellH - margin)),
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
	}

	return state, actions
end

return usePuzzleState
