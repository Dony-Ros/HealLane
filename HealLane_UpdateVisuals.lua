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
    if not btn.sim and (btn.nativeAurasActive
        or (EvsHL.nativeAuraSupported and not EvsHL.CanScanAuras())) then
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
    curve:SetType(Enum.LuaCurveType.Step)
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
    if not ok then
        return nil
    end
    if EvsHL.IsSecretValue(status) then
        return nil
    end
    if status == nil then
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
        local nearbyCondition
        local hasNearbyCondition = false
        local fullHealth = not EvsHL.IsSecretValue(health) and not EvsHL.IsSecretValue(maxLife)
            and type(health) == "number" and type(maxLife) == "number"
            and maxLife > 0 and health >= maxLife
        local hasThreat = HasThreat(btn, unit)
        if hasThreat then
            local c = S.thresholdColor or EvsHL.DEFAULTS.thresholdColor
            base = CreateColor(c[1], c[2], c[3], S.barAlpha)
        elseif fullHealth then
            local c = S.barColor or EvsHL.DEFAULTS.barColor
            base = CreateColor(c[1], c[2], c[3], S.barAlphaFull)
            if hasThreat == false then
                if UnitIsUnit(unit, "player") then
                    nearbyCondition = true
                    hasNearbyCondition = true
                elseif btn.hasNearbyRange then
                    nearbyCondition = btn.nearbyRange
                    hasNearbyCondition = true
                end
            end
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
        if hasNearbyCondition then
            local nearbyColor = S.nearbyColor or EvsHL.DEFAULTS.nearbyColor
            local safe = CreateColor(nearbyColor[1], nearbyColor[2], nearbyColor[3], 1)
            local normal = CreateColor(r, g, b, 1)
            if bar.fill.SetVertexColorFromBoolean then
                bar.fill:SetVertexColorFromBoolean(nearbyCondition, safe, normal)
                if bar.fill.SetAlphaFromBoolean then
                    bar.fill:SetAlphaFromBoolean(nearbyCondition, S.barAlpha, a)
                end
            elseif not EvsHL.IsSecretValue(nearbyCondition) and nearbyCondition then
                bar:SetStatusBarColor(nearbyColor[1], nearbyColor[2], nearbyColor[3])
                bar.fill:SetAlpha(S.barAlpha)
            end
        end
    end

    bar:Show()

    -- ==========================================
    -- 5. Text
    -- ==========================================
    EvsHL.ApplyHealthText(btn)
end

local function ResourceColor(powerType, powerToken)
    local powerTypes = Enum and Enum.PowerType
    if powerType == (powerTypes and powerTypes.Mana or 0) then
        return 0, 0, 1
    elseif powerType == (powerTypes and powerTypes.Rage or 1) then
        return 1, 0, 0
    elseif powerType == (powerTypes and powerTypes.Energy or 3) then
        return 1, 1, 0
    end

    local color = type(powerToken) == "string" and PowerBarColor and PowerBarColor[powerToken]
    if not color and PowerBarColor then
        color = PowerBarColor[powerType]
    end
    if color then
        return color.r or color[1] or 0.5, color.g or color[2] or 0.5, color.b or color[3] or 1
    end
    return 0.5, 0.5, 1
end

function EvsHL.UpdateResourceBar(btn)
    local bar = btn.resourceBar
    local S = EvsHL.S
    if not bar then return end
    if not S or not S.showResourceBar or btn.sim or not btn.unit
        or not UnitPowerType or not UnitPower or not UnitPowerMax then
        bar:Hide()
        return
    end

    local ok, powerType, powerToken = pcall(UnitPowerType, btn.unit)
    if not ok or EvsHL.IsSecretValue(powerType) or type(powerType) ~= "number" then
        bar:Hide()
        return
    end

    local maximum = UnitPowerMax(btn.unit, powerType)
    local power = UnitPower(btn.unit, powerType)
    if not EvsHL.IsSecretValue(maximum) and (type(maximum) ~= "number" or maximum <= 0) then
        bar:Hide()
        return
    end
    if not EvsHL.IsSecretValue(power) and type(power) ~= "number" then
        bar:Hide()
        return
    end

    local r, g, b = ResourceColor(powerType, powerToken)
    bar:SetStatusBarColor(r, g, b)
    bar:SetMinMaxValues(0, maximum)
    bar:SetValue(power)
    bar:Show()
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

local function SetHealPredictionValue(pred, unit, value, color)
    pred:SetStatusBarColor(color[1], color[2], color[3], 0.8)
    pred:SetMinMaxValues(0, UnitHealthMax(unit))
    pred:SetValue(value)
    pred:Show()
end

