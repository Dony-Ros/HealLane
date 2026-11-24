-- Parent frame, drag handle, unit button creation, and visuals application.
local EvsHL = EvsHL
-- ============================================================
-- Parent frame + drag handle
-- ============================================================
local parentFrame = EvsHL.CreateBackdropFrame("Frame", "EvsUnitButtonFrame", UIParent)
parentFrame:SetWidth(150)
parentFrame:SetHeight(50)
parentFrame:SetPoint("CENTER")
parentFrame:SetMovable(true)
parentFrame:SetClampedToScreen(true)
parentFrame:EnableMouse(true)
parentFrame:RegisterForDrag("LeftButton")
EvsHL.parentFrame = parentFrame
parentFrame:SetScript("OnDragStart", function(self)
    local S = EvsHL.S
    if not S or S.locked then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        return
    end
    self:StartMoving()
end)
parentFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    local S = EvsHL.S
    if S then
        S.pos = {p, rp, x, y}
    end
end)
local handle = CreateFrame("Button", nil, parentFrame)
handle:SetHeight(14)
handle:SetPoint("BOTTOMLEFT", parentFrame, "BOTTOMLEFT", EvsHL.OUTER, 2)
handle:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -EvsHL.OUTER, 2)
handle:RegisterForClicks("LeftButtonUp")
handle:RegisterForDrag("LeftButton")
local handleText = handle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
handleText:SetPoint("CENTER")
handleText:SetText("Options")
EvsHL.handleText = handleText
handle:SetScript("OnMouseDown", function(self)
    self.moved = false
end)
handle:SetScript("OnDragStart", function(self)
    if InCombatLockdown and InCombatLockdown() then
        return
    end
    self.moved = true
    parentFrame:StartMoving()
end)
handle:SetScript("OnDragStop", function()
    parentFrame:StopMovingOrSizing()
    local p, _, rp, x, y = parentFrame:GetPoint()
    local S = EvsHL.S
    if S then
        S.pos = {p, rp, x, y}
    end
end)
handle:SetScript("OnClick", function(self)
    if self.moved then
        self.moved = false
        return
    end
    if EvsHL.ToggleConfig then
        EvsHL.ToggleConfig()
    end
end)
function EvsHL.ApplyPosition()
    local S = EvsHL.S
    parentFrame:ClearAllPoints()
    if S and S.pos then
        parentFrame:SetPoint(S.pos[1], UIParent, S.pos[2], S.pos[3], S.pos[4])
    else
        parentFrame:SetPoint("CENTER")
    end
end
-- ============================================================
-- ApplyVisuals
-- ============================================================
local function PositionMarker(icon, anchor)
    if not icon then
        return
    end
    anchor = anchor or "TOP"
    local x = anchor:find("LEFT") and 2 or anchor:find("RIGHT") and -2 or 0
    local y = anchor:find("TOP") and -2 or anchor:find("BOTTOM") and 2 or 0
    icon:ClearAllPoints()
    icon:SetPoint(anchor, icon:GetParent(), anchor, x, y)
end
local function LayoutResourceBar(btn, S)
    local bar = btn.resourceBar
    if not bar then
        return
    end
    local anchor = S.resourceBarAnchor or "BOTTOM"
    local width = (btn:GetWidth() - 4) * (S.resourceBarWidth or 100) / 100
    bar:ClearAllPoints()
    bar:SetWidth(math.max(1, width))
    bar:SetHeight(S.resourceBarHeight or 4)
    bar:SetPoint(anchor, btn, anchor, S.resourceBarOffsetX or 0, S.resourceBarOffsetY or 2)
end
local function ApplyTextFont(fontString, font, size, flags, shadow)
    fontString:SetFont(font, size, flags)
    fontString:SetShadowColor(0, 0, 0, shadow and 1 or 0)
    if shadow then
        fontString:SetShadowOffset(1, -1)
    else
        fontString:SetShadowOffset(0, 0)
    end
