local AssetService = game:GetService("AssetService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PuzzleTypes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PuzzleTypes"))

type PieceDefinition = PuzzleTypes.PieceDefinition
type PuzzleDefinition = PuzzleTypes.PuzzleDefinition
type PieceImageData = PuzzleTypes.PieceImageData

local TAB_WIDTH_RATIO = 0.35
local TAB_HEIGHT_RATIO = 0.18
local AA_RADIUS = 2
local OUTLINE_THICKNESS = 4

local PieceMasker = {}

-- Check if a point is inside a tab semicircle on a given edge
-- Returns: distance from the semicircle boundary (negative = inside, positive = outside)
local function semicircleSignedDistance(
	px: number,
	py: number,
	centerX: number,
	centerY: number,
	radius: number,
	edgeSide: string -- "top", "bottom", "left", "right"
): number
	local dx = px - centerX
	local dy = py - centerY
	local dist = math.sqrt(dx * dx + dy * dy)

	-- Check if on the correct side of the edge for the semicircle
	local onCorrectSide = false
	if edgeSide == "top" then
		onCorrectSide = py <= centerY
	elseif edgeSide == "bottom" then
		onCorrectSide = py >= centerY
	elseif edgeSide == "left" then
		onCorrectSide = px <= centerX
	elseif edgeSide == "right" then
		onCorrectSide = px >= centerX
	end

	if onCorrectSide then
		return dist - radius
	else
		-- On the wrong side of the flat edge, use distance from the diameter line
		if edgeSide == "top" or edgeSide == "bottom" then
			if math.abs(dx) <= radius then
				return dist - radius
			end
		else
			if math.abs(dy) <= radius then
				return dist - radius
			end
		end
		return dist - radius
	end
end

-- Compute the signed distance from a pixel to the piece boundary.
-- Negative = inside the piece, positive = outside.
local function getPieceSignedDistance(
	px: number, -- x in piece image space (0-based)
	py: number, -- y in piece image space (0-based)
	cellW: number,
	cellH: number,
	tabW: number,
	tabH: number,
	padTop: number,
	padRight: number,
	padBottom: number,
	padLeft: number,
	edges: PuzzleTypes.PieceEdges
): number
	-- Convert to cell-local coordinates where (0,0) is top-left of the base cell
	local cx = px - padLeft
	local cy = py - padTop

	-- Start by checking if inside base rectangle
	local inBaseRect = cx >= 0 and cx < cellW and cy >= 0 and cy < cellH

	-- Calculate tab/indent semicircle centers and radii for each edge
	local tabRadius = tabW / 2

	-- Base rectangle signed distance (negative = inside)
	local baseDistX = math.max(-cx, cx - cellW)
	local baseDistY = math.max(-cy, cy - cellH)
	local baseDist = math.max(baseDistX, baseDistY)

	-- Start with base rect signed distance
	-- For a union/subtraction SDF, we combine using min (union) and max (intersection/subtraction)
	local dist = baseDist

	-- Top edge
	if edges.top == "tab" then
		local tcx = cellW / 2
		local tcy = 0
		local sd = semicircleSignedDistance(cx, cy, tcx, tcy, tabRadius, "top")
		-- Union: piece = base rect OR tab semicircle
		dist = math.min(dist, sd)
	elseif edges.top == "indent" then
		local tcx = cellW / 2
		local tcy = 0
		local sd = semicircleSignedDistance(cx, cy, tcx, tcy, tabRadius, "bottom")
		-- Subtraction: piece = base rect AND NOT indent semicircle
		dist = math.max(dist, -sd)
	end

	-- Bottom edge
	if edges.bottom == "tab" then
		local tcx = cellW / 2
		local tcy = cellH
		local sd = semicircleSignedDistance(cx, cy, tcx, tcy, tabRadius, "bottom")
		dist = math.min(dist, sd)
	elseif edges.bottom == "indent" then
		local tcx = cellW / 2
		local tcy = cellH
		local sd = semicircleSignedDistance(cx, cy, tcx, tcy, tabRadius, "top")
		dist = math.max(dist, -sd)
	end

	-- Left edge
	if edges.left == "tab" then
		local tcx = 0
		local tcy = cellH / 2
		local sd = semicircleSignedDistance(cx, cy, tcx, tcy, tabRadius, "left")
		dist = math.min(dist, sd)
	elseif edges.left == "indent" then
		local tcx = 0
		local tcy = cellH / 2
		local sd = semicircleSignedDistance(cx, cy, tcx, tcy, tabRadius, "right")
		dist = math.max(dist, -sd)
	end

	-- Right edge
	if edges.right == "tab" then
		local tcx = cellW
		local tcy = cellH / 2
		local sd = semicircleSignedDistance(cx, cy, tcx, tcy, tabRadius, "right")
		dist = math.min(dist, sd)
	elseif edges.right == "indent" then
		local tcx = cellW
		local tcy = cellH / 2
		local sd = semicircleSignedDistance(cx, cy, tcx, tcy, tabRadius, "left")
		dist = math.max(dist, -sd)
	end

	return dist
