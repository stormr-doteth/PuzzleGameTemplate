export type RoomId = string -- 6-char alphanumeric code

export type RoomPlayer = {
	userId: number,
	displayName: string,
	isHost: boolean,
}

export type RoomConfig = {
	imageAssetId: string,
	imageId: string,
	difficultyId: string,
	rows: number,
	cols: number,
}

export type RoomState = "lobby" | "playing" | "complete"

export type RoomInfo = {
	roomId: RoomId,
	state: RoomState,
	players: { RoomPlayer },
	config: RoomConfig?,
	hostUserId: number,
}

export type ServerPieceState = {
	x: number,
	y: number,
	zIndex: number,
	locked: boolean,
	claimedBy: number?, -- userId
}

export type PieceMovePayload = {
	id: number,
	x: number,
	y: number,
}

export type PieceUpdatePayload = {
	id: number,
	x: number,
	y: number,
	userId: number,
}

-- Virtual canvas dimensions for viewport-independent coordinates
export type VirtualCanvas = {
	width: number,
	height: number,
}

local RoomTypes = {
	VIRTUAL_CANVAS_WIDTH = 1200,
	VIRTUAL_CANVAS_HEIGHT = 800,
}

return RoomTypes
