local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages.React)

local MonetizationConfig = require(Shared.MonetizationConfig)
local ShopItems = require(Shared.ShopItems)
local Theme = require(Shared.Theme)
local SnapEffect = require(script.Parent.SnapEffect)
local SoundService = require(script.Parent.Parent.Parent.services.SoundService)

export type ShopScreenProps = {
	onClose: () -> (),
	playerData: any?,
	onEquip: ((itemId: string, category: string) -> ())?,
	onItemPurchased: ((item: any) -> ())?,
}

-- Build combined cash shop items with category labels
local CASH_SHOP_SECTIONS = {
	{ label = "Board Skins", items = ShopItems.BOARD_SKINS },
	{ label = "Confetti", items = ShopItems.CONFETTI_STYLES },
	{ label = "Snap Effects", items = ShopItems.SNAP_EFFECTS },
}

local TABS = {
	{ key = "board_skins", label = "Board Skins" },
	{ key = "confetti_styles", label = "Confetti" },
	{ key = "snap_effects", label = "Snap Effects" },
	{ key = "robux", label = "Robux" },
}

-- Ordered lists for Robux tab rendering
local GAME_PASS_ORDER = { "VIP", "ALL_IMAGES", "EXPERT", "PUZZLE_ASSIST" }
local DEV_PRODUCT_ORDER = { "CASH_100", "CASH_500", "CASH_1500", "CASH_5000" }

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
}

