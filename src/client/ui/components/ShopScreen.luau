local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages.React)

local ShopItems = require(Shared.ShopItems)
local MonetizationConfig = require(Shared.MonetizationConfig)
local Theme = require(Shared.Theme)

export type ShopScreenProps = {
	onClose: () -> (),
	playerData: any?,
	onEquip: ((itemId: string, category: string) -> ())?,
}

local CATEGORIES = {
	{ key = "cash_shop", label = "Cash Shop", items = {} },
	{ key = "robux", label = "Robux Shop", items = {} },
}

-- Build combined cash shop items with category labels
local CASH_SHOP_SECTIONS = {
	{ label = "Board Skins", items = ShopItems.BOARD_SKINS, pillColor = Color3.fromRGB(60, 100, 200) },
	{ label = "Confetti", items = ShopItems.CONFETTI_STYLES, pillColor = Color3.fromRGB(180, 70, 200) },
	{ label = "Snap Effects", items = ShopItems.SNAP_EFFECTS, pillColor = Color3.fromRGB(220, 150, 30) },
	{ label = "Hints", items = ShopItems.HINTS, pillColor = Color3.fromRGB(60, 180, 100) },
}

-- Design constants
local COLORS = {
	headerBg = Theme.Colors.headerGold,
	bodyBg = Theme.Colors.bgCard,
	border = Theme.Colors.borderDark,
	itemRowBg = Theme.Colors.bgElevated,
	rowBorder = Theme.Colors.border,
	bottomBarBg = Theme.Colors.bgDark,
	cashText = Theme.Colors.cashGreen,
	closeBtn = Theme.Colors.closeRed,
	tabSelected = Theme.Colors.accentBlue,
	tabDefault = Theme.Colors.bgButton,
	btnEquipped = Theme.Colors.bgMuted,
	btnEquip = Theme.Colors.accentBlue,
	btnBuy = Theme.Colors.success,
	btnCantAfford = Theme.Colors.dangerDark,
	descText = Theme.Colors.textMuted,
}

local CATEGORY_SWATCH_DEFAULTS = {
	board_skins = Color3.fromRGB(80, 100, 180),
	confetti_styles = Color3.fromRGB(200, 100, 220),
	snap_effects = Color3.fromRGB(255, 180, 60),
	hints = Color3.fromRGB(100, 220, 130),
}

