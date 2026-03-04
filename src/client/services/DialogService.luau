local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DialogModule = require(ReplicatedStorage:WaitForChild("DialogModule"))

local DialogService = {}

-- Callback registered by App.luau to open overlays (shop, leaderboard, etc.)
local overlayOpener: ((overlayName: string) -> ())? = nil

function DialogService.SetOverlayOpener(opener: (overlayName: string) -> ())
	overlayOpener = opener
end

local function openOverlay(name: string)
	if overlayOpener then
		overlayOpener(name)
	end
end

-- ============================================================
-- DATA-DRIVEN DIALOG CONFIG
-- Add new NPCs here. No other code changes needed.
-- ============================================================
type ResponseHandler = (dialogObject: any, responseNum: number, dialogNum: number) -> ()

type DialogEntry = {
	text: string,
	responses: { string },
}

type NPCConfig = {
	displayName: string,
	dialogs: { DialogEntry },
	onResponse: ResponseHandler,
}

local NPC_DIALOG_CONFIG: { [string]: NPCConfig } = {
	["Nerd"] = {
		displayName = "Showcase NPC",
		dialogs = {
			{
				text = "Welcome to skill24's Puzzles",
				responses = { "thanks!", "leave me alone" },
			},
			{
				text = "Want to check out the shop?",
				responses = { "yes", "no thanks" },
			},
		},
		onResponse = function(dialogObject, responseNum, dialogNum)
			if dialogNum == 1 then
				if responseNum == 1 then
					dialogObject:hideGui("You're very smart", true)
					dialogObject:triggerDialog(Players.LocalPlayer, 2)
				elseif responseNum == 2 then
					dialogObject:hideGui("Fine, be that way!")
				end
			elseif dialogNum == 2 then
				if responseNum == 1 then
					dialogObject:hideGui("Here you go!")
					task.delay(1, function()
						openOverlay("shop")
					end)
				elseif responseNum == 2 then
					dialogObject:hideGui("Maybe next time!")
				end
			end
		end,
	},
}

-- ============================================================
-- RUNTIME STATE
-- ============================================================
local activeDialogObjects: { [string]: any } = {}

-- ============================================================
-- PUBLIC API
-- ============================================================
function DialogService.TriggerDialog(npcName: string, npc: Model, prompt: ProximityPrompt)
	local config = NPC_DIALOG_CONFIG[npcName]
	if not config then
		warn("[DialogService] No config found for NPC:", npcName)
		return
	end

	local player = Players.LocalPlayer

	-- Lazily create the DialogModule object on first interaction
	if not activeDialogObjects[npcName] then
		local dialogObject = DialogModule.new(config.displayName, npc, prompt)
		for _, entry in ipairs(config.dialogs) do
			dialogObject:addDialog(entry.text, entry.responses)
		end

		dialogObject.responded:Connect(function(responseNum, dialogNum)
			config.onResponse(dialogObject, responseNum, dialogNum)
		end)

		activeDialogObjects[npcName] = dialogObject
	end

	activeDialogObjects[npcName]:triggerDialog(player, 1)
end

function DialogService.Init()
	-- Dialog objects are created lazily on first trigger.
end

return DialogService
