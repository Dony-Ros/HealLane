-- ============================================================
-- HealLane_Refresh.lua
-- Drives the button updates and grid re-generation.
-- ============================================================
local EvsHL = EvsHL
local function ThreatLevel(unit)
    if UnitThreatSituation then return UnitThreatSituation(unit) end
    if UnitDetailedThreatSituation then
        local _, status = UnitDetailedThreatSituation(unit)
        return status
    end
end
function EvsHL.UpdateButton(btn)
    local S = EvsHL.S
    local now = GetTime()
    if btn.sim then EvsHL.SimData(btn) else EvsHL.RealData(btn) end
    local threat = not btn.sim and ThreatLevel(btn.unit)
    btn.hasAggro = not btn.sim and S.aggroHighlight and not EvsHL.IsSecretValue(threat)
        and (threat or 0) >= 2
    local rangeAlpha = 1
    if not btn.sim and not UnitIsUnit(btn.unit, "player") then
        if UnitDistanceSquared then
            local distanceSquared = UnitDistanceSquared(btn.unit)
            local fadeDistance = S.rangeFadeDistance or 60
            if distanceSquared and distanceSquared >= (fadeDistance * 2.5) ^ 2 then
                rangeAlpha = 0.3
            elseif distanceSquared and distanceSquared >= fadeDistance ^ 2 then
                rangeAlpha = 0.5
            end
        end
    end
    if not btn.sim and UnitInVehicle and UnitInVehicle(btn.unit) then
        rangeAlpha = math.min(rangeAlpha, 0.7)
    end
    if not InCombatLockdown() then btn:SetAlpha(rangeAlpha) end
    EvsHL.UpdateDebuff(btn)
    EvsHL.UpdateHealth(btn)
    EvsHL.UpdateHealPrediction(btn)
    EvsHL.UpdateIncoming(btn, now)
    EvsHL.UpdateHoTs(btn, now)
    EvsHL.UpdateBuff(btn)
    if btn.hasAggro then
        local color = S.aggroColor or EvsHL.DEFAULTS.aggroColor
        btn.aggro:SetBackdropBorderColor(color[1], color[2], color[3], 1)
        btn.aggro:Show()
    else
        btn.aggro:Hide()
    end
end
-- Spell clicks run as a conditional macro so an invalid target (dead, gone, out of
-- zone) fails silently instead of falling back to Auto Self-Cast.
function EvsHL.CastMacro(spell, unit, deadOnly)
    return "/cast [@" .. unit .. ",help," .. (deadOnly and "dead" or "nodead") .. "] " .. spell
end

function EvsHL.ClickAction(btn, v, m, b, blank, rank)
    local macro = v and v:match("^m:(.+)")
    local action = v and v:match("^a:(.+)")
    if macro then
        return "macro", nil, macro, nil
    elseif action then
        if action ~= "target" or btn.unit ~= "target" then return action end
    elseif v and v ~= "" then
        local spell = rank and (v .. "(" .. rank .. ")") or v
        return "macro", nil, nil, EvsHL.CastMacro(spell, btn.unit)
    elseif not blank and m == "" and b == 1 then
        if btn.unit ~= "target" then return "target" end
    elseif not blank and m == "" and b == 2 then
        return "menu"
    end
end

local function RankNumber(rank)
    return type(rank) == "string" and tonumber(rank:match("(%d+)")) or nil
end

function EvsHL.GetClickRank(btn, slotKey)
    local S = EvsHL.S
    local selectedRank = S.clickRanks and S.clickRanks[slotKey]
    if not S.autoDownrank or not btn or btn.sim or not btn.unit then
        return selectedRank
    end

    local spellName = S.clicks[slotKey]
    local learnLevels = spellName and EvsHL.SPELL_RANK_LEARN_LEVELS[spellName]
    local entry = spellName and EvsHL.FindSpell(spellName)
    if not learnLevels or not entry or not entry.ranks then
        return selectedRank
    end

    local targetLevel = UnitLevel(btn.unit)
    if type(targetLevel) ~= "number" or targetLevel < 1 then
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
            local learnedLevel = learnLevels[number]
            if learnedLevel and targetLevel >= math.max(1, learnedLevel - 10)
                and (not bestNumber or number > bestNumber) then
                bestRank, bestNumber = rank, number
            end
        end
    end
    return bestRank or lowestRank or selectedRank
