-----------------------------------------------------------------------------------------------
-- Client Lua Script for Costumes
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
require "Apollo"
require "Sound"
require "GameLib"
require "Item"

local Costumes = {}

local knNumCostumes = 10

local karCostumeSlots = -- string name, then id, then button art
{
	{strSlot="Primary Weapon", 	 eSlotId=GameLib.CodeEnumItemSlots.Weapon,	 strSprite="CharacterWindowSprites:btn_Armor_HandsNormal",},
	{strSlot="Head", 	 eSlotId=GameLib.CodeEnumItemSlots.Head, 	 strSprite="CharacterWindowSprites:btnCh_Armor_Head",},
	{strSlot="Shoulder", eSlotId=GameLib.CodeEnumItemSlots.Shoulder, strSprite="CharacterWindowSprites:btnCh_Armor_Shoulder",},
	{strSlot="Chest", 	 eSlotId=GameLib.CodeEnumItemSlots.Chest, 	 strSprite="CharacterWindowSprites:btnCh_Armor_Chest",},
	{strSlot="Hands", 	 eSlotId=GameLib.CodeEnumItemSlots.Hands, 	 strSprite="CharacterWindowSprites:btnCh_Armor_Hands",},
	{strSlot="Legs", 	 eSlotId=GameLib.CodeEnumItemSlots.Legs, 	 strSprite="CharacterWindowSprites:btnCh_Armor_Legs",},
	{strSlot="Feet", 	 eSlotId=GameLib.CodeEnumItemSlots.Feet, 	 strSprite="CharacterWindowSprites:btnCh_Armor_Feet",},
}

function Costumes:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Costumes:Init()
	Apollo.RegisterAddon(self)
end

function Costumes:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("Costumes.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function Costumes:OnDocumentReady()
	if not self.xmlDoc then
		return
	end
	
	Apollo.RegisterEventHandler("WindowManagementReady", 		"OnWindowManagementReady", self)
	
	Apollo.RegisterEventHandler("ShowDye", 						"ShowCostumeWindow", self)
	Apollo.RegisterEventHandler("HideDye", 						"OnClose", self)
	Apollo.RegisterEventHandler("DyeLearned",					"OnDyeLearned", self)
	Apollo.RegisterEventHandler("AppearanceChanged",			"OnAppearanceChanged", self)
	Apollo.RegisterEventHandler("UpdateInventory",				"Reset", self)
	
	self.wndMain 		= Apollo.LoadForm(self.xmlDoc, "CharacterWindow", nil, self)
	self.wndDyeList 	= self.wndMain:FindChild("Right:DyeListContainer:DyeList")
	self.wndCostume 	= self.wndMain:FindChild("Middle:Costume")
	self.wndCost 		= self.wndMain:FindChild("Cost")
	self.wndResetBtn	= self.wndMain:FindChild("ResetBtn")
	self.wndDyeButton	= self.wndMain:FindChild("DyeBtn")
	
	self.wndMain:Show(false, true)
	
	self.nCurrentCostume = nil
	self.arCostumeSlots = {}
	self.arDyeButtons = {{}, {}, {}}
	
	for idx, tInfo in ipairs(karCostumeSlots) do
		local wndCostumeEntry = Apollo.LoadForm(self.xmlDoc, "CostumeEntryForm", self.wndMain:FindChild("CostumeListContainer"), self)
		wndCostumeEntry:FindChild("CostumeSlot"):ChangeArt(tInfo.strSprite)
		wndCostumeEntry:FindChild("CostumeSlot"):SetData(tInfo.eSlotId)
		
		wndCostumeEntry:FindChild("DyeColor1Container:DyeSwatchArtHack:DyeSwatch"):Show(false)
		wndCostumeEntry:FindChild("DyeColor2Container:DyeSwatchArtHack:DyeSwatch"):Show(false)
		wndCostumeEntry:FindChild("DyeColor3Container:DyeSwatchArtHack:DyeSwatch"):Show(false)
		
		wndCostumeEntry:FindChild("DyeColor1"):Enable(false)
		wndCostumeEntry:FindChild("DyeColor2"):Enable(false)
		wndCostumeEntry:FindChild("DyeColor3"):Enable(false)
		
		if tInfo.eSlotId == GameLib.CodeEnumItemSlots.Weapon then
			--spacer after weapon
			self.wndSpacer = Apollo.LoadForm(self.xmlDoc, "CostumeEntrySpacer", self.wndMain:FindChild("CostumeListContainer"), self)
			self.wndSpacer:FindChild("DyeColor1"):SetData(1)
			self.wndSpacer:FindChild("DyeColor2"):SetData(2)
			self.wndSpacer:FindChild("DyeColor3"):SetData(3)
			
			wndCostumeEntry:FindChild("DyeColor1Container"):Show(false)
			wndCostumeEntry:FindChild("DyeColor2Container"):Show(false)
			wndCostumeEntry:FindChild("DyeColor3Container"):Show(false)
		else
			wndCostumeEntry:FindChild("VisibleBtn"):SetData(tInfo.eSlotId)
		end
		
		self.arDyeButtons[1][tInfo.eSlotId] = wndCostumeEntry:FindChild("DyeColor1")
		self.arDyeButtons[2][tInfo.eSlotId] = wndCostumeEntry:FindChild("DyeColor2")
		self.arDyeButtons[3][tInfo.eSlotId] = wndCostumeEntry:FindChild("DyeColor3")
		
		wndCostumeEntry:FindChild("VisibleBtn"):SetData(tInfo.eSlotId)
		wndCostumeEntry:FindChild("RemoveSlotBtn"):SetData(tInfo.eSlotId)
		
		self.arCostumeSlots[tInfo.eSlotId] = wndCostumeEntry
	end
	
	self.wndMain:FindChild("CostumeListContainer"):ArrangeChildrenVert(0)
end

function Costumes:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("Costumes_Title")})
end

