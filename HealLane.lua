local EvsHL = {}
_G.EvsHL = EvsHL

local DEFAULTS = {
    locked = false,
    showPlayer = true,
    hideSolo = false,
    showHots = true,
    debuffBorder = true,
    classColor = true,
    hpMode = "max",
    showBorder = false,
    showTooltip = false,
    hoverColor = { 1, 1, 1 },
    hotAnchor = "BOTTOMRIGHT",
    showRoleIcon = true,
    showRaidIcon = true,
    roleIconScale = 1,
    raidIconScale = 1,
    roleIconAnchor = "TOPRIGHT",
    raidTargetIconAnchor = "TOP",
    cols = 3,
    width = 125,
    height = 50,
    padding = 2,
    scale = 1,
    bgAlpha = 0.3,
    hotSize = 20,
    barAlpha = 0.85,
    barAlphaFull = 0.3,
    btnAlpha = 0.35,
    barColor = { 0.2, 0.9, 0.2 },
    healthThreshold = 95,
    thresholdColor = { 0.1, 1, 0.1 },
    showIncoming = false,
    incomingColor = { 0.3, 1, 0.5 },
    hotLookahead = 3,
    sortByRole = true,
    roleOverrides = {},
    debuffCurseColor = { 1, 0.45, 0.05 },
    debuffPoisonColor = { 0.05, 0.48, 0.12 },
    debuffDiseaseColor = { 0.62, 0.16, 0.82 },
    debuffMagicColor = { 0.65, 0.65, 0.65 },
    debuffBleedColor = { 0.9, 0.1, 0.1 },
    smartCast = true,
    clicks = {},
    hots = {},
    hotsSeen = {},
    dispel = { spells = {} },
    resSpell = "",
    trackBuffs = {},
    checkBuffsInCombat = false,
    buffsMissingColor = { 1, 0.5, 0 },
    debuffColor = { 1, 0, 0 },
    debuffIcon = true,
    buffIcon = true,
    frameAnchor = "TOPRIGHT",
    barsAnchor = "LEFT",
    showTempTarget = true,
}

local KNOWN_HOTS = {
    ["Rejuvenation"] = true,
    ["Regrowth"] = true,
    ["Lifebloom"] = true,
    ["Wild Growth"] = true,
    ["Renew"] = true,
    ["Prayer of Mending"] = true,
    ["Power Word: Shield"] = true,
    ["Riptide"] = true,
    ["Earth Shield"] = true,
    ["Beacon of Light"] = true,
    ["Sacred Shield"] = true,
}

local MAX_UNITS = 40
local MAX_HOTS = 8
local OUTER = 4
local FLAT = "Interface\\Buttons\\WHITE8x8"
local FONT = "Fonts\\FRIZQT__.TTF"
local MODS = { "", "shift-", "ctrl-", "alt-", "ctrl-shift-", "alt-shift-", "alt-ctrl-", "alt-ctrl-shift-" }
local DEBUFF_TYPE_COLORS = {
    Curse = { r = 1, g = 0.45, b = 0.05 },
    Poison = { r = 0.05, g = 0.48, b = 0.12 },
    Disease = { r = 0.62, g = 0.16, b = 0.82 },
    Magic = { r = 0.65, g = 0.65, b = 0.65 },
    Bleed = { r = 0.9, g = 0.1, b = 0.1 },
}
local DEBUFF_COLOR_KEYS = {
    Curse = "debuffCurseColor",
    Poison = "debuffPoisonColor",
    Disease = "debuffDiseaseColor",
    Magic = "debuffMagicColor",
    Bleed = "debuffBleedColor",
}

local S
local buttons = {}
local pending = false
local pendingCast
local orderSignature
local rosterRefreshRemaining
local activeCount = 0

EvsHL.defaults = DEFAULTS
EvsHL.mods = MODS
EvsHL.simCount = 0

local function Copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = Copy(x) end
    return t
end