end

-- Determine if a pixel (in local piece coordinates) is inside the jigsaw piece shape
-- Returns a value: 1 = fully inside, 0 = fully outside, 0..1 = anti-aliased edge
local function getPieceAlpha(
	px: number, -- x in piece image space (0-based)
	py: number, -- y in piece image space (0-based)
	cellW: number,
	cellH: number,
	tabW: number,
	tabH: number,
	padTop: number,
	padRight: number,
	padBottom: number,
	padLeft: number,
	edges: PuzzleTypes.PieceEdges
): number
	-- Convert to cell-local coordinates where (0,0) is top-left of the base cell
	local cx = px - padLeft
	local cy = py - padTop

	-- Start by checking if inside base rectangle
	local inBaseRect = cx >= 0 and cx < cellW and cy >= 0 and cy < cellH

	-- Calculate tab/indent semicircle centers and radii for each edge
	local tabRadius = tabW / 2
	local minDist = math.huge -- minimum signed distance to any boundary

	-- Start with base rect
	local insidePiece = inBaseRect

	-- Top edge
	if edges.top == "tab" then
		local tcx = cellW / 2
		local tcy = 0
		local sd = semicircleSignedDistance(cx, cy, tcx, tcy, tabRadius, "top")
		if sd < 0 then
			insidePiece = true
			if not inBaseRect then
				minDist = math.min(minDist, math.abs(sd))
			end
		end
	elseif edges.top == "indent" then
		local tcx = cellW / 2
		local tcy = 0
		local sd = semicircleSignedDistance(cx, cy, tcx, tcy, tabRadius, "bottom")
		if sd < 0 and inBaseRect then
			insidePiece = false
		end
		if sd < 0 and inBaseRect then
			minDist = math.min(minDist, math.abs(sd))
		end
	end

	-- Bottom edge
	if edges.bottom == "tab" then
		local tcx = cellW / 2
		local tcy = cellH
		local sd = semicircleSignedDistance(cx, cy, tcx, tcy, tabRadius, "bottom")
		if sd < 0 then
			insidePiece = true
			if not inBaseRect then
				minDist = math.min(minDist, math.abs(sd))
			end
		end
	elseif edges.bottom == "indent" then
		local tcx = cellW / 2
		local tcy = cellH
		local sd = semicircleSignedDistance(cx, cy, tcx, tcy, tabRadius, "top")
		if sd < 0 and inBaseRect then
			insidePiece = false
		end
		if sd < 0 and inBaseRect then
			minDist = math.min(minDist, math.abs(sd))
		end
	end

	-- Left edge
	if edges.left == "tab" then
		local tcx = 0
		local tcy = cellH / 2
		local sd = semicircleSignedDistance(cx, cy, tcx, tcy, tabRadius, "left")
		if sd < 0 then
			insidePiece = true
			if not inBaseRect then
				minDist = math.min(minDist, math.abs(sd))
			end
		end
	elseif edges.left == "indent" then
		local tcx = 0
		local tcy = cellH / 2
		local sd = semicircleSignedDistance(cx, cy, tcx, tcy, tabRadius, "right")
		if sd < 0 and inBaseRect then
			insidePiece = false
		end
		if sd < 0 and inBaseRect then
			minDist = math.min(minDist, math.abs(sd))
		end
	end

	-- Right edge
	if edges.right == "tab" then
		local tcx = cellW
		local tcy = cellH / 2
		local sd = semicircleSignedDistance(cx, cy, tcx, tcy, tabRadius, "right")
		if sd < 0 then
			insidePiece = true
			if not inBaseRect then
				minDist = math.min(minDist, math.abs(sd))
			end
		end
	elseif edges.right == "indent" then
		local tcx = cellW
		local tcy = cellH / 2
		local sd = semicircleSignedDistance(cx, cy, tcx, tcy, tabRadius, "left")
		if sd < 0 and inBaseRect then
			insidePiece = false
		end
		if sd < 0 and inBaseRect then
			minDist = math.min(minDist, math.abs(sd))
		end
	end

	if not insidePiece then
		return 0
	end

	-- Anti-aliasing: smooth alpha near boundaries
	if minDist < AA_RADIUS then
		return math.clamp(minDist / AA_RADIUS, 0, 1)
	end

	return 1
end