end

function EvsHL.ApplyClicks(btn, blank)
    local S = EvsHL.S
    for _, m in ipairs(EvsHL.MODS) do
        for b = 1, 5 do
            local v = not blank and S.clicks[m .. b]
            local rank = EvsHL.GetClickRank(btn, m .. b)
            local t, spell, mac, macText = EvsHL.ClickAction(btn, v, m, b, blank, rank)
            btn:SetAttribute(m .. "type" .. b, t)
            btn:SetAttribute(m .. "spell" .. b, spell)
            btn:SetAttribute(m .. "macro" .. b, mac)
            btn:SetAttribute(m .. "macrotext" .. b, macText)
        end
    end
end

local function SyncButtonLabels(btn)
    EvsHL.UpdateName(btn)
    if btn.isPet then
        btn.role = "DPS"
        btn.roleIcon:Hide()
    else
        if EvsHL.IsTank(btn.unit) then
            btn.role = "TANK"
        elseif EvsHL.IsHeal(btn.unit) then
            btn.role = "HEALER"
        else
            btn.role = "DPS"
        end
        EvsHL.UpdateUnitRoleIcon(btn)
    end
    EvsHL.UpdateUnitRaidIcon(btn)
end

-- Combat-safe: only touches text/textures, never secure frame layout or attributes.
function EvsHL.SyncLabels()
    for _, btn in ipairs(EvsHL.buttons) do
        if btn.unit and not btn.sim and btn:IsShown() then
            pcall(SyncButtonLabels, btn)
        end
    end
end

