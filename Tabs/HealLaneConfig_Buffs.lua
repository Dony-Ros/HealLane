local HealLane = HealLane
local S
local H = HealLane.ConfigHelpers
function HealLane.BuildBuffsTab(page)
    S = HealLane.S
    local MAXROWS = 16
    local rows = {}
    local List

    local function TargetOf(name)
        local t = name and S.trackBuffs[name]
        if not t or t == true then return "any" end
        return t
    end

    local options = H.Section(page, "Options", -4, 144)
    H.AddButton(options, "Add Buff...", 12, -28, 140, function()
        H.OpenPicker(false, "Add Tracked Buff", function(e)
            local count = 0
            for _ in pairs(S.trackBuffs) do count = count + 1 end
            if count >= MAXROWS and not S.trackBuffs[e.name] then
                DEFAULT_CHAT_FRAME:AddMessage("HealLane: Buff tracking list is full (" .. MAXROWS .. ")")
                return
            end
            S.trackBuffs[e.name] = TargetOf(e.name)
            List()
        end)
    end)
    H.Field(options, "Recast buffs expiring within:", 250, -26, 120, HealLane.BUFF_EXPIRE_OPTIONS,
        function() return S.buffExpireWarn or 0 end,
        function(v) S.buffExpireWarn = v end)
    H.AddCheck(options, "Monitor missing buffs", 8, -80, "monitorMissingBuffs", HealLane.ApplyVisuals)
    H.AddCheck(options, "Highlight missing buffs", 235, -80, "buffBorder", HealLane.ApplyVisuals)
    H.AddCheck(options, "Check missing buffs on units in combat", 8, -108, "checkBuffsInCombat", HealLane.ApplyVisuals)
    H.AddColor(options, "Missing Buff Color", 243, -112, "buffsMissingColor", HealLane.ApplyVisuals)

    local listBox = H.Section(page, "Tracked buffs", -156, 384)
    H.Tooltip(listBox.titleButton, "Choose which unit types each buff is tracked on. Pets are always ignored.")
    for i = 1, MAXROWS do
        local row = CreateFrame("Frame", nil, listBox)
        row:SetWidth(436)
        row:SetHeight(24)
        row:SetPoint("TOPLEFT", 12, -28 - (i - 1) * 22)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetWidth(18) row.icon:SetHeight(18) row.icon:SetPoint("LEFT", 0, 0)
        row.text = HealLane.CreateFontString(row, nil, "OVERLAY", "GameFontHighlight")
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.text:SetWidth(150)
        row.text:SetJustifyH("LEFT")
        HealLane.ConfigUI:StyleText(row.text)
        row.dd = H.AddDropdown(row, 210, 2, 150, HealLane.BUFF_TARGETS,
            function() return TargetOf(row.spell) end,
            function(v) if row.spell then S.trackBuffs[row.spell] = v end end)
        row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        HealLane.ConfigUI:StyleButton(row.remove)
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
                row.icon:SetTexture(HealLane.GetSpellTexture(n))
                row.dd:SetValue(TargetOf(n))
                row:Show()
            else
                row.spell = nil
                row:Hide()
            end
        end
    end
    HealLane.AddConfigWidget(List)
end