function Costumes:OnSlashCommand()
	self:ShowCostumeWindow()
end

function Costumes:OnClose()
	self:HideCostumeWindow()
	
	Event_CancelDyeWindow()
end

function Costumes:OnDyeLearned()
	self:FillDyes()
end

function Costumes:OnAppearanceChanged()
	if self.wndMain:IsShown() then
		self:HelperPreviewItems()
	end
end

function Costumes:CostumeSelectionWindowToggle()
	self.wndCostumeSelectionList:Show(not self.wndCostumeSelectionList:IsShown())
end

function Costumes:OnCostumeBtnToggle(wndHandler, wndCtrl)
	if wndHandler ~= wndCtrl then
		return false
	end

	self.nCurrentCostume = nil

	local wndCostumeHolder = self.wndMain:FindChild("Middle:CostumeBtnHolder")
	for idx = 1, knNumCostumes do
		if wndCostumeHolder:FindChild("CostumeBtn"..idx):IsChecked() then
			self.nCurrentCostume = idx
		end
	end

	self.wndMain:FindChild("Middle:BGArt_HeaderFrame:SelectCostumeWindowToggle"):SetCheck(false)
	self.wndCostumeSelectionList:Show(false)
	GameLib.SetCostumeIndex(self.nCurrentCostume)
	self:Reset()

	return true
end

function Costumes:OnDyeSelect(wndHandler, wndControl, eMouseButton)
	if wndHandler ~= wndControl then return end
	
	self:HelperPreviewItems(wndControl:GetData())
end

function Costumes:OnDyeCursorAll(wndHandler, wndControl, eMouseButton)
	if wndHandler ~= wndControl then return end
	
	if wndControl:IsChecked() then
		for idx, tButton in pairs(self.arDyeButtons[wndControl:GetData()]) do
			tButton:SetCheck(true)
			self:OnDyeChecked(tButton, false)
		end
	else
		for idx, tButton in pairs(self.arDyeButtons[wndControl:GetData()]) do
			tButton:SetCheck(false)
			self:OnDyeChecked(tButton, false)
		end
	end
end

function Costumes:OnDyeCursor(wndHandler, wndControl, eMouseButton)
	if wndHandler ~= wndControl then return end
	
	self:OnDyeChecked(wndControl, true)
end

