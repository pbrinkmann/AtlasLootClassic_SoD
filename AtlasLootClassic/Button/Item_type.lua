local ALName, ALPrivate = ...
local AtlasLoot = _G.AtlasLoot
local Item = AtlasLoot.Button:AddType("Item", "i")
local Query = {}
Item.Query = Query
local AL = AtlasLoot.Locales
local ClickHandler = AtlasLoot.ClickHandler
local Token = AtlasLoot.Data.Token
local Recipe = AtlasLoot.Data.Recipe
local Profession = AtlasLoot.Data.Profession
local Sets = AtlasLoot.Data.Sets
local Mount = AtlasLoot.Data.Mount
local ItemFrame, Favourite

-- lua
local tonumber = _G.tonumber
local assert = _G.assert
local next, wipe, tab_remove = _G.next, _G.wipe, _G.table.remove
local format, split, sfind, slower = _G.string.format, _G.string.split, _G.string.find, _G.string.lower

-- WoW
local GetItemInfo, IsEquippableItem = _G.GetItemInfo, _G.IsEquippableItem

-- AL
local GetAlTooltip = AtlasLoot.Tooltip.GetTooltip
local GetItemDescInfo = AtlasLoot.ItemInfo.GetDescription
local GetItemString = AtlasLoot.ItemString.Create

local ITEM_COLORS = {}
local WHITE_ICON_FRAME = "Interface\\Common\\WhiteIconFrame"
local SET_ITEM = "|cff00ff00"..AL["Set item"]..":|r "

local itemIsOnEnter, buttonOnEnter = nil, nil

local ItemClickHandler = nil
ClickHandler:Add(
	"Item",
	{
		ChatLink = { "LeftButton", "Shift" },
		DressUp = { "LeftButton", "Ctrl" },
		SetFavourite = { "LeftButton", "Alt" },
		ShowExtraItems = { "LeftButton", "None" },
		types = {
			ChatLink = true,
			DressUp = true,
			ShowExtraItems = true,
			SetFavourite = true,
		},
	},
	{
		{ "ChatLink", 		AL["Chat Link"], 			AL["Add item into chat"] },
		{ "DressUp", 		AL["Dress up"], 			AL["Shows the item in the Dressing room"] },
		{ "SetFavourite", 	AL["Set Favourite"], 		AL["Set the item as favourite"] },
		{ "ShowExtraItems", AL["Show extra items"], 	AL["Shows extra items (tokens,mats)"] },
	}
)

local function OnFavouriteAddonLoad(addon, enabled)
	Favourite = enabled and addon or nil
end


function Item.OnSet(button, second)
	if not ItemClickHandler then
		ItemClickHandler = ClickHandler:GetHandler("Item")
		AtlasLoot.Addons:GetAddon("Favourite", OnFavouriteAddonLoad)
		-- create item colors
		for i=0,7 do
			local _, _, _, itemQuality = GetItemQualityColor(i)
			ITEM_COLORS[i] = itemQuality
		end
		ItemFrame = AtlasLoot.GUI.ItemFrame
	end
	if not button then return end
	if second and button.__atlaslootinfo.secType then
		if type(button.__atlaslootinfo.secType[2]) == "table" then
			button.secButton.ItemID = button.__atlaslootinfo.secType[2].itemID or tonumber(tab_remove(button.__atlaslootinfo.secType[2], 1))
			button.secButton.ItemString = button.__atlaslootinfo.secType[2].itemString or GetItemString(button.secButton.ItemID)
		else
			button.secButton.ItemID = button.__atlaslootinfo.secType[2]
			if button.__atlaslootinfo.preSet and button.__atlaslootinfo.preSet.Item and ( button.__atlaslootinfo.preSet.Item.item2bonus or button.__atlaslootinfo.ItemDifficulty ) then
				button.secButton.ItemString = GetItemString(button.ItemID)
			end
		end
		button.secButton.Droprate = button.__atlaslootinfo.Droprate
		button.secButton.SetID = Sets:GetItemSetForItemID(button.secButton.ItemID)

		Item.Refresh(button.secButton)
	else
		if type(button.__atlaslootinfo.type[2]) == "table" then
			button.ItemID = button.__atlaslootinfo.type[2].itemID or tonumber(tab_remove(button.__atlaslootinfo.type[2], 1))
			button.ItemString = button.__atlaslootinfo.type[2].itemString or GetItemString(button.ItemID)
		else
			button.ItemID = button.__atlaslootinfo.type[2]
			if button.__atlaslootinfo.preSet and button.__atlaslootinfo.preSet.Item and ( button.__atlaslootinfo.preSet.Item.item1bonus or button.__atlaslootinfo.ItemDifficulty ) then
				button.ItemString = GetItemString(button.ItemID)
			end
		end
		button.Droprate = button.__atlaslootinfo.Droprate

		Item.Refresh(button)
	end
