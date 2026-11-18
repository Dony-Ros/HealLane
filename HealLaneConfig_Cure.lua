local EvsHL = EvsHL
local S
local H = EvsHL.ConfigHelpers
function EvsHL.BuildCureTab(page)
    S = EvsHL.S
    local MAXROWS = 6
    local rows = {}
    local List
    H.Label(page, "Smart Cast Dispel Spells", 25, -20)
    H.Label(page, "Add spells and check which debuffs they can remove.", 25, -36)
    H.AddButton(page, "Add Dispel Spell...", 25, -55, 160, function()
        H.OpenPicker(false, "Add Dispel Spell", function(e)
            local count = 0
            for _ in pairs(S.dispel.spells) do count = count + 1 end
            if count >= MAXROWS then
                DEFAULT_CHAT_FRAME:AddMessage("HealLane: Dispel list is full (" .. MAXROWS .. ")")
                return
            end
            S.dispel.spells[e.name] = { spell = e.name, types = {} }
            List()
            EvsHL.ApplyVisuals()
        end)
    end)
    local types = { "Magic", "Curse", "Disease", "Poison", "Bleed" }
    local function UpdateTypeDropdown(row)
        local entry = row.spell and S.dispel.spells[row.spell]
        if not entry then
            UIDropDownMenu_SetText(row.typeDropdown, "Select types...")
            return
        end
        local count = 0
        for _, tName in ipairs(types) do
            if entry.types and entry.types[tName] then count = count + 1 end
        end
        UIDropDownMenu_SetText(row.typeDropdown, count == 0 and "Select types..."
            or (count == 1 and "1 type selected" or count .. " types selected"))
    end
    for i = 1, MAXROWS do
        local row = CreateFrame("Frame", nil, page)
        row:SetWidth(460)
        row:SetHeight(32)
        row:SetPoint("TOPLEFT", 25, -85 - (i - 1) * 34)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetWidth(18)
        row.icon:SetHeight(18)
        row.icon:SetPoint("LEFT", 0, 0)
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.text:SetWidth(98)
        row.text:SetJustifyH("LEFT")
        row.typeDropdown = CreateFrame("Frame", nil, row, "UIDropDownMenuTemplate")
        row.typeDropdown:SetPoint("LEFT", row, "LEFT", 130, 0)
        if not pcall(UIDropDownMenu_SetWidth, 150, row.typeDropdown) then
            pcall(UIDropDownMenu_SetWidth, row.typeDropdown, 150)
        end
        UIDropDownMenu_Initialize(row.typeDropdown, function(self, level)
            for _, tName in ipairs(types) do
                local typeName = tName
                local info = UIDropDownMenu_CreateInfo()
                info.text = typeName
                info.isNotRadio = true
                info.keepShownOnClick = true
                info.checked = function()
                    local entry = row.spell and S.dispel.spells[row.spell]
                    return entry and entry.types and entry.types[typeName] or false
                end
                info.func = function()
                    local entry = row.spell and S.dispel.spells[row.spell]
                    if not entry then return end
                    entry.types = entry.types or {}
                    entry.types[typeName] = not entry.types[typeName]
                    UpdateTypeDropdown(row)
                    EvsHL.ApplyVisuals()
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
        row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.remove:SetWidth(22)
        row.remove:SetHeight(20)
        row.remove:SetPoint("RIGHT", -5, 0)
        row.remove:SetText("X")
        row.remove:SetScript("OnClick", function()
            S.dispel.spells[row.spell] = nil
            List()
            EvsHL.ApplyVisuals()
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
                row.icon:SetTexture(EvsHL.GetSpellTexture(n))
                UpdateTypeDropdown(row)
                row.remove:Show()
                row:Show()
            else
                row:Hide()
            end
        end
    end
    EvsHL.AddConfigWidget(List)
    H.Label(page, "Debuff type colors", 25, -340)
    for i, tName in ipairs(types) do
        local column = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local colorKey = "debuff" .. tName .. "Color"
        H.AddColor(page, tName, 25 + column * 235, -365 - row * 28, colorKey, EvsHL.ApplyVisuals)
    end
end
