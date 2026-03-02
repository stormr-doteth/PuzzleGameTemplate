local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared.MonetizationConfig)
local ShopItems = require(Shared.ShopItems)
local Remotes = require(Shared.Remotes)

local ProfileService = require(script.Parent.Parent.data.ProfileService)

local MonetizationHandler = {}

-- Rate limiting for shop purchases (3s cooldown per player)
local SHOP_COOLDOWN = 3
local lastShopPurchaseTime: { [number]: number } = {}

local function getPlayerByUserId(userId: number): Player?
	for _, player in Players:GetPlayers() do
		if player.UserId == userId then
			return player
		end
	end
	return nil
end

function MonetizationHandler.Init()
	-- Clean up on PlayerRemoving
	Players.PlayerRemoving:Connect(function(player)
		lastShopPurchaseTime[player.UserId] = nil
	end)

	-- Process DevProduct receipts
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local player = getPlayerByUserId(receiptInfo.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local profileData = ProfileService.GetData(player)
		if not profileData then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		-- Check if already processed
		if not profileData.PurchaseHistory then
			profileData.PurchaseHistory = {}
		end
		for _, purchase in profileData.PurchaseHistory do
			if purchase.receiptId == receiptInfo.PurchaseId then
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
		end

		local productId = receiptInfo.ProductId
		local product = MonetizationConfig.getDevProductById(productId)

		if not product then
			warn("[MonetizationHandler] Unknown product:", productId)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		-- Grant the product
		local granted = false

		if product.cashAmount then
			-- Cash products (CASH_100, CASH_500, CASH_1500, CASH_5000)
			profileData.Cash = profileData.Cash + product.cashAmount
			granted = true
		end

		if granted then
			-- Record purchase (cap history to prevent unbounded DataStore growth)
			table.insert(profileData.PurchaseHistory, {
				receiptId = receiptInfo.PurchaseId,
				productId = productId,
				timestamp = os.time(),
			})
			if #profileData.PurchaseHistory > 100 then
				table.remove(profileData.PurchaseHistory, 1)
			end

			-- Force save immediately to prevent duplicate grants on crash
			local profile = ProfileService.GetProfile(player)
			if profile then
				pcall(function()
					profile:Save()
				end)
			end

			-- Notify client of updated data
			local xpAwarded = Remotes.GetEvent("XPAwarded")
			xpAwarded:FireClient(player, {
				cashGained = product.cashAmount or 0,
			})

			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Handle Cash shop purchases (in-game currency)
	local remotes = ReplicatedStorage:WaitForChild("PuzzleRemotes")

	-- Create shop purchase remote if it doesn't exist
	local shopPurchase = remotes:FindFirstChild("ShopPurchase")
	if not shopPurchase then
		shopPurchase = Instance.new("RemoteFunction")
		shopPurchase.Name = "ShopPurchase"
		shopPurchase.Parent = remotes
	end

	(shopPurchase :: RemoteFunction).OnServerInvoke = function(player, itemId)
		if type(itemId) ~= "string" then
			return { success = false, message = "Invalid item" }
		end

		-- Rate limit shop purchases
		local now = os.clock()
		local lastTime = lastShopPurchaseTime[player.UserId]
		if lastTime and (now - lastTime) < SHOP_COOLDOWN then
			return { success = false, message = "Please wait before purchasing again" }
		end
		lastShopPurchaseTime[player.UserId] = now

		local profileData = ProfileService.GetData(player)
		if not profileData then
			return { success = false, message = "Profile not loaded" }
		end

		local item = ShopItems.getById(itemId)
		if not item then
			return { success = false, message = "Item not found" }
		end

		-- Validate price is positive
		if type(item.cashPrice) ~= "number" or item.cashPrice <= 0 then
			return { success = false, message = "Invalid item price" }
		end

		-- Check if already owned (non-consumable items)
		if item.category == "board_skins" then
			if profileData.OwnedBoardSkins and profileData.OwnedBoardSkins[itemId] then
				return { success = false, message = "Already owned" }
			end
		elseif item.category == "confetti_styles" then
			if profileData.OwnedConfettiStyles and profileData.OwnedConfettiStyles[itemId] then
				return { success = false, message = "Already owned" }
			end
		elseif item.category == "snap_effects" then
			if profileData.OwnedSnapEffects and profileData.OwnedSnapEffects[itemId] then
				return { success = false, message = "Already owned" }
			end
		end

		-- Check cash
		if profileData.Cash < item.cashPrice then
			return { success = false, message = "Not enough Cash" }
		end

		-- Deduct cash
		profileData.Cash = profileData.Cash - item.cashPrice

		-- Grant item
		if item.category == "board_skins" then
			if not profileData.OwnedBoardSkins then profileData.OwnedBoardSkins = {} end
			profileData.OwnedBoardSkins[itemId] = true
		elseif item.category == "confetti_styles" then
			if not profileData.OwnedConfettiStyles then profileData.OwnedConfettiStyles = {} end
			profileData.OwnedConfettiStyles[itemId] = true
		elseif item.category == "snap_effects" then
			if not profileData.OwnedSnapEffects then profileData.OwnedSnapEffects = {} end
			profileData.OwnedSnapEffects[itemId] = true
		elseif item.category == "hints" then
			local hintCount = (item :: any).hintCount or 1
			profileData.HintsRemaining = (profileData.HintsRemaining or 0) + hintCount
		end

		return { success = true, message = "Purchased!", newCash = profileData.Cash }
	end

	-- Handle EquipItem requests
	local equipItem = remotes:FindFirstChild("EquipItem")
	if not equipItem then
		equipItem = Instance.new("RemoteFunction")
		equipItem.Name = "EquipItem"
		equipItem.Parent = remotes
	end

	(equipItem :: RemoteFunction).OnServerInvoke = function(player, itemId, category)
		if type(itemId) ~= "string" or type(category) ~= "string" then
			return { success = false, message = "Invalid request" }
		end

		local profileData = ProfileService.GetData(player)
		if not profileData then
			return { success = false, message = "Profile not loaded" }
		end

		if category == "board_skins" then
			if not profileData.OwnedBoardSkins or not profileData.OwnedBoardSkins[itemId] then
				return { success = false, message = "Not owned" }
			end
			profileData.EquippedBoardSkin = itemId
		elseif category == "confetti_styles" then
			if not profileData.OwnedConfettiStyles or not profileData.OwnedConfettiStyles[itemId] then
				return { success = false, message = "Not owned" }
			end
			profileData.EquippedConfettiStyle = itemId
		elseif category == "snap_effects" then
			if not profileData.OwnedSnapEffects or not profileData.OwnedSnapEffects[itemId] then
				return { success = false, message = "Not owned" }
			end
			profileData.EquippedSnapEffect = itemId
		else
			return { success = false, message = "Invalid category" }
		end

		return { success = true, message = "Equipped!" }
	end
end

return MonetizationHandler
