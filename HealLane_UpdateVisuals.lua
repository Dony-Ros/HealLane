-- ============================================================
-- HealLane_UpdateVisuals.lua
-- Handles updating the visual elements of a unit button.
-- ============================================================
local EvsHL = EvsHL

local function PlaceIcons(btn, n)
    local S = EvsHL.S
    local a = S.hotAnchor
    local v = a:find("TOP") and "TOP" or a:find("BOTTOM") and "BOTTOM" or ""
    local h = a:find("LEFT") and "LEFT" or a:find("RIGHT") and "RIGHT" or ""
    local sz, gap = S.hotSize, 1
    local y = v == "TOP" and -1 or v == "BOTTOM" and 1 or 0
    local total = math.max(n, 1) * sz + (math.max(n, 1) - 1) * gap
    for i = 1, EvsHL.MAX_HOTS do
        local icon = btn.hotIcons[i]
        local step = (i - 1) * (sz + gap)
        icon:SetWidth(sz)
        icon:SetHeight(sz)
        icon:ClearAllPoints()
        if h == "LEFT" then
            icon:SetPoint(v .. "LEFT", btn, v .. "LEFT", step, y)
        elseif h == "RIGHT" then
            icon:SetPoint(v .. "RIGHT", btn, v .. "RIGHT", -step, y)
        else
            icon:SetPoint(v .. "LEFT", btn, v ~= "" and v or "CENTER", -total / 2 + step, y)
        end
        btn.hotTexts[i]:SetFont(EvsHL.FONT, math.max(7, math.floor(sz * 0.7)), "OUTLINE")
    end
    btn.placedN = n
    btn.placedVer = EvsHL.ver
end

function EvsHL.UpdateHoTs(btn, now)
    local S = EvsHL.S
    if btn.nativeAurasActive and not btn.sim then
        for i = 1, EvsHL.MAX_HOTS do
            btn.hotIcons[i]:Hide()
            btn.hotTexts[i]:Hide()
        end
        return
    end

    local n = S.showHots and btn.nh or 0
    for i = 1, EvsHL.MAX_HOTS do
        local icon, txt = btn.hotIcons[i], btn.hotTexts[i]
        if i <= n then
            local h = btn.hots[i]
            icon:SetTexture(h.icon)
            icon:Show()

            local rem = h.expires - now
            if h.duration > 0 and h.expires > 0 and rem > 0 then
                if rem >= 60 then
                    txt:SetText(math.floor(rem / 60) .. "m")
                else
                    txt:SetText(tostring(math.ceil(rem)))
                end
                local g = math.min(1, math.max(0, (rem - 1) / 4))
                txt:SetTextColor(1, g, 0)
                txt:Show()
            else
                txt:Hide()
            end
        else
            icon:Hide()
            txt:Hide()
        end
    end
    if btn.placedN ~= n or btn.placedVer ~= EvsHL.ver then
        PlaceIcons(btn, n)
    end
end

-- ============================================================
-- HEALTH TEXT (Ported from DF:ApplyHealthText)
-- ============================================================
function EvsHL.ApplyHealthText(btn)
    local S = EvsHL.S
    local fs = btn.hpText
    local mode = S.hpMode or "none"

    if mode == "none" or btn.dead or not btn.online then
        fs:Hide()
        return
    end

    local unit = btn.unit
    local abbreviate = S.healthTextAbbreviate and AbbreviateNumbers

    if mode == "percent" then
        local pct = UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)
        if pct then
            -- SetFormattedText handles secret values safely on the C-side
            fs:SetFormattedText("%.0f%%", pct)
        else
            fs:SetText("")
        end

    elseif mode == "current" then
        local curr = UnitHealth(unit, true)
        if curr then
            if abbreviate then
                fs:SetText(AbbreviateNumbers(curr))
            else
                fs:SetFormattedText("%s", curr)
            end
        else
            fs:SetText("")
        end

    elseif mode == "missing" then
        local deficit = UnitHealthMissing(unit, true)
        if deficit then
            if abbreviate then
                fs:SetFormattedText("-%s", AbbreviateNumbers(deficit))
            else
                fs:SetFormattedText("-%s", deficit)
            end
        else
            fs:SetText("")
        end

    elseif mode == "max" then
        local maxHp = UnitHealthMax(unit, true)
        if maxHp then
            if abbreviate then
                fs:SetText(AbbreviateNumbers(maxHp))
            else
                fs:SetFormattedText("%s", maxHp)
            end
        else
            fs:SetText("")
        end
    end

    fs:Show()
end