local function ShopScreen(props: ShopScreenProps)
	local selectedCategory, setSelectedCategory = React.useState(1)
	local playerCash, setPlayerCash = React.useState(if props.playerData then props.playerData.cash or 0 else 0)
	local purchaseMessage, setPurchaseMessage = React.useState("")
	local isPurchasing, setIsPurchasing = React.useState(false)

	-- Equipped state (local mirrors of server state)
	local equippedSkin, setEquippedSkin = React.useState(if props.playerData then props.playerData.equippedBoardSkin or "" else "")
	local equippedConfetti, setEquippedConfetti = React.useState(if props.playerData then props.playerData.equippedConfettiStyle or "" else "")
	local equippedSnapEffect, setEquippedSnapEffect = React.useState(if props.playerData then props.playerData.equippedSnapEffect or "" else "")

	-- Owned state (local mirrors)
	local ownedBoardSkins, setOwnedBoardSkins = React.useState(if props.playerData then props.playerData.ownedBoardSkins or {} else {})
	local ownedConfettiStyles, setOwnedConfettiStyles = React.useState(if props.playerData then props.playerData.ownedConfettiStyles or {} else {})
	local ownedSnapEffects, setOwnedSnapEffects = React.useState(if props.playerData then props.playerData.ownedSnapEffects or {} else {})

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
				setEquippedSnapEffect(data.equippedSnapEffect or "")
				setOwnedBoardSkins(data.ownedBoardSkins or {})
				setOwnedConfettiStyles(data.ownedConfettiStyles or {})
				setOwnedSnapEffects(data.ownedSnapEffects or {})
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
				elseif category == "snap_effects" then
					setEquippedSnapEffect(itemId)
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
		if isPurchasing then return end
		setIsPurchasing(true)
		task.spawn(function()
			local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
			if not remotes then setIsPurchasing(false) return end
			local shopPurchase = remotes:FindFirstChild("ShopPurchase")
			if not shopPurchase or not shopPurchase:IsA("RemoteFunction") then setIsPurchasing(false) return end

			local ok, result = pcall(function()
				return shopPurchase:InvokeServer(itemId)
			end)

			setIsPurchasing(false)

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
					elseif category == "snap_effects" then
						setOwnedSnapEffects(function(prev)
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
			Padding = UDim.new(0, 6),
		}),
		LeftPad = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
	}

	for i, cat in CATEGORIES do
		local isSelected = i == selectedCategory
		tabChildren["Tab_" .. i] = React.createElement("TextButton", {
			LayoutOrder = i,
			Size = UDim2.new(0, 100, 0, 34),
			BackgroundColor3 = if isSelected then COLORS.tabSelected else COLORS.tabDefault,
			Text = cat.label,
			TextColor3 = Theme.Colors.textPrimary,
			TextSize = Theme.TextSize.small,
			Font = Theme.Font.bold,
			[React.Event.Activated] = function()
				setSelectedCategory(i)
			end,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Stroke = React.createElement("UIStroke", {
				Thickness = 1,
				Color = COLORS.rowBorder,
			}),
		})
	end

	-- Build item list
	local listChildren: { [string]: any } = {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
	}

	local category = CATEGORIES[selectedCategory]

	if category.key == "robux" then
		-- Robux shop: GamePasses and DevProducts
		local order = 1

		-- GamePasses
		for key, pass in MonetizationConfig.GAME_PASSES do
			local firstLetter = string.sub(pass.name, 1, 1)
			listChildren["GP_" .. key] = React.createElement("Frame", {
				LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, 90),
				BackgroundColor3 = COLORS.itemRowBg,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
				Stroke = React.createElement("UIStroke", {
					Thickness = 1.5,
					Color = COLORS.rowBorder,
				}),
				-- Preview swatch
				Swatch = React.createElement("Frame", {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 10, 0.5, 0),
					Size = UDim2.fromOffset(64, 64),
					BackgroundColor3 = Theme.Colors.warning,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
					Letter = React.createElement("TextLabel", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "R",
						TextColor3 = Theme.Colors.textPrimary,
						TextSize = Theme.TextSize.heading,
						Font = Theme.Font.heading,
					}, {
						LetterStroke = React.createElement("UIStroke", {
							Thickness = 1,
							Color = Theme.Colors.black,
						}),
					}),
				}),
				-- Category pill
				Pill = React.createElement("TextLabel", {
					Position = UDim2.new(0, 84, 0, 8),
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.new(0, 0, 0, 18),
					BackgroundColor3 = Color3.fromRGB(200, 170, 30),
					Text = "Game Pass",
					TextColor3 = Theme.Colors.textPrimary,
					TextSize = Theme.TextSize.tiny,
					Font = Theme.Font.bold,
				}, {
					PillCorner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
					PillPad = React.createElement("UIPadding", {
						PaddingTop = UDim.new(0, 2),
						PaddingBottom = UDim.new(0, 2),
						PaddingLeft = UDim.new(0, 8),
						PaddingRight = UDim.new(0, 8),
					}),
				}),
				-- Name
				Name = React.createElement("TextLabel", {
					Position = UDim2.new(0, 84, 0, 30),
					Size = UDim2.new(1, -220, 0, 22),
					BackgroundTransparency = 1,
					Text = pass.name,
					TextColor3 = Theme.Colors.warning,
					TextSize = Theme.TextSize.button,
					Font = Theme.Font.bold,
					TextXAlignment = Enum.TextXAlignment.Left,
				}, {
					NameStroke = React.createElement("UIStroke", {
						Thickness = 1.5,
						Color = Theme.Colors.black,
					}),
				}),
				-- Description
				Desc = React.createElement("TextLabel", {
					Position = UDim2.new(0, 84, 0, 52),
					Size = UDim2.new(1, -220, 0, 16),
					BackgroundTransparency = 1,
					Text = pass.description,
					TextColor3 = COLORS.descText,
					TextSize = Theme.TextSize.tiny,
					Font = Theme.Font.regular,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextWrapped = true,
				}),
				-- Price
				Price = React.createElement("TextLabel", {
					Position = UDim2.new(0, 84, 0, 68),
					Size = UDim2.new(0, 100, 0, 16),
					BackgroundTransparency = 1,
					Text = "R$ " .. pass.robuxPrice,
					TextColor3 = COLORS.cashText,
					TextSize = Theme.TextSize.small,
					Font = Theme.Font.bold,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				-- Buy button
				BuyButton = React.createElement("TextButton", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 0),
					Size = UDim2.new(0, 120, 0, 38),
					BackgroundColor3 = COLORS.btnBuy,
					Text = "R$ " .. pass.robuxPrice,
					TextColor3 = Theme.Colors.textPrimary,
					TextSize = Theme.TextSize.label,
					Font = Theme.Font.bold,
					[React.Event.Activated] = function()
						promptGamePass(pass.id)
					end,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
					BtnStroke = React.createElement("UIStroke", {
						Thickness = 2,
						Color = COLORS.border,
					}),
				}),
			})
			order += 1
		end

		-- DevProducts
		for key, product in MonetizationConfig.DEV_PRODUCTS do
			listChildren["DP_" .. key] = React.createElement("Frame", {
				LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, 90),
				BackgroundColor3 = COLORS.itemRowBg,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
				Stroke = React.createElement("UIStroke", {
					Thickness = 1.5,
					Color = COLORS.rowBorder,
				}),
				-- Preview swatch
				Swatch = React.createElement("Frame", {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 10, 0.5, 0),
					Size = UDim2.fromOffset(64, 64),
					BackgroundColor3 = Theme.Colors.successLight,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
					Letter = React.createElement("TextLabel", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "R",
						TextColor3 = Theme.Colors.textPrimary,
						TextSize = Theme.TextSize.heading,
						Font = Theme.Font.heading,
					}, {
						LetterStroke = React.createElement("UIStroke", {
							Thickness = 1,
							Color = Theme.Colors.black,
						}),
					}),
				}),
				-- Category pill
				Pill = React.createElement("TextLabel", {
					Position = UDim2.new(0, 84, 0, 8),
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.new(0, 0, 0, 18),
					BackgroundColor3 = Color3.fromRGB(60, 180, 100),
					Text = "Boost",
					TextColor3 = Theme.Colors.textPrimary,
					TextSize = Theme.TextSize.tiny,
					Font = Theme.Font.bold,
				}, {
					PillCorner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
					PillPad = React.createElement("UIPadding", {
						PaddingTop = UDim.new(0, 2),
						PaddingBottom = UDim.new(0, 2),
						PaddingLeft = UDim.new(0, 8),
						PaddingRight = UDim.new(0, 8),
					}),
				}),
				-- Name
				Name = React.createElement("TextLabel", {
					Position = UDim2.new(0, 84, 0, 30),
					Size = UDim2.new(1, -220, 0, 22),
					BackgroundTransparency = 1,
					Text = product.name,
					TextColor3 = Theme.Colors.successLight,
					TextSize = Theme.TextSize.button,
					Font = Theme.Font.bold,
					TextXAlignment = Enum.TextXAlignment.Left,
				}, {
					NameStroke = React.createElement("UIStroke", {
						Thickness = 1.5,
						Color = Theme.Colors.black,
					}),
				}),
				-- Description
				Desc = React.createElement("TextLabel", {
					Position = UDim2.new(0, 84, 0, 52),
					Size = UDim2.new(1, -220, 0, 16),
					BackgroundTransparency = 1,
					Text = product.description,
					TextColor3 = COLORS.descText,
					TextSize = Theme.TextSize.tiny,
					Font = Theme.Font.regular,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextWrapped = true,
				}),
				-- Price
				Price = React.createElement("TextLabel", {
					Position = UDim2.new(0, 84, 0, 68),
					Size = UDim2.new(0, 100, 0, 16),
					BackgroundTransparency = 1,
					Text = "R$ " .. product.robuxPrice,
					TextColor3 = COLORS.cashText,
					TextSize = Theme.TextSize.small,
					Font = Theme.Font.bold,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				-- Buy button
				BuyButton = React.createElement("TextButton", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 0),
					Size = UDim2.new(0, 120, 0, 38),
					BackgroundColor3 = COLORS.btnBuy,
					Text = "R$ " .. product.robuxPrice,
					TextColor3 = Theme.Colors.textPrimary,
					TextSize = Theme.TextSize.label,
					Font = Theme.Font.bold,
					[React.Event.Activated] = function()
						promptDevProduct(product.id)
					end,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
					BtnStroke = React.createElement("UIStroke", {
						Thickness = 2,
						Color = COLORS.border,
					}),
				}),
			})
			order += 1
		end
	else
		-- Cash shop: all categories combined with section pill labels
		local order = 1

		for _, section in CASH_SHOP_SECTIONS do
			local pillColor = section.pillColor
			local swatchDefault = CATEGORY_SWATCH_DEFAULTS[section.items[1] and section.items[1].category or ""] or Color3.fromRGB(80, 80, 100)

			for _, item in section.items do
				local swatchColor = item.previewColor or swatchDefault
				local firstLetter = string.sub(item.name, 1, 1)

				-- Determine owned/equipped state
				local isOwned = false
				local isEquipped = false
				if item.category == "board_skins" then
					isOwned = ownedBoardSkins[item.id] == true
					isEquipped = equippedSkin == item.id
				elseif item.category == "confetti_styles" then
					isOwned = ownedConfettiStyles[item.id] == true
					isEquipped = equippedConfetti == item.id
				elseif item.category == "snap_effects" then
					isOwned = ownedSnapEffects[item.id] == true
					isEquipped = equippedSnapEffect == item.id
				end

				local canAfford = playerCash >= item.cashPrice and not isPurchasing

				-- Action button
				local actionButton
				if isEquipped then
					actionButton = React.createElement("TextLabel", {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -10, 0.5, 0),
						Size = UDim2.new(0, 120, 0, 38),
						BackgroundColor3 = COLORS.btnEquipped,
						Text = "Equipped",
						TextColor3 = Theme.Colors.textPrimary,
						TextSize = Theme.TextSize.label,
						Font = Theme.Font.bold,
					}, {
						Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
						BtnStroke = React.createElement("UIStroke", {
							Thickness = 2,
							Color = COLORS.border,
						}),
					})
				elseif isOwned and item.category ~= "hints" then
					actionButton = React.createElement("TextButton", {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -10, 0.5, 0),
						Size = UDim2.new(0, 120, 0, 38),
						BackgroundColor3 = COLORS.btnEquip,
						Text = "Equip",
						TextColor3 = Theme.Colors.textPrimary,
						TextSize = Theme.TextSize.label,
						Font = Theme.Font.bold,
						[React.Event.Activated] = function()
							equipItem(item.id, item.category)
						end,
					}, {
						Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
						BtnStroke = React.createElement("UIStroke", {
							Thickness = 2,
							Color = COLORS.border,
						}),
					})
				elseif canAfford then
					actionButton = React.createElement("TextButton", {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -10, 0.5, 0),
						Size = UDim2.new(0, 120, 0, 38),
						BackgroundColor3 = COLORS.btnBuy,
						Text = "$" .. item.cashPrice,
						TextColor3 = Theme.Colors.textPrimary,
						TextSize = Theme.TextSize.label,
						Font = Theme.Font.bold,
						[React.Event.Activated] = function()
							purchaseItem(item.id, item.category)
						end,
					}, {
						Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
						BtnStroke = React.createElement("UIStroke", {
							Thickness = 2,
							Color = COLORS.border,
						}),
					})
				else
					actionButton = React.createElement("TextButton", {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -10, 0.5, 0),
						Size = UDim2.new(0, 120, 0, 38),
						BackgroundColor3 = COLORS.btnCantAfford,
						Text = "Can't Afford",
						TextColor3 = Theme.Colors.textPrimary,
						TextSize = Theme.TextSize.tiny,
						Font = Theme.Font.bold,
						[React.Event.Activated] = function()
							if not isPurchasing then
								purchaseItem(item.id, item.category)
							end
						end,
					}, {
						Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
						BtnStroke = React.createElement("UIStroke", {
							Thickness = 2,
							Color = COLORS.border,
						}),
					})
				end

				listChildren["Item_" .. order] = React.createElement("Frame", {
					LayoutOrder = order,
					Size = UDim2.new(1, 0, 0, 90),
					BackgroundColor3 = COLORS.itemRowBg,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
					Stroke = React.createElement("UIStroke", {
						Thickness = 1.5,
						Color = COLORS.rowBorder,
					}),
					-- Preview swatch
					Swatch = React.createElement("Frame", {
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 10, 0.5, 0),
						Size = UDim2.fromOffset(64, 64),
						BackgroundColor3 = swatchColor,
					}, {
						SwatchCorner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
						Letter = React.createElement("TextLabel", {
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							Text = firstLetter,
							TextColor3 = Theme.Colors.textPrimary,
							TextSize = Theme.TextSize.heading,
							Font = Theme.Font.heading,
						}, {
							LetterStroke = React.createElement("UIStroke", {
								Thickness = 1,
								Color = Theme.Colors.black,
							}),
						}),
					}),
					-- Category pill
					Pill = React.createElement("TextLabel", {
						Position = UDim2.new(0, 84, 0, 8),
						AutomaticSize = Enum.AutomaticSize.X,
						Size = UDim2.new(0, 0, 0, 18),
						BackgroundColor3 = pillColor,
						Text = section.label,
						TextColor3 = Theme.Colors.textPrimary,
						TextSize = Theme.TextSize.tiny,
						Font = Theme.Font.bold,
					}, {
						PillCorner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
						PillPad = React.createElement("UIPadding", {
							PaddingTop = UDim.new(0, 2),
							PaddingBottom = UDim.new(0, 2),
							PaddingLeft = UDim.new(0, 8),
							PaddingRight = UDim.new(0, 8),
						}),
					}),
					-- Item name
					Name = React.createElement("TextLabel", {
						Position = UDim2.new(0, 84, 0, 30),
						Size = UDim2.new(1, -220, 0, 22),
						BackgroundTransparency = 1,
						Text = item.name,
						TextColor3 = Theme.Colors.textPrimary,
						TextSize = Theme.TextSize.button,
						Font = Theme.Font.bold,
						TextXAlignment = Enum.TextXAlignment.Left,
					}, {
						NameStroke = React.createElement("UIStroke", {
							Thickness = 1.5,
							Color = Theme.Colors.black,
						}),
					}),
					-- Description
					Desc = React.createElement("TextLabel", {
						Position = UDim2.new(0, 84, 0, 52),
						Size = UDim2.new(1, -220, 0, 16),
						BackgroundTransparency = 1,
						Text = item.description,
						TextColor3 = COLORS.descText,
						TextSize = Theme.TextSize.tiny,
						Font = Theme.Font.regular,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextWrapped = true,
					}),
					-- Price
					PriceTag = React.createElement("TextLabel", {
						Position = UDim2.new(0, 84, 0, 68),
						Size = UDim2.new(0, 100, 0, 16),
						BackgroundTransparency = 1,
						Text = "$" .. item.cashPrice,
						TextColor3 = COLORS.cashText,
						TextSize = Theme.TextSize.small,
						Font = Theme.Font.bold,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					-- Action button
					ActionBtn = actionButton,
				})
				order += 1
			end
		end
	end

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.black,
		BackgroundTransparency = Theme.Transparency.overlay,
		ZIndex = 150,
	}, {
		Modal = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.55, 0.7),
			BackgroundColor3 = COLORS.bodyBg,
			ClipsDescendants = true,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 16) }),
			BorderStroke = React.createElement("UIStroke", {
				Thickness = 3,
				Color = COLORS.border,
			}),
			SizeConstraint = React.createElement("UISizeConstraint", {
				MinSize = Vector2.new(380, 480),
			}),

			-- Header (gold bar)
			Header = React.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, 56),
				BackgroundColor3 = COLORS.headerBg,
			}, {
				HeaderCorner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 16) }),
				Title = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(0, 200, 0, 40),
					BackgroundTransparency = 1,
					Text = "Shop!",
					TextColor3 = Theme.Colors.textPrimary,
					TextSize = Theme.TextSize.title,
					Font = Theme.Font.heading,
				}, {
					TitleStroke = React.createElement("UIStroke", {
						Thickness = 2,
						Color = Theme.Colors.black,
					}),
				}),
				CloseButton = React.createElement("TextButton", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -8, 0.5, 0),
					Size = UDim2.fromOffset(42, 42),
					BackgroundColor3 = COLORS.closeBtn,
					Text = "X",
					TextColor3 = Theme.Colors.textPrimary,
					TextSize = Theme.TextSize.large,
					Font = Theme.Font.bold,
					[React.Event.Activated] = function()
						props.onClose()
					end,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
					CloseStroke = React.createElement("UIStroke", {
						Thickness = 2,
						Color = COLORS.border,
					}),
				}),
			}),

			-- Category tabs
			TabBar = React.createElement("Frame", {
				Position = UDim2.new(0, 0, 0, 56),
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundTransparency = 1,
			}, tabChildren),

			-- Purchase message (floating)
			Message = if purchaseMessage ~= "" then React.createElement("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 92),
				Size = UDim2.new(0, 300, 0, 24),
				BackgroundTransparency = 1,
				Text = purchaseMessage,
				TextColor3 = Theme.Colors.warning,
				TextSize = Theme.TextSize.body,
				Font = Theme.Font.bold,
				ZIndex = 151,
			}) else nil,

			-- Item list (scrolling)
			ItemList = React.createElement("ScrollingFrame", {
				Position = UDim2.new(0, 0, 0, 100),
				Size = UDim2.new(1, 0, 1, -144),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(0, 0, 0, 0),
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Theme.Colors.scrollbar,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, listChildren),

			-- Bottom bar
			BottomBar = React.createElement("Frame", {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 0, 1, 0),
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundColor3 = COLORS.bottomBarBg,
			}, {
				BarCorner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 16) }),
				CashLabel = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(1, 0, 0, 30),
					BackgroundTransparency = 1,
					Text = "Your Cash: $" .. playerCash,
					TextColor3 = COLORS.cashText,
					TextSize = Theme.TextSize.large,
					Font = Theme.Font.bold,
				}, {
					CashStroke = React.createElement("UIStroke", {
						Thickness = 1.5,
						Color = Theme.Colors.black,
					}),
				}),
			}),
		}),
	})
end

return ShopScreen
