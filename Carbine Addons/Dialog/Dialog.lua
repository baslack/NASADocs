-----------------------------------------------------------------------------------------------
-- Client Lua Script for ChallengeLog
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
require "Window"
require "DialogSys"
require "Quest"
require "DialogResponse"

local Dialog = {}

-- TODO Hardcoded Colors for Items
local karEvalColors = 
{
	[Item.CodeEnumItemQuality.Inferior] 		= ApolloColor.new("ItemQuality_Inferior"),
	[Item.CodeEnumItemQuality.Average] 			= ApolloColor.new("ItemQuality_Average"),
	[Item.CodeEnumItemQuality.Good] 			= ApolloColor.new("ItemQuality_Good"),
	[Item.CodeEnumItemQuality.Excellent] 		= ApolloColor.new("ItemQuality_Excellent"),
	[Item.CodeEnumItemQuality.Superb] 			= ApolloColor.new("ItemQuality_Superb"),
	[Item.CodeEnumItemQuality.Legendary] 		= ApolloColor.new("ItemQuality_Legendary"),
	[Item.CodeEnumItemQuality.Artifact]		 	= ApolloColor.new("ItemQuality_Artifact"),
}

local kcrDefaultOptionColor = ApolloColor.new("white")
local kcrHighlightOptionColor = ApolloColor.new(110/255, 255/255, 72/255, 1.0)

function Dialog:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	return o
end

function Dialog:Init()
	Apollo.RegisterAddon(self)
end

