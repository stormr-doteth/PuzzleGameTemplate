local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.Theme)

local TableStatusService = {}

-- tableId -> BillboardGui
local billboards: { [string]: BillboardGui } = {}

-- tableId -> tableModel
local tables: { [string]: Model } = {}

local function createBillboard(tableModel: Model): BillboardGui?
	local tabletop = tableModel:FindFirstChild("Tabletop", true)
		or tableModel.PrimaryPart
		or tableModel:FindFirstChildWhichIsA("BasePart", true)
	if not tabletop then
		warn("[TableStatusService] No adornee part found in " .. tableModel.Name)
		return nil
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TableStatusBillboard"
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.MaxDistance = 40
	billboard.AlwaysOnTop = false
	billboard.Size = UDim2.new(0, 260, 0, 50)
	billboard.Enabled = false

	local frame = Instance.new("Frame")
	frame.Name = "Background"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Theme.Colors.bgDark
	frame.BackgroundTransparency = 0.15
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.Radius.md
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Color = Theme.Colors.border
	stroke.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "StatusLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = ""
	label.Font = Theme.Font.heading
	label.TextSize = 16
	label.TextColor3 = Theme.Colors.textPrimary
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Theme.Colors.black
	label.Parent = frame

	billboard.Parent = tabletop
	return billboard
end

function TableStatusService.Init(tableModels: { [string]: Model })
	for tableId, tableModel in tableModels do
		local tableType = tableModel:FindFirstChild("TableType")
		if tableType and tableType:IsA("StringValue") and tableType.Value:match("^multi") then
			tables[tableId] = tableModel
			local billboard = createBillboard(tableModel)
			if billboard then
				billboards[tableId] = billboard
			end
		end
	end
end

function TableStatusService.UpdateTableStatus(tableId: string, state: string?, playerCount: number, maxPlayers: number?)
	local billboard = billboards[tableId]
	if not billboard then return end

	local frame = billboard:FindFirstChild("Background")
	if not frame then return end

	local label = frame:FindFirstChild("StatusLabel") :: TextLabel?
	local stroke = frame:FindFirstChildOfClass("UIStroke")
	if not label then return end

	if state == "lobby" then
		billboard.Enabled = true
		label.Text = "\u{2615} " .. playerCount .. "/" .. (maxPlayers or 4) .. " Players \u{2014} Waiting..."
		label.TextColor3 = Theme.Colors.gold
		if stroke then
			stroke.Color = Theme.Colors.gold
		end
	elseif state == "playing" then
		billboard.Enabled = true
		label.Text = "\u{1F9E9} Game In Progress"
		label.TextColor3 = Theme.Colors.danger
		if stroke then
			stroke.Color = Theme.Colors.danger
		end
	else
		billboard.Enabled = false
	end
end

function TableStatusService.SetSeatsEnabled(tableModel: Model, enabled: boolean)
	for _, descendant in tableModel:GetDescendants() do
		if descendant:IsA("Seat") then
			if enabled then
				descendant.Disabled = false
			else
				-- Only disable empty seats so current players aren't ejected
				if not descendant.Occupant then
					descendant.Disabled = true
				end
			end

			-- Also toggle ProximityPrompt on empty seats
			local prompt = descendant:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				if enabled and not descendant.Occupant then
					prompt.Enabled = true
				elseif not enabled then
					prompt.Enabled = false
				end
			end
		end
	end
end

return TableStatusService
