local EvsHL = EvsHL
local curMod = ""
local FLAT = "Interface\\Buttons\\WHITE8x8"
local TAGS = { macro = " |cff9999ff(macro)|r", action = " |cff99ff99(action)|r" }
local ACTIONS = {
    { name = "Target", action = "target", icon = "Interface\\Icons\\Ability_Marksmanship" },
    { name = "Menu", action = "menu", icon = "Interface\\Icons\\INV_Misc_Note_01" },
    { name = "Focus", action = "focus", icon = "Interface\\Icons\\Ability_TrueShot" },
    { name = "Assist", action = "assist", icon = "Interface\\Icons\\Ability_Hunter_SniperShot" },
    { name = "Role menu", action = "role", icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance" },
}

EvsHL.CLICK_ACTIONS = ACTIONS
EvsHL.CLICK_TAGS = TAGS

function EvsHL.GetClickMacros()
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

function EvsHL.DescribeClickBinding(value)
    if not value or value == "" then return nil end
    local macro = value:match("^m:(.+)")
    if macro then
        for _, entry in ipairs(EvsHL.GetClickMacros()) do
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
    return EvsHL.GetSpellTexture(value), value
end
function EvsHL.BuildClicksTab(page)
    local H = EvsHL.ConfigHelpers
    local S = EvsHL.S
    local modOptions = {
        { "", "None" }, { "shift-", "Shift" }, { "ctrl-", "Ctrl" }, { "alt-", "Alt" },
        { "ctrl-shift-", "Ctrl + Shift" }, { "alt-shift-", "Alt + Shift" },
        { "alt-ctrl-", "Alt + Ctrl" }, { "alt-ctrl-shift-", "Alt + Ctrl + Shift" },
    }
    local btnLabels = { "Left", "Right", "Middle", "Button 4", "Button 5", "Scroll Up", "Scroll Down" }
    local ROW_HEIGHT = 40
    local ROW_WIDTH = 420
    local VISIBLE_ROWS = 6
    local scrollName = H.Name()
    local scroll = CreateFrame("ScrollFrame", scrollName, page, "FauxScrollFrameTemplate")
    scroll:SetSize(436, 250)
    scroll:SetPoint("TOPLEFT", 10, -44)
    scroll:EnableMouseWheel(true)
    local rows = {}
    local function GetRankNumber(rank)
        if not rank or rank == "__max" then
            return nil
        end

        return tonumber(tostring(rank):match("%d+"))
    end

    local function ResolveSpellID(spellName, rank)
        if not spellName then return nil end

        local selectedRank = GetRankNumber(rank)

        for _, entry in ipairs(EvsHL.spells or {}) do
            if entry.name == spellName then
                if selectedRank then
                    -- A selected rank must never fall back to the max-rank spell ID.
                    -- Doing so makes every rank display the same tooltip.
                    if entry.spellIDs then
                        local spellID = entry.spellIDs[rank]
                            or entry.spellIDs[selectedRank]
                            or entry.spellIDs["Rank " .. selectedRank]

                        if spellID then
                            return tonumber(spellID) or spellID
                        end
                    end

                    return nil
                end

                if entry.spellID then
                    return tonumber(entry.spellID) or entry.spellID
                end
            end
        end

        return nil
    end

    local function FindSpellBookLink(spellName, rank)
        if not GetNumSpellTabs or not GetSpellTabInfo
            or not GetSpellBookItemName or not GetSpellLink then
            return nil
        end

        local tabCount = GetNumSpellTabs()
        for tab = 1, tabCount do
            local _, _, offset, numSpells = GetSpellTabInfo(tab)
            if offset and numSpells then
                for spellIndex = offset + 1, offset + numSpells do
                    local name, spellRank = GetSpellBookItemName(spellIndex, BOOKTYPE_SPELL or "spell")
                    if name == spellName then
                        local selectedRank = GetRankNumber(rank)
                        local bookRank = GetRankNumber(spellRank)

                        if not selectedRank or selectedRank == bookRank then
                            local link = GetSpellLink(spellIndex, BOOKTYPE_SPELL or "spell")
                            if link then
                                return link
                            end
                        end
                    end
                end
            end
        end

        return nil
    end

    local function UpdateSlotTooltip(row, value, text, tag)
        local slot = row.slot

        -- Macros and built-in actions do not have spell tooltips.
        if not text or tag then
            slot:SetScript("OnEnter", nil)
            slot:SetScript("OnLeave", nil)
            return
        end

        local slotKey = curMod .. row.index
        local rank = S.clickRanks and S.clickRanks[slotKey]
        local spellID = ResolveSpellID(text, rank)

        slot:SetScript("OnEnter", function(self)
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
                local spellLink = FindSpellBookLink(text, rank)
                if spellLink and GameTooltip.SetHyperlink then
                    GameTooltip:SetHyperlink(spellLink)
                    shown = true
                end
            end

            -- Keep the hover useful even if this spell is not in the spellbook
            -- and the spell database does not contain an ID for it.
            if not shown then
                GameTooltip:SetText(text, 1, 1, 1)
                if rank and rank ~= "__max" then
                    GameTooltip:AddLine(rank, 0.8, 0.8, 1)
                end
            end

            GameTooltip:Show()
        end)

        slot:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    local function Load()
        for _, row in ipairs(rows) do
            local index = row.index
            if index then
                local value = S.clicks[curMod .. index]
                local icon, text, tag = EvsHL.DescribeClickBinding(value)
                if text then
                    row.slot.icon:SetTexture(icon)
                    row.slot.text:SetText(text .. (TAGS[tag] or ""))
                    row.slot.text:SetTextColor(1, 1, 1)
                    row.clear:Show()
                else
                    local placeholder = index == 1 and "Target (default)" or index == 2 and "Menu (default)"
                        or index > 5 and "Role menu..." or "Click to choose..."
                    row.slot.icon:SetTexture(nil)
                    row.slot.text:SetText(placeholder)
                    row.slot.text:SetTextColor(0.55, 0.55, 0.55)
                    row.clear:Hide()
                end
                if text and not tag then
                    row.rankDropdown:Show()
                    row.rankText()
                else
                    row.rankDropdown:Hide()
                end
                if index > 5 then
                    EvsHL.ConfigUI:SetTooltip(row.slot, "Scroll bindings can only open the Role menu.")
                elseif row.slot.HealLaneTooltipHooked then
                    row.slot.HealLaneTooltipText = nil
                end
                -- Update tooltip for spell bindings
                UpdateSlotTooltip(row, value, text, tag)
            end
        end
    end

    H.Label(page, "Modifier", 25, -16)
    H.AddDropdown(page, 85, -8, 150, modOptions, function() return curMod end, function(value)
        curMod = value
        Load()
    end)

    local function RankOptions(row)
        local options = { { value = "__max", text = "Max rank" } }
        local slotKey = curMod .. row.index
        local chosen = S.clicks[slotKey]
        local _, _, tag = EvsHL.DescribeClickBinding(chosen)
        if chosen and not tag then
            for _, entry in ipairs(EvsHL.spells or {}) do
                if entry.name == chosen then
                    for _, rank in ipairs(entry.ranks or {}) do
                        options[#options + 1] = { value = rank, text = rank }
                    end
                    break
                end
            end
            local selectedRank = S.clickRanks and S.clickRanks[slotKey]
            local found = false
            for _, option in ipairs(options) do
                if option.value == selectedRank then found = true break end
            end
            if selectedRank and not found then
                options[#options + 1] = { value = selectedRank, text = selectedRank }
            end
        end
        return options
    end

    local function DropdownOptions(row)
        local options = {}
        for _, option in ipairs(RankOptions(row)) do
            options[#options + 1] = { value = option.value, label = option.text }
        end
        return options
    end

    for visibleIndex = 1, VISIBLE_ROWS do
        local row = H.Backdrop("Frame", nil, page)
        row.index = visibleIndex
        row:SetSize(ROW_WIDTH, ROW_HEIGHT - 4)
        row:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
        EvsHL.ConfigUI:StylePanel(row, EvsHL.ConfigUI:GetColors().panel)
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.label:SetPoint("LEFT", 8, 0)
        row.label:SetWidth(72)
        row.label:SetJustifyH("LEFT")
        EvsHL.ConfigUI:StyleText(row.label)

        row.slot = H.Backdrop("Button", nil, row)
        row.slot:SetSize(145, 28)
        row.slot:SetPoint("LEFT", 84, 0)
        row.slot:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
        EvsHL.ConfigUI:StylePanel(row.slot, EvsHL.ConfigUI:GetColors().control)
        row.slot:SetHighlightTexture(FLAT)
        row.slot:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.12)
        row.slot.icon = row.slot:CreateTexture(nil, "OVERLAY")
        row.slot.icon:SetSize(20, 20)
        row.slot.icon:SetPoint("LEFT", 5, 0)
        row.slot.text = row.slot:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.slot.text:SetPoint("LEFT", row.slot.icon, "RIGHT", 8, 0)
        row.slot.text:SetPoint("RIGHT", -6, 0)
        row.slot.text:SetJustifyH("LEFT")
        EvsHL.ConfigUI:StyleText(row.slot.text)

        row.rankDropdown = EvsHL.ConfigUI:CreateDropdown(row, H.Name(), 105, DropdownOptions(row),
            "__max", function(value)
                if not row.index then return end
                local slotKey = curMod .. row.index
                S.clickRanks = S.clickRanks or {}
                if value == "__max" then
                    S.clickRanks[slotKey] = nil
                else
                    S.clickRanks[slotKey] = value
                end
                Load()
                EvsHL.Refresh()
            end)
        row.rankDropdown:SetPoint("LEFT", row.slot, "RIGHT", 8, 0)

        row.slot:SetScript("OnClick", function()
            local index = row.index
            if not index then return end
            local wheelSlot = index > 5
            local title = btnLabels[index] .. (wheelSlot and " role menu" or " click")
            H.OpenPicker(true, title, function(entry)
                local slotKey = curMod .. index
                S.clicks[slotKey] = entry.kind == "macro" and ("m:" .. entry.name)
                    or entry.kind == "action" and ("a:" .. entry.action) or entry.name
                S.clickRanks = S.clickRanks or {}
                S.clickRanks[slotKey] = nil
                EvsHL.Refresh()
                Load()
            end, false, wheelSlot)
        end)

        row.clear = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        EvsHL.ConfigUI:StyleButton(row.clear)
        row.clear:SetSize(24, 24)
        row.clear:SetPoint("RIGHT", -6, 0)
        row.clear:SetText("X")
        row.clear:SetScript("OnClick", function()
            if not row.index then return end
            local slotKey = curMod .. row.index
            S.clicks[slotKey] = nil
            if S.clickRanks then S.clickRanks[slotKey] = nil end
            EvsHL.Refresh()
            Load()
        end)
        row.rankDropdown:Hide()
        row.rankText = function()
            if not row.index then return end
            local slotKey = curMod .. row.index
            local rank = S.clickRanks and S.clickRanks[slotKey]
            row.rankDropdown:SetOptions(DropdownOptions(row))
            row.rankDropdown:SetValue(rank or "__max")
        end
        rows[visibleIndex] = row
    end

    local function UpdateRows()
        FauxScrollFrame_Update(scroll, #btnLabels, VISIBLE_ROWS, ROW_HEIGHT)
        local offset = FauxScrollFrame_GetOffset(scroll)
        for visibleIndex, row in ipairs(rows) do
            local index = offset + visibleIndex
            if index <= #btnLabels then
                row.index = index
                row.label:SetText(btnLabels[index])
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, -((visibleIndex - 1) * ROW_HEIGHT))
                row:Show()
            else
                row.index = nil
                row:Hide()
            end
        end
        Load()
    end

    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, UpdateRows)
    end)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        local bar = _G[scrollName .. "ScrollBar"]
        bar:SetValue(bar:GetValue() - delta * ROW_HEIGHT)
    end)
    UpdateRows()

    local autoDownrank = H.AddCheck(page, "Auto-downgrade ranks for low-level units", 25, -316, "autoDownrank", EvsHL.Refresh)
    H.Tooltip(autoDownrank, "Uses spellbook levels or built-in rank levels. Also applies to tracked buffs cast by Smart Cast.")
    H.Label(page, "Smart Cast Resurrection Spell", 25, -360)
    local resBtn = EvsHL.ConfigUI:CreateIconButton(page, 260, 24)
    resBtn:SetPoint("TOPLEFT", 25, -395)
    local resIcon, resText = resBtn.icon, resBtn.text
    local function UpdateResBtn()
        local val = S.resSpell
        if val and val ~= "" then
            resIcon:SetTexture(EvsHL.GetSpellTexture(val))
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
            UpdateResBtn()
        end)
    end)
    H.Tooltip(resBtn, "Cast automatically when clicking a dead unit.")
    EvsHL.AddConfigWidget(UpdateResBtn)
    EvsHL.AddConfigWidget(Load)
end
