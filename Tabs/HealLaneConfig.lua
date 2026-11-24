local EvsHL = EvsHL
local S
local frame, picker
local widgets, pages, tabs = {}, {}, {}
local seq = 0
local FLAT = "Interface\\Buttons\\WHITE8x8"
local function CreateBackdropFrame(frameType, name, parent, template)
    return EvsHL.ConfigUI:CreateBackdropFrame(frameType, name, parent, template)
end
function EvsHL.AddConfigWidget(fn) table.insert(widgets, fn) end
local function Name() seq = seq + 1 return "EvsHLCfg" .. seq end
local function Layout() EvsHL.Refresh() end
local function Visuals() EvsHL.ApplyVisuals() end
local function Sync()
    for _, fn in ipairs(widgets) do fn() end
end
function EvsHL.SyncConfig()
    if frame and frame:IsShown() then Sync() end
end
local function AddCheck(parent, text, x, y, key, after)
    local name = Name()
    local cb = EvsHL.ConfigUI:CreateCheckbox(parent, name, text, S[key], function(value)
        S[key] = value
        after()
    end)
    cb:SetPoint("TOPLEFT", x, y)
    EvsHL.ConfigUI:StyleCheckbox(cb)
    widgets[#widgets + 1] = function() cb:SetChecked(S[key]) end
    return cb
end
local function AddSlider(parent, text, x, y, key, lo, hi, step, after)
    local name = Name()
    local s
    s = EvsHL.ConfigUI:CreateSlider(parent, name, text, 180, lo, hi, step, S[key], function(v)
        v = tonumber(string.format("%.2f", math.floor(v / step + 0.5) * step))
        if s.loading then return end
        if S[key] ~= v then S[key] = v after() end
    end)
    s:SetPoint("TOPLEFT", x, y)
    widgets[#widgets + 1] = function()
        s.loading = true
        s:SetValue(S[key])
        s.loading = false
    end
    return s
end
local function AddButton(parent, text, x, y, w, onClick, anchorPoint, relativePoint, offsetX, offsetY)
    local b = EvsHL.ConfigUI:CreateButton(parent, text, w, 24, onClick)
    EvsHL.ConfigUI:StyleButton(b)
    if anchorPoint then
        b:SetPoint(anchorPoint, offsetX or 0, offsetY or 0)
    else
        b:SetPoint("TOPLEFT", x, y)
    end
    return b
end
local function AddColor(parent, text, x, y, key, after)
    local sw = EvsHL.ConfigUI:CreateButton(parent, "", 24, 24)
    sw:SetWidth(24) sw:SetHeight(24) sw:SetPoint("TOPLEFT", x, y)
    EvsHL.ConfigUI:StyleButton(sw)
    local border = sw:CreateTexture(nil, "BACKGROUND")
    border:SetPoint("TOPLEFT", -2, 2) border:SetPoint("BOTTOMRIGHT", 2, -2) EvsHL.SetTextureColor(border, 0.6, 0.6, 0.6)
    local tex = sw:CreateTexture(nil, "ARTWORK")
    tex:SetDrawLayer("OVERLAY")
    tex:SetAllPoints() EvsHL.SetTextureColor(tex, 1, 1, 1)
    local label = sw:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", sw, "RIGHT", 10, 0) label:SetText(text)
    EvsHL.ConfigUI:StyleText(label)
    local function paint() tex:SetVertexColor(S[key][1], S[key][2], S[key][3]) end
    sw:SetScript("OnClick", function()
        local c = S[key]
        local function Save()
            c[1], c[2], c[3] = ColorPickerFrame:GetColorRGB()
            paint()
            after()
        end
        local function Restore(previous)
            c[1], c[2], c[3] = previous.r, previous.g, previous.b
            paint()
            after()
        end
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({
                r = c[1],
                g = c[2],
                b = c[3],
                hasOpacity = false,
                swatchFunc = Save,
                cancelFunc = Restore,
            })
        else
            ColorPickerFrame.hasOpacity = false
            ColorPickerFrame.previousValues = { r = c[1], g = c[2], b = c[3] }
            ColorPickerFrame.func = Save
            ColorPickerFrame.cancelFunc = Restore
            ColorPickerFrame:SetColorRGB(c[1], c[2], c[3])
            ColorPickerFrame:Hide()
            ColorPickerFrame:Show()
        end
    end)
    widgets[#widgets + 1] = paint
end
local function AddDropdown(parent, x, y, width, options, get, set)
    local name = Name()
    local uiOptions = {}
    for _, option in ipairs(options) do
        uiOptions[#uiOptions + 1] = { value = option[1], label = option[2] }
    end
    local dd = EvsHL.ConfigUI:CreateDropdown(parent, name, width, uiOptions, get(), function(value)
        set(value)
    end)
    dd:SetPoint("TOPLEFT", x, y)
    widgets[#widgets + 1] = function() dd:SetValue(get()) end
    return dd
end
local function Trim(s) return (s or ""):gsub("^%s+", ""):gsub("%s+$", "") end
local ROWS, ROW_H = 16, 24 -- Increased visible rows for bigger window
local function BuildPicker()
    picker = CreateBackdropFrame("Frame", "EvsHLPicker", UIParent)
    picker:SetWidth(320) picker:SetHeight(480) -- Slightly bigger picker
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:EnableMouse(true) picker:EnableMouseWheel(true) picker:SetClampedToScreen(true)
    picker:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    EvsHL.ConfigUI:StylePanel(picker, EvsHL.ConfigUI:GetColors().bg)
    picker:Hide()
    tinsert(UISpecialFrames, "EvsHLPicker")
    picker.title = picker:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    picker.title:SetPoint("TOP", 0, -16)
    EvsHL.ConfigUI:StyleText(picker.title)
    local close = CreateFrame("Button", nil, picker, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)
    local searchLabel = picker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    searchLabel:SetPoint("TOPLEFT", 22, -44) searchLabel:SetText("Search")
    EvsHL.ConfigUI:StyleText(searchLabel)
    local search = CreateFrame("EditBox", Name(), picker, "InputBoxTemplate")
    EvsHL.ConfigUI:StyleEditBox(search)
    search:SetAutoFocus(false) search:SetWidth(190) search:SetHeight(20) search:SetMaxLetters(40) search:SetPoint("TOPLEFT", 78, -40)
    local allName = Name()
    local all = EvsHL.ConfigUI:CreateCheckbox(picker, allName, "Show all spells", false, function()
        picker.Refilter()
    end)
    all:SetPoint("TOPLEFT", 18, -62)
    EvsHL.ConfigUI:StyleCheckbox(all)
    picker.allCheckbox = all
    local scrollName = Name()
    local scroll = CreateFrame("ScrollFrame", scrollName, picker, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -92) scroll:SetPoint("BOTTOMRIGHT", -34, 14)
    local filtered, rows = {}, {}
    local function UpdateList()
        local offset = FauxScrollFrame_GetOffset(scroll)
        FauxScrollFrame_Update(scroll, #filtered, ROWS, ROW_H)
        for i = 1, ROWS do
            local row, e = rows[i], filtered[offset + i]
            if e then
                row.entry = e row.icon:SetTexture(e.icon) row.text:SetText(e.name .. (EvsHL.CLICK_TAGS[e.kind] or "")) row:Show()
            else row.entry = nil row:Hide() end
        end
    end
    function picker.Refilter()
        local q = Trim(search:GetText()):lower()
        wipe(filtered)
        for _, e in ipairs(picker.entries or {}) do
            if (not picker.roleMenuOnly or (e.kind == "action" and e.action == "role"))
                and (e.kind ~= "spell" or all:GetChecked() or e.helpful)
                and (q == "" or e.name:lower():find(q, 1, true)) then
                filtered[#filtered + 1] = e
            end
        end
        _G[scrollName .. "ScrollBar"]:SetValue(0) scroll.offset = 0 UpdateList()
    end
    scroll:SetScript("OnVerticalScroll", function(self, offset) FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, UpdateList) end)
    picker:SetScript("OnMouseWheel", function(_, delta) local bar = _G[scrollName .. "ScrollBar"] bar:SetValue(bar:GetValue() - delta * ROW_H * 3) end)
    search:SetScript("OnTextChanged", function() picker.Refilter() end)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    all:SetScript("OnClick", function() picker.Refilter() end)
    for i = 1, ROWS do
        local row = CreateFrame("Button", nil, picker)
        row:SetWidth(266) row:SetHeight(ROW_H) row:SetPoint("TOPLEFT", 16, -92 - (i - 1) * ROW_H)
        row:SetHighlightTexture(FLAT) row:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.15)
        row.icon = row:CreateTexture(nil, "ARTWORK") row.icon:SetWidth(20) row.icon:SetHeight(20) row.icon:SetPoint("LEFT", 2, 0)
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight") row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0) row.text:SetPoint("RIGHT", -4, 0) row.text:SetJustifyH("LEFT")
        EvsHL.ConfigUI:StyleText(row.text)
        row:SetScript("OnEnter", function(self)
            local entry = self.entry
            if entry and entry.kind == "spell" and entry.index then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if entry.spellID and GameTooltip.SetSpellByID then
                    GameTooltip:SetSpellByID(entry.spellID)
                    GameTooltip:Show()
                elseif GameTooltip.SetSpell then
                    GameTooltip:SetSpell(entry.index, "spell")
                    GameTooltip:Show()
                end
            end
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:SetScript("OnClick", function(self)
            local cb, e = picker.callback, self.entry
            picker:Hide() if cb and e then cb(e) end
        end)
        rows[i] = row
    end
    picker.search = search
end
local function OpenPicker(withMacros, title, callback, showAllSpells, roleMenuOnly)
    if not picker then BuildPicker() end
    EvsHL.ScanSpells()
    local entries = {}
    for _, e in ipairs(EvsHL.spells or {}) do entries[#entries + 1] = e end
    if withMacros then
        for _, macro in ipairs(EvsHL.GetClickMacros()) do entries[#entries + 1] = macro end
        for _, action in ipairs(EvsHL.CLICK_ACTIONS) do
            entries[#entries + 1] = { name = action.name, icon = action.icon, kind = "action", action = action.action }
        end
    end
    picker.entries = entries
    picker.callback = callback
    picker.roleMenuOnly = roleMenuOnly and true or false
    picker.title:SetText(title)
    picker.search:SetText("")
    picker.allCheckbox:SetChecked(showAllSpells and true or false)
    if picker.roleMenuOnly then picker.allCheckbox:Hide() else picker.allCheckbox:Show() end
    picker:ClearAllPoints()
    picker:SetPoint("TOPLEFT", frame, "TOPRIGHT", -4, 0)
    picker:Show()
    picker.Refilter()
    picker.search:SetFocus()
end
local function Label(page, text, x, y)
    local fs = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y) fs:SetText(text)
    EvsHL.ConfigUI:StyleText(fs)
    return fs
end
local function Note(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", x, y) fs:SetText(text) fs:SetTextColor(0.7, 0.7, 0.7)
    EvsHL.ConfigUI:StyleText(fs, EvsHL.ConfigUI:GetColors().muted)
    return fs
end
local function Tooltip(element, text)
    EvsHL.ConfigUI:SetTooltip(element, text)
end
local function Field(parent, text, x, y, width, options, get, set)
    Label(parent, text, x, y)
    return AddDropdown(parent, x - 16, y - 18, width, options, get, set)
end
local function Section(page, title, y, h, x, w)
    local c = CreateBackdropFrame("Frame", nil, page)
    c:SetWidth(w or 460) c:SetHeight(h) c:SetPoint("TOPLEFT", x or 10, y)
    c:SetBackdrop({ bgFile = FLAT, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    c:SetBackdropColor(0, 0, 0, 0.35)
    c:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    EvsHL.ConfigUI:StylePanel(c, EvsHL.ConfigUI:GetColors().panel)
    local titleButton = CreateFrame("Button", nil, c)
    titleButton:SetPoint("TOPLEFT", 12, -2)
    titleButton:SetSize(math.max((w or 460) - 24, 1), 20)
    local fs = titleButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("LEFT")
    fs:SetText(title)
    EvsHL.ConfigUI:StyleText(fs)
    c.titleButton = titleButton
    return c
end
-- Expose to the other config files
EvsHL.ConfigHelpers = { Backdrop = CreateBackdropFrame, Name = Name, AddCheck = AddCheck, AddSlider = AddSlider, AddButton = AddButton, AddColor = AddColor, AddDropdown = AddDropdown, OpenPicker = OpenPicker, Label = Label, Note = Note, Tooltip = Tooltip, Field = Field, Section = Section }
-- GENERAL TAB
local function BuildGeneralOptions(page)
    local H = EvsHL.ConfigHelpers
    local L, R = 8, 235

    local frameBox = Section(page, "Frame", -4, 116)
    H.AddCheck(frameBox, "Lock frame", L, -26, "locked", Layout)
    H.AddCheck(frameBox, "Show player", L, -54, "showPlayer", Layout)
    H.AddCheck(frameBox, "Hide when solo (locked only)", L, -82, "hideSolo", Layout)
    H.AddCheck(frameBox, "Show pets", R, -54, "showPets", Layout)
    H.AddCheck(frameBox, "Show temporary target frame", R, -82, "showTempTarget", Layout)

    local displayBox = Section(page, "Display", -128, 126)
    H.AddCheck(displayBox, "Debuff outline", L, -26, "debuffBorder", Visuals)
    H.AddCheck(displayBox, "Class colored names", L, -54, "classColor", Visuals)
    H.AddCheck(displayBox, "Unit tooltip on hover", R, -26, "showTooltip", Visuals)
    H.AddColor(displayBox, "Hover outline", R + 8, -58, "hoverColor", Visuals)
    H.Label(displayBox, "Health text", 14, -96)
    H.AddDropdown(displayBox, 95, -88, 120, {
        { "none", "None" }, { "max", "Max health" }, { "missing", "Missing health" }, { "current", "Current health" }, { "percent", "Percent" },
    }, function() return S.hpMode end, function(v) S.hpMode = v Visuals() end)

    local behaviorBox = Section(page, "Behavior", -262, 150)
    H.AddCheck(behaviorBox, "Enable Smart Cast (Dispel/Ress)", L, -26, "smartCast", Visuals)
    H.AddCheck(behaviorBox, "Hide Blizzard party frames", L, -54, "hideBlizzardPartyFrames", EvsHL.SetBlizzardPartyFramesHidden)
    H.AddCheck(behaviorBox, "Hide Blizzard raid frames", L, -82, "hideBlizzardRaidFrames", EvsHL.SetBlizzardRaidFramesHidden)
    H.Label(behaviorBox, "Simulation", 14, -120)
    H.AddDropdown(behaviorBox, 95, -112, 120, {
        { 0, "Off" }, { 5, "Party (5)" }, { 10, "Raid (10)" }, { 25, "Raid (25)" }, { 40, "Raid (40)" },
    }, function() return EvsHL.simCount or 0 end, function(v) EvsHL.SetSimulation(v) end)

    H.AddButton(page, "Reset position", 0, 0, 140, function() EvsHL.ResetPosition() end, "BOTTOMLEFT", nil, 15, 15)
    H.AddButton(page, "Reset all settings", 0, 0, 160, function() EvsHL.ResetAll() Sync() end, "BOTTOMRIGHT", nil, -15, 15)
end
local function BuildGeneralFont(page)
    local H = EvsHL.ConfigHelpers
    local textBox = Section(page, "Unit frame text", -4, 210)
    H.Label(textBox, "Font", 20, -38)
    H.AddDropdown(textBox, 54, -30, 165, {
        { "Fonts\\FRIZQT__.TTF", "Friz Quadrata" },
        { "Fonts\\ARIALN.TTF", "Arial Narrow" },
        { "Fonts\\MORPHEUS.TTF", "Morpheus" },
        { "Fonts\\SKURRI.TTF", "Skurri" },
    }, function() return S.fontFace or EvsHL.DEFAULTS.fontFace end, function(value)
        S.fontFace = value
        EvsHL.ApplyVisuals()
    end)
    H.Label(textBox, "Outline", 250, -38)
    H.AddDropdown(textBox, 294, -30, 145, {
        { "", "None" },
        { "OUTLINE", "Outline" },
        { "THICKOUTLINE", "Thick outline" },
    }, function() return S.fontOutline or EvsHL.DEFAULTS.fontOutline end, function(value)
        S.fontOutline = value
        EvsHL.ApplyVisuals()
    end)
    H.AddSlider(textBox, "Name and health text size", 20, -86, "fontSize", 6, 16, 1, EvsHL.ApplyVisuals)
    H.AddCheck(textBox, "Text shadow", 250, -90, "fontShadow", EvsHL.ApplyVisuals)
    H.AddCheck(textBox, "Monochrome", 250, -118, "fontMonochrome", EvsHL.ApplyVisuals)
    H.Tooltip(textBox.titleButton, "WoW supports font faces, outlines, shadows, and monochrome; bold/italic styles aren't exposed.")
end
local function BuildGeneral(page)
    local labels = { "Options", "Font" }
    local builders = { BuildGeneralOptions, BuildGeneralFont }
    local pages, tabs = {}, {}

    local function Select(index)
        for i, subPage in ipairs(pages) do
            if i == index then
                subPage:Show()
            else
                subPage:Hide()
            end
            EvsHL.ConfigUI:SetTabSelected(tabs[i], i == index)
        end
    end

    for i, build in ipairs(builders) do
        local index = i
        local tab = EvsHL.ConfigUI:CreateTabButton(page, labels[i], 76, 22, function()
            Select(index)
        end)
        tab:SetPoint("TOPLEFT", 20 + (i - 1) * 78, -5)
        tabs[i] = tab

        local subPage = CreateFrame("Frame", nil, page)
        subPage:SetPoint("TOPLEFT", 0, -30)
        subPage:SetPoint("BOTTOMRIGHT")
        subPage:Hide()
        pages[i] = subPage
        build(subPage)
    end
    Select(1)
end
local function BuildHots(page)
    local H = EvsHL.ConfigHelpers
    local MAXROWS = 16
    local rows = {}
    local List
    H.AddButton(page, "Pick spell...", 25, -8, 140, function()
        H.OpenPicker(false, "Add HoT", function(e)
            local count = 0 for _ in pairs(S.hots) do count = count + 1 end
            if count >= MAXROWS and not S.hots[e.name] then
                DEFAULT_CHAT_FRAME:AddMessage("HealLane: HoT list is full (" .. MAXROWS .. ")") return
            end
            S.hots[e.name] = true
            List()
            EvsHL.ApplyVisuals()
        end)
    end)
    local spellInput = CreateFrame("EditBox", Name(), page, "InputBoxTemplate")
    EvsHL.ConfigUI:StyleEditBox(spellInput)
    spellInput:SetAutoFocus(false)
    spellInput:SetWidth(125)
    spellInput:SetHeight(20)
    spellInput:SetMaxLetters(80)
    spellInput:SetPoint("TOPLEFT", 178, -10)
    spellInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local function AddSpell(value)
        local query = Trim(value)
        if query == "" then return end
        local spellName = EvsHL.GetSpellInfo(tonumber(query) or query)
        if not spellName or spellName == "" then
            DEFAULT_CHAT_FRAME:AddMessage("HealLane: Spell not found. Enter a valid spell name or ID.")
            return
        end
        local count = 0
        for _ in pairs(S.hots) do count = count + 1 end
        if count >= MAXROWS and not S.hots[spellName] then
            DEFAULT_CHAT_FRAME:AddMessage("HealLane: HoT list is full (" .. MAXROWS .. ")")
            return
        end
        S.hots[spellName] = true
        spellInput:SetText("")
        spellInput:ClearFocus()
        List()
        EvsHL.ApplyVisuals()
    end
    spellInput:SetScript("OnEnterPressed", function(self) AddSpell(self:GetText()) end)
    H.AddButton(page, "Add name/ID", 315, -8, 105, function() AddSpell(spellInput:GetText()) end)
    for i = 1, MAXROWS do
        local row = CreateFrame("Frame", nil, page)
        row:SetWidth(370) row:SetHeight(20) row:SetPoint("TOPLEFT", 25, -42 - (i - 1) * 22)
        row.icon = row:CreateTexture(nil, "ARTWORK") row.icon:SetWidth(18) row.icon:SetHeight(18) row.icon:SetPoint("LEFT", 0, 0)
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight") row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        EvsHL.ConfigUI:StyleText(row.text)
        row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        EvsHL.ConfigUI:StyleButton(row.remove)
        row.remove:SetWidth(22) row.remove:SetHeight(20) row.remove:SetPoint("RIGHT", -5, 0) row.remove:SetText("X")
        row.remove:SetScript("OnClick", function()
            S.hots[row.spell] = nil
            List()
            EvsHL.ApplyVisuals()
        end)
        rows[i] = row
    end
    List = function()
        local names = {}
        for n in pairs(S.hots) do names[#names + 1] = n end
        table.sort(names)
        for i, row in ipairs(rows) do
            local n = names[i]
            if n then row.spell = n row.text:SetText(n) row.icon:SetTexture(EvsHL.GetSpellTexture(n)) row:Show()
            else row:Hide() end
        end
    end
    widgets[#widgets + 1] = List
end
-- Replace the Select() function
local subPages, subTabs = {}, {}
local function SelectSub(index)
    for i, p in ipairs(subPages) do
        if i == index then
            p:Show()
        else
            p:Hide()
        end
        EvsHL.ConfigUI:SetTabSelected(subTabs[i], i == index)
    end
end
local function BuildAppearanceParent(page)
    local subBuilders = { 
        EvsHL.BuildAppGeneral, 
        EvsHL.BuildAppHealing, 
        EvsHL.BuildAppBars, 
        EvsHL.BuildAppIcons, 
        EvsHL.BuildAppSorting,
    }
    local subLabels = { "General", "Healing", "Bars", "Icons", "Sorting" }
    for i, build in ipairs(subBuilders) do
        local index = i
        local tab = EvsHL.ConfigUI:CreateTabButton(page, subLabels[i], 74, 22, function()
            SelectSub(index)
        end)
        tab:SetPoint("TOPLEFT", 20 + (i - 1) * 76, -5)
        subTabs[index] = tab
        local subPage = CreateFrame("Frame", nil, page)
        subPage:SetPoint("TOPLEFT", 0, -30)
        subPage:SetPoint("BOTTOMRIGHT", 0, 0)
        subPage:Hide()
        subPages[index] = subPage
        build(subPage)
    end
    SelectSub(1)
end
local function Select(index)
    for i, p in ipairs(pages) do
        if i == index then
            p:Show()
        else
            p:Hide()
        end
        EvsHL.ConfigUI:SetTabSelected(tabs[i], i == index)
    end
end
local function Build()
    frame = CreateBackdropFrame("Frame", "EvsHLConfigFrame", UIParent)
    frame:SetWidth(500) frame:SetHeight(660)
    frame:SetPoint("CENTER") frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true) frame:EnableMouse(true) frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving) frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    EvsHL.ConfigUI:StylePanel(frame, EvsHL.ConfigUI:GetColors().bg)
    frame:Hide()
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16) title:SetText("HealLane")
    EvsHL.ConfigUI:StyleText(title)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)
    tinsert(UISpecialFrames, "EvsHLConfigFrame")
    -- Main Tabs
    local builders = { BuildGeneral, BuildAppearanceParent, EvsHL.BuildClicksTab, BuildHots, EvsHL.BuildCureTab, EvsHL.BuildDebuffsTab, EvsHL.BuildBuffsTab, EvsHL.BuildModsTab }
    local labels = { "General", "Appearance", "Clicks", "HoTs", "Cure", "Debuffs", "Buffs", "Mods" }
    local TABS_PER_ROW = 7
    for i, build in ipairs(builders) do
        local index = i
        local tab = EvsHL.ConfigUI:CreateTabButton(frame, labels[i], 64, 24, function()
            Select(index)
        end)
        local tabRow = math.floor((i - 1) / TABS_PER_ROW)
        local tabCol = (i - 1) % TABS_PER_ROW
        tab:SetPoint("TOPLEFT", 22 + tabCol * 66, -44 - tabRow * 26)
        tabs[index] = tab
        local page = CreateFrame("Frame", nil, frame)
        page:SetPoint("TOPLEFT", 10, -102) page:SetPoint("BOTTOMRIGHT", -10, 12) page:Hide()
        pages[index] = page
        build(page)
    end
    frame:SetScript("OnShow", Sync)
    frame:SetScript("OnHide", function() if picker then picker:Hide() end end)
    Select(1)
end
function EvsHL.ToggleConfig()
    S = EvsHL.S
    if not S then return end
    if not frame then Build() end
    if frame:IsShown() then frame:Hide() else frame:Show() end
end
SLASH_HEALLANE1 = "/heallane"
SLASH_HEALLANE2 = "/hl"
SlashCmdList["HEALLANE"] = function() EvsHL.ToggleConfig() end
-- NEW: Slash command to reset settings
SLASH_HEALLANE_RESET1 = "/hlreset"
SlashCmdList["HEALLANE_RESET"] = function()
    if EvsHL.ResetAll then
        EvsHL.ResetAll()
        if EvsHL.SyncConfig then EvsHL.SyncConfig() end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00HealLane:|r Settings have been reset to default.")
    end
end
local panel = CreateFrame("Frame", "EvsHLOptionsPanel", UIParent)
panel.name = "HealLane"
local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
EvsHL.ConfigUI:StyleButton(open)
open:SetWidth(160) open:SetHeight(24) open:SetPoint("TOPLEFT", 20, -20) open:SetText("Open settings")
open:SetScript("OnClick", function() EvsHL.ToggleConfig() end)
if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
end