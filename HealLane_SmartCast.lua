-- SecureActionButton injection for smart-cast dispel/res/buff behavior.
local HealLane = HealLane
local function SmartCast_PreClick(self, button, down)
    local S = HealLane.S
    if not S then return end
    if HealLane.IsRoleMenuClick(button) then return end
    local unit = self.unit
    if S.showIncoming and unit and not self.sim then
        HealLane.pendingClickTarget = { unit = unit, time = GetTime() }
    end
    if not unit or self.sim or InCombatLockdown() then return end
    local isGroupUnit = unit ~= "target" or UnitInParty(unit) or UnitInRaid(unit)
    if S.smartCast then
        -- 1. Resurrection (Dead check)
        if UnitIsDeadOrGhost(unit) and S.resSpell and S.resSpell ~= "" then
            local resName = S.resSpell
            if S.resSpell:match("^m:") then
                resName = S.resSpell:sub(3)
            elseif S.resSpell:match("^a:") then
                resName = nil
            end
            if resName and HealLane.IsSpellInRange(resName, unit) then
                self:SetAttribute("type1", "macro")
                self:SetAttribute("macrotext1", HealLane.CastMacro(resName, unit, true))
                return
            end
        end
        -- 2. Dispel (Debuff check)
        if HealLane.CanScanAuras() and isGroupUnit and S.dispel and S.dispel.spells then
            for _, entry in pairs(S.dispel.spells) do
                local spellName = entry.spell
                if spellName and spellName ~= "" then
                    if spellName:match("^m:") then spellName = spellName:sub(3) end
                    local foundMatch = false
                    for i = 1, #HealLane.buttons do
                        local name, _, _, _, debuffType = HealLane.GetAura(unit, i, "HARMFUL")
                        if HealLane.IsSecretValue(name) then break end
                        if not name then break end
                        if not HealLane.IsSecretValue(debuffType) and debuffType and entry.types[debuffType] then
                            foundMatch = true
                            break
                        end
                    end
                    if foundMatch and HealLane.IsSpellInRange(spellName, unit) then
                        self:SetAttribute("type1", "macro")
                        self:SetAttribute("macrotext1", HealLane.CastMacro(spellName, unit))
                        return
                    end
                end
            end
        end
        -- 3. Missing Buffs
        local unitInCombat = UnitAffectingCombat and UnitAffectingCombat(unit)
        local canCheckCombat = S.checkBuffsInCombat
            or (not HealLane.IsSecretValue(unitInCombat) and not unitInCombat)
        if HealLane.CanScanAuras() and S.monitorMissingBuffs and S.trackBuffs and next(S.trackBuffs) and UnitIsVisible(unit)
            and canCheckCombat then
            local buffs = {}
            local completeScan = true
            for i = 1, #HealLane.buttons do
                local name, _, _, _, _, duration, expires, _, _, _, spellID = HealLane.GetAura(unit, i, "HELPFUL")
                if HealLane.IsSecretValue(name) then
                    completeScan = false
                    break
                end
                if not name then break end
                if not HealLane.RecordBuffAura(buffs, name, spellID, duration, expires) then
                    completeScan = false
                    break
                end
            end
            if completeScan then
                for buffName, target in pairs(S.trackBuffs) do
                    if HealLane.BuffTargetMatches(self, target) and HealLane.BuffLacking(buffs, buffName) then
                        if HealLane.IsSpellInRange(buffName, unit) then
                            local rank = HealLane.GetSpellRankForUnit(buffName, unit)
                            local spellName = rank and (buffName .. "(" .. rank .. ")") or buffName
                            self:SetAttribute("type1", "macro")
                            self:SetAttribute("macrotext1", HealLane.CastMacro(spellName, unit))
                            return
                        end
                    end
                end
            end
        end
    end
    local macroText = self:GetAttribute("type1") == "macro" and self:GetAttribute("macrotext1")
    local clickSpell = macroText and macroText:match("%] (.+)$")
    local rangeSpell = clickSpell
    if clickSpell then
        for _, entry in ipairs(HealLane.spells or {}) do
            for _, rank in ipairs(entry.ranks or {}) do
                if clickSpell == entry.name .. "(" .. rank .. ")" then
                    rangeSpell = entry.name
                    break
                end
            end
            if rangeSpell ~= clickSpell then break end
        end
    end
    if clickSpell and (not UnitIsVisible(unit) or HealLane.IsSpellInRange(rangeSpell, unit) == false) then
        self:SetAttribute("type1", nil)
        self:SetAttribute("macrotext1", nil)
    end
end
local function SmartCast_PostClick(self, button, down)
    local S = HealLane.S
    if not S or not S.smartCast or InCombatLockdown() then return end
    if self.unit and not self.sim then
        local function Restore()
            for _, m in ipairs(HealLane.MODS) do
                for b = 1, 5 do
                    local v = S.clicks[m .. b]
                    local rank = HealLane.GetClickRank(self, m .. b)
                    local tType, spell, mac, macText = HealLane.ClickAction(self, v, m, b, false, rank)
                    self:SetAttribute(m .. "type" .. b, tType)
                    self:SetAttribute(m .. "spell" .. b, spell)
                    self:SetAttribute(m .. "macro" .. b, mac)
                    self:SetAttribute(m .. "macrotext" .. b, macText)
                end
            end
        end
        Restore()
    end
end
HealLane.SmartCast_PreClick = SmartCast_PreClick
HealLane.SmartCast_PostClick = SmartCast_PostClick