---------------------------------------------------------------------------------------------------
-- Dialog EventHandlers
---------------------------------------------------------------------------------------------------
function Dialog:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("Dialog.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function Dialog:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	Apollo.LoadSprites("UI\\Dialog\\DialogSprites.xml") -- Old
	Apollo.RegisterEventHandler("Dialog_ShowState", "OnDialog_ShowState", self)
	Apollo.RegisterEventHandler("Dialog_Close", "OnDialog_Close", self)
	Apollo.RegisterTimerHandler("DialogUpdateTimer", "OnUpdateTimer", self)

	self.wndPlayer = Apollo.LoadForm(self.xmlDoc, "PlayerWindow", nil, self)
	self.wndPlayer:ToFront()
	self.nWndPlayerLeft, self.nWndPlayerTop, self.nWndPlayerRight, self.nWndPlayerBottom = self.wndPlayer:GetAnchorOffsets()
	self.wndPlayer:Show(false, true)

	self.wndNpc = Apollo.LoadForm(self.xmlDoc, "NpcWindow", nil, self)
	self.nWndNpcLeft, self.nWndNpcTop, self.nWndNpcRight, self.nWndNpcBottom = self.wndNpc:GetAnchorOffsets()
	self.wndNpc:Show(false, true)

	self.wndItem = Apollo.LoadForm(self.xmlDoc, "ItemWindow", nil, self)
	self.nWndItemLeft, self.nWndItemTop, self.nWndItemRight, self.nWndItemBottom = self.wndItem:GetAnchorOffsets()
	self.wndItem:Show(false, true)

	self.bRewardPicked = false
	
	Apollo.CreateTimer("DialogUpdateTimer", 0.050, true)
	Apollo.StopTimer("DialogUpdateTimer")
end

---------------------------------------------------------------------------------------------------
-- New Player Bubble Methods
---------------------------------------------------------------------------------------------------
function Dialog:OnDialog_Close()
	self.wndPlayer:Show(false)
	self.wndItem:Show(false)
	self.wndNpc:Show(false)
	Apollo.StopTimer("DialogUpdateTimer")
end

function Dialog:OnDialog_ShowState(eState, queCurrent)
	local idQuest = 0
	if queCurrent and queCurrent:GetId() then
		idQuest = queCurrent:GetId()
	end

	self.bRewardPicked = false

	if eState == DialogSys.DialogState_Inactive or
		eState == DialogSys.DialogState_Vending or
		eState == DialogSys.DialogState_Training or
		eState == DialogSys.DialogState_TradeskillTraining or
		eState == DialogSys.DialogState_CraftingStation then

		self:OnDialog_Close() -- Close if they click vending/training, as we open another window
		return
	end

	-- Player Window
	local tResponseList = DialogSys.GetResponses(idQuest)
	if not tResponseList or #tResponseList == 0 then
		self:OnDialog_Close()
		return
	end

	self:DrawResponses(eState, idQuest, tResponseList)

	-- NPC Window or Item Window when it's not a comm call
	if DialogSys.GetNPC() and not DialogSys.IsItemQuestGiver() and DialogSys.GetCommCreatureId() == nil then
		self:DrawNpcBubble(self.wndNpc, eState, idQuest)
	elseif DialogSys.GetCommCreatureId() == nil then
		self:DrawItemBubble(self.wndItem, eState, idQuest)
	end
	Apollo.StartTimer("DialogUpdateTimer")
end

function Dialog:DrawResponses(eState, idQuest, tResponseList)
	self.wndPlayer:FindChild("ResponseItemContainer"):DestroyChildren()
	self.wndPlayer:FindChild("GoodbyeContainer"):Show(false)
	self.wndPlayer:FindChild("VendorContainer"):Show(false)
	self.wndPlayer:FindChild("TopSummaryText"):Show(false)
	self.wndPlayer:FindChild("QuestTaskText"):Show(false)
	local nOnGoingHeight = 0

	-- Top Summary Text (only shows up for quests and if there are rewards)
	local queCurr = DialogSys.GetViewableQuest(idQuest)
	local strTopResponseText = DialogSys.GetResponseText()
	if queCurr and queCurr:GetRewardData() and #queCurr:GetRewardData() > 0 and strTopResponseText and string.len(strTopResponseText) > 0 then
		self.wndPlayer:FindChild("TopSummaryText"):SetAML("<P Font=\"CRB_Dialog\" TextColor=\"ff7fffb9\">"..strTopResponseText.."</P>")
		self.wndPlayer:FindChild("TopSummaryText"):SetHeightToContentHeight()
		self.wndPlayer:FindChild("TopSummaryText"):Show(true)
		local nLeft, nTop, nRight, nBottom = self.wndPlayer:FindChild("TopSummaryText"):GetAnchorOffsets()
		self.wndPlayer:FindChild("TopSummaryText"):SetAnchorOffsets(nLeft, nTop, nRight, nBottom + 8) -- TODO: Hardcoded!  -- +8 is bottom padding
		nOnGoingHeight = nOnGoingHeight + (nBottom - nTop) + 8

	end

	-- Rest of Responses
	local nResponseHeight = 0
	for idx, drResponse in ipairs(tResponseList) do
		local eResponseType = drResponse:GetType()
		local wndCurr = nil
		if eResponseType == DialogResponse.DialogResponseType_ViewVending then

			wndCurr = self.wndPlayer:FindChild("VendorContainer")
			wndCurr:FindChild("VendorText"):SetAML("<P Font=\"CRB_Dialog\" TextColor=\"ff7fffb9\">"..drResponse:GetText().."</P>")
			wndCurr:FindChild("VendorIcon"):SetSprite(self:HelperComputeIconPath(eResponseType))
			wndCurr:FindChild("VendorBtn"):SetData(drResponse)
			wndCurr:Show(true)
			nOnGoingHeight = nOnGoingHeight + self.wndPlayer:FindChild("VendorContainer"):GetHeight()

		elseif eResponseType == DialogResponse.DialogResponseType_Goodbye then

			wndCurr = self.wndPlayer:FindChild("GoodbyeContainer")
			wndCurr:FindChild("GoodbyeText"):SetAML("<P Font=\"CRB_Dialog\" TextColor=\"ff8096a8\">"..drResponse:GetText().."</P>")
			wndCurr:FindChild("GoodbyeIcon"):SetSprite(self:HelperComputeIconPath(eResponseType))
			wndCurr:FindChild("GoodbyeBtn"):SetData(drResponse)
			wndCurr:Show(true)
			nOnGoingHeight = nOnGoingHeight + self.wndPlayer:FindChild("GoodbyeContainer"):GetHeight()

		elseif eResponseType == DialogResponse.DialogResponseType_QuestComplete then

			wndCurr = Apollo.LoadForm(self.xmlDoc, "ResponseItem", self.wndPlayer:FindChild("ResponseItemContainer"), self)
			self:HelperComputeRewardIcon(wndCurr, drResponse:GetRewardId(), queCurr:GetRewardData().arRewardChoices)
			wndCurr:FindChild("ResponseItemText"):SetData(drResponse:GetText())
			wndCurr:FindChild("ResponseItemText"):SetText(drResponse:GetText())
			wndCurr:FindChild("ResponseItemText"):SetFont("CRB_Dialog")
			wndCurr:FindChild("ResponseItemText"):SetTextColor(self:HelperComputeRewardTextColor(drResponse:GetRewardId(), DialogSys.GetViewableQuest(idQuest):GetRewardData()))
			wndCurr:FindChild("ResponseItemBtn"):SetData(drResponse)
			nResponseHeight = nResponseHeight + wndCurr:GetHeight()
		else
			local crTextColor = eResponseType == DialogResponse.DialogResponseType_QuestMoreInfo and CColor.new(128/255, 150/255, 168/255, 1) or CColor.new(1, 1, 1, 1)
			wndCurr = Apollo.LoadForm(self.xmlDoc, "ResponseItem", self.wndPlayer:FindChild("ResponseItemContainer"), self)
			wndCurr:FindChild("ResponseItemIcon"):SetSprite(self:HelperComputeIconPath(eResponseType))
			wndCurr:FindChild("ResponseItemText"):SetText(drResponse:GetText())
			wndCurr:FindChild("ResponseItemText"):SetFont("CRB_Dialog")
			wndCurr:FindChild("ResponseItemText"):SetTextColor(crTextColor)
			wndCurr:FindChild("ResponseItemBtn"):SetData(drResponse)
			nResponseHeight = nResponseHeight + wndCurr:GetHeight()
		end
	end
	self.wndPlayer:FindChild("ResponseItemContainer"):ArrangeChildrenVert(0, function(a,b) return b:FindChild("ResponseItemCantUse"):IsShown() end)

	local nLeft, nTop, nRight, nBottom = self.wndPlayer:FindChild("ResponseItemContainer"):GetAnchorOffsets()
	self.wndPlayer:FindChild("ResponseItemContainer"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + nResponseHeight)

	self.wndPlayer:FindChild("PlayerWindowContainer"):ArrangeChildrenVert()

	Event_FireGenericEvent("Test_MouseReturnSignal") -- TODO: possibly remove
	
	self.wndPlayer:SetAnchorOffsets(self.nWndPlayerLeft, self.nWndPlayerTop, self.nWndPlayerRight, self.nWndPlayerBottom + nOnGoingHeight + nResponseHeight)
	self.wndPlayer:Show(true)
	self.wndPlayer:ToFront()
end

function Dialog:OnResponseBtnClick(wndHandler, wndControl) -- ResponseItemBtn
	if not wndHandler or not wndHandler:GetData() then
		return
	end

	local drResponse = wndHandler:GetData()
	if drResponse:GetRewardId() and drResponse:GetRewardId() ~= 0 and drResponse:GetRewardId() ~= self.bRewardPicked then
		-- Reset text first
		for idx, wndCurr in pairs(self.wndPlayer:FindChild("ResponseItemContainer"):GetChildren()) do
			if wndCurr:FindChild("ResponseItemText") and wndCurr:FindChild("ResponseItemText"):GetData() then
				wndCurr:FindChild("ResponseItemText"):SetText(wndCurr:FindChild("ResponseItemText"):GetData())
				wndCurr:FindChild("ResponseItemText"):SetTextColor(kcrDefaultOptionColor)
			end
		end
		self.bRewardPicked = drResponse:GetRewardId()
		wndHandler:FindChild("ResponseItemText"):SetText(String_GetWeaselString(Apollo.GetString("Dialog_TakeItem"), wndHandler:FindChild("ResponseItemText"):GetData()))
		wndHandler:FindChild("ResponseItemText"):SetTextColor(kcrHighlightOptionColor)
	else
		wndHandler:GetData():Select() -- All the work is done in DialogSys's Select Method
	end
end

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------

function Dialog:HelperComputeIconPath(eResponseType)
	local strSprite = "CRB_DialogSprites:sprDialog_Icon_Decline"
	if eResponseType == DialogResponse.DialogResponseType_ViewVending then
		strSprite = "sprMM_VendorGeneral"
	elseif eResponseType == DialogResponse.DialogResponseType_ViewTraining then
		strSprite = "sprMM_VendorGeneral"
	elseif eResponseType == DialogResponse.DialogResponseType_ViewCraftingStation then
		strSprite = "sprMM_VendorGeneral"
	elseif eResponseType == DialogResponse.DialogResponseType_ViewTradeskillTraining then
		strSprite = "sprMM_VendorGeneral"
	elseif eResponseType == DialogResponse.DialogResponseType_ViewQuestAccept then
		strSprite = "CRB_DialogSprites:sprDialog_Icon_Exclamation"
	elseif eResponseType == DialogResponse.DialogResponseType_ViewQuestComplete then
		strSprite = "CRB_DialogSprites:sprDialog_Icon_Check"
	elseif eResponseType == DialogResponse.DialogResponseType_ViewQuestIncomplete then
		strSprite = "CRB_DialogSprites:sprDialog_Icon_DisabledCheck"
	elseif eResponseType == DialogResponse.DialogResponseType_Goodbye then
		strSprite = "CRB_DialogSprites:sprDialog_Icon_Decline"
	elseif eResponseType == DialogResponse.DialogResponseType_QuestAccept then
		strSprite = "CRB_DialogSprites:sprDialog_Icon_Exclamation"
	elseif eResponseType == DialogResponse.DialogResponseType_QuestMoreInfo then
		strSprite = "CRB_DialogSprites:sprDialog_Icon_More"
	elseif eResponseType == DialogResponse.DialogResponseType_QuestComplete then
		strSprite = "CRB_DialogSprites:sprDialog_Icon_Check"
	end
	return strSprite
end

function Dialog:HelperComputeRewardTextColor(idReward, tChoiceRewardData)
	if idReward == 0 then
		return kcrDefaultOptionColor
	end

	for idx, tCurrReward in ipairs(tChoiceRewardData) do
		if tCurrReward and tCurrReward.idReward == idReward then
			if tCurrReward.eType == Quest.Quest2RewardType_Item then
				return karEvalColors[tCurrReward.itemReward:GetItemQuality()]
			end
			break
		end
	end
	
	return kcrDefaultOptionColor
end

function Dialog:HelperComputeRewardIcon(wndCurr, idReward, tChoiceRewardData)
	if idReward == 0 then
		return
	end

	local tFoundRewardData = nil
	for idx, tCurrReward in ipairs(tChoiceRewardData) do
		if tCurrReward.idReward == idReward then
			tFoundRewardData = tCurrReward
			break
		end
	end

	if tFoundRewardData and wndCurr then
		local strIconSprite = ""
		if tFoundRewardData.eType == Quest.Quest2RewardType_Item then
			strIconSprite = tFoundRewardData.itemReward:GetIcon()
			self:HelperBuildItemTooltip(wndCurr, tFoundRewardData.itemReward)
		elseif tFoundRewardData.eType == Quest.Quest2RewardType_Reputation then
			strIconSprite = "Icon_ItemMisc_UI_Item_Parchment"
			wndCurr:SetTooltip(String_GetWeaselString(Apollo.GetString("Dialog_FactionRepReward"), tFoundRewardData.nAmount, tFoundRewardData.strFactionName))
		elseif tFoundRewardData.eType == Quest.Quest2RewardType_TradeSkillXp then
			strIconSprite = "ClientSprites:Icon_ItemMisc_tool_0001"
			wndCurr:SetTooltip(String_GetWeaselString(Apollo.GetString("Dialog_TradeskillXPReward"), tFoundRewardData.nXP, tFoundRewardData.strTradeskill)) --hardcoded
		elseif tFoundRewardData.eType == Quest.Quest2RewardType_GrantTradeskill then
			strIconSprite = "ClientSprites:Icon_ItemMisc_tool_0001"
			wndCurr:SetTooltip("")
		elseif tFoundRewardData.eType == Quest.Quest2RewardType_Money then
			if tFoundRewardData.eCurrencyType == Money.CodeEnumCurrencyType.Credits then
				local strText = ""
				local nInCopper = tFoundRewardData.nAmount
				if nInCopper >= 1000000 then
					strText = strText .. String_GetWeaselString(Apollo.GetString("CRB_Platinum"), math.floor(nInCopper / 1000000))
				end
				if nInCopper >= 10000 then
					strText = strText .. String_GetWeaselString(Apollo.GetString("CRB_Gold"), math.floor(nInCopper % 1000000 / 10000))
				end
				if nInCopper >= 100 then
					strText = strText .. String_GetWeaselString(Apollo.GetString("CRB_Silver"), math.floor(nInCopper % 10000 / 100))
				end
				wndCurr:SetTooltip(strText .. String_GetWeaselString(Apollo.GetString("CRB_Copper"), math.floor(nInCopper % 100)))
				strIconSprite = "ClientSprites:Icon_ItemMisc_bag_0001"
			else
				local tDenomInfo = GameLib.GetPlayerCurrency(tFoundRewardData.eCurrencyType):GetDenomInfo()
				if tDenomInfo ~= nil then
					strText = tFoundRewardData.nAmount .. " " .. tDenomInfo[1].strName
					strIconSprite = "ClientSprites:Icon_ItemMisc_bag_0001"
					wndCurr:SetTooltip(strText)				
				end	
			end
		end

		wndCurr:FindChild("ResponseItemIcon"):Show(false)
		wndCurr:FindChild("ResponseItemRewardBG"):Show(true)
		wndCurr:FindChild("ResponseItemRewardIcon"):SetSprite(strIconSprite)
		wndCurr:FindChild("ResponseItemCantUse"):Show(self:HelperPrereqFailed(tFoundRewardData.itemReward))
	end
end


function Dialog:HelperDrawLootItem(wndCurrReward, tCurrReward)
	local strIconSprite = ""
	if tCurrReward and tCurrReward.eType == Quest.Quest2RewardType_Item then

		strIconSprite = tCurrReward.itemReward:GetIcon()
		wndCurrReward:FindChild("LootDescription"):SetText(tCurrReward.itemReward:GetName())
		wndCurrReward:FindChild("LootDescription"):SetTextColor(karEvalColors[tCurrReward.itemReward:GetItemQuality()])
		wndCurrReward:FindChild("LootItemCantUse"):Show(self:HelperPrereqFailed(tCurrReward.itemReward))
		self:HelperBuildItemTooltip(wndCurrReward, tCurrReward.itemReward)

	elseif tCurrReward and tCurrReward.eType == Quest.Quest2RewardType_Reputation then

		-- Reputation has overloaded fields: objectId is factionId. objectAmount is rep amount.
		strIconSprite = "Icon_ItemMisc_UI_Item_Parchment"
		wndCurrReward:FindChild("LootDescription"):SetText(String_GetWeaselString(Apollo.GetString("Dialog_FactionRepReward"), tCurrReward.nAmount, tCurrReward.strFactionName))
		wndCurrReward:SetTooltip(String_GetWeaselString(Apollo.GetString("Dialog_FactionRepReward"), tCurrReward.nAmount, tCurrReward.strFactionName))

	elseif tCurrReward and tCurrReward.eType == Quest.Quest2RewardType_TradeSkillXp then

		-- Tradeskill XP has overloaded fields: objectId is factionId. objectAmount is rep amount.
		strIconSprite = "ClientSprites:Icon_ItemMisc_tool_0001"
		wndCurrReward:FindChild("LootDescription"):SetText(String_GetWeaselString(Apollo.GetString("Dialog_TradeskillXPReward"), tCurrReward.nXP, tCurrReward.strTradeskill))
		wndCurrReward:SetTooltip(String_GetWeaselString(Apollo.GetString("Dialog_TradeskillXPReward"), tCurrReward.nXP, tCurrReward.strTradeskill))

	elseif tCurrReward and tCurrReward.eType == Quest.Quest2RewardType_GrantTradeskill then

		-- Tradeskill XP has overloaded fields: objectId is tradeskillId.
		strIconSprite = "ClientSprites:Icon_ItemMisc_tool_0001"
		wndCurrReward:FindChild("LootDescription"):SetText(tCurrReward.strTradeskill)
		wndCurrReward:SetTooltip("")

	elseif tCurrReward and tCurrReward.eType == Quest.Quest2RewardType_Money then
		if tCurrReward.eCurrencyType == Money.CodeEnumCurrencyType.Credits then
			strIconSprite = "ClientSprites:Icon_ItemMisc_bag_0001"
			wndCurrReward:FindChild("LootDescription"):Show(false)
			wndCurrReward:FindChild("LootCashWindow"):Show(true)
			wndCurrReward:FindChild("LootCashWindow"):SetAmount(tCurrReward.nAmount, 0)

			local strText = ""
			local nInCopper = tCurrReward.nAmount
			if nInCopper >= 1000000 then
				strText = strText .. "  " .. String_GetWeaselString(Apollo.GetString("CRB_Platinum"), math.floor(nInCopper / 1000000))
			end
			if nInCopper >= 10000 then
				strText = strText .. "  " .. String_GetWeaselString(Apollo.GetString("CRB_Gold"), math.floor(nInCopper % 1000000 / 10000))
			end
			if nInCopper >= 100 then
				strText = strText .. "  " .. String_GetWeaselString(Apollo.GetString("CRB_Silver"), math.floor(nInCopper % 10000 / 100))
			end
			wndCurrReward:SetTooltip(strText .. "  " .. String_GetWeaselString(Apollo.GetString("CRB_Copper"), math.floor(nInCopper % 100)))
		else
			local tDenomInfo = GameLib.GetPlayerCurrency(tCurrReward.eCurrencyType):GetDenomInfo()
			if tDenomInfo ~= nil then
				strText = tCurrReward.nAmount .. " " .. tDenomInfo[1].strName
				strIconSprite = "ClientSprites:Icon_ItemMisc_bag_0001"
				wndCurrReward:FindChild("LootDescription"):Show(false)
				wndCurrReward:FindChild("LootCashWindow"):Show(true)
				wndCurrReward:FindChild("LootCashWindow"):SetMoneySystem(tCurrReward.eCurrencyType or 0)				
				wndCurrReward:FindChild("LootCashWindow"):SetAmount(tCurrReward.nAmount, 0)				
				wndCurrReward:SetTooltip(strText)				
			end
		end
	end

	wndCurrReward:FindChild("LootItemIcon"):SetSprite(strIconSprite)
end


---------------------------------------------------------------------------------------------------
-- New Item and NPC Bubble Methods
---------------------------------------------------------------------------------------------------

function Dialog:DrawItemBubble(wndArg, eState, idQuest)
	-- We are going to be sneaky and just use DrawNpcBubble to draw ItemBubble as they are set up the same
	self:DrawNpcBubble(wndArg, eState, idQuest)
	local nHeightWithText = self:HelperExpandForText(self.nWndItemTop, wndArg)
	self.wndItem:SetAnchorOffsets(self.nWndItemLeft, nHeightWithText, self.nWndItemRight, self.nWndItemBottom)
end

function Dialog:DrawNpcBubble(wndArg, eState, idQuest)
	-- Hardcoded formatting

	-- Text
	local strText = DialogSys.GetNPCText(idQuest)
	if not strText or string.len(strText) == 0 then return end
	wndArg:FindChild("BubbleText"):SetAML("<P Font=\"CRB_Dialog\" TextColor=\"ff7fffb9\">"..strText.."</P>")
	wndArg:FindChild("BubbleText"):SetHeightToContentHeight()

	-- Rewards
	wndArg:FindChild("GivenRewardsText"):Show(false)
	wndArg:FindChild("ChoiceRewardsText"):Show(false)
	local queCurr = DialogSys.GetViewableQuest(idQuest)
	local nGivenContainerHeight = 0
	local nChoiceContainerHeight = 0
	if queCurr then
		local tRewardInfo = queCurr:GetRewardData()
		if tRewardInfo.arFixedRewards and #tRewardInfo.arFixedRewards > 0 then
			wndArg:FindChild("GivenRewardsItems"):DestroyChildren()
			local tDoThisLast = nil
			for idx, tCurrReward in ipairs(tRewardInfo.arFixedRewards) do
				if tCurrReward and tCurrReward.eType == Quest.Quest2RewardType_Money and tCurrReward.nAmount > 0 then
					tDoThisLast = tCurrReward
				elseif tCurrReward then
					local wndCurrReward = Apollo.LoadForm(self.xmlDoc, "LootItem", wndArg:FindChild("GivenRewardsItems"), self)
					self:HelperDrawLootItem(wndCurrReward, tCurrReward)
					nGivenContainerHeight = nGivenContainerHeight + wndCurrReward:GetHeight()
				end
			end

			 -- Given Rewards Only: Draw money at the bottom
			if tDoThisLast then
				local wndCurrReward = Apollo.LoadForm(self.xmlDoc, "LootItem", wndArg:FindChild("GivenRewardsItems"), self)
				self:HelperDrawLootItem(wndCurrReward, tDoThisLast)
				nGivenContainerHeight = nGivenContainerHeight + wndCurrReward:GetHeight()
			end
			-- End draw money and xp

			wndArg:FindChild("GivenRewardsItems"):ArrangeChildrenVert()
			wndArg:FindChild("GivenRewardsItems"):SetAnchorOffsets(0, 0, 0, nGivenContainerHeight)

			wndArg:FindChild("GivenRewardsText"):Show(true)
			nGivenContainerHeight = nGivenContainerHeight + 30 -- +30 for the text label after resizing
		end

		if tRewardInfo.arRewardChoices and #tRewardInfo.arRewardChoices > 0 and eState ~= DialogSys.DialogState_QuestComplete then -- GOTCHA: Choices are shown in Player, not NPC for QuestComplete
			wndArg:FindChild("ChoiceRewardsItems"):DestroyChildren()
			for idx, tCurrReward in ipairs(tRewardInfo.arRewardChoices) do
				if tCurrReward then
					local wndCurrReward = Apollo.LoadForm(self.xmlDoc, "LootItem", wndArg:FindChild("ChoiceRewardsItems"), self)
					self:HelperDrawLootItem(wndCurrReward, tCurrReward)
					nChoiceContainerHeight = nChoiceContainerHeight + wndCurrReward:GetHeight()
				end
			end

			wndArg:FindChild("ChoiceRewardsItems"):ArrangeChildrenVert()
			wndArg:FindChild("ChoiceRewardsItems"):SetAnchorOffsets(0, 0, 0, nChoiceContainerHeight)

			wndArg:FindChild("ChoiceRewardsText"):Show(#tRewardInfo.arRewardChoices > 1)
			if #tRewardInfo.arRewardChoices > 1 then 
				nChoiceContainerHeight = nChoiceContainerHeight + 30 
			end
		end
	end

	wndArg:FindChild("RewardsContainer"):ArrangeChildrenVert()
	wndArg:FindChild("RewardsContainer"):SetAnchorOffsets(0, 0, 0, nGivenContainerHeight + nChoiceContainerHeight)

	wndArg:FindChild("BubbleWindowContainer"):ArrangeChildrenVert()
	wndArg:Show(true)
	wndArg:ToFront()
end

---------------------------------------------------------------------------------------------------
-- Old NPC Bubble Methods
---------------------------------------------------------------------------------------------------
function Dialog:PositionNpcBubble(wndArg)
	local unitNpc = DialogSys.GetNPC()
	if not unitNpc then
		return
	end

	local tAnchor = unitNpc:GetOverheadAnchor()
	local nLeft, nTop, nRight, nBottom
	nLeft = tAnchor.x - (self.nWndNpcRight - self.nWndNpcLeft)
	nTop = tAnchor.y - (self.nWndNpcBottom - self.nWndNpcTop) + 40  --hardcoded
	nRight = tAnchor.x
	nBottom = tAnchor.y + 17  --hardcoded  -- The +40 is to get the dangling speech bubble *right* on the NPC


	-- Expand for text
	nTop = self:HelperExpandForText(nTop, wndArg)

	-- Ensure on screen
	local tMax = Apollo.GetDisplaySize()
	if nTop < 0 then -- Order matters
		nBottom = nBottom - nTop
		nTop = 0
	elseif nBottom > tMax.nHeight then
		nTop = nTop - (nBottom - tMax.nHeight)
		nBottom = tMax.nHeight
	end

	if nLeft < 0 then
		nRight = nRight - nLeft
		nLeft = 0
	elseif nRight > tMax.nWidth then
		nLeft = nLeft - (nRight - tMax.nWidth)
		nRight = tMax.nWidth
	end
	-- End Ensure on screen

	wndArg:SetAnchorOffsets(nLeft, nTop, nRight, nBottom)
end

function Dialog:HelperExpandForText(nNewTop, wndArg)
	local nLeft, nTop, nRight, nBottom = wndArg:FindChild("BubbleText"):GetAnchorOffsets()
	nNewTop = nNewTop - (nBottom - nTop)
	if wndArg:FindChild("RewardsContainer"):IsShown() then
		local nTempLeft, nTempTop, nTempRight, nTempBottom = wndArg:FindChild("RewardsContainer"):GetAnchorOffsets()
		nNewTop = nNewTop - (nTempBottom - nTempTop)
	end
	return nNewTop
end

function Dialog:OnGenerateTooltip(wndHandler, wndControl, eType, arg1, arg2)
	local xml = nil
	if eType == Tooltip.TooltipGenerateType_ItemData then
		local itemCurr = arg1
		local itemEquipped = itemCurr:GetEquippedItemForItemType()

		Tooltip.GetItemTooltipForm(self, wndControl, itemCurr, {bPrimary = true, bSelling = self.bVendorOpen, itemCompare = itemEquipped})

	elseif eType == Tooltip.TooltipGenerateType_Reputation or eType == Tooltip.TooltipGenerateType_TradeSkill then
		xml = XmlDoc.new()
		xml:StartTooltip(Tooltip.TooltipWidth)
		xml:AddLine(arg1)
		wndControl:SetTooltipDoc(xml)
	elseif eType == Tooltip.TooltipGenerateType_Money then
		xml = XmlDoc.new()
		xml:StartTooltip(Tooltip.TooltipWidth)
		xml:AddLine(arg1:GetMoneyString(), CColor.new(1, 1, 1, 1), "CRB_Dialog")
		wndControl:SetTooltipDoc(xml)
	else
		wndControl:SetTooltipDoc(nil)
	end
end

function Dialog:OnWindowClosed(wndHandler, wndControl) -- The 'esc' key from xml
	if wndHandler:GetId() ~= wndControl:GetId() then return end
	DialogSys.End()
end

function Dialog:OnUpdateTimer(strVarName, nCount)
	if self.wndNpc and self.wndNpc:IsShown() then
		self:PositionNpcBubble(self.wndNpc)
	end
end

function Dialog:HelperBuildItemTooltip(wndArg, item)
	wndArg:SetTooltipDoc(nil)
	wndArg:SetTooltipDocSecondary(nil)
	local itemEquipped = item:GetEquippedItemForItemType()
	Tooltip.GetItemTooltipForm(self, wndArg, item, {bPrimary = true, bSelling = false, itemCompare = itemEquipped})
	--if itemEquipped then -- OLD
	--	Tooltip.GetItemTooltipForm(self, wndArg, itemEquipped, {bPrimary = false, bSelling = false, itemCompare = item})
	--end
end

function Dialog:HelperPrereqFailed(itemCurr)
	return itemCurr and itemCurr:IsEquippable() and not itemCurr:CanEquip()
end

---------------------------------------------------------------------------------------------------
-- Dialog instance
---------------------------------------------------------------------------------------------------
local DialogInst = Dialog:new()
DialogInst:Init()
