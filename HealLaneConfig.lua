local EvsHL = EvsHL
local S
local frame, picker
local widgets, pages, tabs = {}, {}, {}
local seq = 0
local curMod = ""
local FLAT = "Interface\\Buttons\\WHITE8x8"

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
    local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    _G[name .. "Text"]:SetText(text)
    cb:SetScript("OnClick", function(self) S[key] = self:GetChecked() and true or false after() end)
    widgets[#widgets + 1] = function() cb:SetChecked(S[key]) end
end

local function AddSlider(parent, text, x, y, key, lo, hi, step, after)
    local name = Name()
    local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", x, y)
    s:SetWidth(180)
    s:SetMinMaxValues(lo, hi)
    s:SetValueStep(step)
    _G[name .. "Low"]:SetText(lo)
    _G[name .. "High"]:SetText(hi)
    local label = _G[name .. "Text"]
    s:SetScript("OnValueChanged", function(self, v)
        v = tonumber(string.format("%.2f", math.floor(v / step + 0.5) * step))
        label:SetText(text .. ": " .. v)
        if self.loading then return end
        if S[key] ~= v then S[key] = v after() end
    end)
    widgets[#widgets + 1] = function()
        s.loading = true
        s:SetValue(S[key])
        label:SetText(text .. ": " .. S[key])
        s.loading = false
    end
end

local function AddButton(parent, text, x, y, w, onClick, anchorPoint, relativePoint, offsetX, offsetY)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetWidth(w) b:SetHeight(24) b:SetText(text) b:SetScript("OnClick", onClick)
    
    if anchorPoint then
        b:SetPoint(anchorPoint, offsetX or 0, offsetY or 0)
    else
        b:SetPoint("TOPLEFT", x, y)
    end
    return b
end

local function AddColor(parent, text, x, y, key, after)
    local sw = CreateFrame("Button", nil, parent)
    sw:SetWidth(24) sw:SetHeight(24) sw:SetPoint("TOPLEFT", x, y)
    local border = sw:CreateTexture(nil, "BACKGROUND")
    border:SetPoint("TOPLEFT", -2, 2) border:SetPoint("BOTTOMRIGHT", 2, -2) border:SetTexture(0.6, 0.6, 0.6)
    local tex = sw:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints() tex:SetTexture(1, 1, 1)
    local label = sw:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", sw, "RIGHT", 10, 0) label:SetText(text)
    local function paint() tex:SetVertexColor(S[key][1], S[key][2], S[key][3]) end
    sw:SetScript("OnClick", function()
        local c = S[key]
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = { r = c[1], g = c[2], b = c[3] }
        ColorPickerFrame.func = function() c[1], c[2], c[3] = ColorPickerFrame:GetColorRGB() paint() after() end
        ColorPickerFrame.cancelFunc = function(prev) c[1], c[2], c[3] = prev.r, prev.g, prev.b paint() after() end
        ColorPickerFrame:SetColorRGB(c[1], c[2], c[3])
        ColorPickerFrame:Hide() ColorPickerFrame:Show()
    end)
    widgets[#widgets + 1] = paint
end

local function AddDropdown(parent, x, y, width, options, get, set)
    local name = Name()
    local dd = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", x, y)
    if not pcall(UIDropDownMenu_SetWidth, width, dd) then pcall(UIDropDownMenu_SetWidth, dd, width) end
    local text = _G[name .. "Text"]
    local function Show()
        local cur = get()
        for _, o in ipairs(options) do if o[1] == cur then text:SetText(o[2]) end end
    end
    UIDropDownMenu_Initialize(dd, function()
        for _, o in ipairs(options) do
            local info = { text = o[2], checked = (get() == o[1]), func = function() set(o[1]) Show() end }
            UIDropDownMenu_AddButton(info)
        end
    end)
    widgets[#widgets + 1] = Show
    return dd
end

local function Trim(s) return (s or ""):gsub("^%s+", ""):gsub("%s+$", "") end
local function Macros()
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

local ACTIONS = {
    { name = "Target", action = "target", icon = "Interface\\Icons\\Ability_Marksmanship" },
    { name = "Menu", action = "menu", icon = "Interface\\Icons\\INV_Misc_Note_01" },
    { name = "Focus", action = "focus", icon = "Interface\\Icons\\Ability_TrueShot" },
    { name = "Assist", action = "assist", icon = "Interface\\Icons\\Ability_Hunter_SniperShot" },
}
local TAGS = { macro = " |cff9999ff(macro)|r", action = " |cff99ff99(action)|r" }

local function Describe(value)
    if not value or value == "" then return nil end
    local macro = value:match("^m:(.+)")
    if macro then
        for _, m in ipairs(Macros()) do if m.name == macro then return m.icon, macro, "macro" end end
        return nil, macro, "macro"
    end
    local action = value:match("^a:(.+)")
    if action then
        for _, a in ipairs(ACTIONS) do if a.action == action then return a.icon, a.name, "action" end end
        return nil, action, "action"
    end
    return GetSpellTexture(value), value
end

local ROWS, ROW_H = 16, 24 -- Increased visible rows for bigger window
local function BuildPicker()
    picker = CreateFrame("Frame", "EvsHLPicker", UIParent)
    picker:SetWidth(320) picker:SetHeight(480) -- Slightly bigger picker
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:EnableMouse(true) picker:EnableMouseWheel(true) picker:SetClampedToScreen(true)
    picker:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    picker:Hide()
    tinsert(UISpecialFrames, "EvsHLPicker")
    picker.title = picker:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    picker.title:SetPoint("TOP", 0, -16)
    local close = CreateFrame("Button", nil, picker, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)
    local searchLabel = picker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    searchLabel:SetPoint("TOPLEFT", 22, -44) searchLabel:SetText("Search")
    local search = CreateFrame("EditBox", Name(), picker, "InputBoxTemplate")
    search:SetAutoFocus(false) search:SetWidth(190) search:SetHeight(20) search:SetMaxLetters(40) search:SetPoint("TOPLEFT", 78, -40)
    local allName = Name()
    local all = CreateFrame("CheckButton", allName, picker, "UICheckButtonTemplate")
    all:SetPoint("TOPLEFT", 18, -62) _G[allName .. "Text"]:SetText("Show all spells")
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
                row.entry = e row.icon:SetTexture(e.icon) row.text:SetText(e.name .. (TAGS[e.kind] or "")) row:Show()
            else row.entry = nil row:Hide() end
        end
    end
    function picker.Refilter()
        local q = Trim(search:GetText()):lower()
        wipe(filtered)
        for _, e in ipairs(picker.entries or {}) do
            if (e.kind ~= "spell" or all:GetChecked() or e.helpful) and (q == "" or e.name:lower():find(q, 1, true)) then
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
        row:SetScript("OnEnter", function(self)
            local entry = self.entry
            if entry and entry.kind == "spell" and entry.index then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetSpell(entry.index, "spell")
                GameTooltip:Show()
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

local function OpenPicker(withMacros, title, callback)
    if not picker then BuildPicker() end
    EvsHL.ScanSpells()
    local entries = {}
    for _, e in ipairs(EvsHL.spells or {}) do entries[#entries + 1] = e end
    if withMacros then
        for _, m in ipairs(Macros()) do entries[#entries + 1] = m end
        for _, a in ipairs(ACTIONS) do entries[#entries + 1] = { name = a.name, icon = a.icon, kind = "action", action = a.action } end
    end
    picker.entries = entries
    picker.callback = callback
    picker.title:SetText(title)
    picker.search:SetText("")
    picker:ClearAllPoints()
    picker:SetPoint("TOPLEFT", frame, "TOPRIGHT", -4, 0)
    picker:Show()
    picker.Refilter()
    picker.search:SetFocus()
end

-- Expose to the other config files
EvsHL.ConfigHelpers = { AddCheck = AddCheck, AddSlider = AddSlider, AddButton = AddButton, AddColor = AddColor, AddDropdown = AddDropdown, OpenPicker = OpenPicker, Label = function(page, text, x, y) local fs = page:CreateFontString(nil, "OVERLAY", "GameFontNormal") fs:SetPoint("TOPLEFT", x, y) fs:SetText(text) end }

-- GENERAL TAB
local function BuildGeneral(page)
    local H = EvsHL.ConfigHelpers
    H.AddCheck(page, "Lock frame", 20, -10, "locked", Layout)
    H.AddCheck(page, "Show player", 20, -38, "showPlayer", Layout)
    H.AddCheck(page, "Hide when solo (locked only)", 20, -66, "hideSolo", Layout)
    H.AddCheck(page, "Show HoT icons", 20, -94, "showHots", Visuals)
    H.AddCheck(page, "Debuff outline", 20, -122, "debuffBorder", Visuals)
    H.AddCheck(page, "Class colored names", 20, -150, "classColor", Visuals)
    H.AddCheck(page, "Container border", 20, -178, "showBorder", Visuals)
    H.AddCheck(page, "Incoming heals", 20, -206, "showIncoming", Visuals)
    H.AddCheck(page, "Sort: tanks first, then healers", 20, -234, "sortByRole", Layout)
    H.AddCheck(page, "Unit tooltip on hover", 20, -262, "showTooltip", Visuals)
    H.AddCheck(page, "Enable Smart Cast (Dispel/Ress)", 20, -290, "smartCast", Visuals)
    --H.AddCheck(page, "Show temporary target frame", 20, -318, "showTempTarget", EvsHL.ApplyVisuals)
    H.AddCheck(page, "Show temporary target frame", 20, -318, "showTempTarget", Layout)
    
    H.AddColor(page, "Hover outline", 260, -262, "hoverColor", Visuals)

    H.Label(page, "Health text", 260, -80)
    H.AddDropdown(page, 244, -98, 120, {
        { "none", "None" }, { "max", "Max health" }, { "missing", "Missing health" }, { "current", "Current health" }, { "percent", "Percent" },
    }, function() return S.hpMode end, function(v) S.hpMode = v Visuals() end)

    H.Label(page, "Simulation", 260, -146)
    H.AddDropdown(page, 244, -164, 120, {
        { 0, "Off" }, { 5, "Party (5)" }, { 10, "Raid (10)" }, { 25, "Raid (25)" }, { 40, "Raid (40)" },
    }, function() return EvsHL.simCount or 0 end, function(v) EvsHL.SetSimulation(v) end)

    H.AddButton(page, "Reset position", 0, 0, 140, function() EvsHL.ResetPosition() end, "BOTTOMLEFT", nil, 15, 15)
    H.AddButton(page, "Reset all settings", 0, 0, 160, function() EvsHL.ResetAll() Sync() end, "BOTTOMRIGHT", nil, -15, 15)
end

local function BuildClicks(page)
    local H = EvsHL.ConfigHelpers
    local modOptions = {
        { "", "None" }, { "shift-", "Shift" }, { "ctrl-", "Ctrl" }, { "alt-", "Alt" },
        { "ctrl-shift-", "Ctrl + Shift" }, { "alt-shift-", "Alt + Shift" },
        { "alt-ctrl-", "Alt + Ctrl" }, { "alt-ctrl-shift-", "Alt + Ctrl + Shift" },
    }
    local btnLabels = { "Left", "Right", "Middle", "Button 4", "Button 5" }
    local slots = {}

    local function Load()
        for i, slot in ipairs(slots) do
            local value = S.clicks[curMod .. i]
            local icon, text, tag = Describe(value)
            if text then
                slot.icon:SetTexture(icon) slot.text:SetText(text .. (TAGS[tag] or "")) slot.text:SetTextColor(1, 1, 1) slot.clear:Show()
            else
                slot.icon:SetTexture(nil) slot.text:SetText(i == 1 and "Target (default)" or i == 2 and "Menu (default)" or "Click to choose...") slot.text:SetTextColor(0.55, 0.55, 0.55) slot.clear:Hide()
            end
        end
    end

    H.Label(page, "Modifier", 25, -16)
    H.AddDropdown(page, 85, -8, 150, modOptions, function() return curMod end, function(v) curMod = v Load() end)

    for i, text in ipairs(btnLabels) do
        local y = -52 - (i - 1) * 42
        H.Label(page, text, 25, y - 7)
        local slot = CreateFrame("Button", nil, page)
        slot:SetWidth(260) slot:SetHeight(28) slot:SetPoint("TOPLEFT", 110, y)
        slot:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        slot:SetBackdropColor(0, 0, 0, 0.6)
        slot:SetHighlightTexture(FLAT) slot:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.12)
        slot.icon = slot:CreateTexture(nil, "ARTWORK") slot.icon:SetWidth(20) slot.icon:SetHeight(20) slot.icon:SetPoint("LEFT", 5, 0)
        slot.text = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlight") slot.text:SetPoint("LEFT", slot.icon, "RIGHT", 8, 0) slot.text:SetPoint("RIGHT", -6, 0) slot.text:SetJustifyH("LEFT")
        slot:SetScript("OnClick", function()
            H.OpenPicker(true, btnLabels[i] .. " click", function(e)
                S.clicks[curMod .. i] = e.kind == "macro" and ("m:" .. e.name) or e.kind == "action" and ("a:" .. e.action) or e.name
                EvsHL.Refresh() Load()
            end)
        end)
        slot.clear = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        slot.clear:SetWidth(24) slot.clear:SetHeight(24) slot.clear:SetPoint("LEFT", slot, "RIGHT", 6, 0) slot.clear:SetText("X")
        slot.clear:SetScript("OnClick", function() S.clicks[curMod .. i] = nil EvsHL.Refresh() Load() end)
        slots[i] = slot
    end
    widgets[#widgets + 1] = Load
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
            S.hots[e.name] = true List()
        end)
    end)
    local spellInput = CreateFrame("EditBox", Name(), page, "InputBoxTemplate")
    spellInput:SetAutoFocus(false)
    spellInput:SetWidth(125)
    spellInput:SetHeight(20)
    spellInput:SetMaxLetters(80)
    spellInput:SetPoint("TOPLEFT", 178, -10)
    spellInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local function AddSpell(value)
        local query = Trim(value)
        if query == "" then return end
        local spellName = GetSpellInfo(tonumber(query) or query)
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
    end
    spellInput:SetScript("OnEnterPressed", function(self) AddSpell(self:GetText()) end)
    H.AddButton(page, "Add name/ID", 315, -8, 105, function() AddSpell(spellInput:GetText()) end)
    for i = 1, MAXROWS do
        local row = CreateFrame("Frame", nil, page)
        row:SetWidth(370) row:SetHeight(20) row:SetPoint("TOPLEFT", 25, -42 - (i - 1) * 22)
        row.icon = row:CreateTexture(nil, "ARTWORK") row.icon:SetWidth(18) row.icon:SetHeight(18) row.icon:SetPoint("LEFT", 0, 0)
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight") row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.remove:SetWidth(22) row.remove:SetHeight(20) row.remove:SetPoint("RIGHT", -5, 0) row.remove:SetText("X")
        row.remove:SetScript("OnClick", function() S.hots[row.spell] = nil List() end)
        rows[i] = row
    end
    List = function()
        local names = {}
        for n in pairs(S.hots) do names[#names + 1] = n end
        table.sort(names)
        for i, row in ipairs(rows) do
            local n = names[i]
            if n then row.spell = n row.text:SetText(n) row.icon:SetTexture(GetSpellTexture(n)) row:Show()
            else row:Hide() end
        end
    end
    widgets[#widgets + 1] = List
end

-- Replace the Select() function
local subPages, subTabs = {}, {}
local function SelectSub(index)
    for i, p in ipairs(subPages) do
        if i == index then p:Show() subTabs[i]:Disable() else p:Hide() subTabs[i]:Enable() end
    end
end

local function BuildAppearanceParent(page)
    local subBuilders = { 
        EvsHL.BuildAppGeneral, 
        EvsHL.BuildAppHealing, 
        EvsHL.BuildAppBars, 
        EvsHL.BuildAppIcons, 
        EvsHL.BuildAppIncoming 
    }
    local subLabels = { "General", "Healing", "Bars", "Icons", "inc.Heals" }
    
    for i, build in ipairs(subBuilders) do
        local tab = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        tab:SetWidth(74) tab:SetHeight(22)
        tab:SetPoint("TOPLEFT", 20 + (i - 1) * 76, -5)
        tab:SetText(subLabels[i])
        tab:SetScript("OnClick", function() SelectSub(i) end)
        subTabs[i] = tab
        
        local subPage = CreateFrame("Frame", nil, page)
        subPage:SetPoint("TOPLEFT", 0, -30)
        subPage:SetPoint("BOTTOMRIGHT", 0, 0)
        subPage:Hide()
        subPages[i] = subPage
        build(subPage)
    end
    SelectSub(1)
end

local function Select(index)
    for i, p in ipairs(pages) do
        if i == index then p:Show() tabs[i]:Disable() else p:Hide() tabs[i]:Enable() end
    end
end

local function Build()
    frame = CreateFrame("Frame", "EvsHLConfigFrame", UIParent)
    frame:SetWidth(500) frame:SetHeight(700)
    frame:SetPoint("CENTER") frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true) frame:EnableMouse(true) frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving) frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:Hide()
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16) title:SetText("HealLane")
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)
    tinsert(UISpecialFrames, "EvsHLConfigFrame")

    -- Main Tabs
    local builders = { BuildGeneral, BuildAppearanceParent, BuildClicks, BuildHots, EvsHL.BuildCureTab, EvsHL.BuildBuffsTab }
    local labels = { "General", "Appearance", "Clicks", "HoTs", "Cure", "Buffs" }
    for i, build in ipairs(builders) do
        local tab = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        tab:SetWidth(74) tab:SetHeight(24)
        tab:SetPoint("TOPLEFT", 22 + (i - 1) * 76, -44)
        tab:SetText(labels[i])
        tab:SetScript("OnClick", function() Select(i) end)
        tabs[i] = tab
        local page = CreateFrame("Frame", nil, frame)
        page:SetPoint("TOPLEFT", 10, -76) page:SetPoint("BOTTOMRIGHT", -10, 12) page:Hide()
        pages[i] = page
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
open:SetWidth(160) open:SetHeight(24) open:SetPoint("TOPLEFT", 20, -20) open:SetText("Open settings")
open:SetScript("OnClick", function() EvsHL.ToggleConfig() end)
InterfaceOptions_AddCategory(panel)