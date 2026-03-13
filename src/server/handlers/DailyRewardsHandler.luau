local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local DailyRewardsConfig = require(Shared.DailyRewardsConfig)

local ProfileService = require(script.Parent.Parent.data.ProfileService)

-- All snap effect IDs that can be given as Day 7 bonus
local SNAP_EFFECT_IDS = {
	"snap_sparkle", "snap_candy", "snap_hearts", "snap_frost",
	"snap_ripple", "snap_toxic", "snap_fire", "snap_emerald",
	"snap_lightning", "snap_confetti", "snap_shadow", "snap_galaxy", "snap_solar",
}

local DailyRewardsHandler = {}

function DailyRewardsHandler.Init()
	local claimDaily = Remotes.GetFunction("ClaimDailyReward")
	local getStatus = Remotes.GetFunction("GetDailyRewardStatus")

	getStatus.OnServerInvoke = function(player)
		local data = ProfileService.GetData(player)
		if not data then
			return { streak = 0, canClaim = false, rewards = DailyRewardsConfig.REWARDS }
		end

		local now = os.time()
		local lastClaim = data.DailyReward_LastClaimTime or 0
		local hoursSinceClaim = (now - lastClaim) / 3600

		local canClaim = lastClaim == 0 or hoursSinceClaim >= DailyRewardsConfig.MIN_CLAIM_HOURS

		-- Check if streak should reset (>48h since last claim)
		local streak = data.DailyReward_Streak or 0
		if lastClaim > 0 and hoursSinceClaim >= DailyRewardsConfig.RESET_HOURS then
			streak = 0
		end

		return {
			streak = streak,
			canClaim = canClaim,
			rewards = DailyRewardsConfig.REWARDS,
			nextDay = streak + 1,
		}
	end

	claimDaily.OnServerInvoke = function(player)
		local data = ProfileService.GetData(player)
		if not data then
			return { success = false, message = "Profile not loaded" }
		end

		local now = os.time()
		local lastClaim = data.DailyReward_LastClaimTime or 0
		local hoursSinceClaim = (now - lastClaim) / 3600

		-- Must wait at least MIN_CLAIM_HOURS since last claim
		if lastClaim > 0 and hoursSinceClaim < DailyRewardsConfig.MIN_CLAIM_HOURS then
			return { success = false, message = "Too soon to claim" }
		end

		-- Determine streak
		local streak = data.DailyReward_Streak or 0

		-- Reset streak if more than RESET_HOURS since last claim
		if lastClaim > 0 and hoursSinceClaim >= DailyRewardsConfig.RESET_HOURS then
			streak = 0
		end

		-- Advance streak (wrap 7→1)
		streak = streak + 1
		if streak > DailyRewardsConfig.STREAK_LENGTH then
			streak = 1
		end

		-- Get reward for this day
		local reward = DailyRewardsConfig.REWARDS[streak]
		if not reward then
			return { success = false, message = "Invalid streak" }
		end

		-- Grant cash
		data.Cash = (data.Cash or 0) + reward.cash

		-- Day 7 bonus: random snap effect player doesn't own, or hints
		local bonusReward = nil
		if reward.isBonus then
			-- Try to find a snap effect the player doesn't own
			local unownedEffects = {}
			for _, effectId in SNAP_EFFECT_IDS do
				if not data.OwnedSnapEffects or not data.OwnedSnapEffects[effectId] then
					table.insert(unownedEffects, effectId)
				end
			end

			if #unownedEffects > 0 then
				-- Pick random unowned snap effect
				local pick = unownedEffects[math.random(1, #unownedEffects)]
				if not data.OwnedSnapEffects then
					data.OwnedSnapEffects = {}
				end
				data.OwnedSnapEffects[pick] = true
				bonusReward = { type = "snap_effect", id = pick }
			else
				-- All snap effects owned, give a cash boost
				data.CashBoostsRemaining = (data.CashBoostsRemaining or 0) + 1
				bonusReward = { type = "cash_boost", count = 1 }
			end
		end

		-- Update profile
		data.DailyReward_LastClaimTime = now
		data.DailyReward_Streak = streak

		return {
			success = true,
			day = streak,
			cash = reward.cash,
			bonusReward = bonusReward,
			newCash = data.Cash,
			newStreak = streak,
		}
	end
end

return DailyRewardsHandler
