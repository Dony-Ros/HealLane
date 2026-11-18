-- Spellbook scanning, tooltip parsing, HoT rate estimation, and incoming heal tracking.
local EvsHL = EvsHL
local scanTip = CreateFrame("GameTooltip", "EvsHLScanTip", nil, "GameTooltipTemplate")
local function FindSpell(name)
    for _, e in ipairs(EvsHL.spells or {}) do
        if e.name == name then return e end
    end
end
local function Tooltip(entry)
    scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    if entry.spellID and scanTip.SetSpellByID then
        scanTip:SetSpellByID(entry.spellID)
    else
        scanTip:SetSpell(entry.index, "spell")
    end
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
local function AddSpellRank(entry, rank)
    if not rank or rank == "" then return end
    entry.ranks = entry.ranks or {}
    for _, knownRank in ipairs(entry.ranks) do
        if knownRank == rank then return end
    end
    entry.ranks[#entry.ranks + 1] = rank
end
local function SpellRankLabel(index)
    if type(RANK) == "string" and RANK:find("%%d") then
        return RANK:format(index)
    end
    return "Rank " .. index
end
local function SpellBookInfo(slot, bank, spellID, name, rank, rankCounts, missingRanks)
    local bookName, bookRank
    if C_SpellBook and C_SpellBook.GetSpellBookItemName then
        bookName, bookRank = C_SpellBook.GetSpellBookItemName(slot, bank)
    elseif GetSpellBookItemName then
        bookName, bookRank = GetSpellBookItemName(slot, "spell")
    elseif GetSpellName then
        bookName, bookRank = GetSpellName(slot, "spell")
    end
    if bookName and bookName ~= "" then name = bookName end
    if bookRank and bookRank ~= "" then rank = bookRank end
    if (not rank or rank == "") and spellID and GetSpellInfo then
        local _, legacyRank = GetSpellInfo(spellID)
        rank = legacyRank
    end
    local count = (rankCounts[name] or 0) + 1
    rankCounts[name] = count
    if not rank or rank == "" then
        missingRanks[name] = missingRanks[name] or {}
        missingRanks[name][#missingRanks[name] + 1] = count
    end
    return name, rank
end
function EvsHL.LearnHotID(name, spellID)
    local S = EvsHL.S
    if not S or type(spellID) ~= "number" then return false end
    S.hotIDs = S.hotIDs or {}
    local ids = S.hotIDs[name]
    if not ids then
        ids = {}
        S.hotIDs[name] = ids
    end
    if ids[spellID] then return false end
    for _, entry in ipairs(EvsHL.spells or {}) do
        if entry.name == name and entry.spellIDs and entry.spellIDs[spellID] then
            return false
        end
    end
    ids[spellID] = true
    return true
end

EvsHL.FindSpell = FindSpell
EvsHL.HealAmount = HealAmount
EvsHL.HotRate = HotRate
function EvsHL.ScanSpells()
    local list, seen = {}, {}
    local rankCounts = {}
    local missingRanks = {}
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines
        and C_SpellBook.GetSpellBookSkillLineInfo and C_SpellBook.GetSpellBookItemInfo then
        local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
        for skillLineIndex = 1, C_SpellBook.GetNumSpellBookSkillLines() do
            local skillLine = C_SpellBook.GetSpellBookSkillLineInfo(skillLineIndex)
            if skillLine then
                local firstSlot = (skillLine.itemIndexOffset or 0) + 1
                local lastSlot = firstSlot + (skillLine.numSpellBookItems or 0) - 1
                for slot = firstSlot, lastSlot do
                    local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
                    local spellID = item and item.spellID
                    if spellID then
                        local name, rank = EvsHL.GetSpellInfo(spellID)
                        local passive = C_Spell and C_Spell.IsSpellPassive and C_Spell.IsSpellPassive(spellID)
                        if name and not passive then
                            name, rank = SpellBookInfo(slot, bank, spellID, name, rank, rankCounts, missingRanks)
                            local entry = seen[name]
                            if entry then
                                entry.index = slot
                                entry.spellID = spellID
                                entry.spellIDs[spellID] = true
                                entry.rank = rank
                                AddSpellRank(entry, rank)
                            else
                                local helpful = C_Spell and C_Spell.IsSpellHelpful and C_Spell.IsSpellHelpful(spellID)
                                if helpful == nil then helpful = true end
                                entry = {
                                    name = name,
                                    icon = EvsHL.GetSpellTexture(spellID),
                                    helpful = helpful,
                                    kind = "spell",
                                    index = slot,
                                    spellID = spellID,
                                    spellIDs = { [spellID] = true },
                                    rank = rank,
                                }
                                AddSpellRank(entry, rank)
                                seen[name] = entry
                                list[#list + 1] = entry
                            end
                        end
                    end
                end
            end
        end
    elseif GetNumSpellTabs and GetSpellTabInfo and (GetSpellBookItemName or GetSpellName) then
        local getBookName = GetSpellBookItemName or GetSpellName
        for tab = 1, GetNumSpellTabs() do
            local _, _, offset, num = GetSpellTabInfo(tab)
            for i = offset + 1, offset + num do
                local name, rank = getBookName(i, "spell")
                local passive = IsPassiveSpell and IsPassiveSpell(i, "spell")
                if name and not passive then
                    name, rank = SpellBookInfo(i, "spell", nil, name, rank, rankCounts, missingRanks)
                    local entry = seen[name]
                    if entry then
                        entry.index = i
                        entry.rank = rank
                        AddSpellRank(entry, rank)
                    else
                        entry = {
                            name = name,
                            icon = EvsHL.GetSpellTexture(i),
                            helpful = IsHelpfulSpell and IsHelpfulSpell(i, "spell") or false,
                            kind = "spell",
                            index = i,
                            rank = rank,
                        }
                        AddSpellRank(entry, rank)
                        seen[name] = entry
                        list[#list + 1] = entry
                    end
                end
            end
        end
    end
    for name, missing in pairs(missingRanks) do
        if rankCounts[name] > 1 then
            local entry = seen[name]
            if entry then
                for _, rankNumber in ipairs(missing) do
                    AddSpellRank(entry, SpellRankLabel(rankNumber))
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    EvsHL.spells = list
    local S = EvsHL.S
    if S then
        for name in pairs(seen) do
            if EvsHL.KNOWN_HOTS[name] and not S.hotsSeen[name] then
                S.hotsSeen[name] = true
                S.hots[name] = true
            end
        end
    end
    if EvsHL.SyncConfig then EvsHL.SyncConfig() end
    EvsHL.ApplyVisuals()
end
-- ============================================================
-- Incoming-heal tracking (cast events)
-- ============================================================
function EvsHL.ClearIncoming(spell)
    for _, btn in pairs(EvsHL.buttons) do
        if not spell or btn.incomingSpell == spell then
            btn.incoming = nil
            btn.incomingSpell = nil
            btn.incomingEnd = nil
        end
    end
end
function EvsHL.SpellNameFromCastEvent(value, spellID)
    if type(spellID) == "number" then
        return EvsHL.GetSpellInfo(spellID) or tostring(spellID)
    end
    return value
end
function EvsHL.StartIncoming(spell)
    local S = EvsHL.S
    if not S then return end
    if not S.showIncoming then return end
    local pendingCast = EvsHL.pendingCast
    if not pendingCast or pendingCast.spell ~= spell then return end
    local amount = HealAmount(spell)
    if not amount then return end
    local _, _, _, _, _, endTime = UnitCastingInfo("player")
    local target = pendingCast.target
    if not target or target == "" then return end
    local matchedButton
    for _, btn in pairs(EvsHL.buttons) do
        if btn.unit and not btn.sim then
            if UnitExists(target) and UnitIsUnit(btn.unit, target) then
                matchedButton = btn
                break
            end
        end
    end
    if not matchedButton then
        local nameMatches = {}
        for _, btn in pairs(EvsHL.buttons) do
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
    EvsHL.pendingCast = nil
end