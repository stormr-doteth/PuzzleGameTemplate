local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local FLOOR_WIDTH = 120
local FLOOR_DEPTH = 80
local WALL_HEIGHT = 16
local WALL_THICKNESS = 2
local TABLE_HEIGHT = 3.5
local CHAIR_SEAT_HEIGHT = 2.5
local LEG_THICKNESS = 0.3

local WOOD_COLOR = Color3.fromRGB(139, 90, 43)
local DARK_WOOD_COLOR = Color3.fromRGB(101, 67, 33)
local CREAM_COLOR = Color3.fromRGB(255, 248, 231)
local FLOOR_COLOR = Color3.fromRGB(178, 132, 72)
local COUNTER_COLOR = Color3.fromRGB(120, 80, 40)
local PLANT_POT_COLOR = Color3.fromRGB(140, 80, 40)
local PLANT_GREEN = Color3.fromRGB(34, 120, 50)
local LIGHT_COLOR = Color3.fromRGB(255, 223, 160)
local CHAIR_CUSHION = Color3.fromRGB(165, 42, 42)

local CafeBuilder = {}

-- Helper to create an anchored part
local function makePart(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Build a single chair with a Seat at the given position, facing toward faceDirection
local function buildChair(parent: Instance, position: Vector3, faceDirection: Vector3, tableId: string, seatIndex: number): Seat
	local chairModel = Instance.new("Model")
	chairModel.Name = "Chair_" .. seatIndex

	-- Seat (the functional sit part)
	local seat = Instance.new("Seat")
	seat.Name = "Seat"
	seat.Size = Vector3.new(2, 0.5, 2)
	seat.Position = Vector3.new(position.X, CHAIR_SEAT_HEIGHT, position.Z)
	seat.Color = CHAIR_CUSHION
	seat.Material = Enum.Material.Fabric
	seat.Anchored = true
	seat.CanCollide = true
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth

	-- Orient seat to face the table
	local lookAt = position + faceDirection
	seat.CFrame = CFrame.lookAt(
		Vector3.new(position.X, CHAIR_SEAT_HEIGHT, position.Z),
		Vector3.new(lookAt.X, CHAIR_SEAT_HEIGHT, lookAt.Z)
	)

	-- Tag with TableId and SeatIndex
	local tableIdValue = Instance.new("StringValue")
	tableIdValue.Name = "TableId"
	tableIdValue.Value = tableId
	tableIdValue.Parent = seat

	local seatIndexValue = Instance.new("IntValue")
	seatIndexValue.Name = "SeatIndex"
	seatIndexValue.Value = seatIndex
	seatIndexValue.Parent = seat

	seat.Parent = chairModel

	-- Chair legs (4)
	local legOffsets = {
		Vector3.new(-0.7, 0, -0.7),
		Vector3.new(0.7, 0, -0.7),
		Vector3.new(-0.7, 0, 0.7),
		Vector3.new(0.7, 0, 0.7),
	}
	for i, offset in legOffsets do
		makePart(
			chairModel,
			"Leg_" .. i,
			Vector3.new(LEG_THICKNESS, CHAIR_SEAT_HEIGHT - 0.25, LEG_THICKNESS),
			Vector3.new(position.X + offset.X, (CHAIR_SEAT_HEIGHT - 0.25) / 2, position.Z + offset.Z),
			DARK_WOOD_COLOR,
			Enum.Material.Wood
		)
	end

	-- Chair back (behind the seat, away from table)
	local backDir = -faceDirection.Unit
	local backPos = Vector3.new(
		position.X + backDir.X * 1,
		CHAIR_SEAT_HEIGHT + 1.5,
		position.Z + backDir.Z * 1
	)
	makePart(
		chairModel,
		"Back",
		Vector3.new(2, 2.5, 0.3),
		backPos,
		DARK_WOOD_COLOR,
		Enum.Material.Wood
	)

	chairModel.Parent = parent
	return seat
end

-- Build a table with chairs
local function buildTable(parent: Instance, tableId: string, position: Vector3, numChairs: number, tableType: string): Model
	local tableModel = Instance.new("Model")
	tableModel.Name = tableId

	-- Table type tag
	local tableTypeValue = Instance.new("StringValue")
	tableTypeValue.Name = "TableType"
	tableTypeValue.Value = tableType
	tableTypeValue.Parent = tableModel

	-- Tabletop
	local topSize = if numChairs <= 1
		then Vector3.new(4, 0.4, 4)
		elseif numChairs <= 2 then Vector3.new(5, 0.4, 3.5)
		else Vector3.new(6, 0.4, 6)

	makePart(
		tableModel,
		"Tabletop",
		topSize,
		Vector3.new(position.X, TABLE_HEIGHT, position.Z),
		WOOD_COLOR,
		Enum.Material.Wood
	)

	-- Table legs (4 corners)
	local halfW = topSize.X / 2 - 0.3
	local halfD = topSize.Z / 2 - 0.3
	local tableLegOffsets = {
		Vector3.new(-halfW, 0, -halfD),
		Vector3.new(halfW, 0, -halfD),
		Vector3.new(-halfW, 0, halfD),
		Vector3.new(halfW, 0, halfD),
	}
	for i, offset in tableLegOffsets do
		makePart(
			tableModel,
			"TableLeg_" .. i,
			Vector3.new(LEG_THICKNESS, TABLE_HEIGHT - 0.2, LEG_THICKNESS),
			Vector3.new(position.X + offset.X, (TABLE_HEIGHT - 0.2) / 2, position.Z + offset.Z),
			DARK_WOOD_COLOR,
			Enum.Material.Wood
		)
	end

	-- Place chairs around the table
	local chairDistance = math.max(topSize.X, topSize.Z) / 2 + 1.5
	local seats: { Seat } = {}

	if numChairs == 1 then
		-- Single chair on one side
		local chairPos = Vector3.new(position.X, 0, position.Z + chairDistance)
		local faceDir = Vector3.new(0, 0, -1) -- face toward table
		local s = buildChair(tableModel, chairPos, faceDir, tableId, 1)
		table.insert(seats, s)
	elseif numChairs == 2 then
		-- Two chairs on opposite sides
		local dirs = {
			{ offset = Vector3.new(0, 0, chairDistance), face = Vector3.new(0, 0, -1) },
			{ offset = Vector3.new(0, 0, -chairDistance), face = Vector3.new(0, 0, 1) },
		}
		for i, d in dirs do
			local chairPos = position + d.offset
			local s = buildChair(tableModel, chairPos, d.face, tableId, i)
			table.insert(seats, s)
		end
	else
		-- 4 chairs on all sides
		local dirs = {
			{ offset = Vector3.new(0, 0, chairDistance), face = Vector3.new(0, 0, -1) },
			{ offset = Vector3.new(0, 0, -chairDistance), face = Vector3.new(0, 0, 1) },
			{ offset = Vector3.new(chairDistance, 0, 0), face = Vector3.new(-1, 0, 0) },
			{ offset = Vector3.new(-chairDistance, 0, 0), face = Vector3.new(1, 0, 0) },
		}
		for i, d in dirs do
			local chairPos = position + d.offset
			local s = buildChair(tableModel, chairPos, d.face, tableId, i)
			table.insert(seats, s)
		end
	end

	tableModel.Parent = parent
	return tableModel
end

-- Build decorations
local function buildDecorations(parent: Instance)
	-- Counter/bar along back wall
	local counterWidth = 60
	makePart(
		parent,
		"Counter",
		Vector3.new(counterWidth, 4, 3),
		Vector3.new(0, 2, -(FLOOR_DEPTH / 2 - 3)),
		COUNTER_COLOR,
		Enum.Material.Wood
	)

	-- Counter top surface
	makePart(
		parent,
		"CounterTop",
		Vector3.new(counterWidth, 0.3, 3.5),
		Vector3.new(0, 4.15, -(FLOOR_DEPTH / 2 - 3)),
		Color3.fromRGB(160, 110, 60),
		Enum.Material.Marble
	)

	-- Potted plants (corners and along walls)
	local plantPositions = {
		Vector3.new(FLOOR_WIDTH / 2 - 5, 0, FLOOR_DEPTH / 2 - 5),
		Vector3.new(-(FLOOR_WIDTH / 2 - 5), 0, FLOOR_DEPTH / 2 - 5),
		Vector3.new(FLOOR_WIDTH / 2 - 5, 0, -(FLOOR_DEPTH / 2 - 5)),
		Vector3.new(-(FLOOR_WIDTH / 2 - 5), 0, -(FLOOR_DEPTH / 2 - 5)),
		Vector3.new(FLOOR_WIDTH / 2 - 5, 0, 0),
		Vector3.new(-(FLOOR_WIDTH / 2 - 5), 0, 0),
	}

	for i, pos in plantPositions do
		-- Pot
		makePart(
			parent,
			"Pot_" .. i,
			Vector3.new(2.5, 3, 2.5),
			Vector3.new(pos.X, 1.5, pos.Z),
			PLANT_POT_COLOR,
			Enum.Material.SmoothPlastic
		)
		-- Plant foliage (sphere-ish)
		local foliage = makePart(
			parent,
			"Plant_" .. i,
			Vector3.new(4, 5, 4),
			Vector3.new(pos.X, 5.5, pos.Z),
			PLANT_GREEN,
			Enum.Material.Grass
		)
		foliage.Shape = Enum.PartType.Ball
	end

	-- Hanging lights
	local lightXPositions = { -30, -10, 10, 30 }
	for i, lx in lightXPositions do
		-- Light fixture
		local fixture = makePart(
			parent,
			"LightFixture_" .. i,
			Vector3.new(2, 1, 2),
			Vector3.new(lx, WALL_HEIGHT - 2, 0),
			Color3.fromRGB(60, 60, 60),
			Enum.Material.Metal
		)
		fixture.Shape = Enum.PartType.Cylinder

		-- Light glow
		local light = Instance.new("PointLight")
		light.Color = LIGHT_COLOR
		light.Brightness = 1
		light.Range = 30
		light.Parent = fixture

		-- Cord
		makePart(
			parent,
			"LightCord_" .. i,
			Vector3.new(0.15, 2, 0.15),
			Vector3.new(lx, WALL_HEIGHT - 0.5, 0),
			Color3.fromRGB(40, 40, 40),
			Enum.Material.Metal
		)
	end
end

-- Configure lighting for cozy atmosphere
local function configureLighting()
	Lighting.Ambient = Color3.fromRGB(80, 60, 40)
	Lighting.Brightness = 1.5
	Lighting.ClockTime = 14
	Lighting.OutdoorAmbient = Color3.fromRGB(100, 80, 60)
	Lighting.GlobalShadows = true

	-- Color correction for cozy glow
	local existing = Lighting:FindFirstChild("CafeColorCorrection")
	if existing then existing:Destroy() end

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "CafeColorCorrection"
	cc.Brightness = 0.02
	cc.Contrast = 0.05
	cc.Saturation = 0.1
	cc.TintColor = Color3.fromRGB(255, 240, 220)
	cc.Parent = Lighting
end

function CafeBuilder.Build(): { [string]: Model }
	-- Create cafe folder in workspace
	local cafeFolder = Workspace:FindFirstChild("CafeTables")
	if cafeFolder then cafeFolder:Destroy() end
	cafeFolder = Instance.new("Folder")
	cafeFolder.Name = "CafeTables"
	cafeFolder.Parent = Workspace

	-- Floor
	makePart(
		cafeFolder,
		"Floor",
		Vector3.new(FLOOR_WIDTH, 1, FLOOR_DEPTH),
		Vector3.new(0, -0.5, 0),
		FLOOR_COLOR,
		Enum.Material.Wood
	)

	-- Walls (back + two sides, front open as entrance)
	-- Back wall
	makePart(
		cafeFolder,
		"BackWall",
		Vector3.new(FLOOR_WIDTH, WALL_HEIGHT, WALL_THICKNESS),
		Vector3.new(0, WALL_HEIGHT / 2, -(FLOOR_DEPTH / 2)),
		CREAM_COLOR,
		Enum.Material.SmoothPlastic
	)
	-- Left wall
	makePart(
		cafeFolder,
		"LeftWall",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, FLOOR_DEPTH),
		Vector3.new(-(FLOOR_WIDTH / 2), WALL_HEIGHT / 2, 0),
		CREAM_COLOR,
		Enum.Material.SmoothPlastic
	)
	-- Right wall
	makePart(
		cafeFolder,
		"RightWall",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, FLOOR_DEPTH),
		Vector3.new(FLOOR_WIDTH / 2, WALL_HEIGHT / 2, 0),
		CREAM_COLOR,
		Enum.Material.SmoothPlastic
	)

	-- SpawnLocation near front entrance
	local existingSpawn = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if existingSpawn then existingSpawn:Destroy() end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "CafeSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, 0.5, FLOOR_DEPTH / 2 - 6)
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Material = Enum.Material.Wood
	spawn.Color = FLOOR_COLOR
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Duration = 0
	spawn.Parent = cafeFolder

	-- Build tables
	local tableModels: { [string]: Model } = {}

	-- 4 single-player tables along walls
	local singlePositions = {
		Vector3.new(-(FLOOR_WIDTH / 2 - 10), 0, -15),  -- left wall
		Vector3.new(-(FLOOR_WIDTH / 2 - 10), 0, 15),   -- left wall
		Vector3.new(FLOOR_WIDTH / 2 - 10, 0, -15),     -- right wall
		Vector3.new(FLOOR_WIDTH / 2 - 10, 0, 15),      -- right wall
	}
	for i, pos in singlePositions do
		local tableId = "single_" .. i
		local model = buildTable(cafeFolder, tableId, pos, 1, "single")
		tableModels[tableId] = model
	end

	-- 2 two-player tables in center
	local twoPlayerPositions = {
		Vector3.new(-15, 0, -10),
		Vector3.new(15, 0, -10),
	}
	for i, pos in twoPlayerPositions do
		local tableId = "multi_2p_" .. i
		local model = buildTable(cafeFolder, tableId, pos, 2, "multi")
		tableModels[tableId] = model
	end

	-- 2 four-player tables in center
	local fourPlayerPositions = {
		Vector3.new(-15, 0, 15),
		Vector3.new(15, 0, 15),
	}
	for i, pos in fourPlayerPositions do
		local tableId = "multi_4p_" .. i
		local model = buildTable(cafeFolder, tableId, pos, 4, "multi")
		tableModels[tableId] = model
	end

	-- Build decorations
	buildDecorations(cafeFolder)

	-- Configure lighting
	configureLighting()

	print("[CafeBuilder] Cafe built with " .. tostring(#singlePositions + #twoPlayerPositions + #fourPlayerPositions) .. " tables")
	return tableModels
end

return CafeBuilder
