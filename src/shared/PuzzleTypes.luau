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
	outlineImage: EditableImage,
	width: number,
	height: number,
	offsetX: number,
	offsetY: number,
}

export type DifficultyId = "2x2" | "6x6" | "9x9" | "15x15" | "25x25"

export type PuzzleSessionResult = {
	imageId: string,
	difficultyId: DifficultyId,
	completionTime: number,
	rows: number,
	cols: number,
}

export type SavedPuzzleData = {
	imageId: string,
	imageAssetId: string,
	difficultyId: string,
	rows: number,
	cols: number,
	elapsedSeconds: number,
	savedAt: number,
	puzzleDef: PuzzleDefinition,
	pieces: { { id: number, x: number, y: number, zIndex: number, locked: boolean, groupId: number? } },
	groups: { { id: number, pieceIds: { number } } }?,
}

return {}
