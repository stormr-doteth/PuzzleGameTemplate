local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local SpinWheelConfig = require(Shared.SpinWheelConfig)
local DailyPuzzleConfig = require(Shared.DailyPuzzleConfig)

local ProfileService = require(script.Parent.Parent.data.ProfileService)

-- Cache PolicyService results per player
local policyCache: { [number]: boolean } = {}

local function arePaidRandomItemsRestricted(player: Player): boolean
	if policyCache[player.UserId] ~= nil then
		return policyCache[player.UserId]
	end
	local ok, result = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	local restricted = false
	if ok and result then
		restricted = result.ArePaidRandomItemsRestricted == true
	end
	policyCache[player.UserId] = restricted
	return restricted
end

-- All snap effect IDs for random rewards
local SNAP_EFFECT_IDS = {
	"snap_sparkle", "snap_candy", "snap_hearts", "snap_frost",
	"snap_ripple", "snap_toxic", "snap_fire", "snap_emerald",
	"snap_lightning", "snap_confetti", "snap_shadow", "snap_galaxy", "snap_solar",
}

local SpinWheelHandler = {}

local function getTodaysDateString(): string
	return DailyPuzzleConfig.getTodaysDateString()
end

local function weightedRandomPick(): number
	local roll = math.random(1, SpinWheelConfig.TOTAL_WEIGHT)
	local cumulative = 0
	for i, seg in SpinWheelConfig.SEGMENTS do
		cumulative = cumulative + seg.weight
		if roll <= cumulative then
			return i
		end
	end
	return #SpinWheelConfig.SEGMENTS
end

function SpinWheelHandler.Init()
	local spinWheel = Remotes.GetFunction("SpinWheel")
	local getStatus = Remotes.GetFunction("GetSpinWheelStatus")

	-- Clean up policy cache on player leaving
	Players.PlayerRemoving:Connect(function(player)
		policyCache[player.UserId] = nil
	end)

	getStatus.OnServerInvoke = function(player)
		local data = ProfileService.GetData(player)
		if not data then
			return { canFreeSpin = false, secondsUntilFreeSpin = 0, paidSpinsRestricted = false }
		end

		local today = getTodaysDateString()
		local canFreeSpin = (data.SpinWheel_LastFreeSpinDate or "") ~= today

		-- Compute seconds until UTC midnight (when the date changes and free spin resets)
		local secondsUntilFreeSpin = 0
		if not canFreeSpin then
			local utcNow = os.date("!*t", os.time())
			secondsUntilFreeSpin = (24 - utcNow.hour - 1) * 3600 + (60 - utcNow.min - 1) * 60 + (60 - utcNow.sec)
		end

		return {
			canFreeSpin = canFreeSpin,
			secondsUntilFreeSpin = secondsUntilFreeSpin,
			paidSpinsRestricted = arePaidRandomItemsRestricted(player),
		}
	end

	spinWheel.OnServerInvoke = function(player)
		local data = ProfileService.GetData(player)
		if not data then
			return { success = false, message = "Profile not loaded" }
		end

		local today = getTodaysDateString()
		local isFreeSpin = (data.SpinWheel_LastFreeSpinDate or "") ~= today

		-- If not free, consume a spin token (purchased via Robux)
		if not isFreeSpin then
			-- Block paid spins in restricted regions
			if arePaidRandomItemsRestricted(player) then
				return { success = false, message = "Paid random items are not available in your region" }
			end
			if (data.SpinTokens or 0) < 1 then
				return { success = false, message = "No spin tokens" }
			end
			data.SpinTokens = data.SpinTokens - 1
		end

		-- Server-authoritative weighted random pick
		local segmentIndex = weightedRandomPick()
		local segment = SpinWheelConfig.SEGMENTS[segmentIndex]

		-- Grant reward
		local rewardDescription = segment.label
		if segment.type == "cash" then
			data.Cash = (data.Cash or 0) + segment.amount
		elseif segment.type == "hints" then
			data.HintsRemaining = (data.HintsRemaining or 0) + segment.amount
		elseif segment.type == "snap_effect" then
			-- Give a random snap effect the player doesn't own
			local unowned = {}
			for _, effectId in SNAP_EFFECT_IDS do
				if not data.OwnedSnapEffects or not data.OwnedSnapEffects[effectId] then
					table.insert(unowned, effectId)
				end
			end
			if #unowned > 0 then
				local pick = unowned[math.random(1, #unowned)]
				if not data.OwnedSnapEffects then
					data.OwnedSnapEffects = {}
				end
				data.OwnedSnapEffects[pick] = true
				rewardDescription = "Snap Effect: " .. pick
			else
				-- All owned, give $100 instead
				data.Cash = (data.Cash or 0) + 100
				rewardDescription = "$100 (all effects owned)"
			end
		elseif segment.type == "cash_boost" then
			data.CashBoostsRemaining = (data.CashBoostsRemaining or 0) + segment.amount
		end

		-- Mark free spin used
		if isFreeSpin then
			data.SpinWheel_LastFreeSpinDate = today
			data.SpinWheel_LastFreeSpinTimestamp = os.time()
		end

		return {
			success = true,
			segmentIndex = segmentIndex,
			reward = rewardDescription,
			newCash = data.Cash,
			canFreeSpin = false, -- just used or paid
		}
	end
end

return SpinWheelHandler
