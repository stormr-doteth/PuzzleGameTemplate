local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

local SNAP_THRESHOLD = 25

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
	groups: { [number]: { number } },
}

export type PuzzleActions = {
	scramblePieces: (
		pieceIds: { number },
		areaWidth: number,
		areaHeight: number,
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
		correctY: number,
		puzzleDef: any?,
		pieceImages: any?,
		cellSize: Vector2?,
		pixelScale: number?,
		boardOffsetX: number?,
		boardOffsetY: number?
	) -> boolean,
	bringToFront: (id: number) -> (),
	restorePieces: (savedPieces: { { id: number, x: number, y: number, zIndex: number, locked: boolean, groupId: number? } }, savedGroups: { { id: number, pieceIds: { number } } }?) -> (),
	snapPiece: (id: number, x: number, y: number) -> (),
}

local function usePuzzleState(): (PuzzleState, PuzzleActions)
	local pieces, setPieces = React.useState({} :: { [number]: PieceState })
	local zCounter, setZCounter = React.useState(1)
	local isComplete, setIsComplete = React.useState(false)
	local groups, setGroups = React.useState({} :: { [number]: { number } })
	local nextGroupId, setNextGroupId = React.useState(1)

	local function scramblePieces(
		pieceIds: { number },
		areaWidth: number,
		areaHeight: number,
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
		local topYMax = boardY - gap
		if topYMax >= margin then
			table.insert(zones, {
				xMin = margin,
				xMax = math.max(margin, areaWidth - margin),
				yMin = margin,
				yMax = topYMax,
			})
		end

		-- Bottom zone: full width, below the board
		local bottomYMin = boardY + boardH + gap
		local bottomYMax = areaHeight - margin
		if bottomYMax >= bottomYMin then
			table.insert(zones, {
				xMin = margin,
				xMax = math.max(margin, areaWidth - margin),
				yMin = bottomYMin,
				yMax = bottomYMax,
			})
		end

		-- Left zone: left of board
		local leftXMax = boardX - gap
		if leftXMax >= margin then
			table.insert(zones, {
				xMin = margin,
				xMax = leftXMax,
				yMin = margin,
				yMax = math.max(margin, areaHeight - margin),
			})
		end

		-- Right zone: right of board
		local rightXMin = boardX + boardW + gap
		local rightXMax = areaWidth - margin
		if rightXMax >= rightXMin then
			table.insert(zones, {
				xMin = rightXMin,
				xMax = rightXMax,
				yMin = margin,
				yMax = math.max(margin, areaHeight - margin),
			})
		end

		-- Fallback: if no zones available, use area left of the board
		if #zones == 0 then
			table.insert(zones, {
				xMin = margin,
				xMax = math.max(margin + 1, boardX - gap),
				yMin = margin,
				yMax = math.max(margin + 1, areaHeight - margin),
			})
		end

		for _, id in pieceIds do
			local zone = zones[math.random(1, #zones)]
			newPieces[id] = {
				x = math.random(zone.xMin, zone.xMax),
				y = math.random(zone.yMin, zone.yMax),
				zIndex = 1,
				locked = false,
				groupId = nil,
			}
		end

		setPieces(newPieces)
		setIsComplete(false)
		setZCounter(2)
		setGroups({})
		setNextGroupId(1)
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

	local function snapPiece(id: number, x: number, y: number)
		setPieces(function(prev)
			local updated = table.clone(prev)
			updated[id] = {
				x = x, y = y, zIndex = 1, locked = true, groupId = nil,
			}
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
		-- Remove piece from its group if it was in one
		setGroups(function(prevGroups)
			local newGroups = table.clone(prevGroups)
			for gid, members in newGroups do
				local idx = table.find(members, id)
				if idx then
					local newMembers = table.clone(members)
					table.remove(newMembers, idx)
					if #newMembers <= 1 then
						-- Dissolve single-member group
						if #newMembers == 1 then
							-- Clear groupId on the remaining piece
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
						newGroups[gid] = nil
					else
						newGroups[gid] = newMembers
					end
					break
				end
			end
			return newGroups
		end)
	end

	local function trySnap(
		id: number,
		x: number,
		y: number,
		correctX: number,
		correctY: number,
		puzzleDef: any?,
		pieceImages: any?,
		cellSize: Vector2?,
		pixelScale: number?,
		boardOffsetX: number?,
		boardOffsetY: number?
	): boolean
		local dx = x - correctX
		local dy = y - correctY
		local dist = math.sqrt(dx * dx + dy * dy)

		-- Try grid snap for the individual piece first
		if dist <= SNAP_THRESHOLD then
			-- If piece is in a group, try to grid-snap the whole group
			local currentPieces = pieces
			local pieceData = currentPieces[id]
			local gid = pieceData and pieceData.groupId

			if gid and puzzleDef and pieceImages and cellSize and pixelScale and boardOffsetX and boardOffsetY then
				-- Grid snap entire group
				local currentGroups = groups
				local memberIds = currentGroups[gid]
				if memberIds then
					-- Build lookup for piece defs
					local defById = {}
					for _, pDef in puzzleDef.pieces do
						defById[pDef.id] = pDef
					end

					-- Check all members can grid-snap (compute correct positions)
					local corrections = {}
					for _, memberId in memberIds do
						local mDef = defById[memberId]
						local mImg = pieceImages[memberId]
						if not mDef or not mImg then
							-- Can't snap group
							corrections = nil
							break
						end
						local sox = math.floor(mImg.offsetX * pixelScale)
						local soy = math.floor(mImg.offsetY * pixelScale)
						local cx = boardOffsetX + (mDef.col - 1) * cellSize.X - sox
						local cy = boardOffsetY + (mDef.row - 1) * cellSize.Y - soy
						corrections[memberId] = { x = cx, y = cy }
					end

					if corrections then
						setPieces(function(prev)
							local updated = table.clone(prev)
							for _, memberId in memberIds do
								local corr = corrections[memberId]
								updated[memberId] = {
									x = corr.x,
									y = corr.y,
									zIndex = 1,
									locked = true,
									groupId = nil,
								}
							end
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
						-- Remove the group
						setGroups(function(prevGroups)
							local newGroups = table.clone(prevGroups)
							newGroups[gid] = nil
							return newGroups
						end)
						return true
					end
				end
			end

			-- Single piece grid snap (no group or group snap failed)
			setPieces(function(prev)
				local updated = table.clone(prev)
				updated[id] = {
					x = correctX,
					y = correctY,
					zIndex = 1,
					locked = true,
					groupId = nil,
				}
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
			-- Remove from group if needed
			if gid then
				setGroups(function(prevGroups)
					local newGroups = table.clone(prevGroups)
					local members = newGroups[gid]
					if members then
						local newMembers = table.clone(members)
						local idx = table.find(newMembers, id)
						if idx then
							table.remove(newMembers, idx)
						end
						if #newMembers <= 1 then
							if #newMembers == 1 then
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
							newGroups[gid] = nil
						else
							newGroups[gid] = newMembers
						end
					end
					return newGroups
				end)
			end
			return true
		end

		-- Grid snap failed — try neighbor snap
		if not puzzleDef or not pieceImages or not cellSize or not pixelScale or not boardOffsetX or not boardOffsetY then
			return false
		end

		local currentPieces = pieces
		local currentGroups = groups

		-- Build (row,col) → pieceId lookup
		local gridLookup: { [string]: number } = {}
		local defById: { [number]: any } = {}
		for _, pDef in puzzleDef.pieces do
			gridLookup[pDef.row .. "," .. pDef.col] = pDef.id
			defById[pDef.id] = pDef
		end

		local droppedDef = defById[id]
		if not droppedDef then
			return false
		end

		-- Collect all pieces in the dropped piece's group
		local droppedPiece = currentPieces[id]
		local droppedGroupId = droppedPiece and droppedPiece.groupId
		local droppedSet: { number } = {}
		if droppedGroupId and currentGroups[droppedGroupId] then
			for _, memberId in currentGroups[droppedGroupId] do
				table.insert(droppedSet, memberId)
			end
		else
			table.insert(droppedSet, id)
		end

		-- Build a set for quick membership check
		local droppedSetLookup: { [number]: boolean } = {}
		for _, mid in droppedSet do
			droppedSetLookup[mid] = true
		end

		-- Directions: row offset, col offset
		local directions = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }

		local snappedAny = false
		local mergedGroupId: number? = nil

		-- We need to work with mutable snapshots since we may do multiple merges
		local workingPieces: { [number]: PieceState } = {}
		for pid, ps in currentPieces do
			workingPieces[pid] = table.clone(ps)
		end
		-- Use the actual drop position for the dragged piece (state may be stale)
		if workingPieces[id] then
			workingPieces[id] = table.clone(workingPieces[id])
			workingPieces[id].x = x
			workingPieces[id].y = y
		end
		local workingGroups: { [number]: { number } } = {}
		for gid, members in currentGroups do
			workingGroups[gid] = table.clone(members)
		end
		local workingNextGroupId = nextGroupId

		for _, memberId in droppedSet do
			local memberDef = defById[memberId]
			if not memberDef then continue end
			local memberPiece = workingPieces[memberId]
			if not memberPiece then continue end

			local memberImg = pieceImages[memberId]
			if not memberImg then continue end
			local memberSox = math.floor(memberImg.offsetX * pixelScale)
			local memberSoy = math.floor(memberImg.offsetY * pixelScale)

			for _, dir in directions do
				local nRow = memberDef.row + dir[1]
				local nCol = memberDef.col + dir[2]
				local neighborKey = nRow .. "," .. nCol
				local neighborId = gridLookup[neighborKey]
				if not neighborId then continue end

				local neighborPiece = workingPieces[neighborId]
				if not neighborPiece or neighborPiece.locked then continue end

				-- Skip if already in the same group as the dropped set
				if droppedSetLookup[neighborId] then continue end

				-- Also skip if already merged into the same group this pass
				local neighborGid = neighborPiece.groupId
				local memberGid = workingPieces[memberId].groupId
				if memberGid and neighborGid and memberGid == neighborGid then continue end

				local neighborDef = defById[neighborId]
				if not neighborDef then continue end

				local neighborImg = pieceImages[neighborId]
				if not neighborImg then continue end
				local neighborSox = math.floor(neighborImg.offsetX * pixelScale)
				local neighborSoy = math.floor(neighborImg.offsetY * pixelScale)

				-- Expected relative position (image position of B relative to A)
				local expectedDx = (neighborDef.col - memberDef.col) * cellSize.X - (neighborSox - memberSox)
				local expectedDy = (neighborDef.row - memberDef.row) * cellSize.Y - (neighborSoy - memberSoy)

				-- Actual relative position
				local actualDx = neighborPiece.x - memberPiece.x
				local actualDy = neighborPiece.y - memberPiece.y

				local snapDx = actualDx - expectedDx
				local snapDy = actualDy - expectedDy
				local snapDist = math.sqrt(snapDx * snapDx + snapDy * snapDy)

				if snapDist <= SNAP_THRESHOLD then
					snappedAny = true

					-- Correct the dropped group's positions so alignment is exact
					-- Move all pieces in the dropped set by the correction delta
					local corrX = snapDx
					local corrY = snapDy
					-- Determine the current dropped group members in working state
					local currentDroppedGid = workingPieces[id].groupId
					local piecesToCorrect: { number } = {}
					if currentDroppedGid and workingGroups[currentDroppedGid] then
						for _, pid in workingGroups[currentDroppedGid] do
							table.insert(piecesToCorrect, pid)
						end
					else
						table.insert(piecesToCorrect, id)
					end

					for _, pid in piecesToCorrect do
						local wp = workingPieces[pid]
						if wp then
							workingPieces[pid] = table.clone(wp)
							workingPieces[pid].x = wp.x + corrX
							workingPieces[pid].y = wp.y + corrY
						end
					end

					-- Now merge groups
					-- Determine what group the neighbor belongs to
					local targetGroupMembers: { number } = {}
					if neighborGid and workingGroups[neighborGid] then
						for _, pid in workingGroups[neighborGid] do
							table.insert(targetGroupMembers, pid)
						end
					else
						table.insert(targetGroupMembers, neighborId)
					end

					local sourceGroupMembers: { number } = {}
					local sourceGid = workingPieces[id].groupId
					if sourceGid and workingGroups[sourceGid] then
						for _, pid in workingGroups[sourceGid] do
							table.insert(sourceGroupMembers, pid)
						end
					else
						table.insert(sourceGroupMembers, id)
					end

					-- Create or pick a group ID for the merged group
					local finalGid: number
					if neighborGid then
						finalGid = neighborGid
					elseif sourceGid then
						finalGid = sourceGid
					else
						finalGid = workingNextGroupId
						workingNextGroupId = workingNextGroupId + 1
					end

					-- Merge all into finalGid
					local finalMembers: { [number]: boolean } = {}
					for _, pid in targetGroupMembers do
						finalMembers[pid] = true
					end
					for _, pid in sourceGroupMembers do
						finalMembers[pid] = true
					end

					-- Build final member list
					local finalList: { number } = {}
					for pid in finalMembers do
						table.insert(finalList, pid)
					end

					-- Remove old groups
					if neighborGid and neighborGid ~= finalGid then
						workingGroups[neighborGid] = nil
					end
					if sourceGid and sourceGid ~= finalGid then
						workingGroups[sourceGid] = nil
					end

					-- Set the merged group
					workingGroups[finalGid] = finalList

					-- Update all member pieces
					for _, pid in finalList do
						local wp = workingPieces[pid]
						if wp then
							workingPieces[pid] = table.clone(wp)
							workingPieces[pid].groupId = finalGid
						end
						-- Update dropped set lookup
						droppedSetLookup[pid] = true
					end

					mergedGroupId = finalGid
					break -- Re-check from outer loop after this merge
				end
			end

			if snappedAny then
				break -- We did a merge; we'll apply and let the next drop re-check
			end
		end

		if not snappedAny then
			return false
		end

		-- Apply working state
		setPieces(function(_prev)
			return workingPieces
		end)
		setGroups(function(_prev)
			return workingGroups
		end)
		setNextGroupId(workingNextGroupId)

		-- After merge, try grid snap for the merged group
		if mergedGroupId and workingGroups[mergedGroupId] then
			local memberIds = workingGroups[mergedGroupId]
			-- Pick the dropped piece and check its grid distance
			local testDef = defById[id]
			local testImg = pieceImages[id]
			local testPiece = workingPieces[id]
			if testDef and testImg and testPiece then
				local sox = math.floor(testImg.offsetX * pixelScale)
				local soy = math.floor(testImg.offsetY * pixelScale)
				local cx = boardOffsetX + (testDef.col - 1) * cellSize.X - sox
				local cy = boardOffsetY + (testDef.row - 1) * cellSize.Y - soy
				local gdx = testPiece.x - cx
				local gdy = testPiece.y - cy
				local gdist = math.sqrt(gdx * gdx + gdy * gdy)

				if gdist <= SNAP_THRESHOLD then
					-- Lock all group members at correct grid positions
					local corrections = {}
					local canSnap = true
					for _, memberId in memberIds do
						local mDef = defById[memberId]
						local mImg = pieceImages[memberId]
						if not mDef or not mImg then
							canSnap = false
							break
						end
						local mSox = math.floor(mImg.offsetX * pixelScale)
						local mSoy = math.floor(mImg.offsetY * pixelScale)
						corrections[memberId] = {
							x = boardOffsetX + (mDef.col - 1) * cellSize.X - mSox,
							y = boardOffsetY + (mDef.row - 1) * cellSize.Y - mSoy,
						}
					end

					if canSnap then
						setPieces(function(prev)
							local updated = table.clone(prev)
							for _, memberId in memberIds do
								local corr = corrections[memberId]
								updated[memberId] = {
									x = corr.x,
									y = corr.y,
									zIndex = 1,
									locked = true,
									groupId = nil,
								}
							end
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
						setGroups(function(prevGroups)
							local newGroups = table.clone(prevGroups)
							newGroups[mergedGroupId] = nil
							return newGroups
						end)
					end
				end
			end
		end

		return true
	end

	local function restorePieces(
		savedPieces: { { id: number, x: number, y: number, zIndex: number, locked: boolean, groupId: number? } },
		savedGroups: { { id: number, pieceIds: { number } } }?
	)
		local restored: { [number]: PieceState } = {}
		local maxZ = 1
		for _, p in savedPieces do
			restored[p.id] = {
				x = p.x, y = p.y, zIndex = p.zIndex,
				locked = p.locked, groupId = p.groupId,
			}
			if p.zIndex > maxZ then maxZ = p.zIndex end
		end
		setPieces(restored)
		setZCounter(maxZ + 1)
		setIsComplete(false)

		-- Restore groups
		if savedGroups then
			local restoredGroups: { [number]: { number } } = {}
			local maxGid = 0
			for _, g in savedGroups do
				restoredGroups[g.id] = g.pieceIds
				if g.id > maxGid then maxGid = g.id end
			end
			setGroups(restoredGroups)
			setNextGroupId(maxGid + 1)
		else
			setGroups({})
			setNextGroupId(1)
		end
	end

	local function bringToFront(id: number)
		setZCounter(function(prev)
			local newZ = prev + 1
			setPieces(function(prevPieces)
				local updated = table.clone(prevPieces)
				local piece = updated[id]
				if piece and not piece.locked then
					-- Bring the piece itself
					updated[id] = table.clone(piece)
					updated[id].zIndex = newZ

					-- Also bring all group members
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
		groups = groups,
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
