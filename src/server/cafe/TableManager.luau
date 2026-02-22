local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local TableManager = {}

-- State
local tableModels: { [string]: Model } = {}
local RoomManager: any = nil

-- Per-table occupancy: tableId -> { [seatIndex]: Player }
local tableOccupancy: { [string]: { [number]: Player } } = {}

-- Per-table room mapping: tableId -> roomId (for multi tables)
local tableRooms: { [string]: string } = {}

-- Player -> tableId mapping for quick lookup
local playerTable: { [number]: string } = {}
local playerSeat: { [number]: number } = {}

-- Per-table lock to prevent race conditions
local tableLocks: { [string]: boolean } = {}

local function acquireLock(tableId: string): boolean
	if tableLocks[tableId] then
		return false
	end
	tableLocks[tableId] = true
	return true
end

local function releaseLock(tableId: string)
	tableLocks[tableId] = nil
end

local function getTableType(tableModel: Model): string
	local tv = tableModel:FindFirstChild("TableType")
	if tv and tv:IsA("StringValue") then
		return tv.Value
	end
	return "single"
end

local function getOccupantCount(tableId: string): number
	local occupants = tableOccupancy[tableId]
	if not occupants then return 0 end
	local count = 0
	for _ in occupants do count += 1 end
	return count
end

local function fireOccupancyChanged(tableId: string)
	local occupants = tableOccupancy[tableId] or {}
	local occupantList = {}
	for seatIdx, player in occupants do
		table.insert(occupantList, {
			seatIndex = seatIdx,
			userId = player.UserId,
			displayName = player.DisplayName,
		})
	end

	local event = Remotes.GetEvent("TableOccupancyChanged")
	for _, player in Players:GetPlayers() do
		event:FireClient(player, {
			tableId = tableId,
			occupants = occupantList,
		})
	end
end

local function handleSit(seat: Seat, tableId: string, seatIndex: number)
	local humanoid = seat.Occupant
	if not humanoid then return end

	local character = humanoid.Parent
	if not character then return end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end

	-- Try to acquire lock
	local retries = 0
	while not acquireLock(tableId) do
		task.wait(0.05)
		retries += 1
		if retries > 20 then
			warn("[TableManager] Failed to acquire lock for table " .. tableId)
			return
		end
	end

	local tableModel = tableModels[tableId]
	local tableType = if tableModel then getTableType(tableModel) else "single"

	-- Record occupancy
	if not tableOccupancy[tableId] then
		tableOccupancy[tableId] = {}
	end
	tableOccupancy[tableId][seatIndex] = player
	playerTable[player.UserId] = tableId
	playerSeat[player.UserId] = seatIndex

	local roomId: string? = nil

	if tableType == "multi" then
		-- Check if this table already has a room
		local existingRoomId = tableRooms[tableId]
		if existingRoomId then
			-- Join existing room
			local joined = RoomManager.JoinRoomInternal(player, existingRoomId)
			if joined then
				roomId = existingRoomId
			end
		else
			-- Create new room (first sitter)
			local newRoomId = RoomManager.CreateRoomInternal(player)
			if newRoomId then
				tableRooms[tableId] = newRoomId
				roomId = newRoomId
			end
		end
	end

	releaseLock(tableId)

	-- Fire PlayerSeated event to the client
	local seatedEvent = Remotes.GetEvent("PlayerSeated")
	seatedEvent:FireClient(player, {
		tableId = tableId,
		tableType = tableType,
		seatIndex = seatIndex,
		roomId = roomId,
	})

	fireOccupancyChanged(tableId)

	print(string.format("[TableManager] %s sat at %s (seat %d, type=%s)", player.Name, tableId, seatIndex, tableType))
end

local function handleUnsit(player: Player, tableId: string, seatIndex: number)
	-- Try to acquire lock
	local retries = 0
	while not acquireLock(tableId) do
		task.wait(0.05)
		retries += 1
		if retries > 20 then
			warn("[TableManager] Failed to acquire lock for table " .. tableId)
			return
		end
	end

	local tableModel = tableModels[tableId]
	local tableType = if tableModel then getTableType(tableModel) else "single"

	-- Clear occupancy
	if tableOccupancy[tableId] then
		tableOccupancy[tableId][seatIndex] = nil
	end
	playerTable[player.UserId] = nil
	playerSeat[player.UserId] = nil

	if tableType == "multi" then
		-- Leave the room
		RoomManager.LeaveRoomInternal(player)

		-- If table is now empty, clean up room mapping
		if getOccupantCount(tableId) == 0 then
			tableRooms[tableId] = nil
		end
	end

	releaseLock(tableId)

	-- Fire PlayerUnseated event to the client
	local unseatedEvent = Remotes.GetEvent("PlayerUnseated")
	unseatedEvent:FireClient(player, {})

	fireOccupancyChanged(tableId)

	print(string.format("[TableManager] %s left %s (seat %d)", player.Name, tableId, seatIndex))
end

local function setupSeatListener(seat: Seat, tableId: string, seatIndex: number)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if seat.Occupant then
			handleSit(seat, tableId, seatIndex)
		else
			-- Need to figure out who was sitting here
			-- Check our records for this table+seat
			local occupants = tableOccupancy[tableId]
			if occupants and occupants[seatIndex] then
				local player = occupants[seatIndex]
				handleUnsit(player, tableId, seatIndex)
			end
		end
	end)
end

function TableManager.Init(models: { [string]: Model }, roomManager: any)
	tableModels = models
	RoomManager = roomManager

	-- Set up seat listeners for all tables
	for tableId, tableModel in models do
		for _, descendant in tableModel:GetDescendants() do
			if descendant:IsA("Seat") then
				local tableIdVal = descendant:FindFirstChild("TableId")
				local seatIdxVal = descendant:FindFirstChild("SeatIndex")
				if tableIdVal and tableIdVal:IsA("StringValue") and seatIdxVal and seatIdxVal:IsA("IntValue") then
					setupSeatListener(descendant, tableIdVal.Value, seatIdxVal.Value)
				end
			end
		end
	end

	-- GetTableInfo remote function
	local getTableInfo = Remotes.GetFunction("GetTableInfo")
	getTableInfo.OnServerInvoke = function(_player, tableId)
		if type(tableId) ~= "string" then
			return { error = "Invalid tableId" }
		end

		local tableModel = tableModels[tableId]
		if not tableModel then
			return { error = "Table not found" }
		end

		local tableType = getTableType(tableModel)
		local occupants = tableOccupancy[tableId] or {}
		local occupantList = {}
		for seatIdx, p in occupants do
			table.insert(occupantList, {
				seatIndex = seatIdx,
				userId = p.UserId,
				displayName = p.DisplayName,
			})
		end

		local roomId = tableRooms[tableId]
		local roomInfo = nil
		if roomId and RoomManager then
			roomInfo = RoomManager.GetRoomInfo(roomId)
		end

		return {
			tableId = tableId,
			tableType = tableType,
			occupants = occupantList,
			roomId = roomId,
			roomInfo = roomInfo,
		}
	end

	-- Clean up on player removing
	Players.PlayerRemoving:Connect(function(player)
		local userId = player.UserId
		local tableId = playerTable[userId]
		local seatIndex = playerSeat[userId]

		if tableId and seatIndex then
			handleUnsit(player, tableId, seatIndex)
		end
	end)

	print("[TableManager] Initialized with " .. tostring(#models == nil and 0 or (function()
		local c = 0
		for _ in models do c += 1 end
		return c
	end)()) .. " tables")
end

return TableManager