-- ============================================================
-- HEALTH BAR SUB-MODULES
-- ============================================================

local function UpdateHealthSimulation(btn)
    local S = EvsHL.S
    local bar = btn.healthBar
    local maxHealth = btn.max or 1
    local healthVal = btn.health or 0
    local fullHealth = healthVal >= maxHealth

    if btn._barMax ~= maxHealth then
        btn._barMax = maxHealth
        bar:SetMinMaxValues(0, maxHealth)
    end
    bar:SetValue(healthVal)

    local lowHealth = S.lowHealthColor and not fullHealth
    local debuffColor = btn.debuff ~= "Unknown" and btn.debuffColor or nil
    local aggro = btn.simAggro or not fullHealth
    local bright = aggro or debuffColor ~= nil or lowHealth

    local color
    if debuffColor then
        color = debuffColor
    elseif bright then
        color = S.thresholdColor or EvsHL.DEFAULTS.thresholdColor
    else
        color = S.barColor
    end

    local alpha = bright and S.barAlpha or S.barAlphaFull
    bar:SetStatusBarColor(color[1], color[2], color[3])
    bar.fill:SetAlpha(alpha)
    bar:Show()

    EvsHL.ApplyHealthText(btn)
end

-- ============================================================
-- MAIN UPDATE HEALTH
-- ============================================================
-- Build the health color curve once (colors depend on settings)
local function EnsureHealthColorCurve()
    local S = EvsHL.S
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and Enum and Enum.LuaCurveType) then
        return nil
    end

    local bright = S.thresholdColor or EvsHL.DEFAULTS.thresholdColor
    local dark = S.barColor or EvsHL.DEFAULTS.barColor
    local brightAlpha = S.barAlpha
    local darkAlpha = S.barAlphaFull

    local c = EvsHL._healthColorCurveCache
    if c and c.bright[1] == bright[1] and c.bright[2] == bright[2] and c.bright[3] == bright[3] and c.dark[1] == dark[1] and
        c.dark[2] == dark[2] and c.dark[3] == dark[3] and c.brightAlpha == brightAlpha and c.darkAlpha == darkAlpha then
        return c.curve
    end

    local curve = C_CurveUtil.CreateColorCurve()
    curve:SetType(Enum.LuaCurveType.Linear)
    curve:AddPoint(0, CreateColor(bright[1], bright[2], bright[3], brightAlpha))
    curve:AddPoint(0.995, CreateColor(bright[1], bright[2], bright[3], brightAlpha))
    curve:AddPoint(1, CreateColor(dark[1], dark[2], dark[3], darkAlpha))

    EvsHL._healthColorCurveCache = {
        bright = {bright[1], bright[2], bright[3]},
        dark = {dark[1], dark[2], dark[3]},
        brightAlpha = brightAlpha,
        darkAlpha = darkAlpha,
        curve = curve
    }
    return curve
end

local function HasThreat(btn, unit)
    if btn.hasAggro then
        return true
    end
    if not UnitThreatSituation then
        return false
    end
    local ok, status = pcall(UnitThreatSituation, unit)
    if not ok or status == nil then
        return false
    end
    if issecretvalue and issecretvalue(status) then
        return false
    end
    return status > 0
end

