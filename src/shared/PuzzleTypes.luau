export type EdgeType = "flat" | "tab" | "indent"

export type PieceEdges = {
	top: EdgeType,
	right: EdgeType,
	bottom: EdgeType,
	left: EdgeType,
}

export type PieceDefinition = {
	id: number,
	row: number,
	col: number,
	edges: PieceEdges,
}

export type PuzzleDefinition = {
	rows: number,
	cols: number,
	pieces: { PieceDefinition },
}

export type PieceImageData = {
	image: EditableImage,
	width: number,
	height: number,
	offsetX: number,
	offsetY: number,
}

return {}
