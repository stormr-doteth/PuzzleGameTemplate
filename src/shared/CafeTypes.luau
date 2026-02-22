export type TableType = "single" | "multi"

export type TableConfig = {
	tableId: string,
	tableType: TableType,
	maxSeats: number,
	position: Vector3,
}

export type SeatingInfo = {
	tableId: string,
	tableType: TableType,
	seatIndex: number,
	roomId: string?,
}

return {}
