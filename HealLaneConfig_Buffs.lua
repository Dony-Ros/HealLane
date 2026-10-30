local EvsHL = EvsHL
local S
local H = EvsHL.ConfigHelpers

function EvsHL.BuildBuffsTab(page)
    S = EvsHL.S
    local MAXROWS = 20
    local rows = {}
    local List
    
    H.Label(page, "Tracked Buffs (Smart Cast)", 25, -20)
    H.Label(page, "If missing, the frame highlights and Smart Cast clicks will cast the buff.", 25, -36)
    
    H.AddButton(page, "Add Buff...", 25, -55, 140, function()
        H.OpenPicker(false, "Add Tracked Buff", function(e)
            local count = 0
            for _ in pairs(S.trackBuffs) do count = count + 1 end
            if count >= MAXROWS and not S.trackBuffs[e.name] then
                DEFAULT_CHAT_FRAME:AddMessage("HealLane: Buff tracking list is full (" .. MAXROWS .. ")")
                return
            end
            S.trackBuffs[e.name] = true
            List()
        end)
    end)

    for i = 1, MAXROWS do
        local row = CreateFrame("Frame", nil, page)
        row:SetWidth(200)
        row:SetHeight(20)
        row:SetPoint("TOPLEFT", 25, -85 - (i - 1) * 22)
        
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetWidth(18) row.icon:SetHeight(18) row.icon:SetPoint("LEFT", 0, 0)
        
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        
        row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.remove:SetWidth(22) row.remove:SetHeight(20) row.remove:SetPoint("RIGHT", -5, 0) row.remove:SetText("X")
        row.remove:SetScript("OnClick", function()
            S.trackBuffs[row.spell] = nil
            List()
        end)
        rows[i] = row
    end

    List = function()
        local names = {}
        for n in pairs(S.trackBuffs) do names[#names + 1] = n end
        table.sort(names)
        for i, row in ipairs(rows) do
            local n = names[i]
            if n then
                row.spell = n
                row.text:SetText(n)
                row.icon:SetTexture(GetSpellTexture(n))
                row:Show()
            else
                row:Hide()
            end
        end
    end
    EvsHL.AddConfigWidget(List)

    -- Visuals
    H.Label(page, "Visuals", 260, -55)
    H.AddCheck(page, "Monitor missing buffs", 260, -85, "monitorMissingBuffs", EvsHL.ApplyVisuals)
    H.AddCheck(page, "Highlight missing buffs", 260, -115, "buffBorder", EvsHL.ApplyVisuals)
    H.AddColor(page, "Missing Buff Color", 260, -155, "buffsMissingColor", EvsHL.ApplyVisuals)
    H.AddCheck(page, "Check missing buffs on units in combat", 260, -195, "checkBuffsInCombat", EvsHL.ApplyVisuals)
end