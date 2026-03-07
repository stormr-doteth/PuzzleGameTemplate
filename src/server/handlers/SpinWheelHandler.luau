local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local SpinWheelConfig = require(Shared.SpinWheelConfig)
local DailyPuzzleConfig = require(Shared.DailyPuzzleConfig)

local ProfileService = require(script.Parent.Parent.data.ProfileService)

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

	getStatus.OnServerInvoke = function(player)
		local data = ProfileService.GetData(player)
		if not data then
			return { canFreeSpin = false, extraSpinCost = SpinWheelConfig.EXTRA_SPIN_COST }
		end

		local today = getTodaysDateString()
		local canFreeSpin = (data.SpinWheel_LastFreeSpinDate or "") ~= today

		return {
			canFreeSpin = canFreeSpin,
			extraSpinCost = SpinWheelConfig.EXTRA_SPIN_COST,
		}
	end

	spinWheel.OnServerInvoke = function(player)
		local data = ProfileService.GetData(player)
		if not data then
			return { success = false, message = "Profile not loaded" }
		end

		local today = getTodaysDateString()
		local isFreeSpin = (data.SpinWheel_LastFreeSpinDate or "") ~= today

		-- If not free, deduct cash
		if not isFreeSpin then
			if (data.Cash or 0) < SpinWheelConfig.EXTRA_SPIN_COST then
				return { success = false, message = "Not enough cash" }
			end
			data.Cash = data.Cash - SpinWheelConfig.EXTRA_SPIN_COST
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
		end

		-- Mark free spin used
		if isFreeSpin then
			data.SpinWheel_LastFreeSpinDate = today
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
