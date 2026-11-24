local EvsHL = EvsHL
local FLAT = "Interface\\Buttons\\WHITE8x8"
local CHIP_W, CHIP_H, GAP, PAD = 58, 48, 4, 3
local TRACK_W, TRACK_H = 436, 58
local KEYS = { "TANK", "PLAYER", "HEALER", "DPS", "PETS", "TARGET", "BREAK" }
local CHIPS = {
    TANK = { label = "Tank", color = { 0.35, 0.55, 1 }, texture = EvsHL.Role_Icons.TANK, tip = "Tanks" },
    PLAYER = { label = "You", color = { 1, 0.82, 0.2 }, portrait = true, tip = "Your own frame" },
    HEALER = { label = "Healer", color = { 0.3, 0.9, 0.4 }, texture = EvsHL.Role_Icons.HEALER, tip = "Healers" },
    DPS = { label = "DPS", color = { 0.95, 0.35, 0.35 }, texture = EvsHL.Role_Icons.DPS, tip = "Damage dealers and everyone else" },
    PETS = { label = "Pets", color = { 0.75, 0.55, 0.3 }, texture = "Interface\\Icons\\Ability_Hunter_MendPet", coords = { 0.08, 0.92, 0.08, 0.92 }, tip = "Pet frames" },
    TARGET = { label = "Target", color = { 0.7, 0.7, 0.7 }, texture = "Interface\\Icons\\Ability_Marksmanship", coords = { 0.08, 0.92, 0.08, 0.92 }, tip = "Temporary target frame" },
    BREAK = { label = "Break", color = { 1, 0.82, 0 }, tip = "Column break", desc = "Everything before it stacks in the first column. Everything after it fills the remaining columns." },
}
local SAMPLE = { TANK = 2, PLAYER = 1, HEALER = 3, DPS = 8, PETS = 2, TARGET = 1 }

