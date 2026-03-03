local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages.React)

local ShopItems = require(Shared.ShopItems)
local Theme = require(Shared.Theme)
local SnapEffect = require(script.Parent.SnapEffect)
local SoundService = require(script.Parent.Parent.Parent.services.SoundService)

export type ShopScreenProps = {
	onClose: () -> (),
	playerData: any?,
	onEquip: ((itemId: string, category: string) -> ())?,
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
					TextConstraint = React.createElement("UITextSizeConstraint", {
						MaxTextSize = 14,
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
					TextConstraint = React.createElement("UITextSizeConstraint", {
						MaxTextSize = 14,
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
					TextConstraint = React.createElement("UITextSizeConstraint", {
						MaxTextSize = 14,
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
					TextConstraint = React.createElement("UITextSizeConstraint", {
						MaxTextSize = 11,
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
					TextConstraint = React.createElement("UITextSizeConstraint", {
						MaxTextSize = 12,
					}),
				})
			end

			listChildren["Item_" .. order] = React.createElement("Frame", {
				LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, 80),
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
					Size = UDim2.fromScale(0.15, 0.75),
					BackgroundColor3 = swatchColor,
				}, {
					SwatchCorner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
					AspectRatio = React.createElement("UIAspectRatioConstraint", {
						AspectRatio = 1,
					}),
					Letter = React.createElement("TextLabel", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = firstLetter,
						TextColor3 = Theme.Colors.textPrimary,
						TextScaled = true,
						Font = Theme.Font.heading,
					}, {
						LetterStroke = React.createElement("UIStroke", {
							Thickness = 1,
							Color = Theme.Colors.black,
						}),
						TextConstraint = React.createElement("UITextSizeConstraint", {
							MaxTextSize = 28,
						}),
					}),
				}),
				-- Item name
				Name = React.createElement("TextLabel", {
					Position = UDim2.fromScale(0.2, 0.1),
					Size = UDim2.fromScale(0.45, 0.25),
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
					TextConstraint = React.createElement("UITextSizeConstraint", {
						MaxTextSize = 16,
					}),
				}),
				-- Description
				Desc = React.createElement("TextLabel", {
					Position = UDim2.fromScale(0.2, 0.38),
					Size = UDim2.fromScale(0.45, 0.2),
					BackgroundTransparency = 1,
					Text = item.description,
					TextColor3 = COLORS.descText,
					TextScaled = true,
					Font = Theme.Font.regular,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextWrapped = true,
				}, {
					TextConstraint = React.createElement("UITextSizeConstraint", {
						MaxTextSize = 11,
					}),
				}),
				-- Price
				PriceTag = React.createElement("TextLabel", {
					Position = UDim2.fromScale(0.2, 0.62),
					Size = UDim2.fromScale(0.2, 0.18),
					BackgroundTransparency = 1,
					Text = "$" .. item.cashPrice,
					TextColor3 = COLORS.cashText,
					TextScaled = true,
					Font = Theme.Font.bold,
					TextXAlignment = Enum.TextXAlignment.Left,
				}, {
					TextConstraint = React.createElement("UITextSizeConstraint", {
						MaxTextSize = 13,
					}),
				}),
				-- Action button
				ActionBtn = actionButton,
				-- Test button (snap effects only)
				TestBtn = testButton,
			})
			order += 1
		end
	end

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.black,
		BackgroundTransparency = Theme.Transparency.overlay,
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
			BorderStroke = React.createElement("UIStroke", {
				Thickness = 3,
				Color = COLORS.border,
			}),

			-- Header (gold bar)
			Header = React.createElement("Frame", {
				Size = UDim2.new(1, 0, 0.08, 0),
				BackgroundColor3 = COLORS.headerBg,
			}, {
				HeaderCorner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 16) }),
				Title = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.5, 0.7),
					BackgroundTransparency = 1,
					Text = "Cash Shop",
					TextColor3 = Theme.Colors.textPrimary,
					TextScaled = true,
					Font = Theme.Font.heading,
				}, {
					TitleStroke = React.createElement("UIStroke", {
						Thickness = 2,
						Color = Theme.Colors.black,
					}),
					TextConstraint = React.createElement("UITextSizeConstraint", {
						MaxTextSize = 24,
					}),
				}),
				CloseButton = React.createElement("TextButton", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -8, 0.5, 0),
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
					TextConstraint = React.createElement("UITextSizeConstraint", {
						MaxTextSize = 20,
					}),
				}),
			}),

			-- Purchase message (floating)
			Message = if purchaseMessage ~= "" then React.createElement("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0.09),
				Size = UDim2.fromScale(0.6, 0.04),
				BackgroundTransparency = 1,
				Text = purchaseMessage,
				TextColor3 = Theme.Colors.warning,
				TextScaled = true,
				Font = Theme.Font.bold,
				ZIndex = 151,
			}, {
				TextConstraint = React.createElement("UITextSizeConstraint", {
					MaxTextSize = 16,
				}),
			}) else nil,

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
						Size = UDim2.fromScale(0.28, 0.8),
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
						TextConstraint = React.createElement("UITextSizeConstraint", {
							MaxTextSize = 13,
						}),
					})
				end
				return tabChildren
			end)()),

			-- Item list (scrolling)
			ItemList = React.createElement("ScrollingFrame", {
				Position = UDim2.fromScale(0, 0.14),
				Size = UDim2.fromScale(1, 0.78),
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

			-- Bottom bar
			BottomBar = React.createElement("Frame", {
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
					TextConstraint = React.createElement("UITextSizeConstraint", {
						MaxTextSize = 20,
					}),
				}),
			}),
		}),
	})
end

return ShopScreen