end
function EvsHL.ApplyVisuals()
    local S = EvsHL.S
    if not S then
        return
    end
    if InCombatLockdown() then
        return
    end
    if EvsHL.PrepareHotPredictions then
        EvsHL.PrepareHotPredictions()
    end
    EvsHL.RefreshNativeAuraFrames()
    EvsHL.healthAlphaCurve = nil
    EvsHL.healthColorCurves = nil
    if C_CurveUtil and C_CurveUtil.CreateCurve and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Linear then
        local curve = C_CurveUtil.CreateCurve()
        curve:SetType(Enum.LuaCurveType.Linear)
        curve:AddPoint(0, S.barAlpha)
        curve:AddPoint(1, S.barAlphaFull)
        EvsHL.healthAlphaCurve = curve
        if S.lowHealthColor then
            local colors = {S.thresholdColor or EvsHL.DEFAULTS.thresholdColor, S.barColor or EvsHL.DEFAULTS.barColor}
            EvsHL.healthColorCurves = {}
            for channel = 1, 3 do
                local colorCurve = C_CurveUtil.CreateCurve()
                colorCurve:SetType(Enum.LuaCurveType.Linear)
                colorCurve:AddPoint(0, colors[1][channel])
                colorCurve:AddPoint(1, colors[2][channel])
                EvsHL.healthColorCurves[channel] = colorCurve
            end
        end
    end
    parentFrame:SetScale(S.scale)
    if S.showBorder then
        parentFrame:SetBackdrop({
            bgFile = EvsHL.FLAT,
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = {
                left = 3,
                right = 3,
                top = 3,
                bottom = 3
            }
        })
        parentFrame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    else
        parentFrame:SetBackdrop({
            bgFile = EvsHL.FLAT
        })
    end
    parentFrame:SetBackdropColor(0, 0, 0, S.bgAlpha)
    if S.locked then
        handle:Hide()
    else
        handle:Show()
    end
    EvsHL.ver = (EvsHL.ver or 0) + 1
    if not S.showIncoming then
        EvsHL.pendingCast = nil
    end
    local fontSize = tonumber(S.fontSize) or EvsHL.DEFAULTS.fontSize
    local font = S.fontFace or EvsHL.DEFAULTS.fontFace
    local fontFlags = S.fontOutline or EvsHL.DEFAULTS.fontOutline
    if S.fontMonochrome then
        fontFlags = fontFlags ~= "" and (fontFlags .. ",MONOCHROME") or "MONOCHROME"
    end
    if fontFlags == "" then fontFlags = nil end
    for _, btn in pairs(EvsHL.buttons) do
        ApplyTextFont(btn.font, font, fontSize, fontFlags, S.fontShadow)
        ApplyTextFont(btn.hpText, font, fontSize, fontFlags, S.fontShadow)
        if not S.showIncoming then
            btn.incoming = nil
            btn.incomingSpell = nil
            btn.incomingEnd = nil
        end
        btn.healthBar.bg:SetVertexColor(0.08, 0.08, 0.08, S.btnAlpha)
        EvsHL.LayoutHealPrediction(btn)
        LayoutResourceBar(btn, S)
        btn.roleIcon:SetWidth(20 * (S.roleIconScale or 1))
        btn.roleIcon:SetHeight(20 * (S.roleIconScale or 1))
        btn.raidTargetIcon:SetWidth(16 * (S.raidIconScale or 1))
        btn.raidTargetIcon:SetHeight(16 * (S.raidIconScale or 1))
        btn.debuffIcon:ClearAllPoints()
        btn.debuffIcon:SetPoint(S.debuffIconAnchor or "BOTTOMLEFT", btn, S.debuffIconAnchor or "BOTTOMLEFT", 0, 0)
        PositionMarker(btn.roleIcon, S.roleIconAnchor or "TOPRIGHT")
        PositionMarker(btn.raidTargetIcon, S.raidTargetIconAnchor or "TOP")
        btn.font:ClearAllPoints()
        btn.hpText:ClearAllPoints()
        if S.hpMode ~= "none" then
            btn.font:SetPoint("CENTER", btn, "CENTER", 0, 5)
            btn.hpText:SetPoint("CENTER", btn, "CENTER", 0, -6)
            btn.hpText:Show()
        else
            btn.font:SetPoint("CENTER", btn, "CENTER", 0, 0)
            btn.hpText:Hide()
        end
        if not S.showHots then
            for _, icon in ipairs(btn.hotIcons) do
                icon:Hide()
            end
            for _, txt in ipairs(btn.hotTexts) do
                txt:Hide()
            end
        end
        if not S.debuffBorder then
            btn.debuffBorder:Hide()
        end
        if btn.buff then
            if not S.buffBorder then
                btn.buff:Hide()
            end
        end
    end
end
-- ============================================================
-- Unit menu (right-click)
-- ============================================================
local menuFrame = CreateFrame("Frame", "EvsHLUnitMenu", UIParent, "UIDropDownMenuTemplate")
local function ShowUnitMenu(btn)
    local unit = btn.unit
    if not unit or btn.sim then
        return
    end
    local which
    if UnitIsUnit(unit, "player") then
        which = "SELF"
    elseif UnitIsUnit(unit, "pet") then
        which = "PET"
    elseif UnitIsPlayer(unit) then
        if UnitInRaid(unit) then
            which = "RAID_PLAYER"
        elseif UnitInParty(unit) then
            which = "PARTY"
        else
            which = "PLAYER"
        end
    else
        which = "TARGET"
    end
    local name = UnitName(unit)
    UIDropDownMenu_Initialize(menuFrame, function(self)
        UnitPopup_ShowMenu(self, which, unit, name)
    end, "MENU")
    ToggleDropDownMenu(1, nil, menuFrame, "cursor")
