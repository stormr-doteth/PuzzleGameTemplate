local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PuzzleTypes = require(Shared.PuzzleTypes)

type PieceDefinition = PuzzleTypes.PieceDefinition
type PuzzleDefinition = PuzzleTypes.PuzzleDefinition

local TAB_WIDTH_RATIO = 0.35
local TAB_HEIGHT_RATIO = 0.18
local AA_RADIUS = 2
local OUTLINE_THICKNESS = 4
local YIELD_EVERY_N_PIECES = 8

local PieceMasker = {}

local function semicircleSignedDistance(
	px: number,
	py: number,
	centerX: number,
	centerY: number,
	radius: number,
	edgeSide: string
): number
	local dx = px - centerX
	local dy = py - centerY
	local dist = math.sqrt(dx * dx + dy * dy)

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

local function getPieceSignedDistance(
	px: number,
	py: number,
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
	local cx = px - padLeft
	local cy = py - padTop

	local tabRadius = tabW / 2

	local baseDistX = math.max(-cx, cx - cellW)
	local baseDistY = math.max(-cy, cy - cellH)
	local dist = math.max(baseDistX, baseDistY)

	if edges.top == "tab" then
		local tcx = cellW / 2
		local tcy = 0
		local sd = semicircleSignedDistance(cx, cy, tcx, tcy, tabRadius, "top")
		dist = math.min(dist, sd)
	elseif edges.top == "indent" then
		local tcx = cellW / 2
		local tcy = 0
		local sd = semicircleSignedDistance(cx, cy, tcx, tcy, tabRadius, "bottom")
		dist = math.max(dist, -sd)
	end

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

local function getPieceAlpha(
	px: number,
	py: number,
	cellW: number,
	cellH: number,
	tabW: number,
	tabH: number,
	padTop: number,
	padRight: number,
	padBottom: number,
	padLeft: number,
	edges: PuzzleTypes.PieceEdges,
	aaRadius: number
): number
	local cx = px - padLeft
	local cy = py - padTop

	local inBaseRect = cx >= 0 and cx < cellW and cy >= 0 and cy < cellH

	local tabRadius = tabW / 2
	local minDist = math.huge

	local insidePiece = inBaseRect

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

	if minDist < aaRadius then
		return math.clamp(minDist / aaRadius, 0, 1)
	end

	return 1
end

function PieceMasker.createPieceImages(
	sourceImage: EditableImage,
	sourceWidth: number,
	sourceHeight: number,
	puzzleDef: PuzzleDefinition
): { [number]: { image: EditableImage, outlineImage: EditableImage, width: number, height: number, offsetX: number, offsetY: number } }
	local cellW = math.floor(sourceWidth / puzzleDef.cols)
	local cellH = math.floor(sourceHeight / puzzleDef.rows)
	local tabW = math.floor(cellW * TAB_WIDTH_RATIO)
	local tabH = math.floor(cellH * TAB_HEIGHT_RATIO)

	if tabW % 2 ~= 0 then tabW += 1 end
	if tabH % 2 ~= 0 then tabH += 1 end

	local tabRadius = math.floor(tabW / 2)

	local scaleFactor = math.min(cellW, cellH) / 500
	local outlineThickness = math.max(1, math.floor(OUTLINE_THICKNESS * scaleFactor + 0.5))
	local aaRadius = math.max(1, math.floor(AA_RADIUS * scaleFactor + 0.5))

	local results: { [number]: any } = {}
	local piecesProcessed = 0

	for _, piece in puzzleDef.pieces do
		local padTop = if piece.edges.top == "tab" then tabRadius else 0
		local padBottom = if piece.edges.bottom == "tab" then tabRadius else 0
		local padLeft = if piece.edges.left == "tab" then tabRadius else 0
		local padRight = if piece.edges.right == "tab" then tabRadius else 0

		local pieceW = cellW + padLeft + padRight
		local pieceH = cellH + padTop + padBottom

		local srcX = (piece.col - 1) * cellW - padLeft
		local srcY = (piece.row - 1) * cellH - padTop

		-- Create the piece EditableImage
		local pieceImage = AssetService:CreateEditableImage({
			Size = Vector2.new(pieceW, pieceH),
		})

		for py = 0, pieceH - 1 do
			local sourcePy = srcY + py
			if sourcePy >= 0 and sourcePy < sourceHeight then
				local readX = math.max(0, srcX)
				local readEndX = math.min(sourceWidth, srcX + pieceW)
				local readWidth = readEndX - readX

				if readWidth > 0 then
					local rowBuffer = sourceImage:ReadPixelsBuffer(
						Vector2.new(readX, sourcePy),
						Vector2.new(readWidth, 1)
					)

					local pieceRowBuffer = buffer.create(pieceW * 4)

					for px = 0, pieceW - 1 do
						local sourcePx = srcX + px
						local alpha = getPieceAlpha(
							px, py, cellW, cellH, tabW, tabH,
							padTop, padRight, padBottom, padLeft,
							piece.edges, aaRadius
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
					end

					pieceImage:WritePixelsBuffer(
						Vector2.new(0, py),
						Vector2.new(pieceW, 1),
						pieceRowBuffer
					)
				end
			end
		end

		-- Generate outline image
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

				if sd <= aaRadius and -sd <= outlineThickness then
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

		results[piece.id] = {
			image = pieceImage,
			outlineImage = outlineImage,
			width = pieceW,
			height = pieceH,
			offsetX = padLeft,
			offsetY = padTop,
		}

		piecesProcessed += 1
		if piecesProcessed % YIELD_EVERY_N_PIECES == 0 then
			task.wait()
		end
	end

	return results
end

return PieceMasker
