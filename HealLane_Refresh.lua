-- ============================================================
-- HealLane_Refresh.lua
-- Drives the button updates and grid re-generation.
-- ============================================================
local HealLane = HealLane
local function ThreatLevel(unit)
    if UnitThreatSituation then return UnitThreatSituation(unit) end
    if UnitDetailedThreatSituation then
        local _, status = UnitDetailedThreatSituation(unit)
        return status
    end
end
function HealLane.UpdateButton(btn)
    local S = HealLane.S
    local now = GetTime()
    if btn.sim then HealLane.SimData(btn) else HealLane.RealData(btn) end
    local rangeFallbackAlpha = S.rangeFallbackAlpha or 0.3
    local threat = not btn.sim and ThreatLevel(btn.unit)
    btn.hasAggro = not btn.sim and S.aggroHighlight and not HealLane.IsSecretValue(threat)
        and (threat or 0) >= 2
    local rangeAlpha = 1
    local distanceKnown = false
    btn.outOfRange = false
    btn.rangeInRange = nil
    btn.hasSecretRange = false
    btn.hasRangeValue = false
    btn.nearbyRange = nil
    btn.hasNearbyRange = false
    if not btn.sim and not UnitIsUnit(btn.unit, "player") then
        local inInstance = false
        if IsInInstance then inInstance = IsInInstance() end
        local isGroupUnit = (UnitInParty and UnitInParty(btn.unit))
            or (UnitInRaid and UnitInRaid(btn.unit))
        if UnitInRange then
            local inRange, checkedRange = UnitInRange(btn.unit)
            local inRangeIsSecret = HealLane.IsSecretValue(inRange)
            local checkedRangeIsSecret = HealLane.IsSecretValue(checkedRange)
            local canCheckRange = false
            if checkedRangeIsSecret or inRangeIsSecret then
                canCheckRange = isGroupUnit and true or false
            elseif checkedRange == true or checkedRange == 1 then
                canCheckRange = true
            elseif isGroupUnit and checkedRange == nil then
                canCheckRange = true
            end
            if canCheckRange then
                if HealLane.IsSecretValue(inRange) then
                    btn.rangeInRange = inRange
                    btn.hasSecretRange = true
                    btn.nearbyRange = inRange
                    btn.hasNearbyRange = true
                else
                    local knownRange = inRange == true or inRange == false or inRange == 1 or inRange == 0
                    if knownRange then
                        local inSpellRange = inRange == true or inRange == 1
                        btn.rangeInRange = inSpellRange
                        btn.hasRangeValue = true
                        btn.nearbyRange = inSpellRange
                        btn.hasNearbyRange = true
                        if not inSpellRange then
                            btn.outOfRange = true
                        end
                    end
                end
            end
        end
        if UnitDistanceSquared then
            local distanceSquared, checkedDistance = UnitDistanceSquared(btn.unit)
            local fadeDistance = S.rangeFadeDistance or 60
            local farFadeDistance = S.farFadeDistance or 200
            local checkedDistanceIsSecret = HealLane.IsSecretValue(checkedDistance)
            local distanceIsValid = false
            if not checkedDistanceIsSecret then
                distanceIsValid = checkedDistance == nil or checkedDistance == true or checkedDistance == 1
            end
            if distanceIsValid and not HealLane.IsSecretValue(distanceSquared) and type(distanceSquared) == "number" then
                distanceKnown = true
                if distanceSquared >= farFadeDistance ^ 2 then
                    rangeAlpha = math.min(rangeAlpha, rangeFallbackAlpha)
                    btn.outOfRange = true
                elseif isGroupUnit and distanceSquared >= fadeDistance ^ 2 then
                    rangeAlpha = math.min(rangeAlpha, 0.5)
                end
            end
            if not btn.hasNearbyRange and distanceKnown then
                btn.nearbyRange = distanceSquared < fadeDistance ^ 2
                btn.hasNearbyRange = true
            end
        end
        if inInstance and isGroupUnit and not distanceKnown and not btn.hasNearbyRange then
            btn.rangeInRange = false
            btn.hasRangeValue = true
            btn.nearbyRange = false
            btn.hasNearbyRange = true
            btn.outOfRange = true
        end
        if not distanceKnown and btn.hasRangeValue and not btn.rangeInRange then
            rangeAlpha = math.min(rangeAlpha, rangeFallbackAlpha)
        end
    end
    if not btn.sim and UnitInVehicle and UnitInVehicle(btn.unit) then
        rangeAlpha = math.min(rangeAlpha, 0.7)
    end
    if btn.SetAlphaFromBoolean and not distanceKnown and btn.hasSecretRange then
        btn:SetAlphaFromBoolean(btn.rangeInRange, 1, rangeFallbackAlpha)
    else
        btn:SetAlpha(rangeAlpha)
    end
    HealLane.UpdateDebuff(btn)
    HealLane.UpdateHealth(btn)
    HealLane.UpdateResourceBar(btn)
    HealLane.UpdateHealPrediction(btn, now)
    HealLane.UpdateHoTs(btn, now)
    HealLane.UpdateBuff(btn)
    if btn.hasAggro then
        local color = S.aggroColor or HealLane.DEFAULTS.aggroColor
        btn.aggro:SetBackdropBorderColor(color[1], color[2], color[3], 1)
        btn.aggro:Show()
    else
        btn.aggro:Hide()
    end