function Costumes:OnDyeChecked(wndControl, bCheckAll)
	local bShowBlocker1 = self:OnDyeCheckedHelper(wndControl, 1, bCheckAll)
	local bShowBlocker2 = self:OnDyeCheckedHelper(wndControl, 2, bCheckAll)
	local bShowBlocker3 = self:OnDyeCheckedHelper(wndControl, 3, bCheckAll)
	
	self.wndMain:FindChild("Right:RightBlocker"):Show(bShowBlocker1 and bShowBlocker2 and bShowBlocker3)
end

function Costumes:OnDyeCheckedHelper(wndControl, nDyeChannel, bCheckAll)
	local bShowBlocker = true
	local nControlDyeChannel = wndControl:GetData() ~= nil and wndControl:GetData()[1] or 0
	local bAllChecked = true
	
	for idx, tButton in pairs(self.arDyeButtons[nDyeChannel]) do
		if tButton:IsEnabled() then
			if tButton:IsChecked() then
				bShowBlocker = false
			else
				bAllChecked = false
				
				-- uncheck the check all check box (say that 10 times fast!)
				if bCheckAll and nControlDyeChannel == nDyeChannel then
					wndControl:GetData()[3]:SetCheck(false)
				end
			end
			
			if idx == #self.arDyeButtons[nDyeChannel] and nControlDyeChannel == nDyeChannel and bAllChecked and bCheckAll then
				wndControl:GetData()[3]:SetCheck(true)
			end
		end
	end
	
	return bShowBlocker
end

function Costumes:OnDyeBtnClicked(wndHandler, wndControl)
	if wndHandler ~= wndControl then return end
	if not GameLib.CanDye() then return end

	for idx, tItemDyes in pairs(self.tSelectedItems) do
		GameLib.DyeItems(tItemDyes[4], tItemDyes[1], tItemDyes[2], tItemDyes[3])
	end

	self:Reset()
	self:OnClose()
end

function Costumes:OnResetBtnClicked(wndHandler, wndControl)
	self:Reset() -- tell the function to retain the slot selection
end

function Costumes:OnGenerateTooltip(wndHandler, wndControl, eType, itemCurr, idx)
	wndControl:SetTooltipDoc(nil)

	if not wndHandler:GetData() then return end
	
	local tButton = self.arDyeButtons[1][wndHandler:GetData()]
	
	if not tButton then return end
	
	local itemData = tButton:GetData() and tButton:GetData()[2] or nil
	
	if itemData then
		local tPrimaryTooltipOpts = {}
		local itemEquipped = itemData:GetEquippedItemForItemType() or itemData

		tPrimaryTooltipOpts.bPrimary = true
		
		if itemData:GetItemId() ~= itemEquipped:GetItemId() then
			tPrimaryTooltipOpts.itemCompare = itemEquipped
		end

		if Tooltip ~= nil and Tooltip.GetSpellTooltipForm ~= nil then
			Tooltip.GetItemTooltipForm(self, wndHandler, itemData, tPrimaryTooltipOpts)
		end
	else
		return nil
	end
end

function Costumes:OnCostumeSlotBtn(wndHandler, wndControl, eMouseButton, nPosX, nPosY, bDoubleClick)
	if wndHandler ~= wndControl then
		return false
	end

	if eMouseButton == GameLib.CodeEnumInputMouse.Right	then
		GameLib.SetCostumeItem(self.nCurrentCostume, wndControl:GetData(), -1)
	end
end

function Costumes:OnCostumeSlotQueryDragDrop(wndHandler, wndControl, nX, nY, wndSource, strType, nValue)
	if wndHandler ~= wndControl then
		return Apollo.DragDropQueryResult.PassOn
	end
	
	if strType == "DDBagItem" then
		return Apollo.DragDropQueryResult.Accept
	end
	
	return Apollo.DragDropQueryResult.Ignore
end

function Costumes:OnCostumeSlotDragDrop(wndHandler, wndControl, nX, nY, wndSource, strType, nValue)
	if wndHandler ~= wndControl then
		return false
	end

	GameLib.SetCostumeItem(self.nCurrentCostume, wndControl:GetData(), nValue)
end

function Costumes:OnSheatheCheck(wndHandler, wndControl)
	self.wndCostume:SetSheathed(wndControl:IsChecked())
end

