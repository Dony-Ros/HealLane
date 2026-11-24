local EvsHL = EvsHL
local H = EvsHL.ConfigHelpers
function EvsHL.BuildDebuffsTab(page)
    local S = EvsHL.S
    local rows = {}
    local List
    local maxRows = 20
    local box = H.Section(page, "Ignored Debuffs", -4, 520)
    H.Tooltip(box.titleButton, "Ignored spell IDs do not show an icon or change the bar color.")
    H.AddButton(box, "Choose spell...", 12, -42, 130, function()
        H.OpenPicker(false, "Ignore Debuff", function(entry)
            if not entry.spellID then
                DEFAULT_CHAT_FRAME:AddMessage("HealLane: This spell has no spell ID and cannot be ignored.")
                return
            end
            local count = 0
            for _ in pairs(S.ignoredDebuffs) do count = count + 1 end
            if count >= maxRows and not S.ignoredDebuffs[entry.spellID] then
                DEFAULT_CHAT_FRAME:AddMessage("HealLane: The ignored debuff list is full (" .. maxRows .. ").")
                return
            end
            S.ignoredDebuffs[entry.spellID] = { name = entry.name, icon = entry.icon }
            List()
            EvsHL.ApplyVisuals()
        end, true)
    end)
    local spellIDInput = CreateFrame("EditBox", nil, box, "InputBoxTemplate")
    EvsHL.ConfigUI:StyleEditBox(spellIDInput)
    spellIDInput:SetAutoFocus(false)
    spellIDInput:SetWidth(110)
    spellIDInput:SetHeight(20)
    spellIDInput:SetMaxLetters(12)
    spellIDInput:SetPoint("TOPLEFT", 163, -45)
    spellIDInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local function AddSpellID()
        local spellID = tonumber(spellIDInput:GetText())
        if not spellID or spellID <= 0 or spellID ~= math.floor(spellID) then
            DEFAULT_CHAT_FRAME:AddMessage("HealLane: Enter a valid debuff spell ID.")
            return
        end
        local count = 0
        for _ in pairs(S.ignoredDebuffs) do count = count + 1 end
        if count >= maxRows and not S.ignoredDebuffs[spellID] then
            DEFAULT_CHAT_FRAME:AddMessage("HealLane: The ignored debuff list is full (" .. maxRows .. ").")
            return
        end
        local name = EvsHL.GetSpellInfo(spellID) or ("Spell " .. spellID)
        S.ignoredDebuffs[spellID] = { name = name, icon = EvsHL.GetSpellTexture(spellID) }
        spellIDInput:SetText("")
        spellIDInput:ClearFocus()
        List()
        EvsHL.ApplyVisuals()
    end
    spellIDInput:SetScript("OnEnterPressed", AddSpellID)
    H.AddButton(box, "Ignore ID", 287, -42, 90, AddSpellID)
    for i = 1, maxRows do
        local row = CreateFrame("Frame", nil, box)
        row:SetWidth(436)
        row:SetHeight(22)
        row:SetPoint("TOPLEFT", 12, -76 - (i - 1) * 22)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(18, 18)
        row.icon:SetPoint("LEFT")
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.text:SetWidth(340)
        row.text:SetJustifyH("LEFT")
        EvsHL.ConfigUI:StyleText(row.text)
        row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        EvsHL.ConfigUI:StyleButton(row.remove)
        row.remove:SetSize(22, 20)
        row.remove:SetPoint("RIGHT", -5, 0)
        row.remove:SetText("X")
        row.remove:SetScript("OnClick", function()
            S.ignoredDebuffs[row.spellID] = nil
            List()
            EvsHL.ApplyVisuals()
        end)
        rows[i] = row
    end
    List = function()
        local spellIDs = {}
        for spellID in pairs(S.ignoredDebuffs) do
            spellIDs[#spellIDs + 1] = tonumber(spellID)
        end
        table.sort(spellIDs)
        for i, row in ipairs(rows) do
            local spellID = spellIDs[i]
            if spellID then
                local entry = S.ignoredDebuffs[spellID] or S.ignoredDebuffs[tostring(spellID)]
                row.spellID = spellID
                row.icon:SetTexture(type(entry) == "table" and entry.icon or EvsHL.GetSpellTexture(spellID))
                local name = type(entry) == "table" and entry.name
                row.text:SetText((name or EvsHL.GetSpellInfo(spellID) or ("Spell " .. spellID))
                    .. "  (" .. spellID .. ")")
                row:Show()
            else
                row:Hide()
            end
        end
    end
    EvsHL.AddConfigWidget(List)
end
