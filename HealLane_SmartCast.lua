-- SecureActionButton injection for smart-cast dispel/res/buff behavior.
local EvsHL = EvsHL
local function SmartCast_PreClick(self, button, down)
    local S = EvsHL.S
    if not S then return end
    local unit = self.unit
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
            if resName and EvsHL.IsSpellInRange(resName, unit) then
                self:SetAttribute("type1", "macro")
                self:SetAttribute("macrotext1", EvsHL.CastMacro(resName, unit, true))
                return
            end
        end
        -- 2. Dispel (Debuff check)
        if isGroupUnit and S.dispel and S.dispel.spells then
            for _, entry in pairs(S.dispel.spells) do
                local spellName = entry.spell
                if spellName and spellName ~= "" then
                    if spellName:match("^m:") then spellName = spellName:sub(3) end
                    local foundMatch = false
                    for i = 1, #EvsHL.buttons do
                        local name, _, _, _, debuffType = EvsHL.GetAura(unit, i, "HARMFUL")
                        if not name then break end
                        if debuffType and entry.types[debuffType] then
                            foundMatch = true
                            break
                        end
                    end
                    if foundMatch and EvsHL.IsSpellInRange(spellName, unit) then
                        self:SetAttribute("type1", "macro")
                        self:SetAttribute("macrotext1", EvsHL.CastMacro(spellName, unit))
                        return
                    end
                end
            end
        end
        -- 3. Missing Buffs
        local unitInCombat = UnitAffectingCombat and UnitAffectingCombat(unit)
        if S.monitorMissingBuffs and S.trackBuffs and next(S.trackBuffs) and UnitIsVisible(unit)
            and (S.checkBuffsInCombat or not unitInCombat) then
            local buffs = {}
            for i = 1, #EvsHL.buttons do
                local name, _, _, _, _, duration, expires = EvsHL.GetAura(unit, i, "HELPFUL")
                if not name then break end
                buffs[name] = math.max(buffs[name] or 0, EvsHL.BuffRemaining(duration, expires))
            end
            for buffName, target in pairs(S.trackBuffs) do
                if EvsHL.BuffTargetMatches(self, target) and EvsHL.BuffLacking(buffs, buffName) then
                    if EvsHL.IsSpellInRange(buffName, unit) then
                        self:SetAttribute("type1", "macro")
                        self:SetAttribute("macrotext1", EvsHL.CastMacro(buffName, unit))
                        return
                    end
                end
            end
        end
    end
    local macroText = self:GetAttribute("type1") == "macro" and self:GetAttribute("macrotext1")
    local clickSpell = macroText and macroText:match("%] (.+)$")
    local rangeSpell = clickSpell
    if clickSpell then
        for _, entry in ipairs(EvsHL.spells or {}) do
            for _, rank in ipairs(entry.ranks or {}) do
                if clickSpell == entry.name .. "(" .. rank .. ")" then
                    rangeSpell = entry.name
                    break
                end
            end
            if rangeSpell ~= clickSpell then break end
        end
    end
    if clickSpell and (not UnitIsVisible(unit) or EvsHL.IsSpellInRange(rangeSpell, unit) == false) then
        self:SetAttribute("type1", nil)
        self:SetAttribute("macrotext1", nil)
    end
end
local function SmartCast_PostClick(self, button, down)
    local S = EvsHL.S
    if not S or not S.smartCast or InCombatLockdown() then return end
    if self.unit and not self.sim then
        local function Restore()
            for _, m in ipairs(EvsHL.MODS) do
                for b = 1, 5 do
                    local v = S.clicks[m .. b]
                    local rank = EvsHL.GetClickRank(self, m .. b)
                    local tType, spell, mac, macText = EvsHL.ClickAction(self, v, m, b, false, rank)
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
EvsHL.SmartCast_PreClick = SmartCast_PreClick
EvsHL.SmartCast_PostClick = SmartCast_PostClick