end

function Item.OnMouseAction(button, mouseButton)
	if not mouseButton then return end

	mouseButton = ItemClickHandler:Get(mouseButton) or mouseButton
	if mouseButton == "ChatLink" then
		local itemInfo, itemLink = GetItemInfo(button.ItemString or button.ItemID)
		itemLink = itemLink or button.ItemString
		AtlasLoot.Button:AddChatLink(itemLink or "item:"..button.ItemID)
	elseif mouseButton == "DressUp" then
		local itemInfo, itemLink = GetItemInfo(button.ItemString or button.ItemID)
		itemLink = itemLink or button.ItemString
		if itemLink then
			DressUpItemLink(itemLink)
		end
	elseif mouseButton == "ShowExtraItems" then
		if Token.IsToken(button.ItemID) then
			button.ExtraFrameShown = true
			AtlasLoot.Button:ExtraItemFrame_GetFrame(button, Token.GetTokenData(button.ItemID))
		elseif Recipe.IsRecipe(button.ItemID) then
			button.ExtraFrameShown = true
			AtlasLoot.Button:ExtraItemFrame_GetFrame(button, Recipe.GetRecipeDataForExtraFrame(button.ItemID))
		elseif button.type ~= "secButton" and ( button.SetData or Sets:GetItemSetForItemID(button.ItemID) ) then -- sec buttons should not be clickable for sets
			if not button.SetData then
				button.SetData = Sets:GetSetItems(Sets:GetItemSetForItemID(button.ItemID))
			end
			button.ExtraFrameShown = true
			AtlasLoot.Button:ExtraItemFrame_GetFrame(button, button.SetData)
		end
	elseif mouseButton == "SetFavourite" then
		if Favourite then
			if Favourite:IsFavouriteItemID(button.ItemID) then
				Favourite:RemoveItemID(button.ItemID)
				button.favourite:Hide()
			else
				if Favourite:AddItemID(button.ItemID) then
					button.favourite:Show()
				end
			end
		end
	elseif mouseButton == "MouseWheelUp" and Item.previewTooltipFrame and Item.previewTooltipFrame:IsShown() then  -- ^
		local frame = Item.previewTooltipFrame.modelFrame
		if IsAltKeyDown() then -- model zoom
			frame.zoomLevelNew = frame.zoomLevelNew + 0.1 >= frame.maxZoom and frame.maxZoom or frame.zoomLevelNew + 0.1
			frame:SetPortraitZoom(frame.zoomLevelNew)
		else -- model rotation
			frame.curRotation = frame.curRotation + 0.1
			frame:SetRotation(frame.curRotation)
		end
	elseif mouseButton == "MouseWheelDown" and Item.previewTooltipFrame and Item.previewTooltipFrame:IsShown() then	-- v
		local frame = Item.previewTooltipFrame.modelFrame
		if IsAltKeyDown() then -- model zoom
			frame.zoomLevelNew = frame.zoomLevelNew - 0.1 <= frame.minZoom and frame.minZoom or frame.zoomLevelNew - 0.1
			frame:SetPortraitZoom(frame.zoomLevelNew)
		else -- model rotation
			frame.curRotation = frame.curRotation - 0.1
			frame:SetRotation(frame.curRotation)
		end
	end

end

function Item.OnEnter(button, owner)
	local tooltip = GetAlTooltip()
	local db = ItemClickHandler:GetDB()
	tooltip:ClearLines()
	itemIsOnEnter = tooltip
	buttonOnEnter = button
	if owner and type(owner) == "table" then
		tooltip:SetOwner(owner[1], owner[2], owner[3], owner[4])
	else
		tooltip:SetOwner(button, "ANCHOR_RIGHT", -(button:GetWidth() * 0.5), 24)
	end
	if button.ItemString then
		tooltip:SetHyperlink(button.ItemString)
	else
		tooltip:SetItemByID(button.ItemID)
	end
	if button.Droprate and db.showDropRate then
		tooltip:AddDoubleLine(AL["Droprate:"], button.Droprate.."%")
	end
	tooltip:Show()
	if IsShiftKeyDown() or db.alwaysShowCompareTT then
		GameTooltip_ShowCompareItem(tooltip)
	end
	if IsControlKeyDown() or db.alwaysShowPreviewTT then
		if Mount.IsMount(button.ItemID) then
			Item.ShowQuickDressUp(button.ItemID, tooltip)
		else
			local _, link = tooltip:GetItem()
			Item.ShowQuickDressUp(link, tooltip)
		end
	end
