local PuzzleTypes = require(script.Parent.PuzzleTypes)

type EdgeType = PuzzleTypes.EdgeType
type PieceDefinition = PuzzleTypes.PieceDefinition
type PuzzleDefinition = PuzzleTypes.PuzzleDefinition

local PuzzleGenerator = {}

function PuzzleGenerator.generatePuzzle(rows: number, cols: number): PuzzleDefinition
	-- Horizontal edges: edges between vertically adjacent pieces (rows-1 x cols)
	-- For each such edge, randomly pick tab on top or bottom piece
	local horizontalEdges: { { EdgeType } } = {}
	for r = 1, rows - 1 do
		horizontalEdges[r] = {}
		for c = 1, cols do
			if math.random() > 0.5 then
				horizontalEdges[r][c] = "tab"
			else
				horizontalEdges[r][c] = "indent"
			end
		end
	end

	-- Vertical edges: edges between horizontally adjacent pieces (rows x cols-1)
	local verticalEdges: { { EdgeType } } = {}
	for r = 1, rows do
		verticalEdges[r] = {}
		for c = 1, cols - 1 do
			if math.random() > 0.5 then
				verticalEdges[r][c] = "tab"
			else
				verticalEdges[r][c] = "indent"
			end
		end
	end

	local pieces: { PieceDefinition } = {}
	local id = 1

	for r = 1, rows do
		for c = 1, cols do
			local top: EdgeType = "flat"
			local bottom: EdgeType = "flat"
			local left: EdgeType = "flat"
			local right: EdgeType = "flat"

			-- Top edge: if not first row, complement of the horizontal edge above
			if r > 1 then
				local edgeAbove = horizontalEdges[r - 1][c]
				if edgeAbove == "tab" then
					top = "indent"
				else
					top = "tab"
				end
			end

			-- Bottom edge: if not last row, use the horizontal edge below
			if r < rows then
				bottom = horizontalEdges[r][c]
			end

			-- Left edge: if not first col, complement of the vertical edge to the left
			if c > 1 then
				local edgeLeft = verticalEdges[r][c - 1]
				if edgeLeft == "tab" then
					left = "indent"
				else
					left = "tab"
				end
			end

			-- Right edge: if not last col, use the vertical edge to the right
			if c < cols then
				right = verticalEdges[r][c]
			end

			table.insert(pieces, {
				id = id,
				row = r,
				col = c,
				edges = {
					top = top,
					right = right,
					bottom = bottom,
					left = left,
				},
			})

			id += 1
		end
	end

	return {
		rows = rows,
		cols = cols,
		pieces = pieces,
	}
end

return PuzzleGenerator