end
-- Spell clicks run as a conditional macro so an invalid target (dead, gone, out of
-- zone) fails silently instead of falling back to Auto Self-Cast.
function HealLane.CastMacro(spell, unit, deadOnly)
    return "/cast [@" .. unit .. ",help," .. (deadOnly and "dead" or "nodead") .. "] " .. spell
end

function HealLane.ClickAction(btn, v, m, b, blank, rank)
    local macro = v and v:match("^m:(.+)")
    local action = v and v:match("^a:(.+)")
    if macro then
        return "macro", nil, macro, nil
    elseif action then
        if action == "role" then return nil end
        if action ~= "target" or btn.unit ~= "target" then return action end
    elseif v and v ~= "" then
        local spell = rank and (v .. "(" .. rank .. ")") or v
        return "macro", nil, nil, HealLane.CastMacro(spell, btn.unit)
    end
end

local function RankNumber(rank)
    return type(rank) == "string" and tonumber(rank:match("(%d+)")) or nil
end

function HealLane.GetSpellRankForUnit(spellName, unit, selectedRank)
    local S = HealLane.S
    if not S.autoDownrank or not spellName or not unit then
        return selectedRank
    end

    local entry = spellName and HealLane.FindSpell(spellName)
    local fallbackLevels = HealLane.SPELL_RANK_LEARN_LEVELS[spellName]
    if not entry or not entry.ranks
        or (not fallbackLevels and (not entry.rankLearnLevels or not next(entry.rankLearnLevels))) then
        return selectedRank
    end

    local targetLevel = UnitLevel(unit)
    if HealLane.IsSecretValue(targetLevel) or type(targetLevel) ~= "number" or targetLevel < 1 then
        return selectedRank
    end

    local rankLimit = math.huge
    if selectedRank then
        rankLimit = RankNumber(selectedRank)
        if not rankLimit then return selectedRank end
    end

    local lowestRank, lowestNumber
    local bestRank, bestNumber
    for _, rank in ipairs(entry.ranks) do
        local number = RankNumber(rank)
        if number and number <= rankLimit then
            if not lowestNumber or number < lowestNumber then
                lowestRank, lowestNumber = rank, number
            end
            local learnedLevel = entry.rankLearnLevels and entry.rankLearnLevels[number]
                or fallbackLevels and fallbackLevels[number]
            if learnedLevel and targetLevel >= math.max(1, learnedLevel - 10)
                and (not bestNumber or number > bestNumber) then
                bestRank, bestNumber = rank, number
            end
        end
    end
    return bestRank or lowestRank or selectedRank
end

function HealLane.GetClickRank(btn, slotKey)
    local S = HealLane.S
    local selectedRank = S.clickRanks and S.clickRanks[slotKey]
    if not btn or btn.sim or not btn.unit then return selectedRank end
    return HealLane.GetSpellRankForUnit(S.clicks[slotKey], btn.unit, selectedRank)
end

function HealLane.ApplyClicks(btn, blank)
    local S = HealLane.S
    for _, m in ipairs(HealLane.MODS) do
        for b = 1, 5 do
            local v = not blank and S.clicks[m .. b]
            local rank = HealLane.GetClickRank(btn, m .. b)
            local t, spell, mac, macText = HealLane.ClickAction(btn, v, m, b, blank, rank)
            btn:SetAttribute(m .. "type" .. b, t)
            btn:SetAttribute(m .. "spell" .. b, spell)
            btn:SetAttribute(m .. "macro" .. b, mac)
            btn:SetAttribute(m .. "macrotext" .. b, macText)
        end
    end
end

local function SyncButtonLabels(btn)
    HealLane.UpdateName(btn)
    if btn.isPet then
        btn.role = "DPS"
        btn.roleIcon:Hide()
    else
        if HealLane.IsTank(btn.unit) then
            btn.role = "TANK"
        elseif HealLane.IsHeal(btn.unit) then
            btn.role = "HEALER"
        else
            btn.role = "DPS"
        end
        HealLane.UpdateUnitRoleIcon(btn)
    end
    HealLane.UpdateUnitRaidIcon(btn)