function EvsHL.UpdateHealth(btn)
    -- ==========================================
    -- 1. Simulation Path
    -- ==========================================
    if btn.sim then
        local S = EvsHL.S
        local bar = btn.healthBar
        local maxHealth = btn.max or 1
        local healthVal = btn.health or 0
        local fullHealth = healthVal >= maxHealth

        if btn._barMax ~= maxHealth then
            btn._barMax = maxHealth
            bar:SetMinMaxValues(0, maxHealth)
        end
        bar:SetValue(healthVal)

        local debuffColor = btn.debuff ~= "Unknown" and btn.debuffColor or nil
        local bright = debuffColor ~= nil or btn.simAggro or not fullHealth

        local color
        if debuffColor then
            color = debuffColor
        elseif bright then
            color = S.thresholdColor or EvsHL.DEFAULTS.thresholdColor
        else
            color = S.barColor
        end

        bar:SetStatusBarColor(color[1], color[2], color[3])
        bar.fill:SetAlpha(bright and S.barAlpha or S.barAlphaFull)
        bar:Show()
        EvsHL.ApplyHealthText(btn)
        return
    end

    -- ==========================================
    -- 2. Dead / Offline check
    -- ==========================================
    local unit = btn.unit
    local bar = btn.healthBar
    local isDead = UnitIsDeadOrGhost(unit)
    local isOnline = UnitIsConnected(unit)

    btn.dead = isDead
    btn.online = isOnline

    if isDead or not isOnline then
        btn._barMax = 1
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(1)
        bar:SetStatusBarColor(0.3, 0.3, 0.3)
        bar.fill:SetAlpha(0.5)
        bar:Show()

        if EvsHL.S.hpMode ~= "none" then
            btn.hpText:SetText(isDead and "Dead" or "Offline")
            btn.hpText:Show()
        else
            btn.hpText:Hide()
        end
        return
    end

    -- ==========================================
    -- 3. Bar value
    -- ==========================================
    local health = UnitHealth(unit)
    local maxLife = UnitHealthMax(unit)

    if issecretvalue and issecretvalue(maxLife) then
        btn._barMax = nil
        bar:SetMinMaxValues(0, maxLife)
    else
        local maxHealth = (type(maxLife) == "number" and maxLife > 0) and maxLife or 1
        if btn._barMax ~= maxHealth then
            btn._barMax = maxHealth
            bar:SetMinMaxValues(0, maxHealth)
        end
    end

    if health then
        bar:SetValue(health)
    end

    -- ==========================================
    -- 4. Color (step curve on health percent + threat/debuff overrides)
    -- ==========================================
    local S = EvsHL.S

    if btn.debuff and btn.debuff ~= "Unknown" and btn.debuffColor then
        local c = btn.debuffColor
        bar:SetStatusBarColor(c[1], c[2], c[3])
        bar.fill:SetAlpha(S.barAlpha)
    else
        local base
        if HasThreat(btn, unit) then
            local c = S.thresholdColor or EvsHL.DEFAULTS.thresholdColor
            base = CreateColor(c[1], c[2], c[3], S.barAlpha)
        else
            local curve = EnsureHealthColorCurve()
            if curve and UnitHealthPercent then
                local ok, color = pcall(UnitHealthPercent, unit, true, curve)
                if ok and color then
                    base = color
                end
            end
            if not base then
                base = CreateColor(S.barColor[1], S.barColor[2], S.barColor[3], S.barAlphaFull)
            end
        end
        local r, g, b, a = base:GetRGBA()
        bar:SetStatusBarColor(r, g, b)
        bar.fill:SetAlpha(a)
    end

    bar:Show()

    -- ==========================================
    -- 5. Text
    -- ==========================================
    EvsHL.ApplyHealthText(btn)
end
-- ============================================================
-- Rest of the visual updates (Incoming, Name, Debuff, Buff)
-- ============================================================

function EvsHL.LayoutHealPrediction(btn)
    local S = EvsHL.S
    local pred = btn.healPred
    if not pred then
        return
    end
    local fill = btn.healthBar.fill
    local reverse = S.barsAnchor == "RIGHT"
    pred:ClearAllPoints()
    if reverse then
        pred:SetPoint("TOPRIGHT", fill, "TOPLEFT")
        pred:SetPoint("BOTTOMRIGHT", fill, "BOTTOMLEFT")
    else
        pred:SetPoint("TOPLEFT", fill, "TOPRIGHT")
        pred:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT")
    end
    pred:SetWidth(math.max(btn:GetWidth(), 1))
    pred:SetReverseFill(reverse)
    local c = S.healPredictionColor or EvsHL.DEFAULTS.healPredictionColor
    pred:SetStatusBarColor(c[1], c[2], c[3], 0.8)
end

function EvsHL.UpdateHealPrediction(btn)
    local S = EvsHL.S
    local pred = btn.healPred
    if not pred then
        return
    end
    if not S.showHealPrediction or btn.dead or btn.online == false then
        pred:Hide()
        return
    end

    if btn.sim then
        local maxHealth = btn.max or 1
        pred:SetMinMaxValues(0, maxHealth)
        pred:SetValue(math.min(btn.cast or 0, maxHealth - (btn.health or 0)))
        pred:Show()
        return
    end

    if not (CreateUnitHealPredictionCalculator and UnitGetDetailedHealPrediction) then
        pred:Hide()
        return
    end
    local calc = EvsHL.healPredCalc
    if not calc then
        calc = CreateUnitHealPredictionCalculator()
        EvsHL.healPredCalc = calc
    end
    local unit = btn.unit
    local ok, total, _, _, clamped = pcall(function()
        UnitGetDetailedHealPrediction(unit, "player", calc)
        return calc:GetIncomingHeals()
    end)
    local value = clamped
    if type(value) ~= "number" then
        value = total
    end
    if not ok or type(value) ~= "number" then
        pred:Hide()
        return
    end
    pred:SetMinMaxValues(0, UnitHealthMax(unit))
    pred:SetValue(value)
    pred:Show()