local function TrackedHealEstimate(btn, now, S)
    local total = 0
    if not S.showIncoming then
        return total
    end
    local cast = btn.cast
    if not EvsHL.IsSecretValue(cast) and type(cast) == "number" and cast > 0 then
        total = cast
    end

    local lookahead = type(S.hotLookahead) == "number" and S.hotLookahead or 3
    local trackedNames = {}
    for name, hot in pairs(btn.trackedHots or {}) do
        local expires = hot.expires
        if not EvsHL.IsSecretValue(expires) and type(expires) == "number" and expires <= now then
            btn.trackedHots[name] = nil
        else
            local rate = hot.rate
            if not EvsHL.IsSecretValue(rate) and type(rate) == "number" and rate > 0
                and not EvsHL.IsSecretValue(expires) and type(expires) == "number" then
                local remaining = expires - now
                if remaining > 0 then
                    total = total + rate * math.min(remaining, lookahead)
                    trackedNames[name] = true
                end
            end
        end
    end
    for i = 1, (btn.nh or 0) do
        local hot = btn.hots[i]
        if hot and not (hot.name and trackedNames[hot.name])
            and not EvsHL.IsSecretValue(hot.rate) and type(hot.rate) == "number"
            and hot.rate > 0 and not EvsHL.IsSecretValue(hot.expires)
            and type(hot.expires) == "number" then
            local remaining = hot.expires - now
            if remaining > 0 then
                total = total + hot.rate * math.min(remaining, lookahead)
            end
        end
    end
    return total
end

function EvsHL.UpdateHealPrediction(btn, now)
    local S = EvsHL.S
    local pred = btn.healPred
    if not pred then
        return
    end
    if (not S.showHealPrediction and not S.showIncoming) or btn.dead or btn.online == false then
        pred:Hide()
        return
    end

    if btn.sim then
        local color = S.showIncoming and S.incomingColor or S.healPredictionColor
        local value = S.showIncoming and TrackedHealEstimate(btn, now or GetTime(), S) or (btn.cast or 0)
        pred:SetStatusBarColor(color[1], color[2], color[3], 0.8)
        pred:SetMinMaxValues(0, btn.max or 1)
        pred:SetValue(value)
        pred:Show()
        return
    end

    local unit = btn.unit
    if S.showHealPrediction and CreateUnitHealPredictionCalculator and UnitGetDetailedHealPrediction then
        local calc = EvsHL.healPredCalc
        if not calc then
            calc = CreateUnitHealPredictionCalculator()
            EvsHL.healPredCalc = calc
        end
        local ok, total, _, _, clamped = pcall(function()
            UnitGetDetailedHealPrediction(unit, "player", calc)
            return calc:GetIncomingHeals()
        end)
        if ok then
            local value
            if type(clamped) == "number" then
                value = clamped
            else
                value = total
            end
            if type(value) == "number" and EvsHL.IsSecretValue(value) then
                -- StatusBar accepts secret values, but their zero/nonzero state cannot be tested here.
                SetHealPredictionValue(pred, unit, value, S.healPredictionColor or EvsHL.DEFAULTS.healPredictionColor)
                return
            elseif type(value) == "number" and value > 0 then
                SetHealPredictionValue(pred, unit, value, S.healPredictionColor or EvsHL.DEFAULTS.healPredictionColor)
                return
            end
        end
    end

    if not S.showIncoming then
        pred:Hide()
        return
    end

    local estimate = TrackedHealEstimate(btn, now or GetTime(), S)
    if estimate <= 0 then
        pred:Hide()
        return
    end
    SetHealPredictionValue(pred, unit, estimate, S.incomingColor or EvsHL.DEFAULTS.incomingColor)
end

function EvsHL.UpdateName(btn)
    local S = EvsHL.S
    local name = UnitName(btn.unit)
    if EvsHL.IsSecretValue(name) then
        btn.name = nil
        btn.shownName = nil
        btn.font:SetText("")
    else
        btn.name = name
        if btn.shownName ~= name then
            btn.shownName = name
            btn.font:SetText(name or "")
        end
    end
    local _, class = UnitClass(btn.unit)
    btn.class = not EvsHL.IsSecretValue(class) and type(class) == "string" and class or nil
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

    if EvsHL.CanScanAuras() then
        foundType, foundIcon = nil, nil
        local genericIcon
        for i = 1, #EvsHL.buttons do
            local name, _, icon, _, debuffType, _, _, _, _, _, spellID = EvsHL.GetAura(btn.unit, i, "HARMFUL")
            if EvsHL.IsSecretValue(name) then break end
            if not name then
                break
            end
            local ignored = type(spellID) == "number" and not EvsHL.IsSecretValue(spellID)
                and S.ignoredDebuffs and S.ignoredDebuffs[spellID]
            if not ignored then
                if not genericIcon then
                    genericIcon = icon
                end
                if not EvsHL.IsSecretValue(debuffType) and debuffType then
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