function EvsHL.Refresh()
    local S = EvsHL.S
    if not S then return end
    if InCombatLockdown() then
        EvsHL.pending = true
        EvsHL.SyncLabels()
        return
    end
    EvsHL.pending = false
    local sim = EvsHL.simCount or 0
    local raid = EvsHL.NumRaid() > 0
    local list = {}
    if sim > 0 then
        for i = 1, sim do list[i] = "sim" end
    elseif raid then
        for i = 1, math.min(EvsHL.NumRaid(), #EvsHL.buttons) do
            local unit = "raid" .. i
            if S.showPlayer or not UnitIsUnit(unit, "player") then list[#list + 1] = unit end
        end
    else
        if S.showPlayer then list[#list + 1] = "player" end
        for i = 1, EvsHL.NumParty() do list[#list + 1] = "party" .. i end
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
            if #list + #petList < EvsHL.MAX_UNITS and UnitExists(petUnit) then
                petList[#petList + 1] = petUnit
            end
        end
        if raid then
            for i = 1, EvsHL.NumRaid() do AddPet("raidpet" .. i) end
        else
            if S.showPlayer then AddPet("pet") end
            for i = 1, EvsHL.NumParty() do AddPet("partypet" .. i) end
        end
    end
    local petsOrdered = false
    if (S.sortByRole or next(S.roleOverrides or {})) and (#list + #petList) > 1 then
        local combined = {}
        for _, u in ipairs(list) do combined[#combined + 1] = u end
        for _, u in ipairs(petList) do combined[#combined + 1] = u end
        local ordered, positions, rowCount, colsUsed = EvsHL.GetOrderedList(combined, raid, cols)
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
                return (UnitName(a) or a) < (UnitName(b) or b)
            end)
        end
        for _, u in ipairs(petList) do list[#list + 1] = u end
    end
    EvsHL.orderSignature = table.concat(list, ",")
    local realCount = #list
    if sim == 0 then
        local function AddSpare(token)
            if #list < EvsHL.MAX_UNITS and not UnitExists(token) then
                list[#list + 1] = token
            end
        end
        if raid then
            for n = EvsHL.NumRaid() + 1, EvsHL.MAX_UNITS do AddSpare("raid" .. n) end
        else
            for n = EvsHL.NumParty() + 1, 4 do AddSpare("party" .. n) end
            if S.showPets then
                AddSpare("pet")
                for n = 1, 4 do AddSpare("partypet" .. n) end
            end
        end
    end
    for i = 1, EvsHL.MAX_UNITS do
        local btn = EvsHL.buttons[i] or EvsHL.CreateUnitButton(i)
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
                xPos = -(EvsHL.OUTER + (S.width + S.padding) * colIndex)
                yPos = -(EvsHL.OUTER + (S.height + S.padding) * rowIndex)
                btn:SetPoint("TOPRIGHT", EvsHL.parentFrame, "TOPRIGHT", xPos, yPos)
            else
                xPos = EvsHL.OUTER + (S.width + S.padding) * colIndex
                yPos = -(EvsHL.OUTER + (S.height + S.padding) * rowIndex)
                btn:SetPoint("TOPLEFT", EvsHL.parentFrame, "TOPLEFT", xPos, yPos)
            end
            btn.isPet = type(unit) == "string" and unit:find("pet") ~= nil
            if unit == "sim" then
                btn.sim = i
                btn.unit = "player"
                btn:SetAttribute("unit", "player")
                EvsHL.ApplyClicks(btn, true)
                if btn.tempTargetDriver then
                    UnregisterStateDriver(btn, "visibility")
                    btn.tempTargetDriver = nil
                end
                if btn.watched then
                    UnregisterUnitWatch(btn)
                    btn.watched = false
                end
                btn:Show()
                EvsHL.UpdateUnitRoleIcon(btn)
                EvsHL.UpdateName(btn)
            elseif unit == "target" then
                btn.sim = nil
                btn.unit = "target"
                btn:SetAttribute("unit", "target")
                EvsHL.ApplyClicks(btn)
                if not btn.tempTargetDriver then
                    RegisterStateDriver(btn, "visibility", "[@target,help] show; hide")
                    btn.tempTargetDriver = true
                end
                if btn.watched then
                    UnregisterUnitWatch(btn)
                    btn.watched = false
                end
                btn:Show()
                EvsHL.UpdateName(btn)
            else
                btn.sim = nil
                btn.unit = unit
                btn.health = UnitHealth(btn.unit)
                btn.max = UnitHealthMax(btn.unit)
                btn.dead = UnitIsDeadOrGhost(btn.unit)
                btn.online = UnitIsConnected(btn.unit)
                btn:SetAttribute("unit", unit)
                EvsHL.ApplyClicks(btn)
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
                    elseif EvsHL.IsTank(unit) then
                        btn.role = "TANK"
                    elseif EvsHL.IsHeal(unit) then
                        btn.role = "HEALER"
                    else
                        btn.role = "DPS"
                    end
                    if not btn.isPet then
                        EvsHL.UpdateUnitRoleIcon(btn)
                    end
                    EvsHL.UpdateUnitRaidIcon(btn)
                    EvsHL.UpdateName(btn)
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
    EvsHL.activeCount = realCount
    local total = math.max(realCount, 1)
    local rows
    if rolePositions then
        rows = roleRowCount or math.ceil(total / cols)
    else
        rows = math.ceil(total / cols)
    end
    rows = math.max(rows, 1)
    EvsHL.parentFrame:SetWidth((S.width + S.padding) * math.min(roleColumns, total) - S.padding + EvsHL.OUTER * 2)
    EvsHL.parentFrame:SetHeight((S.height + S.padding) * rows - S.padding + EvsHL.OUTER * 2 + (S.locked and 0 or 16))
    EvsHL.handleText:SetText(sim > 0 and "Options - simulation" or "Options")
    local solo = sim == 0 and not raid and EvsHL.NumParty() == 0
    if S.hideSolo and solo and S.locked then EvsHL.parentFrame:Hide() else EvsHL.parentFrame:Show() end
    EvsHL.ApplyVisuals()
end