end

function EvsHL.UpdateIncoming(btn, now)
    local S = EvsHL.S
    if not S.showIncoming then
        btn.incoming = nil
        btn.incomingSpell = nil
        btn.incomingEnd = nil
        btn.incomingBar:Hide()
        return
    end
    if not btn.healthBar:IsShown() or (issecretvalue and issecretvalue(btn.health)) or
        (issecretvalue and issecretvalue(btn.max)) or btn.max <= 0 then
        btn.incomingBar:Hide()
        return
    end
    local total = btn.cast
    for k = 1, btn.nh do
        local h = btn.hots[k]
        if h.rate > 0 and h.expires > 0 then
            local rem = h.expires - now
            if rem > 0 then
                total = total + h.rate * math.min(rem, S.hotLookahead)
            end
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

function EvsHL.UpdateName(btn)
    local S = EvsHL.S
    btn.name = UnitName(btn.unit)
    local _, class = UnitClass(btn.unit)
    btn.class = class

    if EvsHL.IsSecretValue(btn.name) then
        btn.shownName = nil
        btn.font:SetText(btn.name)
    elseif btn.shownName ~= btn.name then
        btn.shownName = btn.name
        btn.font:SetText(btn.name)
    end
    local r, g, b = 1, 1, 1
    if btn.isPet then
        r, g, b = 0.75, 0.75, 0.75
    elseif S.classColor then
        local c = btn.class and RAID_CLASS_COLORS[btn.class]
        if c then
            r, g, b = c.r, c.g, c.b
        end
    end
    btn.font:SetTextColor(r, g, b)
end

local function ScamDebuffs(btn)
    local S = EvsHL.S
    local foundType, foundIcon = btn.debuff, btn.debuffIconTexture

    if not InCombatLockdown() then
        foundType, foundIcon = nil, nil
        local genericIcon
        for i = 1, #EvsHL.buttons do
            local name, _, icon, _, debuffType, _, _, _, _, _, spellID = EvsHL.GetAura(btn.unit, i, "HARMFUL")
            if not name then
                break
            end
            if not (spellID and S.ignoredDebuffs and S.ignoredDebuffs[spellID]) then
                if not genericIcon then
                    genericIcon = icon
                end
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
                            if foundType then
                                break
                            end
                        end
                    end
                    if foundType then
                        break
                    end
                end
            end
        end
        if not foundType and genericIcon then
            foundType = "Unknown"
            foundIcon = genericIcon
        end
        btn.debuff = foundType
        btn.debuffIconTexture = foundIcon
    end
    return foundType, foundIcon
end

function EvsHL.UpdateDebuff(btn)
    local S = EvsHL.S
    local foundType, foundIcon
    local nativeCombatAuras = btn.nativeAurasActive and not btn.sim
    if btn.sim then
        foundType, foundIcon = btn.debuff, btn.debuffIconTexture
    elseif nativeCombatAuras then
        btn.debuff = nil
        btn.debuffIconTexture = nil
    else
        foundType, foundIcon = ScamDebuffs(btn)
    end

    btn.debuffColor = nil
    if foundType then
        if foundType == "Unknown" then
            local color = S.debuffColor or {1, 0, 0}
            btn.debuffColor = {color[1], color[2], color[3]}
        else
            local color = S[EvsHL.DEBUFF_COLOR_KEYS[foundType]]
            local fallback = EvsHL.DEBUFF_TYPE_COLORS[foundType] or {
                r = 1,
                g = 0,
                b = 0
            }
            btn.debuffColor = {color and color[1] or fallback.r, color and color[2] or fallback.g,
                               color and color[3] or fallback.b}
        end
    end

    if btn.debuffBorder then
        btn.debuffBorder:Hide()
    end

    if nativeCombatAuras then
        if not InCombatLockdown() then
            EvsHL.RecolorDispelTints(btn)
        end
        btn.debuffIcon:Hide()
    elseif S.debuffIcon and foundIcon then
        btn.debuffIconTex:SetTexture(foundIcon)
        btn.debuffIcon:Show()
    else
        btn.debuffIcon:Hide()
    end
end

function EvsHL.UpdateBuff(btn)
    local S = EvsHL.S
    if S.buffBorder and btn.missingBuff then
        local c = S.buffsMissingColor
        btn.buff:SetBackdropBorderColor(c[1], c[2], c[3], 1)
        btn.buff:Show()
    else
        btn.buff:Hide()
    end
end