local function Merge(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then dst[k] = Copy(v) end
    end
end

local function NumParty()
    if GetNumSubgroupMembers then return GetNumSubgroupMembers() end
    return GetNumPartyMembers()
end

local function NumRaid()
    if IsInRaid then return IsInRaid() and GetNumGroupMembers() or 0 end
    return GetNumRaidMembers()
end

local function AssignedRole(unit)
    if not UnitGroupRolesAssigned then return nil end
    local role, isHeal, isDPS = UnitGroupRolesAssigned(unit)
    if type(role) == "string" then return string.upper(role) end
    if role then return "TANK" end
    if isHeal then return "HEALER" end
    if isDPS then return "DAMAGER" end
end

local function UnitRole(unit)
    local guid = UnitGUID and UnitGUID(unit)
    local override = guid and S and S.roleOverrides and S.roleOverrides[guid]
    if override == "TANK" or override == "HEALER" then return override end
    local role = AssignedRole(unit)
    if role == "TANK" or role == "HEALER" then return role end
    return "DPS"
end

local function IsTank(unit) return UnitRole(unit) == "TANK" end
local function IsHeal(unit) return UnitRole(unit) == "HEALER" end
local function IsDPS(unit) return UnitRole(unit) == "DPS" end
-- 1 = tank, 2 = player, 3 = healer, 4 = everyone else
local function RolePriority(unit)
    if not UnitExists(unit) then return 4 end
    if IsTank(unit) then return 1 end
    if UnitIsUnit(unit, "player") then return 2 end
    if IsHeal(unit) then return 3 end
    if IsDPS(unit) then return 4 end
    return 4
end

local orderCacheDirty = true
local orderCacheKey
local cachedOrder, cachedPositions, cachedRowCount, cachedColumns

local function BuildOrder(list, raid, cols)
    local groups = { {}, {}, {}, {} }
    local tempUnit
    for _, u in ipairs(list) do
        if u == "target" then
            tempUnit = u
        elseif u == "sim" then
            groups[4][#groups[4] + 1] = u
        else
            local p = RolePriority(u)
            groups[p][#groups[p] + 1] = u
        end
    end
    if tempUnit then groups[4][#groups[4] + 1] = tempUnit end
    -- Flatten priority units in role order: tanks, player, healers
    local priority = {}
    for _, g in ipairs({ groups[1], groups[2], groups[3] }) do
        for _, u in ipairs(g) do priority[#priority + 1] = u end
    end
    local others = groups[4]

    local sorted = {}
    local positions = {}
    local rowCount
    local roleColumns = cols

    local priorityCount = #priority
    local othersCount = #others

    -- No sorting needed when there's only one unit total
    if priorityCount + othersCount <= 1 or cols <= 1 then
        for _, u in ipairs(priority) do sorted[#sorted + 1] = u end
        for _, u in ipairs(others) do sorted[#sorted + 1] = u end
        rowCount = math.max(priorityCount + othersCount, 1)
        for i = 1, #sorted do positions[i] = { row = i - 1, col = 0 } end
        return sorted, positions, rowCount, 1
    end

    -- Column 0 holds ALL priority units (tank → player → healer), top to bottom.
    -- Every other column holds DPS, stacked top to bottom.
    -- Rows = max(priority stack height, tallest DPS column).
    local dpsColumns = math.max(cols - 1, 1)
    local dpsRows = math.max(math.ceil(othersCount / dpsColumns), 1)
    rowCount = math.max(priorityCount, dpsRows)
    if rowCount < 1 then rowCount = 1 end

    -- Place priority units in column 0
    for i = 1, priorityCount do
        sorted[#sorted + 1] = priority[i]
        positions[#sorted] = { row = i - 1, col = 0 }
    end

    -- Place DPS in columns 1..dpsColumns, top-to-bottom per column
    for i = 1, othersCount do
        local col = 1 + math.floor((i - 1) / rowCount)
        -- If a DPS column would overflow the total column count, wrap safely
        if col > dpsColumns then
            col = dpsColumns
        end
        local row = (i - 1) % rowCount
        sorted[#sorted + 1] = others[i]
        positions[#sorted] = { row = row, col = col }
    end

    return sorted, positions, rowCount, dpsColumns + 1
end

-- SMART CASTING (SecureActionButton injection) --
local function SmartCast_PreClick(self, button, down)
    if not S then return end
    local unit = self.unit
    if not unit or self.sim or InCombatLockdown() then return end
    if unit == "target" and not UnitInParty(unit) and not UnitInRaid(unit) then return end

    if S.smartCast then
        -- 1. Resurrection (Dead check)
        if UnitIsDeadOrGhost(unit) and S.resSpell and S.resSpell ~= "" then
            local resName = S.resSpell
            if S.resSpell:match("^m:") then
                resName = S.resSpell:sub(3)
            elseif S.resSpell:match("^a:") then
                resName = nil
            end
            if resName and IsSpellInRange(resName, unit) == 1 then
                self:SetAttribute("type1", "spell")
                self:SetAttribute("spell1", resName)
                return
            end
        end

        -- 2. Dispel (Debuff check)
        if S.dispel and S.dispel.spells then
            for _, entry in pairs(S.dispel.spells) do
                local spellName = entry.spell
                if spellName and spellName ~= "" then
                    if spellName:match("^m:") then spellName = spellName:sub(3) end

                    -- Check if unit has a debuff matching the spell's enabled types
                    local foundMatch = false
                    for i = 1, 40 do
                        local name, _, _, _, debuffType = UnitDebuff(unit, i)
                        if not name then break end
                        if debuffType and entry.types[debuffType] then
                            foundMatch = true
                            break
                        end
                    end

                    if foundMatch and IsSpellInRange(spellName, unit) == 1 then
                        self:SetAttribute("type1", "spell")
                        self:SetAttribute("spell1", spellName)
                        return
                    end
                end
            end
        end

        -- 3. Missing Buffs
        local unitInCombat = UnitAffectingCombat and UnitAffectingCombat(unit)
        if S.trackBuffs and next(S.trackBuffs) and (S.checkBuffsInCombat or not unitInCombat) then
            local buffs = {}
            for i = 1, 40 do
                local name = UnitBuff(unit, i)
                if not name then break end
                buffs[name] = true
            end
            for buffName, active in pairs(S.trackBuffs) do
                if active and not buffs[buffName] then
                    if IsSpellInRange(buffName, unit) == 1 then
                        self:SetAttribute("type1", "spell")
                        self:SetAttribute("spell1", buffName)
                        return
                    end
                end
            end
        end
    end

    local clickSpell = self:GetAttribute("type1") == "spell" and self:GetAttribute("spell1")
    if clickSpell and IsSpellInRange(clickSpell, unit) == 0 then
        self:SetAttribute("type1", nil)
        self:SetAttribute("spell1", nil)
    end
end

local function SmartCast_PostClick(self, button, down)
    if not S or not S.smartCast then return end
    -- Restore default click bindings after the cast is sent
    local t = "target" -- default fallback
    if self.unit and not self.sim then
        -- call the default click applier with the correct state
        local function Restore()
            for _, m in ipairs(MODS) do
                for b = 1, 5 do
                    local v = S.clicks[m .. b]
                    local macro = v and v:match("^m:(.+)")
                    local action = v and v:match("^a:(.+)")
                    local tType, spell, mac = nil, nil, nil
                    if macro then
                        tType, mac = "macro", macro
                    elseif action then
                        if action ~= "target" or self.unit ~= "target" then tType = action end
                    elseif v and v ~= "" then
                        tType, spell = "spell", v
                    elseif m == "" and b == 1 then
                        if self.unit ~= "target" then tType = "target" end
                    elseif m == "" and b == 2 then
                        tType = "menu"
                    end
                    self:SetAttribute(m .. "type" .. b, tType)
                    self:SetAttribute(m .. "spell" .. b, spell)
                    self:SetAttribute(m .. "macro" .. b, mac)
                end
            end
        end
        Restore()
    end
end

local parentFrame = CreateFrame("Frame", "EvsUnitButtonFrame", UIParent)
parentFrame:SetWidth(150)
parentFrame:SetHeight(50)
parentFrame:SetPoint("CENTER")
parentFrame:SetMovable(true)
parentFrame:SetClampedToScreen(true)
parentFrame:EnableMouse(true)             -- NEW: Allows clicking the background
parentFrame:RegisterForDrag("LeftButton") -- NEW: Allows dragging

-- NEW: Drag scripts for the container
parentFrame:SetScript("OnDragStart", function(self)
    if not S or S.locked then return end
    self:StartMoving()
end)

parentFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    if S then S.pos = { p, rp, x, y } end
end)

local handle = CreateFrame("Button", nil, parentFrame)
handle:SetHeight(14)
handle:SetPoint("BOTTOMLEFT", parentFrame, "BOTTOMLEFT", OUTER, 2)
handle:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -OUTER, 2)
handle:RegisterForClicks("LeftButtonUp")
handle:RegisterForDrag("LeftButton")
local handleText = handle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
handleText:SetPoint("CENTER")
handleText:SetText("Options")
handle:SetScript("OnMouseDown", function(self) self.moved = false end)
handle:SetScript("OnDragStart", function(self)
    self.moved = true
    parentFrame:StartMoving()
end)
handle:SetScript("OnDragStop", function()
    parentFrame:StopMovingOrSizing()
    local p, _, rp, x, y = parentFrame:GetPoint()
    if S then S.pos = { p, rp, x, y } end
end)
handle:SetScript("OnClick", function(self)
    if self.moved then
        self.moved = false
        return
    end
    if EvsHL.ToggleConfig then EvsHL.ToggleConfig() end
end)

function EvsHL.ApplyPosition()
    parentFrame:ClearAllPoints()
    if S and S.pos then
        parentFrame:SetPoint(S.pos[1], UIParent, S.pos[2], S.pos[3], S.pos[4])
    else
        parentFrame:SetPoint("CENTER")
    end
end

local function PositionMarker(icon, anchor)
    if not icon then return end
    anchor = anchor or "TOP"
    local x = anchor:find("LEFT") and 2 or anchor:find("RIGHT") and -2 or 0
    local y = anchor:find("TOP") and -2 or anchor:find("BOTTOM") and 2 or 0
    icon:ClearAllPoints()
    icon:SetPoint(anchor, icon:GetParent(), anchor, x, y)
end

function EvsHL.ApplyVisuals()
    if not S then return end

    parentFrame:SetScale(S.scale)
    if S.showBorder then
        parentFrame:SetBackdrop({ bgFile = FLAT, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        parentFrame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    else
        parentFrame:SetBackdrop({ bgFile = FLAT })
    end

    parentFrame:SetBackdropColor(0, 0, 0, S.bgAlpha)
    if S.locked then handle:Hide() else handle:Show() end
    EvsHL.ver = (EvsHL.ver or 0) + 1
    if not S.showIncoming then pendingCast = nil end

    for _, btn in pairs(buttons) do
        if not S.showIncoming then
            btn.incoming = nil
            btn.incomingSpell = nil
            btn.incomingEnd = nil
            btn.incomingBar:Hide()
        end
        btn.healthBar.bg:SetVertexColor(0.08, 0.08, 0.08, S.btnAlpha)
        btn.roleIcon:SetWidth(20 * (S.roleIconScale or 1))
        btn.roleIcon:SetHeight(20 * (S.roleIconScale or 1))
        btn.raidTargetIcon:SetWidth(16 * (S.raidIconScale or 1))
        btn.raidTargetIcon:SetHeight(16 * (S.raidIconScale or 1))
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
            for _, icon in ipairs(btn.hotIcons) do icon:Hide() end
            for _, txt in ipairs(btn.hotTexts) do txt:Hide() end
        end
        if btn.debuff then
            if not S.debuffBorder then btn.debuff:Hide() end
        end
        if btn.buff then
            if not S.buffBorder then btn.buff:Hide() end
        end
    end
end

local scanTip = CreateFrame("GameTooltip", "EvsHLScanTip", nil, "GameTooltipTemplate")

local function FindSpell(name)
    for _, e in ipairs(EvsHL.spells or {}) do
        if e.name == name then return e end
    end
end

local function Tooltip(entry)
    scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    scanTip:SetSpell(entry.index, "spell")
end

local function HealAmount(spell)
    local entry = FindSpell(spell)
    if not entry or not entry.helpful then return end
    Tooltip(entry)
    for i = 2, scanTip:NumLines() do
        local fs = _G["EvsHLScanTipTextLeft" .. i]
        local text = fs and fs:GetText()
        if text and text:lower():find("heal") then
            text = text:gsub(",", "")
            local lo, hi = text:match("(%d+)%s+to%s+(%d+)")
            if lo then return (tonumber(lo) + tonumber(hi)) / 2 end
            if not text:find("over") then
                local n = text:match("(%d+)")
                if n then return tonumber(n) end
            end
        end
    end
end

local rateCache = {}
local function HotRate(spell)
    local now = GetTime()
    local c = rateCache[spell]
    if c and now - c.t < 5 then return c.rate end
    local rate = 0
    local entry = FindSpell(spell)
    if entry then
        Tooltip(entry)
        for i = 2, scanTip:NumLines() do
            local fs = _G["EvsHLScanTipTextLeft" .. i]
            local text = fs and fs:GetText()
            if text then
                text = text:gsub(",", "")
                local total, dur = text:match("(%d+)%s+over%s+(%d+%.?%d*)%s+sec")
                if total then
                    rate = tonumber(total) / tonumber(dur)
                    break
                end
            end
        end
    end
    rateCache[spell] = { rate = rate, t = now }
    return rate
end

local function Fmt(n)
    n = math.floor(n + 0.5)
    if n < 1000 then return tostring(n) end
    local k = n / 1000
    if k >= 10 then return string.format("%dk", math.floor(k + 0.5)) end
    return (string.format("%.1fk", k):gsub("%.0k", "k"))
end

local SIM_NAMES = { "Awezon", "Aldrin", "Mirelle", "Torvald", "Selene", "Brokk", "Isolde", "Garrick", "Nyx", "Orin" }
local SIM_CLASSES = { "DRUID", "PRIEST", "PALADIN", "SHAMAN", "WARRIOR", "MAGE", "ROGUE", "HUNTER", "WARLOCK",
    "DEATHKNIGHT" }
local SIM_MAX = { 1016, 850, 3400, 12400, 24000, 6200, 15800 }
local SIM_ICONS = { "Interface\\Icons\\Spell_Nature_Rejuvenation", "Interface\\Icons\\Spell_Holy_Renew",
    "Interface\\Icons\\Spell_Nature_ResistNature" }

local function SimData(btn, d)
    local i = btn.sim
    local now = GetTime()
    d.name = SIM_NAMES[(i - 1) % #SIM_NAMES + 1]
    d.class = SIM_CLASSES[(i * 3) % #SIM_CLASSES + 1]
    d.max = SIM_MAX[i % #SIM_MAX + 1]
    d.online = i ~= 7
    d.dead = i == 3
    local pct = 1
    if i % 5 ~= 1 then pct = math.min(0.4 + ((i * 37) % 55) / 100 + 0.04 * math.sin(now * 0.8 + i), 0.99) end
    d.health = math.floor(d.max * pct)
    d.debuff = (i % 6 == 2 and "Magic") or (i % 9 == 4 and "Poison") or nil
    d.missingBuff = (i % 4 == 1) -- Simulate missing buff
    d.nh = i % 4
    for k = 1, d.nh do
        local h = d.hots[k] or {}
        d.hots[k] = h
        h.duration = 12
        h.expires = now + 12 - ((now + i * 3 + k * 4) % 12)
        h.icon = SIM_ICONS[k]
        h.rate = d.max * 0.02
    end
    d.cast = (i % 3 == 0) and d.max * 0.2 or 0
end

local function RealData(btn)
    local unit = btn.unit
    local now = GetTime()
    btn.health = UnitHealth(unit)
    btn.max = UnitHealthMax(unit)
    btn.online = UnitIsConnected(unit)
    btn.dead = UnitIsDeadOrGhost(unit)
    -- DEBUFFS --
    btn.debuff = nil
    btn.debuffIconTexture = nil

    if (S.debuffBorder or S.debuffIcon) and S.dispel and S.dispel.spells then
        for i = 1, 40 do
            local name, _, icon, _, debuffType = UnitDebuff(unit, i)
            if not name then break end
            if debuffType then
                -- Check if we have a spell configured for this type
                for _, entry in pairs(S.dispel.spells) do
                    if entry.types and entry.types[debuffType] then
                        btn.debuff = debuffType
                        btn.debuffIconTexture = icon
                        break
                    end
                end
                if btn.debuff then break end
            end
        end
    end
    -- BUFFS --
    btn.missingBuff = false
    local unitInCombat = UnitAffectingCombat and UnitAffectingCombat(unit)
    if S.trackBuffs and next(S.trackBuffs) and (S.checkBuffsInCombat or not unitInCombat) then
        local buffs = {}
        for i = 1, MAX_UNITS do
            local name = UnitBuff(unit, i)
            if not name then break end
            buffs[name] = true
        end
        for buffName, active in pairs(S.trackBuffs) do
            if active and not buffs[buffName] then
                btn.missingBuff = true
                break
            end
        end
    end
    btn.nh = 0
    if S.showHots or S.showIncoming then
        for i = 1, MAX_UNITS do
            local name, _, icon, _, _, duration, expires, caster = UnitBuff(unit, i)
            if not name then break end
            if caster == "player" and S.hots[name] and btn.nh < MAX_HOTS then
                btn.nh = btn.nh + 1
                local h = btn.hots[btn.nh] or {}
                btn.hots[btn.nh] = h
                h.icon = icon
                h.duration = duration or 0
                h.expires = expires or 0
                h.rate = S.showIncoming and HotRate(name) or 0
            end
        end
    end
    btn.cast = 0
    if btn.incoming then
        if btn.incomingEnd and now > btn.incomingEnd + 0.3 then
            btn.incoming = nil
        else
            btn.cast = btn.incoming
        end
    end
end

local function PlaceIcons(btn, n)
    local a = S.hotAnchor
    local v = a:find("TOP") and "TOP" or a:find("BOTTOM") and "BOTTOM" or ""
    local h = a:find("LEFT") and "LEFT" or a:find("RIGHT") and "RIGHT" or ""
    local sz, gap = S.hotSize, 1
    local y = v == "TOP" and -2 or v == "BOTTOM" and 2 or 0
    local total = math.max(n, 1) * sz + (math.max(n, 1) - 1) * gap
    for i = 1, MAX_HOTS do
        local icon = btn.hotIcons[i]
        local step = (i - 1) * (sz + gap)
        icon:SetWidth(sz)
        icon:SetHeight(sz)
        icon:ClearAllPoints()
        if h == "LEFT" then
            icon:SetPoint(v .. "LEFT", btn, v .. "LEFT", 2 + step, y)
        elseif h == "RIGHT" then
            icon:SetPoint(v .. "RIGHT", btn, v .. "RIGHT", -2 - step, y)
        else
            icon:SetPoint(v .. "LEFT", btn, v ~= "" and v or "CENTER", -total / 2 + step, y)
        end
        btn.hotTexts[i]:SetFont(FONT, math.max(7, math.floor(sz * 0.7)), "OUTLINE")
    end
    btn.placedN = n
    btn.placedVer = EvsHL.ver
end

local function UpdateHoTs(btn, now)
    local n = S.showHots and btn.nh or 0
    for i = 1, MAX_HOTS do
        local icon, txt = btn.hotIcons[i], btn.hotTexts[i]
        if i <= n then
            local h = btn.hots[i]
            icon:SetTexture(h.icon)
            icon:Show()
            local rem = h.expires - now
            if h.duration > 0 and h.expires > 0 and rem > 0 and rem <= h.duration / 2 then
                local f = rem / (h.duration / 2)
                txt:SetTextColor(1, f, f)
                if rem >= 60 then
                    txt:SetText(math.floor(rem / 60) .. "m")
                else
                    -- FIX: Whole seconds only (4, 3, 2, 1)
                    txt:SetText(tostring(math.ceil(rem)))
                end
                txt:Show()
            else
                txt:Hide()
            end
        else
            icon:Hide()
            txt:Hide()
        end
    end
    if btn.placedN ~= n or btn.placedVer ~= EvsHL.ver then PlaceIcons(btn, n) end
end

local function HpText(btn)
    if btn.dead then return "Dead" end
    local mode = S.hpMode
    if mode == "none" then return "" end
    if not btn.online then return "Offline" end
    if mode == "max" then return Fmt(btn.max) end
    if mode == "current" then return Fmt(btn.health) end
    if mode == "percent" then return btn.max > 0 and (math.floor(btn.health / btn.max * 100 + 0.5) .. "%") or "" end
    local deficit = btn.max - btn.health
    return deficit > 0 and ("-" .. Fmt(deficit)) or ""
end

local function UpdateHealth(btn)
    local bar = btn.healthBar
    local maxHealth = btn.max and btn.max > 0 and btn.max or 1
    local health = btn.health and math.max(0, math.min(btn.health, maxHealth)) or 0
    local validHealth = btn.online and not btn.dead and btn.max and btn.max > 0
    if btn._barMax ~= maxHealth then
        btn._barMax = maxHealth
        bar:SetMinMaxValues(0, maxHealth)
    end
    bar:SetValue(validHealth and health or 0)

    local color = S.barColor
    local fullHealth = validHealth and health >= maxHealth
    if validHealth and not fullHealth then
        if btn.hasAggro then
            color = { 0.1, 1, 0.1 }
        elseif health / maxHealth < (S.healthThreshold or 95) / 100 then
            color = S.thresholdColor or { 0.1, 1, 0.1 }
        end
    end
    local alpha = validHealth and (fullHealth and S.barAlphaFull or S.barAlpha) or 0
    bar:SetStatusBarColor(color[1], color[2], color[3])
    bar.fill:SetAlpha(alpha)
    bar:Show()
    btn.hpText:SetText(HpText(btn))
    if btn.dead or S.hpMode ~= "none" then
        btn.hpText:Show()
    else
        btn.hpText:Hide()
    end
end

local function UpdateIncoming(btn, now)
    if not S.showIncoming then
        btn.incoming = nil
        btn.incomingSpell = nil
        btn.incomingEnd = nil
        btn.incomingBar:Hide()
        return
    end
    if not btn.healthBar:IsShown() or btn.max <= 0 then
        btn.incomingBar:Hide()
        return
    end
    local total = btn.cast
    for k = 1, btn.nh do
        local h = btn.hots[k]
        if h.rate > 0 and h.expires > 0 then
            local rem = h.expires - now
            if rem > 0 then total = total + h.rate * math.min(rem, S.hotLookahead) end
        end
    end
    local w = math.min(total, btn.max - btn.health) / btn.max * btn:GetWidth()
    if w < 0.5 then
        btn.incomingBar:Hide()
        return
    end
    btn.incomingBar:ClearAllPoints()
    if S.barsAnchor == "RIGHT" then
        local offset = -btn:GetWidth() * (1 - btn.health / btn.max)
        btn.incomingBar:SetPoint("TOPRIGHT", btn, "TOPRIGHT", offset, 0)
        btn.incomingBar:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", offset, 0)
    else
        local offset = btn:GetWidth() * btn.health / btn.max
        btn.incomingBar:SetPoint("TOPLEFT", btn, "TOPLEFT", offset, 0)
        btn.incomingBar:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", offset, 0)
    end
    btn.incomingBar:SetWidth(w)
    btn.incomingBar:SetVertexColor(S.incomingColor[1], S.incomingColor[2], S.incomingColor[3], 0.6)
    btn.incomingBar:Show()
end

local function UpdateName(btn)
    btn.name = UnitName(btn.unit)
    local _, class = UnitClass(btn.unit)
    btn.class = class

    if btn.shownName ~= btn.name then
        btn.shownName = btn.name
        btn.font:SetText(btn.name)
    end
    local r, g, b = 1, 1, 1
    if S.classColor then
        local c = btn.class and RAID_CLASS_COLORS[btn.class]
        if c then r, g, b = c.r, c.g, c.b end
    end
    btn.font:SetTextColor(r, g, b)
end

local function UpdateDebuff(btn)
    local foundType, foundIcon = nil, nil
    for i = 1, 40 do
        local name, _, icon, _, debuffType = UnitDebuff(btn.unit, i)
        if not name then break end
        if debuffType then
            for _, entry in pairs((S.dispel and S.dispel.spells) or {}) do
                if entry.spell and entry.spell ~= "" and entry.types and entry.types[debuffType] then
                    for _, knownSpell in ipairs(EvsHL.spells or {}) do
                        if knownSpell.name == entry.spell then
                            foundType = debuffType
                            foundIcon = icon
                            break
                        end
                    end
                    if foundType then break end
                end
            end
            if foundType then break end
        end
    end

    if foundType then
        local color = S[DEBUFF_COLOR_KEYS[foundType]]
        local fallback = DEBUFF_TYPE_COLORS[foundType] or { r = 1, g = 0, b = 0 }
        btn.healthBar.bg:SetVertexColor(color and color[1] or fallback.r, color and color[2] or fallback.g,
            color and color[3] or fallback.b, 1)
    else
        btn.healthBar.bg:SetVertexColor(0.08, 0.08, 0.08, S.btnAlpha)
    end

    if btn.debuff then
        if S.debuffBorder and foundType then
            local color = S[DEBUFF_COLOR_KEYS[foundType]]
            local fallback = DEBUFF_TYPE_COLORS[foundType] or { r = 1, g = 1, b = 1 }
            btn.debuff:SetBackdropBorderColor(color and color[1] or fallback.r, color and color[2] or fallback.g,
                color and color[3] or fallback.b, 1)
            btn.debuff:Show()
        else
            btn.debuff:Hide()
        end
    end

    if S.debuffIcon and foundIcon then
        btn.debuffIconTex:SetTexture(foundIcon)
        btn.debuffIcon:Show()
    else
        btn.debuffIcon:Hide()
    end
end

local function UpdateBuff(btn)
    if S.buffBorder and btn.missingBuff then
        local c = S.buffsMissingColor
        btn.buff:SetBackdropBorderColor(c[1], c[2], c[3], 1)
        btn.buff:Show()
    else
        btn.buff:Hide()
    end
end

local Role_Icons = {
    ["TANK"] = [[Interface\Addons\HealLane\Textures\role\1\tank.tga]],
    ["HEALER"] = [[Interface\Addons\HealLane\Textures\role\1\healer.tga]],
    ["DPS"] = [[Interface\Addons\HealLane\Textures\role\1\dps.tga]],
    ["CUSTOM"] = [[Interface\Addons\HealLane\Textures\role\1\dps.tga]],
}
local Raid_Textures = {
    [1] = [[Interface\Addons\HealLane\Textures\raid\1\star.tga]],
    [2] = [[Interface\Addons\HealLane\Textures\raid\1\circle.tga]],
    [3] = [[Interface\Addons\HealLane\Textures\raid\1\diamond.tga]],
    [4] = [[Interface\Addons\HealLane\Textures\raid\1\triangle.tga]],
    [5] = [[Interface\Addons\HealLane\Textures\raid\1\moon.tga]],
    [6] = [[Interface\Addons\HealLane\Textures\raid\1\square.tga]],
    [7] = [[Interface\Addons\HealLane\Textures\raid\1\cross.tga]],
    [8] = [[Interface\Addons\HealLane\Textures\raid\1\skull.tga]],
}
local function IsGrouped()
    return NumRaid() > 0 or NumParty() > 0
end

local function UpdateUnitRoleIcon(btn)
    if btn.sim or not btn.unit then
        btn.roleIcon:Hide()
        btn.raidTargetIcon:Hide()
        return
    end
    if not S.showRoleIcon or not IsGrouped() then
        btn.roleIcon:Hide()
        return
    end
    if btn.role then
        btn.roleIcon:Show()
        btn.roleIcon:SetTexture(Role_Icons[btn.role])
    else
        btn.roleIcon:Hide()
    end
    if btn.RaidIconIndex then
        btn.raidTargetIcon:SetTexture(Raid_Textures[btn.RaidIconIndex])
        btn.raidTargetIcon:Show()
    else
        btn.raidTargetIcon:Hide()
    end
end

local function UpdateUnitRaidIcon(btn)
    if btn.sim or not btn.unit then
        btn.roleIcon:Hide()
        btn.raidTargetIcon:Hide()
        return
    end
    if not S.showRaidIcon or not IsGrouped() then
        btn.raidTargetIcon:Hide()
        return
    end
    local icon_index = GetRaidTargetIndex(btn.unit)
    if icon_index then
        btn.raidTargetIcon:SetTexture(Raid_Textures[icon_index])
        btn.raidTargetIcon:Show()
    else
        btn.raidTargetIcon:Hide()
    end
end
local function QueueUpdateUnitRaidIcons()
    for i = 1, MAX_UNITS do
        local btn = buttons[i]
        if btn and btn:IsShown() and btn.unit then UpdateUnitRaidIcon(btn) end
    end
end
local function ThreatLevel(unit)
    if UnitThreatSituation then return UnitThreatSituation(unit) end
    if UnitDetailedThreatSituation then
        local _, status = UnitDetailedThreatSituation(unit)
        return status
    end
end
local function UpdateButton(btn)
    local now = GetTime()
    if btn.sim then SimData(btn) else RealData(btn) end
    btn.hasAggro = not btn.sim and (ThreatLevel(btn.unit) or 0) >= 3
    local inRange = true
    local rangeAlpha = 1
    if not btn.sim and not UnitIsUnit(btn.unit, "player") then
        if UnitDistanceSquared then
            local distanceSquared = UnitDistanceSquared(btn.unit)
            if distanceSquared and distanceSquared >= 10000 then
                rangeAlpha = 0.3
            elseif distanceSquared and distanceSquared >= 1600 then
                rangeAlpha = 0.5
            end
        end
        if rangeAlpha == 1 and UnitInRange then
            local unitInRange, checked = UnitInRange(btn.unit)
            if checked == true or checked == 1 then
                if unitInRange ~= true and unitInRange ~= 1 then rangeAlpha = 0.5 end
            elseif CheckInteractDistance then
                local close = CheckInteractDistance(btn.unit, 4)
                if close == false then rangeAlpha = 0.5 end
            end
        elseif rangeAlpha == 1 and CheckInteractDistance then
            local close = CheckInteractDistance(btn.unit, 4)
            if close == false then rangeAlpha = 0.5 end
        end
    end
    btn:SetAlpha(rangeAlpha)
    UpdateHealth(btn)
    UpdateIncoming(btn, now)
    UpdateHoTs(btn, now)
    UpdateDebuff(btn)
    UpdateBuff(btn)
    if btn.hasAggro then
        btn.aggro:SetBackdropBorderColor(1, 0, 0, 1)
        btn.aggro:Show()
    else
        btn.aggro:Hide()
    end
end

local function ApplyClicks(btn, blank)
    for _, m in ipairs(MODS) do
        for b = 1, 5 do
            local v = not blank and S.clicks[m .. b]
            local macro = v and v:match("^m:(.+)")
            local action = v and v:match("^a:(.+)")
            local t, spell, mac = nil, nil, nil
            if macro then
                t, mac = "macro", macro
            elseif action then
                if action ~= "target" or btn.unit ~= "target" then t = action end
            elseif v and v ~= "" then
                t, spell = "spell", v
            elseif not blank and m == "" and b == 1 then
                if btn.unit ~= "target" then t = "target" end
            elseif not blank and m == "" and b == 2 then
                t = "menu"
            end
            btn:SetAttribute(m .. "type" .. b, t)
            btn:SetAttribute(m .. "spell" .. b, spell)
            btn:SetAttribute(m .. "macro" .. b, mac)
        end
    end
end

local menuFrame = CreateFrame("Frame", "EvsHLUnitMenu", UIParent, "UIDropDownMenuTemplate")
local roleMenuFrame = CreateFrame("Frame", "EvsHLRoleMenu", UIParent, "UIDropDownMenuTemplate")

local function ShowRoleMenu(btn)
    local unit = btn.unit
    if not unit or btn.sim then return end
    local guid = UnitGUID and UnitGUID(unit)
    local manualRole = guid and S.roleOverrides and S.roleOverrides[guid]
    UIDropDownMenu_Initialize(roleMenuFrame, function(self, level)
        local tankInfo = UIDropDownMenu_CreateInfo()
        tankInfo.text = manualRole == "TANK" and "Remove tank" or "Add tank"
        tankInfo.func = function()
            if guid then
                S.roleOverrides = S.roleOverrides or {}
                if manualRole == "TANK" then
                    S.roleOverrides[guid] = nil
                else
                    S.roleOverrides[guid] = "TANK"
                end
                btn.role = UnitRole(unit)
                UpdateUnitRoleIcon(btn)
                orderCacheDirty = true
                EvsHL.Refresh()
            end
        end
        UIDropDownMenu_AddButton(tankInfo, level)

        local healerInfo = UIDropDownMenu_CreateInfo()
        healerInfo.text = manualRole == "HEALER" and "Remove heal" or "Add heal"
        healerInfo.func = function()
            if guid then
                S.roleOverrides = S.roleOverrides or {}
                if manualRole == "HEALER" then
                    S.roleOverrides[guid] = nil
                else
                    S.roleOverrides[guid] = "HEALER"
                end
                btn.role = UnitRole(unit)
                UpdateUnitRoleIcon(btn)
                orderCacheDirty = true
                EvsHL.Refresh()
            end
        end
        UIDropDownMenu_AddButton(healerInfo, level)

        local focusInfo = UIDropDownMenu_CreateInfo()
        focusInfo.text = "Set Focus"
        focusInfo.func = function()
            if InCombatLockdown() then
                DEFAULT_CHAT_FRAME:AddMessage("HealLane: Set Focus is unavailable during combat.")
            elseif FocusUnit then
                FocusUnit(unit)
            end
        end
        UIDropDownMenu_AddButton(focusInfo, level)
    end, "MENU")
    ToggleDropDownMenu(1, nil, roleMenuFrame, "cursor")
end

local function ShowUnitMenu(btn)
    local unit = btn.unit
    if not unit or btn.sim then return end
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

local function CreateUnitButton(index)
    local btn = CreateFrame("Button", "PartyHealButton" .. index, parentFrame, "HealLaneUnitButtonTemplate")
    btn:RegisterForClicks("AnyUp")
    btn:EnableMouseWheel(true)
    btn:SetScript("OnMouseWheel", function(self)
        if IsShiftKeyDown() then ShowRoleMenu(self) end
    end)
    btn.hots = { hots = {} }
    btn.menu = ShowUnitMenu

    -- Hook Secure Action Click for Smart Casting
    btn:HookScript("PreClick", SmartCast_PreClick)
    btn:HookScript("PostClick", SmartCast_PostClick)

    local incomingBar = btn.healthBar:CreateTexture(nil, "ARTWORK")
    incomingBar:SetPoint("TOPLEFT", btn.healthBar, "TOPLEFT")
    incomingBar:SetPoint("BOTTOMLEFT", btn.healthBar, "BOTTOMLEFT")
    incomingBar:SetTexture(FLAT)
    incomingBar:Hide()
    btn.incomingBar = incomingBar

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

    local debuff = CreateFrame("Frame", nil, btn)
    debuff:SetAllPoints(btn)
    debuff:SetBackdrop({ edgeFile = FLAT, edgeSize = 1 })
    debuff:Hide()
    btn.debuff = debuff

    local aggro = CreateFrame("Frame", nil, btn)
    aggro:SetAllPoints(btn)
    aggro:SetFrameLevel(btn:GetFrameLevel() + 5)
    aggro:SetBackdrop({ edgeFile = FLAT, edgeSize = 2 })
    aggro:SetBackdropBorderColor(1, 0, 0, 1)
    aggro:Hide()
    btn.aggro = aggro

    local buff = CreateFrame("Frame", nil, btn)
    buff:SetAllPoints(btn)
    buff:SetBackdrop({ edgeFile = FLAT, edgeSize = 2 })
    buff:Hide()
    btn.buff = buff

    -- Debuff Icon Top Left
    local debuffIcon = CreateFrame("Frame", nil, btn)
    debuffIcon:SetWidth(14)
    debuffIcon:SetHeight(14)
    debuffIcon:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 2, 2)
    debuffIcon:SetFrameStrata("HIGH")
    btn.debuffIconTex = debuffIcon:CreateTexture(nil, "OVERLAY")
    btn.debuffIconTex:SetAllPoints(debuffIcon)
    -- add a black background to icon so it pops
    local iconBg = debuffIcon:CreateTexture(nil, "BACKGROUND")
    iconBg:SetAllPoints(debuffIcon)
    iconBg:SetTexture(0, 0, 0, 1)
    debuffIcon:Hide()
    btn.debuffIcon = debuffIcon

    local hover = CreateFrame("Frame", nil, btn)
    hover:SetAllPoints(btn)
    hover:SetBackdrop({ edgeFile = FLAT, edgeSize = 2 })
    hover:Hide()
    btn.hover = hover

    btn.hotIcons, btn.hotTexts = {}, {}
    for i = 1, MAX_HOTS do
        local icon = btn.healthBar:CreateTexture(nil, "OVERLAY")
        icon:Hide()
        btn.hotIcons[i] = icon
        local txt = btn:CreateFontString(nil, "OVERLAY")
        txt:SetFont(FONT, 9, "OUTLINE")
        txt:SetPoint("CENTER", icon, "CENTER", 0, 0)
        txt:Hide()
        btn.hotTexts[i] = txt
    end

    btn:SetScript("OnEnter", function(self)
        local c = S and S.hoverColor or { 1, 1, 1 }
        self.hover:SetBackdropBorderColor(c[1], c[2], c[3], 1)
        self.hover:Show()
        if S and S.showTooltip and UnitFrame_OnEnter and self.unit and not self.sim then UnitFrame_OnEnter(self) end
    end)
    btn:SetScript("OnLeave", function(self)
        self.hover:Hide()
        if S and S.showTooltip and UnitFrame_OnLeave and not self.sim then UnitFrame_OnLeave(self) end
    end)
    -- Hook player button to add target when clicked out of combat
    if index == 1 then
        btn:HookScript("PostClick", function(self, button)
            if S.showTempTarget and not InCombatLockdown() and self.unit == "player" then
                if UnitExists("target") and UnitIsFriend("player", "target") then
                    -- The target frame is now open via the normal click,
                    -- this just forces it to show properly if they click their own frame
                end
            end
        end)
    end


    buttons[index] = btn
    return btn
end

function EvsHL.SetSimulation(count)
    EvsHL.simCount = count or 0
    EvsHL.Refresh()
end

function EvsHL.Refresh()
    if not S then return end
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false

    local sim = EvsHL.simCount or 0
    local raid = NumRaid() > 0
    local list = {}

    if sim > 0 then
        for i = 1, sim do list[i] = "sim" end
    elseif raid then
        for i = 1, math.min(NumRaid(), MAX_UNITS) do
            local unit = "raid" .. i
            if S.showPlayer or not UnitIsUnit(unit, "player") then list[#list + 1] = unit end
        end
    else
        if S.showPlayer then list[#list + 1] = "player" end
        for i = 1, NumParty() do list[#list + 1] = "party" .. i end
    end

    local cols = S.cols
    local roleColumns = cols
    local rolePositions, roleRowCount
    if S.showTempTarget and UnitExists("target") and UnitIsFriend("player", "target") and not UnitInParty("target") and not UnitInRaid("target") and not UnitIsUnit("target", "player") then
        list[#list + 1] = "target"
    end

    if (S.sortByRole or next(S.roleOverrides or {})) and #list > 1 then
        local key = table.concat(list, ",") .. "|" .. tostring(cols)
        if orderCacheDirty or key ~= orderCacheKey then
            cachedOrder, cachedPositions, cachedRowCount, cachedColumns = BuildOrder(list, raid, cols)
            orderCacheKey = key
            orderCacheDirty = false
        end
        list, rolePositions, roleRowCount, roleColumns = cachedOrder, cachedPositions, cachedRowCount, cachedColumns
    elseif #list > 1 then
        table.sort(list, function(a, b)
            return (UnitName(a) or a) < (UnitName(b) or b)
        end)
    end
    orderSignature = table.concat(list, ",")
    for i = 1, MAX_UNITS do
        local btn = buttons[i] or CreateUnitButton(i)
        local unit = list[i]
        if unit then
            btn:SetWidth(S.width)
            btn:SetHeight(S.height)
            btn.font:SetWidth(math.max(S.width - 4, 10))
            btn:ClearAllPoints()
            if btn._barAnchor ~= S.barsAnchor then
                btn._barAnchor = S.barsAnchor
                if btn.healthBar.SetReverseFill then
                    btn.healthBar:SetReverseFill(S.barsAnchor == "RIGHT")
                end
            end

            -- Stack tanks and healers in the first column, then place DPS in columns beside them.
            local xPos, yPos
            local rowIndex = rolePositions and rolePositions[i].row or math.floor((i - 1) / cols)
            local colIndex = rolePositions and rolePositions[i].col or ((i - 1) % cols)

            if S.frameAnchor == "TOPRIGHT" then
                xPos = -(OUTER + (S.width + S.padding) * colIndex)
                yPos = -(OUTER + (S.height + S.padding) * rowIndex)
                btn:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", xPos, yPos)
            else
                xPos = OUTER + (S.width + S.padding) * colIndex
                yPos = -(OUTER + (S.height + S.padding) * rowIndex)
                btn:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", xPos, yPos)
            end

            if unit == "sim" then
                btn.sim = i
                btn.unit = "player"
                btn:SetAttribute("unit", "player")
                ApplyClicks(btn, true)
                if btn.watched then
                    UnregisterUnitWatch(btn)
                    btn.watched = false
                end
                btn:Show()
            elseif unit == "target" then
                btn.sim = nil
                btn.unit = "target"
                btn:SetAttribute("unit", "target")
                ApplyClicks(btn)
                if btn.watched then
                    UnregisterUnitWatch(btn)
                    btn.watched = false
                end
                RegisterUnitWatch(btn)
                btn.watched = true
                btn:Show()
            else
                btn.sim = nil
                btn.unit = unit
                btn.health = UnitHealth(btn.unit)
                btn.max = UnitHealthMax(btn.unit)
                btn.dead = UnitIsDeadOrGhost(btn.unit)
                btn.online = UnitIsConnected(btn.unit)

                btn:SetAttribute("unit", unit)
                ApplyClicks(btn)
                if not btn.watched then
                    RegisterUnitWatch(btn)
                    btn.watched = true
                end

                if IsTank(unit) then
                    btn.role = "TANK"
                elseif IsHeal(unit) then
                    btn.role = "HEALER"
                else
                    btn.role = "DPS"
                end

                UpdateUnitRoleIcon(btn)
                UpdateUnitRaidIcon(btn)
                UpdateName(btn)
            end
            btn.shownName = nil
        else
            btn.sim = nil
            if btn.watched then
                UnregisterUnitWatch(btn)
                btn.watched = false
            end
            btn:Hide()
        end
    end
    activeCount = #list
    local total = math.max(#list, 1)
    local rows = math.max(roleRowCount or math.ceil(total / cols), 1)
    parentFrame:SetWidth((S.width + S.padding) * math.min(roleColumns, total) - S.padding + OUTER * 2)
    parentFrame:SetHeight((S.height + S.padding) * rows - S.padding + OUTER * 2 + (S.locked and 0 or 16))
    handleText:SetText(sim > 0 and "Options - simulation" or "Options")

    local solo = sim == 0 and not raid and NumParty() == 0
    if S.hideSolo and solo and S.locked then parentFrame:Hide() else parentFrame:Show() end

    EvsHL.ApplyVisuals()
end

function EvsHL.ResetPosition()
    if not S then return end
    S.pos = nil
    EvsHL.ApplyPosition()
end

function EvsHL.ResetAll()
    if not S then return end
    wipe(S)
    Merge(S, DEFAULTS)
    EvsHL.ApplyPosition()
    EvsHL.Refresh()
end

local lastTargetName = nil
local acc = 0
local function OnUpdate(_, elapsed)
    if not S then return end

    if rosterRefreshRemaining then
        rosterRefreshRemaining = rosterRefreshRemaining - elapsed
        if rosterRefreshRemaining <= 0 then
            rosterRefreshRemaining = nil
            EvsHL.Refresh()
        end
    end

    -- Check if target changed to force a grid refresh
    if S.showTempTarget then
        local targetName = UnitName("target")
        if targetName ~= lastTargetName then
            lastTargetName = targetName
            -- Debounce by calling Refresh slightly later if not in combat
            if not InCombatLockdown() then EvsHL.Refresh() end
        end
    end

    acc = acc + elapsed
    if acc < (activeCount > 5 and 0.2 or 0.1) then return end
    acc = 0
    for i = 1, MAX_UNITS do
        local btn = buttons[i]
        if btn and btn:IsShown() and btn.unit then UpdateButton(btn) end
    end
end

local GetBookName = GetSpellBookItemName or GetSpellName

function EvsHL.ScanSpells()
    local list, seen = {}, {}
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, num = GetSpellTabInfo(tab)
        for i = offset + 1, offset + num do
            local name = GetBookName(i, "spell")
            if name and not IsPassiveSpell(i, "spell") then
                local entry = seen[name]
                if entry then
                    entry.index = i
                else
                    entry = {
                        name = name,
                        icon = GetSpellTexture(i, "spell"),
                        helpful = IsHelpfulSpell(i, "spell") and
                            true or false,
                        kind = "spell",
                        index = i
                    }
                    seen[name] = entry
                    list[#list + 1] = entry
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    EvsHL.spells = list
    if S then
        for name in pairs(seen) do
            if KNOWN_HOTS[name] and not S.hotsSeen[name] then
                S.hotsSeen[name] = true
                S.hots[name] = true
            end
        end
    end
    if EvsHL.SyncConfig then EvsHL.SyncConfig() end
end

local function ClearIncoming(spell)
    for _, btn in pairs(buttons) do
        if not spell or btn.incomingSpell == spell then
            btn.incoming = nil
            btn.incomingSpell = nil
            btn.incomingEnd = nil
        end
    end
end

local function StartIncoming(spell)
    if not S then return end
    if not S.showIncoming then return end
    if not pendingCast or pendingCast.spell ~= spell then return end
    local amount = HealAmount(spell)
    if not amount then return end
    local _, _, _, _, _, endTime = UnitCastingInfo("player")
    local target = pendingCast.target
    if not target or target == "" then return end
    local matchedButton
    for _, btn in pairs(buttons) do
        if btn.unit and not btn.sim then
            if UnitExists(target) and UnitIsUnit(btn.unit, target) then
                matchedButton = btn
                break
            end
        end
    end

    if not matchedButton then
        local nameMatches = {}
        for _, btn in pairs(buttons) do
            if btn.unit and not btn.sim then
                local name, realm = UnitName(btn.unit)
                local fullName = realm and realm ~= "" and (name .. "-" .. realm) or name
                if target == fullName then
                    matchedButton = btn
                    break
                elseif target == name then
                    nameMatches[#nameMatches + 1] = btn
                end
            end
        end
        if not matchedButton and #nameMatches == 1 then
            matchedButton = nameMatches[1]
        end
    end

    if matchedButton then
        matchedButton.incoming = amount
        matchedButton.incomingSpell = spell
        matchedButton.incomingEnd = endTime and endTime / 1000
    end
    pendingCast = nil
end

local function Init()
    EVS_SetingsHealCharacter = EVS_SetingsHealCharacter or {}
    S = EVS_SetingsHealCharacter
    local old = S.ver or 0
    if old < 3 and not S.hpMode then S.hpMode = S.healthText == false and "none" or "max" end
    S.healthText = nil
    Merge(S, DEFAULTS)
    for _, key in ipairs({ "debuffCurseColor", "debuffPoisonColor", "debuffDiseaseColor", "debuffMagicColor", "debuffBleedColor" }) do
        if type(S[key]) ~= "table" then
            S[key] = Copy(DEFAULTS[key])
        else
            for i = 1, 3 do
                if S[key][i] == nil then S[key][i] = DEFAULTS[key][i] end
            end
        end
    end
    EvsHL.S = S
    EvsHL.ApplyPosition()
end
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

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
local roleClearEvents = {
    GROUP_ROSTER_UPDATE = true,
    PARTY_MEMBERS_CHANGED = true,
    RAID_ROSTER_UPDATE = true,
    PLAYER_ENTERING_WORLD = true,
}
local rosterRefreshEvents = {
    GROUP_ROSTER_UPDATE = true,
    PARTY_MEMBERS_CHANGED = true,
    RAID_ROSTER_UPDATE = true,
    PLAYER_ENTERING_WORLD = true,
    LFG_ROLE_CHECK_ROLE_CHOSEN = true,
    LFG_PROPOSAL_UPDATE = true,
    LFG_PROPOSAL_SUCCEEDED = true,
    ROLE_CHANGED_INFORM = true,
    PLAYER_ROLES_ASSIGNED = true,
}
for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
    "ZONE_CHANGED_NEW_AREA", "LFG_UPDATE", "LFG_ROLE_CHECK_SHOW", "LFG_ROLE_CHECK_HIDE", "LFG_ROLE_CHECK_ROLE_CHOSEN",
    "LFG_PROPOSAL_SHOW", "PLAYER_ROLES_ASSIGNED", "LFG_PROPOSAL_UPDATE", "LFG_PROPOSAL_SUCCEEDED", "ROLE_CHANGED_INFORM",
    "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB",
    "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED", "RAID_TARGET_UPDATE" }) do
    pcall(frame.RegisterEvent, frame, e)
end
frame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4)
    if event == "ADDON_LOADED" then
        if arg1 == "HealLane" then Init() end
        
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending then EvsHL.Refresh() end
    elseif event == "UNIT_SPELLCAST_SENT" then
        if not S.showIncoming then return end
        if arg1 == "player" then
            pendingCast = { spell = arg2, target = arg4 }
        else
            pendingCast = nil
        end
    elseif event == "UNIT_SPELLCAST_START" then
        if not S.showIncoming then return end
        if arg1 == "player" then StartIncoming(arg2) end
    elseif event == "UNIT_SPELLCAST_DELAYED" then
        if not S.showIncoming then return end
        if arg1 == "player" then
            local _, _, _, _, _, endTime = UnitCastingInfo("player")
            for _, btn in pairs(buttons) do
                if btn.incomingSpell == arg2 and endTime then btn.incomingEnd = endTime / 1000 end
            end
        end
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        if not S.showIncoming then return end
        if arg1 == "player" then
            ClearIncoming(arg2)
            pendingCast = nil
        end
    elseif event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" then
        if S then EvsHL.ScanSpells() end
    elseif event == "RAID_TARGET_UPDATE" then
        QueueUpdateUnitRaidIcons()
    else
        if rosterRefreshEvents[event] or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS"
            or event == "ZONE_CHANGED_NEW_AREA" then
            orderCacheDirty = true
        end
        if S and roleClearEvents[event] and NumRaid() == 0 and NumParty() == 0 then
            S.roleOverrides = {}
        end
        if event == "PLAYER_ENTERING_WORLD" and S then EvsHL.ScanSpells() end
        if rosterRefreshEvents[event] then
            rosterRefreshRemaining = 0.3
        else
            EvsHL.Refresh()
        end
    end
end)
frame:SetScript("OnUpdate", OnUpdate)