end
EvsHL.ShowUnitMenu = ShowUnitMenu
-- ============================================================
-- Unit button creation
-- ============================================================
local function UpdateTargetOutline(btn)
    if not btn or not btn.hover then return end
    local S = EvsHL.S
    local color = S and S.hoverColor or { 1, 1, 1 }
    btn.hover:SetBackdropBorderColor(color[1], color[2], color[3], 1)
    local isTarget = not btn.sim and btn.unit and UnitExists("target")
        and UnitIsUnit(btn.unit, "target")
    if btn.mouseHovered or isTarget then
        btn.hover:Show()
    else
        btn.hover:Hide()
    end
end
EvsHL.UpdateTargetOutline = function()
    for _, btn in pairs(EvsHL.buttons) do
        UpdateTargetOutline(btn)
    end
end
function EvsHL.CreateUnitButton(index)
    local btn = CreateFrame("Button", "PartyHealButton" .. index, parentFrame, "HealLaneUnitButtonTemplate")
    btn:SetAttribute("useOnKeyDown", false)
    btn:RegisterForClicks("AnyUp")
    btn:EnableMouseWheel(true)
    btn:SetScript("OnMouseWheel", function(self, delta)
        local slot = delta > 0 and 6 or delta < 0 and 7
        if slot and EvsHL.IsRoleMenuBinding(slot) then
            EvsHL.ShowRoleMenu(self)
        end
    end)
    btn.hots = {}
    btn.menu = ShowUnitMenu
    -- Hook Secure Action Click for Smart Casting
    btn:HookScript("PreClick", EvsHL.SmartCast_PreClick)
    btn:HookScript("PostClick", EvsHL.SmartCast_PostClick)
    btn:HookScript("PostClick", function(self, button)
        if EvsHL.IsRoleMenuClick(button) then
            EvsHL.ShowRoleMenu(self)
        end
    end)
    local predClip = CreateFrame("Frame", nil, btn)
    predClip:SetAllPoints(btn.healthBar)
    predClip:SetFrameLevel(btn.healthBar:GetFrameLevel() + 1)
    predClip:SetClipsChildren(true)
    predClip:EnableMouse(false)
    local pred = CreateFrame("StatusBar", nil, predClip)
    pred:SetFrameLevel(predClip:GetFrameLevel() + 1)
    pred:SetStatusBarTexture(EvsHL.FLAT)
    pred:SetMinMaxValues(0, 1)
    pred:SetValue(0)
    pred:Hide()
    btn.healPredClip = predClip
    btn.healPred = pred
    btn.roleIcon = btn.healthBar:CreateTexture(nil, "OVERLAY")
    btn.roleIcon:SetWidth(20)
    btn.roleIcon:SetHeight(20)
    btn.roleIcon:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -2, -2)
    btn.roleIcon:Hide()
    btn.raidTargetIcon = btn.healthBar:CreateTexture(nil, "OVERLAY")
    btn.raidTargetIcon:SetWidth(16)
    btn.raidTargetIcon:SetHeight(16)
    btn.raidTargetIcon:SetPoint("TOP", btn, "TOP", 0, -1)
    btn.raidTargetIcon:Hide()
    local resourceBar = CreateFrame("StatusBar", nil, btn)
    resourceBar:SetFrameLevel(btn.healthBar:GetFrameLevel() + 4)
    resourceBar:SetStatusBarTexture(EvsHL.FLAT)
    resourceBar:SetMinMaxValues(0, 1)
    resourceBar:SetValue(0)
    resourceBar.background = resourceBar:CreateTexture(nil, "BACKGROUND")
    resourceBar.background:SetAllPoints(resourceBar)
    resourceBar.background:SetTexture(EvsHL.FLAT)
    resourceBar.background:SetVertexColor(0, 0, 0, 0.85)
    resourceBar:Hide()
    btn.resourceBar = resourceBar
    LayoutResourceBar(btn, EvsHL.S or EvsHL.DEFAULTS)
    local textLayer = CreateFrame("Frame", nil, btn)
    textLayer:SetAllPoints(btn)
    textLayer:SetFrameLevel(btn:GetFrameLevel() + 20)
    textLayer:EnableMouse(false)
    btn.textLayer = textLayer
    for _, region in ipairs({btn.font, btn.hpText, btn.roleIcon, btn.raidTargetIcon}) do
        region:SetParent(textLayer)
        if region.SetShadowOffset then
            region:SetShadowOffset(1, -1)
        end
    end
    local debuff = EvsHL.CreateBackdropFrame("Frame", nil, btn)
    debuff:SetAllPoints(btn)
    debuff:SetBackdrop({
        edgeFile = EvsHL.FLAT,
        edgeSize = 1
    })
    debuff:Hide()
    btn.debuffBorder = debuff
    local aggro = EvsHL.CreateBackdropFrame("Frame", nil, btn)
    aggro:SetAllPoints(btn)
    aggro:SetFrameLevel(btn:GetFrameLevel() + 5)
    aggro:SetBackdrop({
        edgeFile = EvsHL.FLAT,
        edgeSize = 2
    })
    aggro:SetBackdropBorderColor(1, 0, 0, 1)
    aggro:Hide()
    btn.aggro = aggro
    local buff = EvsHL.CreateBackdropFrame("Frame", nil, btn)
    buff:SetAllPoints(btn)
    buff:SetFrameLevel(btn:GetFrameLevel() + 10)
    buff:EnableMouse(false)
    buff:SetBackdrop({
        edgeFile = EvsHL.FLAT,
        edgeSize = 2
    })
    buff:Hide()
    btn.buff = buff
    local debuffIcon = CreateFrame("Frame", nil, btn)
    debuffIcon:SetWidth(14)
    debuffIcon:SetHeight(14)
    debuffIcon:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    debuffIcon:SetFrameStrata("HIGH")
    btn.debuffIconTex = debuffIcon:CreateTexture(nil, "OVERLAY")
    btn.debuffIconTex:SetAllPoints(debuffIcon)
    local iconBg = debuffIcon:CreateTexture(nil, "BACKGROUND")
    iconBg:SetAllPoints(debuffIcon)
    EvsHL.SetTextureColor(iconBg, 0, 0, 0, 1)
    debuffIcon:Hide()
    btn.debuffIcon = debuffIcon
    local hover = EvsHL.CreateBackdropFrame("Frame", nil, btn)
    hover:SetAllPoints(btn)
    hover:SetBackdrop({
        edgeFile = EvsHL.FLAT,
        edgeSize = 2
    })
    hover:Hide()
    btn.hover = hover
    btn.hotIcons, btn.hotTexts = {}, {}
    for i = 1, EvsHL.MAX_HOTS do
        local icon = btn.healthBar:CreateTexture(nil, "OVERLAY")
        icon:Hide()
        btn.hotIcons[i] = icon
        local txt = btn:CreateFontString(nil, "OVERLAY")
        txt:SetFont(EvsHL.FONT, 9, "OUTLINE")
        txt:SetPoint("CENTER", icon, "CENTER", 0, 0)
        txt:Hide()
        btn.hotTexts[i] = txt
    end
    btn:SetScript("OnEnter", function(self)
        self.mouseHovered = true
        UpdateTargetOutline(self)
        local S = EvsHL.S
        if S and S.showTooltip and UnitFrame_OnEnter and self.unit and not self.sim then
            UnitFrame_OnEnter(self)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        self.mouseHovered = false
        UpdateTargetOutline(self)
        local S = EvsHL.S
        if S and S.showTooltip and UnitFrame_OnLeave and not self.sim then
            UnitFrame_OnLeave(self)
        end
    end)
    if index == 1 then
        btn:HookScript("PostClick", function(self, button)
            local S = EvsHL.S
            if S.showTempTarget and not InCombatLockdown() and self.unit == "player" then
                if UnitExists("target") and UnitIsFriend("player", "target") then
                    -- hook kept for parity; no-op
                end
            end
        end)
    end
    EvsHL.buttons[index] = btn
    return btn
end
-- Called from the XML OnLoad of HealLaneUnitButtonTemplate
function HealLane_UnitButton_OnLoad(self)
    local name = self:GetName()
    self.healthBar = _G[name .. "HealthBar"]
    assert(self.healthBar, "HealLane unit button is missing its HealthBar template region")
    self.healthBar.bg = _G[name .. "HealthBarBg"]
    assert(self.healthBar.bg, "HealLane health bar is missing its background texture")
    self.healthBar.fill = self.healthBar:GetStatusBarTexture()
    assert(self.healthBar.fill, "HealLane health bar is missing its status texture")
    self.font = _G[name .. "HealthBarName"]
    assert(self.font, "HealLane unit button is missing its name font string")
    self.hpText = _G[name .. "HealthBarHp"]
    assert(self.hpText, "HealLane unit button is missing its health font string")
end
