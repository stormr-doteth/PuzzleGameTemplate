local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages.React)

local ShopItems = require(Shared.ShopItems)
local MonetizationConfig = require(Shared.MonetizationConfig)

export type ShopScreenProps = {
	onClose: () -> (),
	playerData: any?,
	onEquip: ((itemId: string, category: string) -> ())?,
}

local CATEGORIES = {
	{ key = "board_skins", label = "Board Skins", items = ShopItems.BOARD_SKINS },
	{ key = "confetti_styles", label = "Confetti", items = ShopItems.CONFETTI_STYLES },
	{ key = "badges", label = "Badges", items = ShopItems.BADGES },
	{ key = "hints", label = "Hints", items = ShopItems.HINTS },
	{ key = "robux", label = "Robux Shop", items = {} },
}

local function ShopScreen(props: ShopScreenProps)
	local selectedCategory, setSelectedCategory = React.useState(1)
	local playerCash, setPlayerCash = React.useState(if props.playerData then props.playerData.cash or 0 else 0)
	local purchaseMessage, setPurchaseMessage = React.useState("")

	-- Equipped state (local mirrors of server state)
	local equippedSkin, setEquippedSkin = React.useState(if props.playerData then props.playerData.equippedBoardSkin or "" else "")
	local equippedConfetti, setEquippedConfetti = React.useState(if props.playerData then props.playerData.equippedConfettiStyle or "" else "")
	local equippedBadge, setEquippedBadge = React.useState(if props.playerData then props.playerData.equippedBadge or "" else "")

	-- Owned state (local mirrors)
	local ownedBoardSkins, setOwnedBoardSkins = React.useState(if props.playerData then props.playerData.ownedBoardSkins or {} else {})
	local ownedConfettiStyles, setOwnedConfettiStyles = React.useState(if props.playerData then props.playerData.ownedConfettiStyles or {} else {})
	local ownedBadges, setOwnedBadges = React.useState(if props.playerData then props.playerData.ownedBadges or {} else {})

	-- Always fetch fresh player data on mount so owned/equipped state is up to date
	React.useEffect(function()
		task.spawn(function()
			local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
			if not remotes then return end
			local getPlayerData = remotes:FindFirstChild("GetPlayerData")
			if not getPlayerData or not getPlayerData:IsA("RemoteFunction") then return end

			local ok, data = pcall(function()
				return getPlayerData:InvokeServer()
			end)
			if ok and data then
				setPlayerCash(data.cash or 0)
				setEquippedSkin(data.equippedBoardSkin or "")
				setEquippedConfetti(data.equippedConfettiStyle or "")
				setEquippedBadge(data.equippedBadge or "")
				setOwnedBoardSkins(data.ownedBoardSkins or {})
				setOwnedConfettiStyles(data.ownedConfettiStyles or {})
				setOwnedBadges(data.ownedBadges or {})
			end
		end)
	end, {})

	local function equipItem(itemId: string, category: string)
		task.spawn(function()
			local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
			if not remotes then return end
			local equipRemote = remotes:FindFirstChild("EquipItem")
			if not equipRemote or not equipRemote:IsA("RemoteFunction") then return end

			local ok, result = pcall(function()
				return equipRemote:InvokeServer(itemId, category)
			end)

			if ok and result and result.success then
				if category == "board_skins" then
					setEquippedSkin(itemId)
				elseif category == "confetti_styles" then
					setEquippedConfetti(itemId)
				elseif category == "badges" then
					setEquippedBadge(itemId)
				end
				if props.onEquip then
					props.onEquip(itemId, category)
				end
				setPurchaseMessage("Equipped!")
				task.delay(2, function() setPurchaseMessage("") end)
			end
		end)
	end

	local function purchaseItem(itemId: string, category: string)
		task.spawn(function()
			local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
			if not remotes then return end
			local shopPurchase = remotes:FindFirstChild("ShopPurchase")
			if not shopPurchase or not shopPurchase:IsA("RemoteFunction") then return end

			local ok, result = pcall(function()
				return shopPurchase:InvokeServer(itemId)
			end)

			if ok and result then
				setPurchaseMessage(result.message or "")
				if result.success and result.newCash then
					setPlayerCash(result.newCash)
				end
				if result.success then
					-- Update local owned state and auto-equip non-consumables
					if category == "board_skins" then
						setOwnedBoardSkins(function(prev)
							local updated = table.clone(prev)
							updated[itemId] = true
							return updated
						end)
						equipItem(itemId, category)
					elseif category == "confetti_styles" then
						setOwnedConfettiStyles(function(prev)
							local updated = table.clone(prev)
							updated[itemId] = true
							return updated
						end)
						equipItem(itemId, category)
					elseif category == "badges" then
						setOwnedBadges(function(prev)
							local updated = table.clone(prev)
							updated[itemId] = true
							return updated
						end)
						equipItem(itemId, category)
					end
				end
				task.delay(2, function()
					setPurchaseMessage("")
				end)
			end
		end)
	end

	local function promptGamePass(gamePassId: number)
		pcall(function()
			MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, gamePassId)
		end)
	end

	local function promptDevProduct(productId: number)
		pcall(function()
			MarketplaceService:PromptProductPurchase(Players.LocalPlayer, productId)
		end)
	end

	-- Build category tabs
	local tabChildren: { [string]: any } = {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
	}

	for i, cat in CATEGORIES do
		local isSelected = i == selectedCategory
		tabChildren["Tab_" .. i] = React.createElement("TextButton", {
			LayoutOrder = i,
			Size = UDim2.new(0, 90, 0, 32),
			BackgroundColor3 = if isSelected
				then Color3.fromRGB(80, 140, 230)
				else Color3.fromRGB(50, 50, 60),
			Text = cat.label,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 13,
			Font = Enum.Font.GothamMedium,
			[React.Event.Activated] = function()
				setSelectedCategory(i)
			end,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
		})
	end

	-- Build item list
	local listChildren: { [string]: any } = {
		Layout = React.createElement("UIGridLayout", {
			CellSize = UDim2.new(0, 180, 0, 120),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
		Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, 8),
		}),
	}

	local category = CATEGORIES[selectedCategory]

	if category.key == "robux" then
		-- Robux shop: GamePasses and DevProducts
		local order = 1

		-- GamePasses
		for key, pass in MonetizationConfig.GAME_PASSES do
			listChildren["GP_" .. key] = React.createElement("Frame", {
				LayoutOrder = order,
				BackgroundColor3 = Color3.fromRGB(40, 40, 55),
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Name = React.createElement("TextLabel", {
					Position = UDim2.new(0, 8, 0, 8),
					Size = UDim2.new(1, -16, 0, 22),
					BackgroundTransparency = 1,
					Text = pass.name,
					TextColor3 = Color3.fromRGB(255, 220, 80),
					TextSize = 16,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				Desc = React.createElement("TextLabel", {
					Position = UDim2.new(0, 8, 0, 32),
					Size = UDim2.new(1, -16, 0, 36),
					BackgroundTransparency = 1,
					Text = pass.description,
					TextColor3 = Color3.fromRGB(180, 180, 200),
					TextSize = 12,
					Font = Enum.Font.Gotham,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextWrapped = true,
				}),
				BuyButton = React.createElement("TextButton", {
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, -8),
					Size = UDim2.new(0, 140, 0, 30),
					BackgroundColor3 = Color3.fromRGB(50, 180, 80),
					Text = "R$ " .. pass.robuxPrice,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 14,
					Font = Enum.Font.GothamBold,
					[React.Event.Activated] = function()
						promptGamePass(pass.id)
					end,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
				}),
			})
			order += 1
		end

		-- DevProducts
		for key, product in MonetizationConfig.DEV_PRODUCTS do
			listChildren["DP_" .. key] = React.createElement("Frame", {
				LayoutOrder = order,
				BackgroundColor3 = Color3.fromRGB(40, 40, 55),
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Name = React.createElement("TextLabel", {
					Position = UDim2.new(0, 8, 0, 8),
					Size = UDim2.new(1, -16, 0, 22),
					BackgroundTransparency = 1,
					Text = product.name,
					TextColor3 = Color3.fromRGB(120, 255, 120),
					TextSize = 16,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				Desc = React.createElement("TextLabel", {
					Position = UDim2.new(0, 8, 0, 32),
					Size = UDim2.new(1, -16, 0, 36),
					BackgroundTransparency = 1,
					Text = product.description,
					TextColor3 = Color3.fromRGB(180, 180, 200),
					TextSize = 12,
					Font = Enum.Font.Gotham,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextWrapped = true,
				}),
				BuyButton = React.createElement("TextButton", {
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, -8),
					Size = UDim2.new(0, 140, 0, 30),
					BackgroundColor3 = Color3.fromRGB(50, 180, 80),
					Text = "R$ " .. product.robuxPrice,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 14,
					Font = Enum.Font.GothamBold,
					[React.Event.Activated] = function()
						promptDevProduct(product.id)
					end,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
				}),
			})
			order += 1
		end
	else
		-- Cash shop items
		for i, item in category.items do
			local itemChildren: { [string]: any } = {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
			}

			itemChildren["Name"] = React.createElement("TextLabel", {
				Position = UDim2.new(0, 8, 0, 8),
				Size = UDim2.new(1, -16, 0, 22),
				BackgroundTransparency = 1,
				Text = item.name,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 16,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			})

			itemChildren["Desc"] = React.createElement("TextLabel", {
				Position = UDim2.new(0, 8, 0, 32),
				Size = UDim2.new(1, -16, 0, 36),
				BackgroundTransparency = 1,
				Text = item.description,
				TextColor3 = Color3.fromRGB(180, 180, 200),
				TextSize = 12,
				Font = Enum.Font.Gotham,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
			})

			-- Preview color for board skins
			if item.previewColor then
				itemChildren["Preview"] = React.createElement("Frame", {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -8, 0, 8),
					Size = UDim2.fromOffset(24, 24),
					BackgroundColor3 = item.previewColor,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),
				})
			end

			-- Determine owned/equipped state
			local isOwned = false
			local isEquipped = false
			if item.category == "board_skins" then
				isOwned = ownedBoardSkins[item.id] == true
				isEquipped = equippedSkin == item.id
			elseif item.category == "confetti_styles" then
				isOwned = ownedConfettiStyles[item.id] == true
				isEquipped = equippedConfetti == item.id
			elseif item.category == "badges" then
				isOwned = ownedBadges[item.id] == true
				isEquipped = equippedBadge == item.id
			end

			local canAfford = playerCash >= item.cashPrice

			if isEquipped then
				-- Green "EQUIPPED" label
				itemChildren["BuyButton"] = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, -8),
					Size = UDim2.new(0, 140, 0, 30),
					BackgroundColor3 = Color3.fromRGB(40, 120, 60),
					Text = "EQUIPPED",
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 14,
					Font = Enum.Font.GothamBold,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
				})
			elseif isOwned and item.category ~= "hints" then
				-- Blue "EQUIP" button
				itemChildren["BuyButton"] = React.createElement("TextButton", {
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, -8),
					Size = UDim2.new(0, 140, 0, 30),
					BackgroundColor3 = Color3.fromRGB(80, 140, 230),
					Text = "EQUIP",
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 14,
					Font = Enum.Font.GothamBold,
					[React.Event.Activated] = function()
						equipItem(item.id, item.category)
					end,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
				})
			else
				-- Buy button (always shown for hints since they're consumable)
				itemChildren["BuyButton"] = React.createElement("TextButton", {
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, -8),
					Size = UDim2.new(0, 140, 0, 30),
					BackgroundColor3 = if canAfford
						then Color3.fromRGB(80, 140, 230)
						else Color3.fromRGB(60, 60, 70),
					Text = "$" .. item.cashPrice,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 14,
					Font = Enum.Font.GothamBold,
					[React.Event.Activated] = function()
						if canAfford then
							purchaseItem(item.id, item.category)
						end
					end,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
				})
			end

			listChildren["Item_" .. i] = React.createElement("Frame", {
				LayoutOrder = i,
				BackgroundColor3 = Color3.fromRGB(40, 40, 55),
			}, itemChildren)
		end
	end

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.4,
		ZIndex = 150,
	}, {
		Modal = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.5, 0.6),
			BackgroundColor3 = Color3.fromRGB(15, 15, 25),
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 12) }),
			SizeConstraint = React.createElement("UISizeConstraint", {
				MinSize = Vector2.new(320, 400),
			}),

			-- Title bar
			TitleBar = React.createElement("Frame", {
			Size = UDim2.new(1, 0, 0, 50),
			BackgroundTransparency = 1,
		}, {
			Title = React.createElement("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(0, 200, 0, 40),
				BackgroundTransparency = 1,
				Text = "Shop",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 32,
				Font = Enum.Font.GothamBold,
			}),
			CashDisplay = React.createElement("TextLabel", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 16, 0.5, 0),
				Size = UDim2.new(0, 120, 0, 30),
				BackgroundTransparency = 1,
				Text = "Cash: $" .. playerCash,
				TextColor3 = Color3.fromRGB(120, 255, 120),
				TextSize = 18,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			CloseButton = React.createElement("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -16, 0.5, 0),
				Size = UDim2.fromOffset(36, 36),
				BackgroundColor3 = Color3.fromRGB(200, 60, 60),
				Text = "X",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 20,
				Font = Enum.Font.GothamBold,
				[React.Event.Activated] = function()
					props.onClose()
				end,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
			}),
		}),

		-- Category tabs
		TabBar = React.createElement("Frame", {
			Position = UDim2.new(0, 0, 0, 50),
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
		}, tabChildren),

		-- Purchase message
		Message = if purchaseMessage ~= "" then React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 92),
			Size = UDim2.new(0, 300, 0, 24),
			BackgroundTransparency = 1,
			Text = purchaseMessage,
			TextColor3 = Color3.fromRGB(255, 220, 80),
			TextSize = 16,
			Font = Enum.Font.GothamBold,
			ZIndex = 151,
		}) else nil,

		-- Item grid
		ItemGrid = React.createElement("ScrollingFrame", {
			Position = UDim2.new(0, 16, 0, 118),
			Size = UDim2.new(1, -32, 1, -134),
			CanvasSize = UDim2.new(0, 0, 0, math.ceil(#(category.items or {}) / 2) * 128 + 20),
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = Color3.fromRGB(100, 100, 120),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, listChildren),
		}),
	})
end

return ShopScreen
