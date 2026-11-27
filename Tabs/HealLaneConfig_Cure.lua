local HealLane = HealLane
local S
local H = HealLane.ConfigHelpers
function HealLane.BuildCureTab(page)
    S = HealLane.S
    local MAXROWS = 6
    local rows = {}
    local List
    local box = H.Section(page, "Smart Cast Dispel Spells", -4, 288)
    H.Tooltip(box.titleButton, "Add spells and select which debuff types they can remove.")
    H.AddButton(box, "Add Dispel Spell...", 12, -44, 160, function()
        H.OpenPicker(false, "Add Dispel Spell", function(e)
            local count = 0
            for _ in pairs(S.dispel.spells) do count = count + 1 end
            if count >= MAXROWS then
                DEFAULT_CHAT_FRAME:AddMessage("HealLane: Dispel list is full (" .. MAXROWS .. ")")
                return
            end
            S.dispel.spells[e.name] = { spell = e.name, types = {} }
            List()
            HealLane.ApplyVisuals()
        end)
    end)
    local types = { "Magic", "Curse", "Disease", "Poison", "Bleed" }
    local function UpdateTypeDropdown(row)
        if row.typeDropdown then row.typeDropdown:Refresh() end
    end
    local function GetTypeSummary(row)
        local entry = row.spell and S.dispel.spells[row.spell]
        local count = 0
        if entry then
            for _, tName in ipairs(types) do
                if entry.types and entry.types[tName] then count = count + 1 end
            end
        end
        return count == 0 and "Select types..."
            or (count == 1 and "1 type selected" or count .. " types selected")
    end
    for i = 1, MAXROWS do
        local row = CreateFrame("Frame", nil, box)
        row:SetWidth(436)
        row:SetHeight(32)
        row:SetPoint("TOPLEFT", 12, -78 - (i - 1) * 34)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetWidth(18)
        row.icon:SetHeight(18)
        row.icon:SetPoint("LEFT", 0, 0)
        row.text = HealLane.CreateFontString(row, nil, "OVERLAY", "GameFontHighlight")
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.text:SetWidth(98)
        row.text:SetJustifyH("LEFT")
        local function IsTypeSelected(typeName)
            local entry = row.spell and S.dispel.spells[row.spell]
            return entry and entry.types and entry.types[typeName] or false
        end
        local function ToggleType(typeName)
            local entry = row.spell and S.dispel.spells[row.spell]
            if not entry then return end
            entry.types = entry.types or {}
            entry.types[typeName] = not entry.types[typeName]
            UpdateTypeDropdown(row)
            HealLane.ApplyVisuals()
        end
        row.typeDropdown = HealLane.ConfigUI:CreateMultiDropdown(row, nil, 150, types,
            function() return GetTypeSummary(row) end, IsTypeSelected, ToggleType)
        row.typeDropdown:SetPoint("LEFT", row, "LEFT", 130, 0)
        row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        HealLane.ConfigUI:StyleButton(row.remove)
        row.remove:SetWidth(22)
        row.remove:SetHeight(20)
        row.remove:SetPoint("RIGHT", -5, 0)
        row.remove:SetText("X")
        row.remove:SetScript("OnClick", function()
            S.dispel.spells[row.spell] = nil
            List()
            HealLane.ApplyVisuals()
        end)
        rows[i] = row
    end
    List = function()
        local names = {}
        for n in pairs(S.dispel.spells) do names[#names + 1] = n end
        table.sort(names)
        for i, row in ipairs(rows) do
            local n = names[i]
            if n then
                row.spell = n
                row.text:SetText(n)
                row.icon:SetTexture(HealLane.GetSpellTexture(n))
                UpdateTypeDropdown(row)
                row.remove:Show()
                row:Show()
            else
                row:Hide()
            end
        end
    end
    HealLane.AddConfigWidget(List)
    local colorBox = H.Section(page, "Debuff type colors", -300, 116)
    for i, tName in ipairs(types) do
        local column = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local colorKey = "debuff" .. tName .. "Color"
        H.AddColor(colorBox, tName, 14 + column * 229, -30 - row * 28, colorKey, HealLane.ApplyVisuals)
    end
end