function PieceMasker.createPieceImages(
	sourceImage: EditableImage,
	sourceWidth: number,
	sourceHeight: number,
	puzzleDef: PuzzleDefinition
): { [number]: PieceImageData }
	local cellW = math.floor(sourceWidth / puzzleDef.cols)
	local cellH = math.floor(sourceHeight / puzzleDef.rows)
	local tabW = math.floor(cellW * TAB_WIDTH_RATIO)
	local tabH = math.floor(cellH * TAB_HEIGHT_RATIO)

	-- Ensure tab dimensions are even for clean semicircles
	if tabW % 2 ~= 0 then tabW += 1 end
	if tabH % 2 ~= 0 then tabH += 1 end

	-- Tab height used as padding (the protrusion depth)
	-- For semicircles, the radius equals tabW/2, and the protrusion = radius
	local tabRadius = math.floor(tabW / 2)

	local result: { [number]: PieceImageData } = {}

	for _, piece in puzzleDef.pieces do
		-- Calculate padding needed on each side
		local padTop = if piece.edges.top == "tab" then tabRadius else 0
		local padBottom = if piece.edges.bottom == "tab" then tabRadius else 0
		local padLeft = if piece.edges.left == "tab" then tabRadius else 0
		local padRight = if piece.edges.right == "tab" then tabRadius else 0

		local pieceW = cellW + padLeft + padRight
		local pieceH = cellH + padTop + padBottom

		-- Source region top-left (in source image coords)
		local srcX = (piece.col - 1) * cellW - padLeft
		local srcY = (piece.row - 1) * cellH - padTop

		-- Create the piece EditableImage
		local pieceImage = AssetService:CreateEditableImage({
			Size = Vector2.new(pieceW, pieceH),
		})

		-- Read source pixels row by row and apply mask
		-- We'll process in chunks for performance
		for py = 0, pieceH - 1 do
			local sourcePy = srcY + py
			if sourcePy >= 0 and sourcePy < sourceHeight then
				-- Read one row from source at the correct region
				local readX = math.max(0, srcX)
				local readEndX = math.min(sourceWidth, srcX + pieceW)
				local readWidth = readEndX - readX

				if readWidth > 0 then
					local rowBuffer = sourceImage:ReadPixelsBuffer(
						Vector2.new(readX, sourcePy),
						Vector2.new(readWidth, 1)
					)

					-- Create a row buffer for the piece image
					local pieceRowBuffer = buffer.create(pieceW * 4)

					for px = 0, pieceW - 1 do
						local sourcePx = srcX + px
						local alpha = getPieceAlpha(
							px, py, cellW, cellH, tabW, tabH,
							padTop, padRight, padBottom, padLeft,
							piece.edges
						)

						if alpha > 0 and sourcePx >= 0 and sourcePx < sourceWidth then
							local srcOffset = (sourcePx - readX) * 4
							if srcOffset >= 0 and srcOffset + 3 < buffer.len(rowBuffer) then
								local r = buffer.readu8(rowBuffer, srcOffset)
								local g = buffer.readu8(rowBuffer, srcOffset + 1)
								local b = buffer.readu8(rowBuffer, srcOffset + 2)
								local a = buffer.readu8(rowBuffer, srcOffset + 3)

								local destOffset = px * 4
								buffer.writeu8(pieceRowBuffer, destOffset, r)
								buffer.writeu8(pieceRowBuffer, destOffset + 1, g)
								buffer.writeu8(pieceRowBuffer, destOffset + 2, b)
								buffer.writeu8(pieceRowBuffer, destOffset + 3, math.floor(a * alpha))
							end
						end
						-- Pixels outside the mask or outside source bounds stay as 0 (transparent)
					end

					pieceImage:WritePixelsBuffer(
						Vector2.new(0, py),
						Vector2.new(pieceW, 1),
						pieceRowBuffer
					)
				end
			end
		end

		-- Generate outline image: white pixels along the SDF boundary
		local outlineImage = AssetService:CreateEditableImage({
			Size = Vector2.new(pieceW, pieceH),
		})

		for py = 0, pieceH - 1 do
			local outlineRowBuffer = buffer.create(pieceW * 4)

			for px = 0, pieceW - 1 do
				local sd = getPieceSignedDistance(
					px, py, cellW, cellH, tabW, tabH,
					padTop, padRight, padBottom, padLeft,
					piece.edges
				)

				-- Outline band: covers boundary and extends slightly outside to hide AA fringe
				if sd <= AA_RADIUS and -sd <= OUTLINE_THICKNESS then
					local offset = px * 4
					buffer.writeu8(outlineRowBuffer, offset, 255)
					buffer.writeu8(outlineRowBuffer, offset + 1, 255)
					buffer.writeu8(outlineRowBuffer, offset + 2, 255)
					buffer.writeu8(outlineRowBuffer, offset + 3, 255)
				end
			end

			outlineImage:WritePixelsBuffer(
				Vector2.new(0, py),
				Vector2.new(pieceW, 1),
				outlineRowBuffer
			)
		end

		result[piece.id] = {
			image = pieceImage,
			outlineImage = outlineImage,
			width = pieceW,
			height = pieceH,
			offsetX = padLeft,
			offsetY = padTop,
		}
	end

	return result
end

return PieceMasker