end

-- Combat-safe: only touches text/textures, never secure frame layout or attributes.
function HealLane.SyncLabels()
    for _, btn in ipairs(HealLane.buttons) do
        if btn.unit and not btn.sim and btn:IsShown() then
            pcall(SyncButtonLabels, btn)
        end
    end
end

function HealLane.Refresh()
    local S = HealLane.S
    if not S then return end
    if InCombatLockdown() then
        HealLane.pending = true
        HealLane.SyncLabels()
        return
    end
    HealLane.pending = false
    local sim = HealLane.simCount or 0
    local raid = HealLane.NumRaid() > 0
    local list = {}
    if sim > 0 then
        for i = 1, sim do list[i] = "sim" end
    elseif raid then
        for i = 1, math.min(HealLane.NumRaid(), #HealLane.buttons) do
            local unit = "raid" .. i
            if S.showPlayer or not UnitIsUnit(unit, "player") then list[#list + 1] = unit end
        end
    else
        if S.showPlayer then list[#list + 1] = "player" end
        for i = 1, HealLane.NumParty() do list[#list + 1] = "party" .. i end
    end
    local cols = S.cols
    local roleColumns = cols
    local rolePositions, roleRowCount
    if S.showTempTarget and UnitExists("target") and UnitIsFriend("player", "target") and not UnitInParty("target") and not UnitInRaid("target") and not UnitIsUnit("target", "player") then
        list[#list + 1] = "target"
    end
    local petList = {}
    if S.showPets and sim == 0 then
        local function AddPet(petUnit)
            if #list + #petList < HealLane.MAX_UNITS and UnitExists(petUnit) then
                petList[#petList + 1] = petUnit
            end
        end
        if raid then
            for i = 1, HealLane.NumRaid() do AddPet("raidpet" .. i) end
        else
            if S.showPlayer then AddPet("pet") end
            for i = 1, HealLane.NumParty() do AddPet("partypet" .. i) end
        end
    end
    local petsOrdered = false
    if S.sortByRole and (#list + #petList) > 1 then
        local combined = {}
        for _, u in ipairs(list) do combined[#combined + 1] = u end
        for _, u in ipairs(petList) do combined[#combined + 1] = u end
        local ordered, positions, rowCount, colsUsed = HealLane.GetOrderedList(combined, raid, cols)
        if ordered then
            list = {}
            for _, u in ipairs(ordered) do list[#list + 1] = u end
            rolePositions, roleRowCount, roleColumns = positions, rowCount, colsUsed
            petsOrdered = true
        end
    end
    if not petsOrdered then
        if #list > 1 then
            table.sort(list, function(a, b)
                local nameA, nameB = UnitName(a), UnitName(b)
                if HealLane.IsSecretValue(nameA) or HealLane.IsSecretValue(nameB)
                    or (nameA ~= nil and type(nameA) ~= "string")
                    or (nameB ~= nil and type(nameB) ~= "string") then
                    return a < b
                end
                return (nameA or a) < (nameB or b)
            end)
        end
        for _, u in ipairs(petList) do list[#list + 1] = u end
    end
    HealLane.orderSignature = table.concat(list, ",")
    local realCount = #list
    if sim == 0 then
        local function AddSpare(token)
            if #list < HealLane.MAX_UNITS and not UnitExists(token) then
                list[#list + 1] = token
            end
        end
        if raid then
            for n = HealLane.NumRaid() + 1, HealLane.MAX_UNITS do AddSpare("raid" .. n) end
        else
            for n = HealLane.NumParty() + 1, 4 do AddSpare("party" .. n) end
            if S.showPets then
                AddSpare("pet")
                for n = 1, 4 do AddSpare("partypet" .. n) end
            end
        end
    end
    for i = 1, HealLane.MAX_UNITS do
        local btn = HealLane.buttons[i] or HealLane.CreateUnitButton(i)
        local unit = list[i]
        if unit then
            if btn.unit ~= unit then
                btn.nh = 0
                btn.trackedHots = nil
                btn.incoming = nil
                btn.incomingSpell = nil
                btn.incomingEnd = nil
            end
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
            local xPos, yPos
            local rowIndex, colIndex
            if rolePositions and i > realCount then
                local j = i - realCount - 1
                rowIndex = (roleRowCount or 0) + math.floor(j / math.max(roleColumns, 1))
                colIndex = j % math.max(roleColumns, 1)
            else
                rowIndex = rolePositions and rolePositions[i].row or math.floor((i - 1) / cols)
                colIndex = rolePositions and rolePositions[i].col or ((i - 1) % cols)
            end
            if S.frameAnchor == "TOPRIGHT" then
                xPos = -(HealLane.OUTER + (S.width + S.padding) * colIndex)
                yPos = -(HealLane.OUTER + (S.height + S.padding) * rowIndex)
                btn:SetPoint("TOPRIGHT", HealLane.parentFrame, "TOPRIGHT", xPos, yPos)
            else
                xPos = HealLane.OUTER + (S.width + S.padding) * colIndex
                yPos = -(HealLane.OUTER + (S.height + S.padding) * rowIndex)
                btn:SetPoint("TOPLEFT", HealLane.parentFrame, "TOPLEFT", xPos, yPos)
            end
            btn.isPet = type(unit) == "string" and unit:find("pet") ~= nil
            if unit == "sim" then
                btn.sim = i
                btn.unit = "player"
                btn:SetAttribute("unit", "player")
                HealLane.ApplyClicks(btn, true)
                if btn.tempTargetDriver then
                    UnregisterStateDriver(btn, "visibility")
                    btn.tempTargetDriver = nil
                end
                if btn.watched then
                    UnregisterUnitWatch(btn)
                    btn.watched = false
                end
                btn:Show()
                HealLane.UpdateUnitRoleIcon(btn)
                HealLane.UpdateUnitRaidIcon(btn)
                HealLane.UpdateName(btn)
            elseif unit == "target" then
                btn.sim = nil
                btn.unit = "target"
                btn:SetAttribute("unit", "target")
                HealLane.ApplyClicks(btn)
                if not btn.tempTargetDriver then
                    RegisterStateDriver(btn, "visibility", "[@target,help] show; hide")
                    btn.tempTargetDriver = true
                end
                if btn.watched then
                    UnregisterUnitWatch(btn)
                    btn.watched = false
                end
                btn:Show()
                HealLane.UpdateName(btn)
                HealLane.UpdateUnitRaidIcon(btn)
            else
                btn.sim = nil
                btn.unit = unit
                btn.health = UnitHealth(btn.unit)
                btn.max = UnitHealthMax(btn.unit)
                btn.dead = UnitIsDeadOrGhost(btn.unit)
                btn.online = UnitIsConnected(btn.unit)
                btn:SetAttribute("unit", unit)
                HealLane.ApplyClicks(btn)
                if btn.tempTargetDriver then
                    UnregisterStateDriver(btn, "visibility")
                    btn.tempTargetDriver = nil
                end
                if not btn.watched then
                    RegisterUnitWatch(btn)
                    btn.watched = true
                end
                if i > realCount then
                    btn.role = "DPS"
                    btn.roleIcon:Hide()
                    btn.font:SetText("")
                    btn.shownName = nil
                else
                    if btn.isPet then
                        btn.role = "DPS"
                        btn.roleIcon:Hide()
                    elseif HealLane.IsTank(unit) then
                        btn.role = "TANK"
                    elseif HealLane.IsHeal(unit) then
                        btn.role = "HEALER"
                    else
                        btn.role = "DPS"
                    end
                    if not btn.isPet then
                        HealLane.UpdateUnitRoleIcon(btn)
                    end
                    HealLane.UpdateUnitRaidIcon(btn)
                    HealLane.UpdateName(btn)
                end
            end
            btn.shownName = nil
            btn.shownHpText = nil
        else
            btn.sim = nil
            if btn.tempTargetDriver then
                UnregisterStateDriver(btn, "visibility")
                btn.tempTargetDriver = nil
            end
            if btn.watched then
                UnregisterUnitWatch(btn)
                btn.watched = false
            end
            btn:Hide()
        end
    end
    HealLane.activeCount = realCount
    local total = math.max(realCount, 1)
    local rows
    if rolePositions then
        rows = roleRowCount or math.ceil(total / cols)
    else
        rows = math.ceil(total / cols)
    end
    rows = math.max(rows, 1)
    HealLane.parentFrame:SetWidth((S.width + S.padding) * math.min(roleColumns, total) - S.padding + HealLane.OUTER * 2)
    HealLane.parentFrame:SetHeight((S.height + S.padding) * rows - S.padding + HealLane.OUTER * 2 + (S.locked and 0 or 16))
    HealLane.handleText:SetText(sim > 0 and "Options - simulation" or "Options")
    local solo = sim == 0 and not raid and HealLane.NumParty() == 0
    if S.hideSolo and solo and S.locked then HealLane.parentFrame:Hide() else HealLane.parentFrame:Show() end
    HealLane.ApplyVisuals()
    if HealLane.UpdateTargetOutline then HealLane.UpdateTargetOutline() end
end