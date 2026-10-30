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
        end)
    end)

    local types = { "Magic", "Curse", "Disease", "Poison", "Bleed" }
    local typeColorKeys = {
        Magic = "debuffMagicColor",
        Curse = "debuffCurseColor",
        Disease = "debuffDiseaseColor",
        Poison = "debuffPoisonColor",
        Bleed = "debuffBleedColor",
    }
    for i = 1, MAXROWS do
        local row = CreateFrame("Frame", nil, page)
        row:SetWidth(460)
        row:SetHeight(24)
        row:SetPoint("TOPLEFT", 25, -85 - (i - 1) * 26)

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetWidth(18)
        row.icon:SetHeight(18)
        row.icon:SetPoint("LEFT", 0, 0)

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.text:SetWidth(110)
        row.text:SetJustifyH("LEFT")

        row.checks = {}
        for tIdx, tName in ipairs(types) do
            local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            btn:SetWidth(46)
            btn:SetHeight(20)
            btn:SetPoint("LEFT", 130 + (tIdx - 1) * 50, 0)
            btn:SetText(tName)
            -- Smaller font for the button text
            local fs = btn:GetFontString()
            if fs then fs:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE") end

            btn:SetScript("OnClick", function(self)
                local val = not S.dispel.spells[row.spell].types[tName]
                S.dispel.spells[row.spell].types[tName] = val
                if val then
                    btn:LockHighlight()
                else
                    btn:UnlockHighlight()
                end
            end)

            -- Create a glow behind the button when active
            local glow = btn:CreateTexture(nil, "BACKGROUND")
            glow:SetAllPoints()
            local c = S[typeColorKeys[tName]]
            glow:SetTexture(c[1], c[2], c[3], 0.5)
            btn.glow = glow

            row.checks[tName] = btn
        end

        row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.remove:SetWidth(22)
        row.remove:SetHeight(20)
        row.remove:SetPoint("RIGHT", -5, 0)
        row.remove:SetText("X")
        row.remove:SetScript("OnClick", function()
            S.dispel.spells[row.spell] = nil
            List()
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
                row.icon:SetTexture(GetSpellTexture(n))
                for tName, btn in pairs(row.checks) do
                    if S.dispel.spells[n].types[tName] then
                        btn:LockHighlight()
                        btn.glow:Show()
                    else
                        btn:UnlockHighlight()
                        btn.glow:Hide()
                    end
                    btn:Show()
                end
                row.remove:Show()
                row:Show()
            else
                row:Hide()
            end
        end
    end
    EvsHL.AddConfigWidget(List)

    local function UpdateTypeGlows()
        for _, row in ipairs(rows) do
            for tName, btn in pairs(row.checks) do
                local c = S[typeColorKeys[tName]]
                btn.glow:SetTexture(c[1], c[2], c[3], 0.5)
            end
        end
    end
    H.Label(page, "Debuff type colors", 25, -340)
    for i, tName in ipairs(types) do
        H.AddColor(page, tName, 25, -365 - (i - 1) * 28, typeColorKeys[tName], function()
            EvsHL.ApplyVisuals()
            UpdateTypeGlows()
        end)
    end

end