function EvsHL.BuildAppSorting(page)
    local H = EvsHL.ConfigHelpers
    local chips, order = {}, {}
    local dragging, dragIndex
    local RefreshPreview

    local function Apply()
        EvsHL.MarkOrderDirty()
        EvsHL.Refresh()
        RefreshPreview()
    end

    local roleBox = H.Section(page, "Role order", -4, 158)
    H.AddCheck(roleBox, "Enable role sorting", 8, -26, "sortByRole", Apply)
    H.Tooltip(roleBox.titleButton, "Drag a role to reorder. Roles before the Break share the first column; roles after it fill the remaining columns.")

    local track = H.Backdrop("Frame", nil, roleBox)
    track:SetWidth(TRACK_W) track:SetHeight(TRACK_H) track:SetPoint("TOPLEFT", 12, -92)
    track:SetBackdrop({ bgFile = FLAT })
    track:SetBackdropColor(0, 0, 0, 0.35)
    EvsHL.ConfigUI:StylePanel(track, EvsHL.ConfigUI:GetColors().panel)
    local slotTex = track:CreateTexture(nil, "BACKGROUND")
    slotTex:SetWidth(CHIP_W) slotTex:SetHeight(CHIP_H)
    slotTex:SetTexture(FLAT) slotTex:SetVertexColor(1, 1, 1, 0.12)
    slotTex:Hide()

    local function SlotX(i) return PAD + (i - 1) * (CHIP_W + GAP) end

    local function Layout()
        local j = 0
        for _, key in ipairs(order) do
            local chip = chips[key]
            if chip ~= dragging then
                j = j + 1
                local pos = (dragging and j >= dragIndex) and j + 1 or j
                chip:ClearAllPoints()
                chip:SetPoint("TOPLEFT", track, "TOPLEFT", SlotX(pos), -5)
            end
        end
        if dragging then
            slotTex:ClearAllPoints()
            slotTex:SetPoint("TOPLEFT", track, "TOPLEFT", SlotX(dragIndex), -5)
            slotTex:Show()
        else
            slotTex:Hide()
        end
    end

    local function Follow(self)
        local cx = GetCursorPosition() / track:GetEffectiveScale() - track:GetLeft()
        local x = math.max(0, math.min(cx - CHIP_W / 2, TRACK_W - CHIP_W))
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", track, "TOPLEFT", x, -5)
        local index = math.floor((cx - PAD) / (CHIP_W + GAP)) + 1
        index = math.max(1, math.min(index, #order))
        if index ~= dragIndex then
            dragIndex = index
            Layout()
        end
    end

    local function EndDrag(commit)
        local chip = dragging
        if not chip then return end
        chip:SetScript("OnUpdate", nil)
        chip:SetAlpha(1)
        chip:SetFrameLevel(track:GetFrameLevel() + 1)
        dragging = nil
        if commit then
            local from
            for i, key in ipairs(order) do
                if chips[key] == chip then from = i end
            end
            local key = table.remove(order, from)
            table.insert(order, math.min(dragIndex, #order + 1), key)
            EvsHL.SetSortOrder(order)
            Apply()
        end
        Layout()
    end

    for _, key in ipairs(KEYS) do
        local def = CHIPS[key]
        local chip = H.Backdrop("Button", nil, track)
        chip:SetWidth(CHIP_W) chip:SetHeight(CHIP_H)
        chip:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        chip:SetBackdropColor(0, 0, 0, 0.7)
        chip:SetBackdropBorderColor(def.color[1], def.color[2], def.color[3], 1)
        EvsHL.ConfigUI:StyleButton(chip)
        chip:SetHighlightTexture(FLAT) chip:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.12)
        chip.icon = chip:CreateTexture(nil, "ARTWORK")
        chip.icon:SetWidth(24) chip.icon:SetHeight(24) chip.icon:SetPoint("TOP", 0, -6)
        chip.icon:SetDrawLayer("OVERLAY")
        chip.icon:SetVertexColor(1, 1, 1, 1)
        chip.icon:SetAlpha(1)
        chip.label = chip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        chip.label:SetPoint("BOTTOM", 0, 6) chip.label:SetText(def.label)
        EvsHL.ConfigUI:StyleText(chip.label)
        if key == "BREAK" then
            chip.icon:SetTexture(FLAT)
            chip.icon:SetVertexColor(def.color[1], def.color[2], def.color[3])
            chip.icon:SetWidth(4)
        elseif def.portrait then
            chip.icon:SetTexCoord(0, 1, 0, 1)
        else
            chip.icon:SetTexture(def.texture)
            if def.coords then
                chip.icon:SetTexCoord(def.coords[1], def.coords[2], def.coords[3], def.coords[4])
            else
                chip.icon:SetTexCoord(0, 1, 0, 1)
            end
        end
        chip:RegisterForDrag("LeftButton")
        chip:SetScript("OnDragStart", function(self)
            for i, k in ipairs(order) do
                if k == key then dragIndex = i end
            end
            dragging = self
            self:SetFrameLevel(track:GetFrameLevel() + 10)
            self:SetAlpha(0.9)
            self:SetScript("OnUpdate", Follow)
            Layout()
        end)
        chip:SetScript("OnDragStop", function() EndDrag(true) end)
        chip:SetScript("OnEnter", function(self)
            if dragging then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(def.tip)
            GameTooltip:AddLine(def.desc or "Drag to reorder.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        chip:SetScript("OnLeave", function() GameTooltip:Hide() end)
        chips[key] = chip
    end
    track:SetScript("OnHide", function() EndDrag(false) end)

    local function LoadChips()
        EndDrag(false)
        order = EvsHL.GetSortOrder()
        SetPortraitTexture(chips.PLAYER.icon, "player")
        Layout()
    end

    local optionsBox = H.Section(page, "Options", -170, 122)
    H.Field(optionsBox, "Within each role", 20, -30, 140, EvsHL.SORT_WITHIN_OPTIONS,
        function() return EvsHL.GetSortWithin() end,
        function(v) EvsHL.S.sortWithin = v Apply() end)
    H.Field(optionsBox, "Fill direction", 250, -30, 140, EvsHL.SORT_FILL_OPTIONS,
        function() return EvsHL.GetSortFill() end,
        function(v) EvsHL.S.sortFill = v Apply() end)
    H.AddCheck(optionsBox, "Reverse order within roles", 8, -84, "sortReverse", Apply)

    local previewBox = H.Section(page, "Preview", -300, 140)
    H.Tooltip(previewBox.titleButton, "The sample group uses the Columns setting from Bars.")
    local offNote = H.Note(previewBox, "Role sorting is off.", 14, -30)
    local cells = {}
    local legendY = 0
    for _, key in ipairs(KEYS) do
        if key ~= "BREAK" then
            local def = CHIPS[key]
            local swatch = previewBox:CreateTexture(nil, "ARTWORK")
            swatch:SetWidth(10) swatch:SetHeight(10)
            swatch:SetPoint("TOPLEFT", 300, -30 - legendY * 16)
            swatch:SetTexture(FLAT)
            swatch:SetVertexColor(def.color[1], def.color[2], def.color[3])
            local fs = previewBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("LEFT", swatch, "RIGHT", 6, 0)
            fs:SetText(def.label .. " x" .. SAMPLE[key])
            legendY = legendY + 1
        end
    end
    RefreshPreview = function()
        local S = EvsHL.S
        for _, cell in ipairs(cells) do cell:Hide() end
        if not S.sortByRole then
            offNote:Show()
            return
        end
        offNote:Hide()
        local cols = math.max(tonumber(S.cols) or 1, 1)
        local sorted, positions, rowCount = EvsHL.SortPreview(SAMPLE, cols)
        local pitch = math.max(math.min(12, math.floor(100 / rowCount)), 4)
        for i, cat in ipairs(sorted) do
            local cell = cells[i]
            if not cell then
                cell = previewBox:CreateTexture(nil, "ARTWORK")
                cell:SetTexture(FLAT)
                cells[i] = cell
            end
            local p, c = positions[i], CHIPS[cat].color
            cell:SetVertexColor(c[1], c[2], c[3])
            cell:SetWidth(20) cell:SetHeight(pitch - 2)
            cell:ClearAllPoints()
            cell:SetPoint("TOPLEFT", 14 + p.col * 22, -30 - p.row * pitch)
            cell:Show()
        end
    end

    H.AddButton(page, "Reset sorting", 0, 0, 140, function()
        EvsHL.ResetSorting()
        Apply()
        EvsHL.SyncConfig()
    end, "BOTTOMLEFT", nil, 15, 15)

    local function Reload()
        LoadChips()
        RefreshPreview()
    end
    page:SetScript("OnShow", Reload)
    EvsHL.AddConfigWidget(Reload)
    Reload()
end