local function ShopScreen(props: ShopScreenProps)
	local playerCash, setPlayerCash = React.useState(if props.playerData then props.playerData.cash or 0 else 0)
	local purchaseMessage, setPurchaseMessage = React.useState("")
	local isPurchasing, setIsPurchasing = React.useState(false)
	local selectedTab, setSelectedTab = React.useState("board_skins")

	-- Demo effect state for snap effect preview
	local demoEffect, setDemoEffect = React.useState(nil :: { effectId: string, key: string, x: number, y: number }?)
	local demoCounter = React.useRef(0)
	local modalRef = React.useRef(nil :: Frame?)

	-- Equipped state (local mirrors of server state)
	local equippedSkin, setEquippedSkin = React.useState(if props.playerData then props.playerData.equippedBoardSkin or "" else "")
	local equippedConfetti, setEquippedConfetti = React.useState(if props.playerData then props.playerData.equippedConfettiStyle or "" else "")
	local equippedSnapEffect, setEquippedSnapEffect = React.useState(if props.playerData then props.playerData.equippedSnapEffect or "" else "")

	-- Owned state (local mirrors)
	local ownedBoardSkins, setOwnedBoardSkins = React.useState(if props.playerData then props.playerData.ownedBoardSkins or {} else {})
	local ownedConfettiStyles, setOwnedConfettiStyles = React.useState(if props.playerData then props.playerData.ownedConfettiStyles or {} else {})
	local ownedSnapEffects, setOwnedSnapEffects = React.useState(if props.playerData then props.playerData.ownedSnapEffects or {} else {})

	-- Robux tab state
	local ownedGamePasses, setOwnedGamePasses = React.useState({} :: { [string]: boolean })

	-- Check which game passes are already owned
	React.useEffect(function()
		task.spawn(function()
			local localPlayer = Players.LocalPlayer
			if not localPlayer then return end
			local owned: { [string]: boolean } = {}
			for key, pass in MonetizationConfig.GAME_PASSES do
				if pass.id ~= 0 then
					local ok, ownsPass = pcall(function()
						return MarketplaceService:UserOwnsGamePassAsync(localPlayer.UserId, pass.id)
					end)
					if ok and ownsPass then
						owned[key] = true
					end
				end
			end
			setOwnedGamePasses(owned)
		end)
	end, {})

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

					if props.onItemPurchased then
						local purchasedItem = ShopItems.getById(itemId)
						if purchasedItem then
							props.onItemPurchased(purchasedItem)
						end
					end
				end
				task.delay(2, function()
					setPurchaseMessage("")
				end)
			end
		end)
	end

	-- Build item list (cash shop only)
	local listChildren: { [string]: any } = {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0.01, 0),
		}),
		Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0.01, 0),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0.02, 0),
			PaddingRight = UDim.new(0.02, 0),
		}),
	}

	local order = 1

	for _, section in CASH_SHOP_SECTIONS do
		local sectionCategory = section.items[1] and section.items[1].category or ""
		if sectionCategory ~= selectedTab then continue end
		local swatchDefault = CATEGORY_SWATCH_DEFAULTS[sectionCategory] or Color3.fromRGB(80, 80, 100)

		for _, item in section.items do
			-- Hide exclusive items unless already owned (so they can be equipped)
			if (item :: any).starterPackExclusive then
				local isOwnedExclusive = false
				if item.category == "snap_effects" then
					isOwnedExclusive = ownedSnapEffects[item.id] == true
				end
				if not isOwnedExclusive then continue end
			end
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
			local isSnapEffect = item.category == "snap_effects"
			local actionBtnY = if isSnapEffect then 0.72 else 0.5
			local actionBtnH = if isSnapEffect then 0.38 else 0.45

			-- Action button
			local actionButton
			if isEquipped then
				actionButton = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.fromScale(0.95, actionBtnY),
					Size = UDim2.fromScale(0.28, actionBtnH),
					BackgroundColor3 = COLORS.btnEquipped,
					Text = "Equipped",
					TextColor3 = Theme.Colors.textPrimary,
					TextScaled = true,
					Font = Theme.Font.bold,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
					BtnStroke = React.createElement("UIStroke", {
						Thickness = 2,
						Color = COLORS.border,
					}),
				})
			elseif isOwned then
				actionButton = React.createElement("TextButton", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.fromScale(0.95, actionBtnY),
					Size = UDim2.fromScale(0.28, actionBtnH),
					BackgroundColor3 = COLORS.btnEquip,
					Text = "Equip",
					TextColor3 = Theme.Colors.textPrimary,
					TextScaled = true,
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
					Position = UDim2.fromScale(0.95, actionBtnY),
					Size = UDim2.fromScale(0.28, actionBtnH),
					BackgroundColor3 = COLORS.btnBuy,
					Text = "$" .. item.cashPrice,
					TextColor3 = Theme.Colors.textPrimary,
					TextScaled = true,
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
					Position = UDim2.fromScale(0.95, actionBtnY),
					Size = UDim2.fromScale(0.28, actionBtnH),
					BackgroundColor3 = COLORS.btnCantAfford,
					Text = "Can't Afford",
					TextColor3 = Theme.Colors.textPrimary,
					TextScaled = true,
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

			-- Test button for snap effects
			local testButton = nil
			if isSnapEffect then
				testButton = React.createElement("TextButton", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.fromScale(0.95, 0.28),
					Size = UDim2.fromScale(0.28, 0.38),
					BackgroundColor3 = Theme.Colors.accentBlue,
					Text = "Test",
					TextColor3 = Theme.Colors.textPrimary,
					TextScaled = true,
					Font = Theme.Font.bold,
					[React.Event.Activated] = function(_, inputObject)
						demoCounter.current += 1
						local key = item.id .. "_" .. tostring(demoCounter.current)

						-- Calculate click position relative to the modal
						local modal = modalRef.current
						local clickX = 0
						local clickY = 0
						if modal and inputObject then
							local screenPos = inputObject.Position
							local modalPos = modal.AbsolutePosition
							clickX = screenPos.X - modalPos.X
							clickY = screenPos.Y - modalPos.Y
						end

						-- Just set new effect directly — React key forces remount
						setDemoEffect({ effectId = item.id, key = key, x = clickX, y = clickY })
						SoundService.playSnap()
						task.delay(0.8, function()
							setDemoEffect(function(current)
								if current and current.key == key then
									return nil
								end
								return current
							end)
						end)
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
					Position = UDim2.fromScale(0.02, 0.5),
					Size = UDim2.fromScale(0.22, 0.8),
					BackgroundColor3 = swatchColor,
					ClipsDescendants = true,
				}, {
					SwatchCorner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
					AspectRatio = React.createElement("UIAspectRatioConstraint", {
						AspectRatio = 1,
					}),
					SwatchImage = if item.backgroundImage then React.createElement("ImageLabel", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Image = item.backgroundImage,
						ScaleType = Enum.ScaleType.Crop,
					}) else nil,
					Letter = React.createElement("TextLabel", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = firstLetter,
						TextColor3 = Theme.Colors.textPrimary,
						TextScaled = true,
						Font = Theme.Font.heading,
						ZIndex = 2,
					}, {
						LetterStroke = React.createElement("UIStroke", {
							Thickness = 1,
							Color = Theme.Colors.black,
						}),
					}),
				}),
				-- Item name
				Name = React.createElement("TextLabel", {
					Position = UDim2.fromScale(0.26, 0.08),
					Size = UDim2.fromScale(0.4, 0.28),
					BackgroundTransparency = 1,
					Text = item.name,
					TextColor3 = Theme.Colors.textPrimary,
					TextScaled = true,
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
					Position = UDim2.fromScale(0.26, 0.38),
					Size = UDim2.fromScale(0.4, 0.24),
					BackgroundTransparency = 1,
					Text = item.description,
					TextColor3 = COLORS.descText,
					TextScaled = true,
					Font = Theme.Font.regular,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextWrapped = true,
				}, {
				}),
				-- Price
				PriceTag = React.createElement("TextLabel", {
					Position = UDim2.fromScale(0.26, 0.65),
					Size = UDim2.fromScale(0.2, 0.22),
					BackgroundTransparency = 1,
					Text = "$" .. item.cashPrice,
					TextColor3 = COLORS.cashText,
					TextScaled = true,
					Font = Theme.Font.bold,
					TextXAlignment = Enum.TextXAlignment.Left,
				}, {
				}),
				-- Action button
				ActionBtn = actionButton,
				-- Test button (snap effects only)
				TestBtn = testButton,
			})
			order += 1
		end
	end

	-- Robux tab content
	if selectedTab == "robux" then
		-- Helper to create a section header label
		local function createSectionHeader(text: string, color: Color3, layoutOrder: number)
			return React.createElement("TextLabel", {
				LayoutOrder = layoutOrder,
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundTransparency = 1,
				Text = text,
				TextColor3 = color,
				TextScaled = true,
				Font = Theme.Font.heading,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, {
				TextStroke = React.createElement("UIStroke", {
					Thickness = 1.5,
					Color = Theme.Colors.black,
				}),
			})
		end

		-- Section header: Game Passes
		listChildren["SectionGamePasses"] = createSectionHeader("Game Passes", Theme.Colors.headerGold, order)
		order += 1

		-- Game Pass grid container
		local gamePassGridChildren: { [string]: any } = {
			GridLayout = React.createElement("UIGridLayout", {
				CellSize = UDim2.new(0.48, 0, 0, 140),
				CellPadding = UDim2.fromScale(0.02, 0.01),
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}

		local cardOrder = 1
		for _, key in GAME_PASS_ORDER do
			local pass = MonetizationConfig.GAME_PASSES[key]
			if not pass then continue end

			local isOwned = ownedGamePasses[key] == true
			local iconColor = pass.iconColor or Theme.Colors.warning
			local iconText = pass.iconText or "R"
			local iconImage = pass.iconImage

			local actionElement
			if isOwned then
				actionElement = React.createElement("Frame", {
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.fromScale(0.95, 0.9),
					Size = UDim2.fromScale(0.4, 0.25),
					BackgroundColor3 = Theme.Colors.bgMuted,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
					Label = React.createElement("TextLabel", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "Owned",
						TextColor3 = Theme.Colors.textPrimary,
						TextScaled = true,
						Font = Theme.Font.bold,
					}),
				})
			else
				actionElement = React.createElement("TextButton", {
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.fromScale(0.95, 0.9),
					Size = UDim2.fromScale(0.4, 0.25),
					BackgroundColor3 = Theme.Colors.success,
					Text = "R$ " .. pass.robuxPrice,
					TextColor3 = Theme.Colors.textPrimary,
					TextScaled = true,
					Font = Theme.Font.bold,
					[React.Event.Activated] = function()
						promptGamePass(pass.id)
					end,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
					Stroke = React.createElement("UIStroke", {
						Thickness = 2,
						Color = Theme.Colors.border,
					}),
				})
			end

			gamePassGridChildren["GP_" .. key] = React.createElement("Frame", {
				LayoutOrder = cardOrder,
				BackgroundColor3 = Theme.Colors.bgCard,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 12) }),
				Stroke = React.createElement("UIStroke", {
					Thickness = 2,
					Color = Theme.Colors.border,
				}),
				Icon = React.createElement("Frame", {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.fromScale(0.05, 0.5),
					Size = UDim2.fromScale(0.3, 0.9),
					BackgroundColor3 = iconColor,
					BackgroundTransparency = if iconImage then 1 else 0,
				}, {
					IconCorner = React.createElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
					AspectRatio = React.createElement("UIAspectRatioConstraint", {
						AspectRatio = 1,
					}),
					IconContent = if iconImage
						then React.createElement("ImageLabel", {
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							Image = iconImage,
							ScaleType = Enum.ScaleType.Fit,
						})
						else React.createElement("TextLabel", {
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							Text = iconText,
							TextScaled = true,
							Font = Theme.Font.heading,
							TextColor3 = Theme.Colors.textPrimary,
						}),
				}),
				Name = React.createElement("TextLabel", {
					Position = UDim2.fromScale(0.4, 0.08),
					Size = UDim2.fromScale(0.55, 0.2),
					BackgroundTransparency = 1,
					Text = pass.name,
					TextColor3 = Theme.Colors.textPrimary,
					TextScaled = true,
					Font = Theme.Font.bold,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}, {
					NameStroke = React.createElement("UIStroke", {
						Thickness = 1,
						Color = Theme.Colors.black,
					}),
				}),
				Desc = React.createElement("TextLabel", {
					Position = UDim2.fromScale(0.4, 0.3),
					Size = UDim2.fromScale(0.55, 0.25),
					BackgroundTransparency = 1,
					Text = pass.description,
					TextColor3 = Theme.Colors.textMuted,
					TextScaled = true,
					Font = Theme.Font.regular,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextWrapped = true,
				}),
				Action = actionElement,
			})
			cardOrder += 1
		end

		local gpRows = math.ceil(#GAME_PASS_ORDER / 2)
		local gpGridHeight = gpRows * 148

		listChildren["GamePassGrid"] = React.createElement("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, gpGridHeight),
			BackgroundTransparency = 1,
		}, gamePassGridChildren)
		order += 1

		-- Section header: Buy Coins
		listChildren["SectionCoins"] = createSectionHeader("Buy Coins", Theme.Colors.cashGreen, order)
		order += 1

		-- Coin grid container
		local coinGridChildren: { [string]: any } = {
			GridLayout = React.createElement("UIGridLayout", {
				CellSize = UDim2.new(0.48, 0, 0, 140),
				CellPadding = UDim2.fromScale(0.02, 0.01),
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}

		cardOrder = 1
		for _, key in DEV_PRODUCT_ORDER do
			local product = MonetizationConfig.DEV_PRODUCTS[key]
			if not product then continue end

			local iconColor = product.iconColor or Theme.Colors.successLight
			local iconText = product.iconText or "$"

			coinGridChildren["DP_" .. key] = React.createElement("Frame", {
				LayoutOrder = cardOrder,
				BackgroundColor3 = Theme.Colors.bgCard,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 12) }),
				Stroke = React.createElement("UIStroke", {
					Thickness = 2,
					Color = Theme.Colors.border,
				}),
				Icon = React.createElement("Frame", {
					Position = UDim2.fromScale(0.05, 0.1),
					Size = UDim2.fromScale(0.3, 0.5),
					BackgroundColor3 = iconColor,
				}, {
					IconCorner = React.createElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
					AspectRatio = React.createElement("UIAspectRatioConstraint", {
						AspectRatio = 1,
					}),
					Emoji = React.createElement("TextLabel", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = iconText,
						TextScaled = true,
						Font = Theme.Font.heading,
						TextColor3 = Theme.Colors.textPrimary,
					}),
				}),
				Name = React.createElement("TextLabel", {
					Position = UDim2.fromScale(0.4, 0.08),
					Size = UDim2.fromScale(0.55, 0.2),
					BackgroundTransparency = 1,
					Text = product.name,
					TextColor3 = Theme.Colors.textPrimary,
					TextScaled = true,
					Font = Theme.Font.bold,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}, {
					NameStroke = React.createElement("UIStroke", {
						Thickness = 1,
						Color = Theme.Colors.black,
					}),
				}),
				Desc = React.createElement("TextLabel", {
					Position = UDim2.fromScale(0.4, 0.3),
					Size = UDim2.fromScale(0.55, 0.25),
					BackgroundTransparency = 1,
					Text = product.description,
					TextColor3 = Theme.Colors.textMuted,
					TextScaled = true,
					Font = Theme.Font.regular,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextWrapped = true,
				}),
				BuyButton = React.createElement("TextButton", {
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.fromScale(0.95, 0.9),
					Size = UDim2.fromScale(0.4, 0.25),
					BackgroundColor3 = Theme.Colors.success,
					Text = "R$ " .. product.robuxPrice,
					TextColor3 = Theme.Colors.textPrimary,
					TextScaled = true,
					Font = Theme.Font.bold,
					[React.Event.Activated] = function()
						promptDevProduct(product.id)
					end,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
					Stroke = React.createElement("UIStroke", {
						Thickness = 2,
						Color = Theme.Colors.border,
					}),
				}),
			})
			cardOrder += 1
		end

		local coinRows = math.ceil(#DEV_PRODUCT_ORDER / 2)
		local coinGridHeight = coinRows * 148

		listChildren["CoinGrid"] = React.createElement("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, coinGridHeight),
			BackgroundTransparency = 1,
		}, coinGridChildren)
	end

	local isRobuxTab = selectedTab == "robux"

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 150,
	}, {
		Modal = React.createElement("Frame", {
			ref = modalRef,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.85, 0.85),
			BackgroundColor3 = COLORS.bodyBg,
			ClipsDescendants = true,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 16) }),
			AspectRatio = React.createElement("UIAspectRatioConstraint", {
				AspectRatio = 0.85,
				DominantAxis = Enum.DominantAxis.Height,
			}),
			SizeConstraint = React.createElement("UISizeConstraint", {
				MaxSize = Vector2.new(720, math.huge),
			}),
			BorderStroke = React.createElement("UIStroke", {
				Thickness = 3,
				Color = COLORS.border,
			}),

			-- Header (dynamic color based on tab)
			Header = React.createElement("Frame", {
				Size = UDim2.new(1, 0, 0.08, 0),
				BackgroundColor3 = if isRobuxTab then Theme.Colors.accentBlue else COLORS.headerBg,
			}, {
				HeaderCorner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 16) }),
				Title = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.5, 0.7),
					BackgroundTransparency = 1,
					Text = if isRobuxTab then "Robux Shop" else "Cash Shop",
					TextColor3 = Theme.Colors.textPrimary,
					TextScaled = true,
					Font = Theme.Font.heading,
				}, {
					TitleStroke = React.createElement("UIStroke", {
						Thickness = 2,
						Color = Theme.Colors.black,
					}),
				}),
				CloseButton = React.createElement("TextButton", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.fromScale(0.98, 0.5),
					Size = UDim2.fromScale(0.06, 0.8),
					BackgroundColor3 = COLORS.closeBtn,
					Text = "X",
					TextColor3 = Theme.Colors.textPrimary,
					TextScaled = true,
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
					AspectRatio = React.createElement("UIAspectRatioConstraint", {
						AspectRatio = 1,
					}),
				}),
			}),

			-- Tab bar
			TabBar = React.createElement("Frame", {
				Position = UDim2.fromScale(0, 0.08),
				Size = UDim2.new(1, 0, 0.06, 0),
				BackgroundTransparency = 1,
			}, (function()
				local tabChildren: { [string]: any } = {
					Layout = React.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0.02, 0),
					}),
				}
				for i, tab in TABS do
					local isSelected = selectedTab == tab.key
					tabChildren["Tab_" .. tab.key] = React.createElement("TextButton", {
						LayoutOrder = i,
						Size = UDim2.fromScale(0.22, 0.8),
						BackgroundColor3 = if isSelected then Theme.Colors.accentBlue else Theme.Colors.bgMuted,
						BackgroundTransparency = if isSelected then 0 else 0.5,
						Text = tab.label,
						TextColor3 = if isSelected then Theme.Colors.textPrimary else Theme.Colors.textMuted,
						TextScaled = true,
						Font = Theme.Font.bold,
						[React.Event.Activated] = function()
							setSelectedTab(tab.key)
						end,
					}, {
						Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
					})
				end
				return tabChildren
			end)()),

			-- Item list (scrolling) — taller on Robux tab since bottom bar is hidden
			ItemList = React.createElement("ScrollingFrame", {
				Position = UDim2.fromScale(0, 0.14),
				Size = UDim2.fromScale(1, if isRobuxTab then 0.86 else 0.78),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(0, 0, 0, 0),
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Theme.Colors.scrollbar,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, listChildren),

			-- Snap effect demo overlay
			DemoOverlay = if demoEffect ~= nil then React.createElement("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 160,
				ClipsDescendants = false,
			}, {
				[demoEffect.key] = React.createElement(SnapEffect, {
					positionX = demoEffect.x,
					positionY = demoEffect.y,
					effectId = demoEffect.effectId,
					effectKey = demoEffect.key,
				}),
			}) else nil,

			-- Bottom bar (hidden on Robux tab)
			BottomBar = if isRobuxTab then nil else React.createElement("Frame", {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 0, 1, 0),
				Size = UDim2.new(1, 0, 0.07, 0),
				BackgroundColor3 = COLORS.bottomBarBg,
			}, {
				BarCorner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 16) }),
				CashLabel = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.8, 0.7),
					BackgroundTransparency = 1,
					Text = "Your Cash: $" .. playerCash,
					TextColor3 = COLORS.cashText,
					TextScaled = true,
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
