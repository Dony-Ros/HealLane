local HealLane = HealLane
local FLAT = "Interface\\Buttons\\WHITE8x8"
local TAGS = { macro = " |cff9999ff(macro)|r", action = " |cff99ff99(action)|r" }
local ACTIONS = {
    { name = "Target", action = "target", icon = "Interface\\Icons\\Ability_Marksmanship" },
    { name = "Menu", action = "menu", icon = "Interface\\Icons\\INV_Misc_Note_01" },
    { name = "Focus", action = "focus", icon = "Interface\\Icons\\Ability_TrueShot" },
    { name = "Assist", action = "assist", icon = "Interface\\Icons\\Ability_Hunter_SniperShot" },
    { name = "Role menu", action = "role", icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance" },
}
local BUTTON_LABELS = {
    ["1"] = "Left Click",
    ["2"] = "Right Click",
    ["3"] = "Middle Click",
    ["4"] = "Button 4",
    ["5"] = "Button 5",
    ["6"] = "Mouse Wheel Up",
    ["7"] = "Mouse Wheel Down",
}
local MOUSE_BUTTON_SLOTS = {
    LeftButton = "1",
    RightButton = "2",
    MiddleButton = "3",
    Button4 = "4",
    Button5 = "5",
}
local MODIFIER_LABELS = {
    [""] = "",
    ["shift-"] = "Shift",
    ["ctrl-"] = "Ctrl",
    ["alt-"] = "Alt",
    ["ctrl-shift-"] = "Ctrl + Shift",
    ["alt-shift-"] = "Alt + Shift",
    ["alt-ctrl-"] = "Alt + Ctrl",
    ["alt-ctrl-shift-"] = "Alt + Ctrl + Shift",
}

HealLane.CLICK_ACTIONS = ACTIONS
HealLane.CLICK_TAGS = TAGS

function HealLane.GetClickMacros()
    local list = {}
    local max = (MAX_ACCOUNT_MACROS or 36) + (MAX_CHARACTER_MACROS or 18)
    for i = 1, max do
        local name, icon = GetMacroInfo(i)
        if name then
            if type(icon) == "string" and not icon:find("\\") then icon = "Interface\\Icons\\" .. icon end
            list[#list + 1] = { name = name, icon = icon, kind = "macro" }
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

function HealLane.DescribeClickBinding(value)
    if type(value) ~= "string" or value == "" then return nil end
    local macro = value:match("^m:(.+)")
    if macro then
        for _, entry in ipairs(HealLane.GetClickMacros()) do
            if entry.name == macro then return entry.icon, macro, "macro" end
        end
        return nil, macro, "macro"
    end
    local action = value:match("^a:(.+)")
    if action then
        for _, entry in ipairs(ACTIONS) do
            if entry.action == action then return entry.icon, entry.name, "action" end
        end
        return nil, action, "action"
    end
    return HealLane.GetSpellTexture(value), value
end

function HealLane.BuildClicksTab(page)
    local H = HealLane.ConfigHelpers
    local S = HealLane.S
    local ROW_HEIGHT = 42
    local ROW_WIDTH = 420
    local VISIBLE_ROWS = 5
    local pendingRecords = {}
    local rows = {}
    local captureID
    local captureRecord
    local scrollName = H.Name()
    local scroll = CreateFrame("ScrollFrame", scrollName, page, "FauxScrollFrameTemplate")
    scroll:SetSize(436, 220)
    scroll:SetPoint("TOPLEFT", 10, -112)
    scroll:EnableMouseWheel(true)
    local scrollBar = _G[scrollName .. "ScrollBar"]
    local bindings = HealLane.MODS

    local setName = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    setName:SetSize(120, 22)
    setName:SetPoint("TOPLEFT", 210, -10)
    setName:SetAutoFocus(false)
    setName:SetMaxLetters(32)

    local setStatus = HealLane.CreateFontString(page, nil, "OVERLAY", "GameFontNormalSmall")
    setStatus:SetPoint("TOPLEFT", 210, -36)
    setStatus:Hide()
    setStatus:SetJustifyH("RIGHT")

    local setDropdown
    local function RefreshClickSets()
        local options = {}
        for _, name in ipairs(HealLane.ClickSetNames()) do
            options[#options + 1] = { value = name, label = name }
        end
        setDropdown:SetOptions(options)
        setDropdown:SetValue(HealLane.baseDB.activeClickSet or "Default")
        setStatus:SetText("Set: " .. (HealLane.baseDB.activeClickSet or "Default"))
    end

    setDropdown = H.AddDropdown(page, 10, -2, 180,
        {},
        function() return HealLane.baseDB.activeClickSet or "Default" end,
        function(name)
            if HealLane.ApplyClickSet(name) then
                setName:SetText("")
                RefreshClickSets()
            end
        end)

    H.AddButton(page, "Create", 338, -10, 58, function()
        local name = HealLane.CreateProfileName(setName:GetText())
        if name and HealLane.CreateClickSet(name) then
            setName:SetText("")
            RefreshClickSets()
        end
    end)
    H.AddButton(page, "Delete", 398, -10, 58, function()
        local name = HealLane.baseDB.activeClickSet or "Default"
        if HealLane.DeleteClickSet(name) then
            setName:SetText("")
            RefreshClickSets()
        end
    end)

    local function ParseBinding(key)
        if type(key) ~= "string" then return nil end
        for _, prefix in ipairs(bindings) do
            if key:sub(1, #prefix) == prefix then
                local slot = key:sub(#prefix + 1)
                if BUTTON_LABELS[slot] then return prefix, slot end
            end
        end
    end

    local function BindingText(key)
        local prefix, slot = ParseBinding(key)
        if not prefix then return tostring(key or "Choose binding...") end
        local modifier = MODIFIER_LABELS[prefix]
        if modifier and modifier ~= "" then
            return modifier .. " + " .. BUTTON_LABELS[slot]
        end
        return BUTTON_LABELS[slot]
    end

    local function IsWheelBinding(key)
        local _, slot = ParseBinding(key)
        return slot == "6" or slot == "7"
    end

    local function GetRecordID(record)
        if record.pending then return record end
        return record.key
    end

    local function CurrentModifierPrefix()
        local control = IsControlKeyDown()
        local alt = IsAltKeyDown()
        local shift = IsShiftKeyDown()
        if alt and control and shift then return "alt-ctrl-shift-" end
        if alt and control then return "alt-ctrl-" end
        if alt and shift then return "alt-shift-" end
        if control and shift then return "ctrl-shift-" end
        if alt then return "alt-" end
        if control then return "ctrl-" end
        if shift then return "shift-" end
        return ""
    end

    local function GetRecords()
        local records = {}
        for key, value in pairs(S.clicks) do
            if type(key) == "string" then
                records[#records + 1] = { key = key, value = value }
            end
        end
        for _, record in ipairs(pendingRecords) do
            records[#records + 1] = record
        end
        local prefixOrder = {}
        for index, prefix in ipairs(bindings) do prefixOrder[prefix] = index end
        table.sort(records, function(a, b)
            local keyA, keyB = a.binding or a.key, b.binding or b.key
            local prefixA, slotA = ParseBinding(keyA)
            local prefixB, slotB = ParseBinding(keyB)
            if prefixA and prefixB then
                local modA, modB = prefixOrder[prefixA], prefixOrder[prefixB]
                if modA ~= modB then return modA < modB end
                if slotA ~= slotB then return tonumber(slotA) < tonumber(slotB) end
            elseif prefixA ~= nil then
                return true
            elseif prefixB ~= nil then
                return false
            end
            return tostring(keyA or "") < tostring(keyB or "")
        end)
        return records
    end

    local function Notify(message)
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00HealLane:|r " .. message)
        end
    end

    local function IsBindingTaken(key, record)
        if S.clicks[key] ~= nil and key ~= record.key then return true end
        for _, pending in ipairs(pendingRecords) do
            if pending ~= record and (pending.binding or pending.key) == key then
                return true
            end
        end
        return false
    end

    local function RemovePending(record)
        for index, pending in ipairs(pendingRecords) do
            if pending == record then
                table.remove(pendingRecords, index)
                return
            end
        end
    end

    local function SaveRecord(record)
        local key = record.binding or record.key
        if not key or not record.value then return false end
        -- Wheel bindings accept the same actions as all other mouse bindings.
        if IsBindingTaken(key, record) then
            Notify("That mouse binding is already assigned. Remove or change its existing action first.")
            return false
        end

        if record.key and record.key ~= key then
            local ranks = S.clickRanks
            if ranks and ranks[record.key] then
                ranks[key] = ranks[key] or ranks[record.key]
                ranks[record.key] = nil
            end
            S.clicks[record.key] = nil
        end
        S.clicks[key] = record.value
        HealLane.SaveActiveClickSet()
        HealLane.AutoSaveActiveProfile()
        record.key = key
        record.binding = nil
        if record.pending then
            record.pending = nil
            RemovePending(record)
        end
        HealLane.Refresh()
        return true
    end

    local function GetRankNumber(rank)
        if not rank or rank == "__max" then return nil end
        return tonumber(tostring(rank):match("%d+"))
    end

    local function ResolveSpellID(spellName, rank)
        if not spellName then return nil end
        local selectedRank = GetRankNumber(rank)
        for _, entry in ipairs(HealLane.spells or {}) do
            if entry.name == spellName then
                if selectedRank then
                    if entry.spellIDs then
                        local spellID = entry.spellIDs[rank]
                            or entry.spellIDs[selectedRank]
                            or entry.spellIDs["Rank " .. selectedRank]
                        if spellID then return tonumber(spellID) or spellID end
                    end
                    return nil
                end
                if entry.spellID then return tonumber(entry.spellID) or entry.spellID end
            end
        end
    end

    local function FindSpellBookLink(spellName, rank)
        if not GetNumSpellTabs or not GetSpellTabInfo
            or not GetSpellBookItemName or not GetSpellLink then
            return nil
        end
        for tab = 1, GetNumSpellTabs() do
            local _, _, offset, numSpells = GetSpellTabInfo(tab)
            if offset and numSpells then
                for spellIndex = offset + 1, offset + numSpells do
                    local name, spellRank = GetSpellBookItemName(spellIndex, BOOKTYPE_SPELL or "spell")
                    if name == spellName then
                        local selectedRank = GetRankNumber(rank)
                        local bookRank = GetRankNumber(spellRank)
                        if not selectedRank or selectedRank == bookRank then
                            local link = GetSpellLink(spellIndex, BOOKTYPE_SPELL or "spell")
                            if link then return link end
                        end
                    end
                end
            end
        end
    end

    local function RankOptions(record)
        local options = { { value = "__max", label = "Max rank" } }
        local value = record.value
        local _, _, tag = HealLane.DescribeClickBinding(value)
        if value and not tag then
            for _, entry in ipairs(HealLane.spells or {}) do
                if entry.name == value then
                    for _, rank in ipairs(entry.ranks or {}) do
                        options[#options + 1] = { value = rank, label = rank }
                    end
                    break
                end
            end
            local key = record.key or record.binding
            local selectedRank = key and S.clickRanks and S.clickRanks[key]
            local found = false
            for _, option in ipairs(options) do
                if option.value == selectedRank then found = true break end
            end
            if selectedRank and not found then
                options[#options + 1] = { value = selectedRank, label = selectedRank }
            end
        end
        return options
    end

    local function SetActionTooltip(button, record)
        local value = record and record.value
        local _, text, tag = HealLane.DescribeClickBinding(value)
        if not text or tag then
            button:SetScript("OnEnter", nil)
            button:SetScript("OnLeave", nil)
            return
        end
        local key = record.key or record.binding
        local rank = key and S.clickRanks and S.clickRanks[key]
        local spellID = ResolveSpellID(text, rank)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local shown = false
            if spellID then
                if GameTooltip.SetSpellByID then
                    GameTooltip:SetSpellByID(spellID)
                    shown = true
                elseif GameTooltip.SetHyperlink then
                    GameTooltip:SetHyperlink("spell:" .. spellID)
                    shown = true
                end
            end
            if not shown then
                local link = FindSpellBookLink(text, rank)
                if link and GameTooltip.SetHyperlink then
                    GameTooltip:SetHyperlink(link)
                    shown = true
                end
            end
            if not shown then
                GameTooltip:SetText(text, 1, 1, 1)
                if rank and rank ~= "__max" then GameTooltip:AddLine(rank, 0.8, 0.8, 1) end
            end
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    local function Render()
        local records = GetRecords()
        FauxScrollFrame_Update(scroll, #records, VISIBLE_ROWS, ROW_HEIGHT)
        local offset = FauxScrollFrame_GetOffset(scroll)
        local maxOffset = math.max(0, #records - VISIBLE_ROWS)
        if offset > maxOffset then
            scrollBar:SetValue(maxOffset * ROW_HEIGHT)
            offset = FauxScrollFrame_GetOffset(scroll)
        end
        for visibleIndex, row in ipairs(rows) do
            local record = records[offset + visibleIndex]
            row.record = record
            if record then
                row.binding:SetText(captureID == GetRecordID(record) and "Press binding..." or BindingText(record.binding or record.key))
                local icon, text, tag = HealLane.DescribeClickBinding(record.value)
                if text then
                    row.action.icon:SetTexture(icon)
                    row.action.text:SetText(text .. (TAGS[tag] or ""))
                    row.action.text:SetTextColor(1, 1, 1)
                else
                    row.action.icon:SetTexture(nil)
                    row.action.text:SetText("Choose action...")
                    row.action.text:SetTextColor(0.55, 0.55, 0.55)
                end
                local options = RankOptions(record)
                if text and not tag then
                    row.rankDropdown:SetOptions(options)
                    local key = record.key or record.binding
                    local rank = key and S.clickRanks and S.clickRanks[key]
                    row.rankDropdown:SetValue(rank or "__max")
                    row.rankDropdown:Show()
                else
                    row.rankDropdown:Hide()
                end
                row.clear:Show()
                SetActionTooltip(row.action, record)
                row:Show()
            else
                row.record = nil
                row:Hide()
            end
        end
    end

    local bindingPopup = HealLane.ConfigUI:CreateBackdropFrame("Frame", "HealLaneClickBindingPopup", UIParent)
    bindingPopup:SetSize(360, 190)
    bindingPopup:SetPoint("CENTER")
    bindingPopup:SetFrameStrata("FULLSCREEN_DIALOG")
    bindingPopup:EnableMouse(true)
    bindingPopup:EnableMouseWheel(true)
    if bindingPopup.SetMovable then bindingPopup:SetMovable(true) end
    if bindingPopup.SetClampedToScreen then bindingPopup:SetClampedToScreen(true) end
    bindingPopup:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    HealLane.ConfigUI:StylePanel(bindingPopup, HealLane.ConfigUI:GetColors().bg)
    bindingPopup:Hide()
    tinsert(UISpecialFrames, "HealLaneClickBindingPopup")

    local popupTitle = HealLane.CreateFontString(bindingPopup, nil, "OVERLAY", "GameFontNormalLarge")
    popupTitle:SetPoint("TOP", 0, -18)
    popupTitle:SetText("Choose Mouse Binding")
    HealLane.ConfigUI:StyleText(popupTitle)

    local popupText = HealLane.CreateFontString(bindingPopup, nil, "OVERLAY", "GameFontHighlight")
    popupText:SetPoint("TOPLEFT", 25, -50)
    popupText:SetPoint("TOPRIGHT", -25, -50)
    popupText:SetHeight(48)
    popupText:SetJustifyH("CENTER")
    popupText:SetText("Press the desired mouse button or mouse wheel. Hold Ctrl, Alt, or Shift for a modified binding.")
    HealLane.ConfigUI:StyleText(popupText)

    local popupCapture = HealLane.ConfigUI:CreateButton(bindingPopup, "Press Binding Now", 180, 28)
    HealLane.ConfigUI:StyleButton(popupCapture)
    popupCapture:SetPoint("CENTER", 0, -30)
    popupCapture:EnableMouse(true)
    if popupCapture.RegisterForClicks then
        popupCapture:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp", "Button4Up", "Button5Up")
    end
    popupCapture:EnableMouseWheel(true)
    bindingPopup.captureArmed = false

    local function FinishCapture(slot)
        local record = captureRecord
        if not record then
            Notify("No action is selected for binding capture.")
            bindingPopup:Hide()
            return
        end
        record.binding = CurrentModifierPrefix() .. slot
        if record.value and not SaveRecord(record) then
            record.binding = nil
            bindingPopup.captureArmed = true
            popupCapture:SetText("Try Binding Again")
            popupText:SetText("That binding was not saved. Press another mouse button or mouse wheel.")
            return
        end
        bindingPopup:Hide()
    end

    popupCapture:SetScript("OnClick", function(self, button)
        if not bindingPopup.captureArmed then return end
        local slot = MOUSE_BUTTON_SLOTS[button]
        if slot then FinishCapture(slot) end
    end)
    popupCapture:SetScript("OnMouseWheel", function(_, delta)
        if bindingPopup.captureArmed then
            FinishCapture(delta > 0 and "6" or "7")
        end
    end)

    local popupClose = HealLane.ConfigUI:CreateButton(bindingPopup, "Cancel", 90, 24)
    HealLane.ConfigUI:StyleButton(popupClose)
    popupClose:SetPoint("BOTTOM", 0, 18)
    popupClose:EnableMouse(true)
    popupClose:RegisterForClicks("LeftButtonUp")
    popupClose:SetScript("OnClick", function() bindingPopup:Hide() end)

    local popupX = CreateFrame("Button", nil, bindingPopup, "UIPanelCloseButton")
    popupX:SetPoint("TOPRIGHT", -5, -5)
    popupX:EnableMouse(true)
    popupX:RegisterForClicks("LeftButtonUp")
    popupX:SetScript("OnClick", function() bindingPopup:Hide() end)
    bindingPopup:SetScript("OnHide", function()
        bindingPopup.captureArmed = false
        popupCapture:SetText("Press Binding Now")
        captureID = nil
        captureRecord = nil
        Render()
    end)

    H.Label(page, "Mouse buttons + Ctrl/Alt/Shift combinations", 25, -84)
    local addActionButton = H.AddButton(page, "Add Action", 328, -76, 96, function()
        local record = { pending = true }
        pendingRecords[#pendingRecords + 1] = record
        Render()
        local offset = math.max(0, #GetRecords() - VISIBLE_ROWS) * ROW_HEIGHT
        scrollBar:SetValue(offset)
        Render()
    end)
    addActionButton:EnableMouse(true)
    addActionButton:RegisterForClicks("LeftButtonUp")

    for visibleIndex = 1, VISIBLE_ROWS do
        local row = H.Backdrop("Frame", nil, page)
        row:SetFrameLevel(scroll:GetFrameLevel() + 10)
        row:EnableMouse(false)
        row:SetSize(ROW_WIDTH, ROW_HEIGHT - 4)
        row:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
        HealLane.ConfigUI:StylePanel(row, HealLane.ConfigUI:GetColors().panel)
        row:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, -((visibleIndex - 1) * ROW_HEIGHT))

        row.binding = HealLane.ConfigUI:CreateButton(row, "Choose binding...", 112, 28)
        HealLane.ConfigUI:StyleButton(row.binding)
        row.binding:SetPoint("LEFT", 4, 0)
        row.binding:EnableMouse(true)
        row.binding:RegisterForClicks("LeftButtonUp")
        H.Tooltip(row.binding, "Press the mouse button or mouse wheel to bind this action. Hold Ctrl, Alt, or Shift for a modified binding.")
        row.binding:SetScript("OnClick", function()
            local record = row.record
            if not record then
                Notify("This action row has no binding data.")
                return
            end
            captureRecord = record
            captureID = GetRecordID(record)
            bindingPopup.captureArmed = true
            popupCapture:SetText("Press Binding Now")
            popupText:SetText("Press the desired mouse button or mouse wheel. Hold Ctrl, Alt, or Shift for a modified binding.")
            bindingPopup:Show()
            Render()
        end)

        row.action = H.Backdrop("Button", nil, row)
        row.action:SetSize(150, 28)
        row.action:SetPoint("LEFT", row.binding, "RIGHT", 4, 0)
        row.action:EnableMouse(true)
        row.action:RegisterForClicks("LeftButtonUp")
        row.action:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
        HealLane.ConfigUI:StylePanel(row.action, HealLane.ConfigUI:GetColors().control)
        row.action:SetHighlightTexture(FLAT)
        row.action:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.12)
        row.action.icon = row.action:CreateTexture(nil, "OVERLAY")
        row.action.icon:SetSize(20, 20)
        row.action.icon:SetPoint("LEFT", 5, 0)
        row.action.text = HealLane.CreateFontString(row.action, nil, "OVERLAY", "GameFontHighlight")
        row.action.text:SetPoint("LEFT", row.action.icon, "RIGHT", 6, 0)
        row.action.text:SetPoint("RIGHT", -4, 0)
        row.action.text:SetJustifyH("LEFT")
        HealLane.ConfigUI:StyleText(row.action.text)
        row.action:SetScript("OnClick", function()
            local record = row.record
            if not record then
                Notify("This action row has no action data.")
                return
            end
            local key = record.binding or record.key
            H.OpenPicker(true, "Choose Click Action", function(entry)
                local value = entry.kind == "macro" and ("m:" .. entry.name)
                    or entry.kind == "action" and ("a:" .. entry.action) or entry.name
                local oldKey = record.key or record.binding
                -- The same action list is available for every mouse and wheel binding.
                if oldKey and record.value ~= value then
                    S.clickRanks = S.clickRanks or {}
                    S.clickRanks[oldKey] = nil
                end
                record.value = value
                if oldKey and not SaveRecord(record) then
                    Render()
                    return
                end
                HealLane.Refresh()
                Render()
            end, false, false)
        end)

        row.rankDropdown = HealLane.ConfigUI:CreateDropdown(row, H.Name(), 60,
            { { value = "__max", label = "Max rank" } }, "__max", function(value)
                local record = row.record
                local key = record and (record.key or record.binding)
                if not key then return end
                S.clickRanks = S.clickRanks or {}
                if value == "__max" then
                    S.clickRanks[key] = nil
                else
                    S.clickRanks[key] = value
                end
                HealLane.SaveActiveClickSet()
                HealLane.AutoSaveActiveProfile()
                Render()
                HealLane.Refresh()
            end)
        row.rankDropdown:SetPoint("LEFT", row.action, "RIGHT", 4, 0)

        row.clear = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        HealLane.ConfigUI:StyleButton(row.clear)
        row.clear:SetSize(24, 24)
        row.clear:SetPoint("RIGHT", -4, 0)
        row.clear:SetFrameLevel(row:GetFrameLevel() + 5)
        row.clear:EnableMouse(true)
        row.clear:RegisterForClicks("LeftButtonUp")
        row.clear:SetText("X")
        row.clear:SetScript("OnClick", function()
            local record = row.record
            if not record then
                Notify("This action row has nothing to delete.")
                return
            end
            if captureID == GetRecordID(record) then captureID = nil end
            if record.pending then
                RemovePending(record)
            elseif record.key then
                S.clicks[record.key] = nil
                if S.clickRanks then S.clickRanks[record.key] = nil end
            end
            HealLane.SaveActiveClickSet()
            HealLane.AutoSaveActiveProfile()
            HealLane.Refresh()
            Render()
        end)
        rows[visibleIndex] = row
    end

    local function UpdateRows()
        Render()
    end
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, UpdateRows)
    end)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        scrollBar:SetValue(scrollBar:GetValue() - delta * ROW_HEIGHT)
    end)
    Render()
    RefreshClickSets()
    HealLane.AddConfigWidget(function()
        Render()
        RefreshClickSets()
    end)

    local autoDownrank = H.AddCheck(page, "Auto-downgrade ranks for low-level units", 25, -348, "autoDownrank", function()
        HealLane.SaveActiveClickSet()
        HealLane.AutoSaveActiveProfile()
        HealLane.Refresh()
    end)
    H.Tooltip(autoDownrank, "Uses spellbook levels or built-in rank levels. Also applies to tracked buffs cast by Smart Cast.")
    H.Label(page, "Smart Cast Resurrection Spell", 25, -392)
    local resBtn = HealLane.ConfigUI:CreateIconButton(page, 260, 24)
    resBtn:SetPoint("TOPLEFT", 25, -427)
    local resIcon, resText = resBtn.icon, resBtn.text
    local function UpdateResBtn()
        local val = S.resSpell
        if val and val ~= "" then
            resIcon:SetTexture(HealLane.GetSpellTexture(val))
            resIcon:SetVertexColor(1, 1, 1, 1)
            resIcon:SetAlpha(1)
            resText:SetText(val)
        else
            resIcon:SetTexture(nil)
            resText:SetText("Click to pick a resurrection spell...")
        end
    end
    UpdateResBtn()
    resBtn:SetScript("OnClick", function()
        H.OpenPicker(false, "Pick Resurrection Spell", function(entry)
            S.resSpell = entry.name
            HealLane.SaveActiveClickSet()
            HealLane.AutoSaveActiveProfile()
            UpdateResBtn()
        end)
    end)
    H.Tooltip(resBtn, "Cast automatically when clicking a dead unit.")
    HealLane.AddConfigWidget(UpdateResBtn)
end
