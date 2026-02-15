local AssetService = game:GetService("AssetService")

local ImageService = {}

function ImageService.loadImage(assetId: string): (EditableImage?, number, number)
	local success, editableImage = pcall(function()
		return AssetService:CreateEditableImageAsync(Content.fromUri(assetId))
	end)

	if not success or not editableImage then
		warn("[ImageService] Failed to load image:", assetId, editableImage)
		return nil, 0, 0
	end

	local width = editableImage.Size.X
	local height = editableImage.Size.Y

	return editableImage, width, height
end

return ImageService
