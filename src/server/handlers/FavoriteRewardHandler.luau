local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local ImageCatalog = require(Shared.ImageCatalog)
local FavoriteRewardConfig = require(Shared.FavoriteRewardConfig)

local ProfileService = require(script.Parent.Parent.data.ProfileService)

local FavoriteRewardHandler = {}

function FavoriteRewardHandler.Init()
	local claimFavoriteReward = Remotes.GetFunction("ClaimFavoriteReward")

	claimFavoriteReward.OnServerInvoke = function(player)
		local profileData = ProfileService.GetData(player)
		if not profileData then
			return { success = false, message = "Profile not loaded" }
		end

		if profileData.HasClaimedFavoriteReward then
			return { success = false, message = "Already claimed" }
		end

		-- Unlock all non-default images in the reward pack
		local packImages = ImageCatalog.getByPackId(FavoriteRewardConfig.REWARD_PACK_ID)
		if not profileData.UnlockedImages then
			profileData.UnlockedImages = {}
		end

		local unlockedIds = {}
		for _, entry in packImages do
			if not entry.defaultUnlocked then
				profileData.UnlockedImages[entry.id] = true
				table.insert(unlockedIds, entry.id)
			end
		end

		profileData.HasClaimedFavoriteReward = true

		return {
			success = true,
			unlockedIds = unlockedIds,
			packId = FavoriteRewardConfig.REWARD_PACK_ID,
		}
	end
end

return FavoriteRewardHandler
