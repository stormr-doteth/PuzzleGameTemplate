local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local ImageCatalog = require(Shared.ImageCatalog)
local FavoriteRewardConfig = require(Shared.FavoriteRewardConfig)

local ProfileService = require(script.Parent.Parent.data.ProfileService)

local FavoriteRewardHandler = {}

local GROUP_ID = FavoriteRewardConfig.GROUP_ID

-- Rate limit: one claim attempt per player per 10 seconds
local lastClaimAttempt: { [number]: number } = {}

local function isInGroup(userId: number): boolean
	local ok, groups = pcall(function()
		return GroupService:GetGroupsAsync(userId)
	end)
	if not ok then
		warn("[FavoriteReward] GetGroupsAsync FAILED:", groups)
		return false
	end
	for _, group in groups do
		if group.Id == GROUP_ID then
			return true
		end
	end
	return false
end

function FavoriteRewardHandler.Init()
	local claimFavoriteReward = Remotes.GetFunction("ClaimFavoriteReward")

	claimFavoriteReward.OnServerInvoke = function(player)
		local userId = player.UserId
		print("[FavoriteReward] === CLAIM ATTEMPT === Player:", player.Name, "UserId:", userId)

		-- Rate limit
		local now = os.clock()
		if lastClaimAttempt[userId] and now - lastClaimAttempt[userId] < 10 then
			return { success = false, message = "Please wait before trying again." }
		end
		lastClaimAttempt[userId] = now

		local profileData = ProfileService.GetData(player)
		if not profileData then
			return { success = false, message = "Profile not loaded" }
		end

		if profileData.HasClaimedFavoriteReward then
			return { success = false, message = "Already claimed" }
		end

		-- Verify group membership (required)
		print("[FavoriteReward] Checking group membership for group:", GROUP_ID)
		local inGroup = isInGroup(userId)
		print("[FavoriteReward] In group:", inGroup)
		if not inGroup then
			return { success = false, message = "Please join our group first, then try again!" }
		end

		-- Verification passed — unlock the reward pack
		print("[FavoriteReward] === GRANTING REWARD ===")
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