end

function Item.OnLeave(button)
	GetAlTooltip():Hide()
	itemIsOnEnter = nil
	buttonOnEnter = nil
	ShoppingTooltip1:Hide()
	ShoppingTooltip2:Hide()
	if Item.previewTooltipFrame and Item.previewTooltipFrame:IsShown() then Item.previewTooltipFrame:Hide() end
	--ShoppingTooltip3:Hide()
end

function Item.OnClear(button)
	Query:Remove(button)
	Query:Remove(button.secButton)
	button.ItemID = nil
	button.Droprate = nil
	button.ItemString = nil
	button.SetData = nil
	button.secButton.ItemID = nil
	button.secButton.Droprate = nil
	button.secButton.ItemString = nil
	button.secButton.SetData = nil

	if button.overlay then
		button.overlay:SetDesaturated(false)
		button.overlay:Hide()
	end
	button.secButton.overlay:Hide()
	button.secButton.overlay:SetDesaturated(false)
	if button.ExtraFrameShown then
		AtlasLoot.Button:ExtraItemFrame_ClearFrame()
		button.ExtraFrameShown = false
	end
end

function Item.Refresh(button)
	if not button.ItemID then return end
	local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(button.ItemString or button.ItemID)
	if not itemName then
		Query:Add(button)
		return false
	end

	button.overlay:Show()
	button.overlay:SetTexture(WHITE_ICON_FRAME)
	button.overlay:SetAtlas(LOOT_BORDER_BY_QUALITY[itemQuality] or LOOT_BORDER_BY_QUALITY[LE_ITEM_QUALITY_UNCOMMON])
	if not LOOT_BORDER_BY_QUALITY[itemQuality] then
		button.overlay:SetDesaturated(true)
	end

	if button.type == "secButton" then
		button:SetNormalTexture(itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
	else
		-- ##################
		-- icon
		-- ##################
		button.icon:SetTexture(itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark")

		-- ##################
		-- name
		-- ##################
		button.name:SetText("|c"..ITEM_COLORS[itemQuality or 0]..itemName)

		-- ##################
		-- description
		-- ##################
		button.extra:SetText(
			Token.GetTokenDescription(button.ItemID) or
			Recipe.GetRecipeDescriptionWithRank(button.ItemID) or
			Profession.GetColorSkillRankItem(button.ItemID) or
			( Sets:GetItemSetForItemID(button.ItemID) and AL["|cff00ff00Set item:|r "] or "")..GetItemDescInfo(itemEquipLoc, itemType, itemSubType)
		)
	end
	if Favourite and Favourite:IsFavouriteItemID(button.ItemID) then
		button.favourite:Show()
	else
		button.favourite:Hide()
	end
	--[[
	if db.showCompletedHook then
		local itemCount = GetItemCount(button.ItemString, true)
		if itemCount and itemCount > 0 then
			button.completed:Show()
		end
	end
	]]--

	return true
end

function Item.GetStringContent(str)
	if tonumber(str) then
		return tonumber(str)
	else
		return {
			split(":", str)
		}
	end
end

--################################
-- Item dess up
--################################
function Item.ShowQuickDressUp(itemLink, ttFrame)
	if not itemLink or ( not IsEquippableItem(itemLink) and not Mount.IsMount(itemLink) ) then return end
	if not Item.previewTooltipFrame then
		local name = "AtlasLoot-SetToolTip"
		local frame = CreateFrame("Frame", name)
		frame:SetClampedToScreen(true)
		frame:SetSize(230, 280)

		frame.modelFrame = CreateFrame("DressUpModel", name.."-ModelFrame", frame)
		frame.modelFrame:ClearAllPoints()
		frame.modelFrame:SetParent(frame)
		frame.modelFrame:SetAllPoints(frame)
		frame.modelFrame.defaultRotation = MODELFRAME_DEFAULT_ROTATION
		frame.modelFrame:SetRotation(MODELFRAME_DEFAULT_ROTATION)
		frame.modelFrame:SetBackdrop(ALPrivate.BOX_BORDER_BACKDROP)
		frame.modelFrame:SetBackdropColor(0,0,0,1)
		frame.modelFrame:SetUnit("player")
		frame.modelFrame.minZoom = 0
		frame.modelFrame.maxZoom = 1.0
		frame.modelFrame.curRotation = MODELFRAME_DEFAULT_ROTATION
		frame.modelFrame.zoomLevel = frame.modelFrame.minZoom
		frame.modelFrame.zoomLevelNew = frame.modelFrame.zoomLevel
		frame.modelFrame:SetPortraitZoom(frame.modelFrame.zoomLevel)
		frame.modelFrame.Reset = _G.Model_Reset

		Item.previewTooltipFrame = frame
		frame:Hide()
	end

	local frame = Item.previewTooltipFrame

	-- calculate point for frame
	local x,y = ttFrame:GetOwner():GetCenter()
	local fPoint, oPoint = "BOTTOMLEFT", "TOPRIGHT"

	if y/GetScreenHeight() > 0.3 then
		fPoint, oPoint = "TOP", "BOTTOM"
	else
		fPoint, oPoint = "BOTTOM", "TOP"
	end
	if x/GetScreenWidth() > 0.5 then
		fPoint, oPoint = fPoint.."LEFT", oPoint.."LEFT"
	else
		fPoint, oPoint = fPoint.."RIGHT", oPoint.."RIGHT"
	end

	frame:Show()

	frame:ClearAllPoints()
	frame:SetParent(ttFrame:GetOwner():GetParent())
	frame:SetFrameStrata("TOOLTIP")
	frame:SetPoint(fPoint, ttFrame, oPoint)

	frame = Item.previewTooltipFrame.modelFrame
	frame:Reset()
	frame:Undress()
	local npcID = Mount.GetMountNpcID(itemLink)
	if npcID then
		frame:SetDisplayInfo(npcID)
		frame:SetPortraitZoom(frame.zoomLevel)
		frame:SetCamDistanceScale(2)
	else
		frame:SetCamDistanceScale(1)
		frame:SetUnit("player")
		local info = {GetItemInfo(itemLink)}
		if not (info[9] == "INVTYPE_CLOAK") then
			frame:SetRotation(frame.curRotation)
		else
			frame:SetRotation(frame.curRotation + math.pi)
		end
		frame:SetPortraitZoom(frame.zoomLevelNew)
		frame:TryOn(itemLink)
	end
end

--################################
-- Item querys
--################################
local button_list = {}

Query.EventFrame = CreateFrame("FRAME")

local function EventFrame_OnEvent(frame, event, arg1, arg2)
	if event == "GET_ITEM_INFO_RECEIVED" then
		if arg1 and button_list[arg1] then
			local button
			for i = 1, #button_list[arg1] do
				button = button_list[arg1][i]
				if button.type == "secButton" then
					button.obj:GetSecTypeFunctions().Refresh(button_list[arg1][i])
				else
					local typFunc = button:GetTypeFunctions()
					if typFunc then
						typFunc.Refresh(button_list[arg1][i])
						if ItemFrame and ItemFrame.SearchString then
							local text = button.name:GetText()
							if text and not sfind(slower(text), ItemFrame.SearchString, 1, true) then
								button:SetAlpha(0.33)
							end
						end
					end
				end
			end
			button_list[arg1] = nil
		end

		if not next(button_list) then
			frame:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
		end
	elseif event == "MODIFIER_STATE_CHANGED" then
		if itemIsOnEnter then
			-- arg2: 1 for pressed, 0 (not nil!) for released
			if arg2 == 1 then
				if arg1 == "LSHIFT" or arg1 == "RSHIFT" then
					GameTooltip_ShowCompareItem(itemIsOnEnter)
				elseif arg1 == "LCTRL" or arg1 == "RCTRL" then
					if Mount.IsMount(buttonOnEnter.ItemID) then
						Item.ShowQuickDressUp(buttonOnEnter.ItemID, itemIsOnEnter)
					else
						local _, link = itemIsOnEnter:GetItem()
						Item.ShowQuickDressUp(link, itemIsOnEnter)
					end
				end
			else
				if arg1 == "LSHIFT" or arg1 == "RSHIFT" then
					ShoppingTooltip1:Hide()
					ShoppingTooltip2:Hide()
					--ShoppingTooltip3:Hide()
				elseif arg1 == "LCTRL" or arg1 == "RCTRL" then
					if Item.previewTooltipFrame and Item.previewTooltipFrame:IsShown() then Item.previewTooltipFrame:Hide() end
				end
			end
		end
	end
end
Query.EventFrame:SetScript("OnEvent", EventFrame_OnEvent)
Query.EventFrame:RegisterEvent("MODIFIER_STATE_CHANGED")

function Query:Add(button)
	assert(button, "Button not found.")
	Query.EventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	if not button_list[button.ItemID] then
		button_list[button.ItemID] = { button }
	else
		button_list[button.ItemID][#button_list[button.ItemID]+1] = button
	end
end

function Query:Remove(button)
	if not button then return end
	if button_list[button] then
		button_list[button] = nil
		if not next(button_list) then
			Query.EventFrame:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
		end
	end
end

function Query:Wipe()
	wipe(button_list)
	Query.EventFrame:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
end