function Costumes:OnVisibleBtnCheck(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return false
	end

	local bVisible = wndControl:IsChecked()
	local iSlot = wndControl:GetData()

	if self.nCurrentCostume ~= nil and self.nCurrentCostume ~= 0 then
		GameLib.SetCostumeSlotVisible(self.nCurrentCostume, iSlot, bVisible)
	end

	self:HelperPreviewItems()
end

function Costumes:OnRemoveSlotBtn(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return false
	end

	GameLib.SetCostumeItem(self.nCurrentCostume, wndControl:GetData(), -1)
	self:UpdateCostumeSlotIcons()
	self:HelperPreviewItems()
end

function Costumes:OnRotateRight()
	self.wndCostume:ToggleLeftSpin(true)
end

function Costumes:OnRotateRightCancel()
	self.wndCostume:ToggleLeftSpin(false)
end

function Costumes:OnRotateLeft()
	self.wndCostume:ToggleRightSpin(true)
end

function Costumes:OnRotateLeftCancel()
	self.wndCostume:ToggleRightSpin(false)
end

function Costumes:UpdateCostumeSlotIcons()
-- this is our update function; it's used to repopulate the slots on the costume window (when shown) and mark what slots on the character
-- window are effected by a costume piece (when shown)

	self.nCostumeCount = GameLib.GetCostumeCount()
	self.nCurrentCostume = GameLib.GetCostumeIndex()
	
	local unitPlayer = GameLib.GetPlayerUnit()
	local wndCostumeHolder = self.wndMain:FindChild("Middle:CostumeBtnHolder")
	local wndHeaderFrame = self.wndMain:FindChild("Middle:BGArt_HeaderFrame")

	-- update all btns so the UI's move in sync; happens AFTER the costume is set.
	for idx = 1, knNumCostumes do -- update the costume window to match
		local wndCostumeBtn = wndCostumeHolder:FindChild("CostumeBtn" .. idx)
		wndCostumeBtn:SetCheck(false)
		wndCostumeBtn:Show( idx <= self.nCostumeCount )
	end
	
	self.tEquippedItems = {}
	local tEquippedItems = unitPlayer and unitPlayer:GetEquippedItems() or {}
	local tSlotNames = {}
	
	for nIdx, tInfo in ipairs(karCostumeSlots) do
		tSlotNames[tInfo.eSlotId] = tInfo.strSlot
		
		local tCostumeItem = nil
		
		for nIdx2, tItemInfo in ipairs(tEquippedItems) do
			if tItemInfo:GetSlotName() == tInfo.strSlot then
				tCostumeItem = tItemInfo
				self.tEquippedItems[tInfo.eSlotId] = tItemInfo
				break
			end
		end
		
		if tCostumeItem ~= nil then
			local tDyeChannels = tCostumeItem:GetAvailableDyeChannel()
			
			if self.arDyeButtons[1][tInfo.eSlotId] ~= nil then
				self.arDyeButtons[1][tInfo.eSlotId]:SetData({1, tCostumeItem, self.wndSpacer:FindChild("DyeColor1"), tInfo.eSlotId})
				self.arDyeButtons[1][tInfo.eSlotId]:Enable(tDyeChannels.bDyeChannel1)
				self.arDyeButtons[1][tInfo.eSlotId]:SetTooltip(tDyeChannels.bDyeChannel1 and "" or Apollo.GetString("Costumes_DyeChannelDisabled"))
			end
			if self.arDyeButtons[2][tInfo.eSlotId] ~= nil then
				self.arDyeButtons[2][tInfo.eSlotId]:SetData({2, tCostumeItem, self.wndSpacer:FindChild("DyeColor2"), tInfo.eSlotId})
				self.arDyeButtons[2][tInfo.eSlotId]:Enable(tDyeChannels.bDyeChannel2)
				self.arDyeButtons[2][tInfo.eSlotId]:SetTooltip(tDyeChannels.bDyeChannel2 and "" or Apollo.GetString("Costumes_DyeChannelDisabled"))
			end
			if self.arDyeButtons[3][tInfo.eSlotId] ~= nil then
				self.arDyeButtons[3][tInfo.eSlotId]:SetData({3, tCostumeItem, self.wndSpacer:FindChild("DyeColor3"), tInfo.eSlotId})
				self.arDyeButtons[3][tInfo.eSlotId]:Enable(tDyeChannels.bDyeChannel3)
				self.arDyeButtons[3][tInfo.eSlotId]:SetTooltip(tDyeChannels.bDyeChannel3 and "" or Apollo.GetString("Costumes_DyeChannelDisabled"))
			end
		else
			if self.arDyeButtons[1][tInfo.eSlotId] ~= nil then
				self.arDyeButtons[1][tInfo.eSlotId]:SetData(nil)
				self.arDyeButtons[1][tInfo.eSlotId]:Enable(false)
				self.arDyeButtons[1][tInfo.eSlotId]:SetTooltip("")
			end
			if self.arDyeButtons[2][tInfo.eSlotId] ~= nil then
				self.arDyeButtons[2][tInfo.eSlotId]:SetData(nil)
				self.arDyeButtons[2][tInfo.eSlotId]:Enable(false)
				self.arDyeButtons[2][tInfo.eSlotId]:SetTooltip("")
			end
			if self.arDyeButtons[3][tInfo.eSlotId] ~= nil then
				self.arDyeButtons[3][tInfo.eSlotId]:SetData(nil)
				self.arDyeButtons[3][tInfo.eSlotId]:Enable(false)
				self.arDyeButtons[3][tInfo.eSlotId]:SetTooltip("")
			end
		end
	end
	
	wndHeaderFrame:FindChild("SelectCostumeWindowToggle"):SetText(Apollo.GetString("Character_CostumeSelectDefault"))
		
	for eSlotId, wndSlot in pairs(self.arCostumeSlots) do
		local wndCostumeIcon = wndSlot:FindChild("CostumeSlot:CostumeIcon")
		
		local tCurrItem = nil
		for nIdx2, tItemInfo in ipairs(tEquippedItems) do
			if tItemInfo:GetSlotName() == tSlotNames[eSlotId] then
				tCurrItem = tItemInfo
				break
			end
		end
		
		wndSlot:FindChild("CostumeShadow"):Show(true)
		wndCostumeIcon:SetSprite(tCurrItem ~= nil and tCurrItem:GetIcon() or "")
		wndCostumeIcon:GetWindowSubclass():SetItem(tCurrItem)
		
		wndSlot:FindChild("VisibleBtn"):SetCheck(false)
		wndSlot:FindChild("VisibleBtn"):Enable(false)
		wndSlot:FindChild("RemoveSlotBtn"):Enable(false)
	end
	
	if self.nCurrentCostume > 0 then
		for nIdx, tInfo in ipairs(karCostumeSlots) do
			local tCostumeItem = GameLib.GetCostumeItem(self.nCurrentCostume, tInfo.eSlotId) or self.tEquippedItems[tInfo.eSlotId]
			local tDyeChannels = tCostumeItem ~= nil and tCostumeItem:GetAvailableDyeChannel() or {bDyeChannel1=false, bDyeChannel2=false, bDyeChannel3=false}
			
			if self.arDyeButtons[1][tInfo.eSlotId] ~= nil then
				self.arDyeButtons[1][tInfo.eSlotId]:SetData({1, tCostumeItem, self.wndSpacer:FindChild("DyeColor1"), tInfo.eSlotId})
				self.arDyeButtons[1][tInfo.eSlotId]:Enable(tDyeChannels.bDyeChannel1)
				self.arDyeButtons[1][tInfo.eSlotId]:SetTooltip(tDyeChannels.bDyeChannel1 and "" or Apollo.GetString("Costumes_DyeChannelDisabled"))				
			end
			if self.arDyeButtons[2][tInfo.eSlotId] ~= nil then
				self.arDyeButtons[2][tInfo.eSlotId]:SetData({2, tCostumeItem, self.wndSpacer:FindChild("DyeColor2"), tInfo.eSlotId})
				self.arDyeButtons[2][tInfo.eSlotId]:Enable(tDyeChannels.bDyeChannel2)
				self.arDyeButtons[2][tInfo.eSlotId]:SetTooltip(tDyeChannels.bDyeChannel2 and "" or Apollo.GetString("Costumes_DyeChannelDisabled"))
			end
			if self.arDyeButtons[3][tInfo.eSlotId] ~= nil then
				self.arDyeButtons[3][tInfo.eSlotId]:SetData({3, tCostumeItem, self.wndSpacer:FindChild("DyeColor3"), tInfo.eSlotId})
				self.arDyeButtons[3][tInfo.eSlotId]:Enable(tDyeChannels.bDyeChannel3)
				self.arDyeButtons[3][tInfo.eSlotId]:SetTooltip(tDyeChannels.bDyeChannel3 and "" or Apollo.GetString("Costumes_DyeChannelDisabled"))
			end
		end
		
		local wndCurrentCostume = wndCostumeHolder:FindChild("CostumeBtn" .. self.nCurrentCostume)
		wndCurrentCostume:SetCheck(true)
		wndCostumeHolder:FindChild("ClearCostumeBtn"):SetCheck(false)

		local strName = wndCurrentCostume:GetText()
		wndHeaderFrame:FindChild("SelectCostumeWindowToggle"):SetText(strName)
		
		for eSlotId, wndSlot in pairs(self.arCostumeSlots) do
			local tCostumeItem = GameLib.GetCostumeItem(self.nCurrentCostume, eSlotId) or self.tEquippedItems[eSlotId]
			local strIcon = tCostumeItem ~= nil and tCostumeItem:GetIcon() or ""
			local bShown = GameLib.IsCostumeSlotVisible(self.nCurrentCostume, eSlotId)
			local wndCostumeIcon = wndSlot:FindChild("CostumeSlot:CostumeIcon")
						
			wndSlot:FindChild("VisibleBtn"):SetCheck(bShown)
			wndSlot:FindChild("VisibleBtn"):Enable(eSlotId ~= GameLib.CodeEnumItemSlots.Weapon and strIcon ~= "")
			wndSlot:FindChild("HiddenBlocker"):Show(not bShown)
			wndSlot:FindChild("RemoveSlotBtn"):Enable(strIcon ~= "")
			
			wndSlot:FindChild("CostumeShadow"):Show(self.tEquippedItems[eSlotId] and self.tEquippedItems[eSlotId]:GetItemId() == tCostumeItem:GetItemId())
			wndCostumeIcon:SetSprite(strIcon)
			wndCostumeIcon:GetWindowSubclass():SetItem(tCostumeItem)
			
			local wndCostumeIconCurrent = self.arCostumeSlots[eSlotId]:FindChild("Middle:BG_IconFrameCurrent:CostumeIconCurrent")
		end
	end
end

function Costumes:HideCostumeWindow()
	self.wndMain:Show(false)
end

function Costumes:ShowCostumeWindow()
	self.wndMain:Show(true)
	
	local unitPlayer = GameLib.GetPlayerUnit()
	
	-- hide the costumes list.
	self.wndCostumeSelectionList = self.wndMain:FindChild("Middle:CostumeBtnHolder")
	self.wndCostumeSelectionList:Show(false)
	
	self.tCostumeBtns = {}
	self.nCostumeCount = GameLib.GetCostumeCount()

	for idx = 1, knNumCostumes do
		self.tCostumeBtns[idx] = self.wndCostumeSelectionList:FindChild("CostumeBtn"..idx)
		self.tCostumeBtns[idx]:SetData(idx)		
		self.tCostumeBtns[idx]:Show( idx <= self.nCostumeCount)
		
		if idx <= self.nCostumeCount then
			self.wndMain:FindChild("CostumeBtn" .. idx):SetCheck(false)
			self.wndMain:FindChild("CostumeBtn" .. idx):SetText(String_GetWeaselString(Apollo.GetString("Character_CostumeNum"), idx)) -- TODO: this will be a real name at some point
		end
	end
	
	local nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("CostumeBtnHolder"):GetAnchorOffsets()
	self.wndMain:FindChild("CostumeBtnHolder"):SetAnchorOffsets(nLeft, nBottom - (75 + 28 * self.nCostumeCount), nRight, nBottom)
	
	self.wndCostume:SetCostume(unitPlayer)
	self.wndCostume:SetSheathed(self.wndMain:FindChild("SetSheatheBtn"):IsChecked())
	
	self:Reset()
end

function Costumes:ResetInputs()
	for nDyeChannel = 1,#self.arDyeButtons do
		for idx, tButton in pairs(self.arDyeButtons[nDyeChannel]) do
			tButton:SetCheck(false)
			tButton:GetParent():FindChild("DyeSwatchArtHack:DyeSwatch"):SetSprite("")
		end
	end
	
	self.wndSpacer:FindChild("DyeColor1"):SetCheck(false)
	self.wndSpacer:FindChild("DyeColor2"):SetCheck(false)
	self.wndSpacer:FindChild("DyeColor3"):SetCheck(false)
	self.wndMain:FindChild("Right:RightBlocker"):Show(true)
end

function Costumes:Reset()
	self.tSelectedItems = {}
	
	self:FillDyes()
	self:UpdateCostumeSlotIcons()
	self:HelperPreviewItems()
	self:ResetInputs()
end

function Costumes:FillDyes()
	self.wndDyeList:DestroyChildren()

	local tDyeSort = GameLib.GetKnownDyes()
	
	table.sort(tDyeSort, function (a,b) return a.nId < b.nId end)

	for idx, tDyeInfo in ipairs(tDyeSort) do
		local wndNewDye = Apollo.LoadForm(self.xmlDoc, "DyeColor", self.wndDyeList, self)
		local strName = ""

		if tDyeInfo.strName and tDyeInfo.strName:len() > 0 then
			strName = tDyeInfo.strName
		else
			strName = String_GetWeaselString(Apollo.GetString("CRB_CurlyBrackets"), "", tDyeInfo.nRampIndex)
		end

		local strSprite = "CRB_DyeRampSprites:sprDyeRamp_" .. tDyeInfo.nRampIndex
		wndNewDye:FindChild("DyeSwatchArtHack:DyeSwatch"):SetSprite(strSprite)
		wndNewDye:SetTooltip(strName)

		local tNewDyeInfo = {}
		tNewDyeInfo.id = tDyeInfo.nId
		tNewDyeInfo.strName = strName
		tNewDyeInfo.strSprite = strSprite
		
		wndNewDye:SetData(tNewDyeInfo)
	end
	
	self.wndDyeList:ArrangeChildrenTiles()
end

function Costumes:GetSelectedItems(tDye)
	local nDyeId = tDye ~= nil and tDye.id or 0
	
	for nDyeChannel = 1,#self.arDyeButtons do
		for idx, tInfo in ipairs(karCostumeSlots) do
			local wndButton = self.arDyeButtons[nDyeChannel][tInfo.eSlotId]
			
			if wndButton and wndButton:GetData() ~= nil then
				local tItem = wndButton:GetData()[2]
				
				if tItem ~= nil then
					if self.tSelectedItems[tItem:GetItemId()] == nil then
						self.tSelectedItems[tItem:GetItemId()] = {0,0,0,tItem}
					end
					
					if self.tSelectedItems[tItem:GetItemId()][nDyeChannel] == nil or self.tSelectedItems[tItem:GetItemId()][nDyeChannel] == 0 then
						self.tSelectedItems[tItem:GetItemId()][nDyeChannel] = 0
					end
					
					if nDyeId > 0 and wndButton:IsChecked() then
						self.tSelectedItems[tItem:GetItemId()][nDyeChannel] = nDyeId
						wndButton:GetParent():FindChild("DyeSwatch"):SetSprite(tDye.strSprite)
						wndButton:GetParent():FindChild("DyeSwatch"):Show(true)
					end
				end
			end
		end
	end
end

function Costumes:HelperPreviewItems(tDye)
	self:GetSelectedItems(tDye)
	
	local monCost = 0
	for idx, tItemDyes in pairs(self.tSelectedItems) do
		local cost = GameLib.GetDyeCost(tItemDyes[4], tItemDyes[1], tItemDyes[2], tItemDyes[3])
		
		monCost = cost:GetAmount() > 0 and monCost + cost:GetAmount() or monCost
		self.wndCostume:SetItemDye(tItemDyes[4], tItemDyes[1], tItemDyes[2], tItemDyes[3])
	end
	
	self.wndDyeButton:Enable(GameLib.CanDye() and monCost > 0 and monCost <= GameLib.GetPlayerCurrency():GetAmount())
	self.wndResetBtn:Enable(monCost > 0)

	self.wndCost:SetAmount(monCost, false)
end

local CostumesInstance = Costumes:new()
CostumesInstance:Init()
