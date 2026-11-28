-- ============================================================
-- HealLane_Data.lua
-- Collects unit data from the game API or generates it for
-- the simulation.
-- ============================================================
local HealLane = HealLane
local SIM_NAMES = { "Awezon", "Aldrin", "Mirelle", "Torvald", "Selene", "Brokk", "Isolde", "Garrick", "Nyx", "Orin" }
local SIM_CLASSES = { "DRUID", "PRIEST", "PALADIN", "SHAMAN", "WARRIOR", "MAGE", "ROGUE", "HUNTER", "WARLOCK","DEATHKNIGHT" }
local SIM_MAX = { 1016, 850, 3400, 12400, 24000, 6200, 15800 }
local SIM_ICONS = { "Interface\\Icons\\Spell_Nature_Rejuvenation", "Interface\\Icons\\Spell_Holy_Renew",
    "Interface\\Icons\\Spell_Nature_ResistNature" }
local SIM_DEBUFFS = { "Magic", "Curse", "Disease", "Poison", "Bleed", "Unknown" }
local SIM_DEBUFF_ICON = "Interface\\Icons\\Spell_Shadow_ShadowWordPain"
function HealLane.SimData(btn)
    local S = HealLane.S
    local i = btn.sim
    local now = GetTime()
    btn.name = SIM_NAMES[(i - 1) % #SIM_NAMES + 1]
    btn.class = SIM_CLASSES[(i * 3) % #SIM_CLASSES + 1]
    btn.max = SIM_MAX[i % #SIM_MAX + 1]
    btn.online = i ~= 7
    btn.dead = i == 3
    local phase = math.floor((now + i * 2.5) / 5) % 8
    btn.debuff = SIM_DEBUFFS[phase + 1] or nil
    btn.debuffIconTexture = btn.debuff and SIM_DEBUFF_ICON or nil
    btn.missingBuff = S.monitorMissingBuffs and (i % 4 == 1) or false
    -- Initialize health state
    if not btn.simHealth or btn.simHealth > btn.max or btn.simHealth < 0 then
        btn.simHealth = btn.max
        btn.simLastUpdate = now
    end
    -- Simulate Aggro (toggles on and off every few seconds)
    local aggroWave = math.sin(now * 0.5 + i * 2)
    btn.simAggro = aggroWave > 0.6 
    if not btn.dead then
        local dt = now - btn.simLastUpdate
        btn.simLastUpdate = now
        -- Determine role priority for damage
        local role = HealLane.SimRole(i, HealLane.simCount or 0)
        local damageMultiplier = 1.0
        if role == "TANK" then
            damageMultiplier = 3.5 -- Tank takes more damage
        elseif role == "HEALER" then
            damageMultiplier = 0.5
        else
            damageMultiplier = 1.3 -- DPS takes very little damage
        end
        -- 1. Base passive regeneration (pulls everyone towards 100%)
        local regen = btn.max * 0.15 * dt
        btn.simHealth = btn.simHealth + regen
        -- 2. Sudden Damage Spikes
        -- The sine wave determines WHEN the damage happens, centered around 0.
        -- When the wave is positive, they take damage.
        local wave = math.sin(now * 0.8 + i)
        if wave > 0.3 then
            -- Damage happens when the wave peaks
            local damage = (btn.max * 0.08) * wave * damageMultiplier * dt
            btn.simHealth = btn.simHealth - damage
        end
        -- Clamp between 10% and 100%
        local minHealth = btn.max * 0.1
        if btn.simHealth < minHealth then btn.simHealth = minHealth end
        if btn.simHealth > btn.max then btn.simHealth = btn.max end
    else
        btn.simHealth = 0
    end
    btn.health = math.floor(btn.simHealth)
    -- Simulated HoTs
    btn.nh = i % 4
    for k = 1, HealLane.MAX_HOTS do
        btn.hots[k] = nil
    end
    for k = 1, btn.nh do
        local h = btn.hots[k] or {}
        btn.hots[k] = h
        h.duration = 12
        if not h.expires or h.expires <= now then
            h.expires = now + (h.expires and 12 or 3 + (i * 3 + k * 4) % 9)
        end
        h.icon = SIM_ICONS[k]
        h.rate = btn.max * 0.02
    end
    -- Simulated incoming cast
    btn.cast = (i % 3 == 0) and (btn.max * 0.2) or 0
end
function HealLane.RealData(btn)
    local S = HealLane.S
    local unit = btn.unit
    local now = GetTime()
    btn.health = UnitHealth(unit)
    btn.max = UnitHealthMax(unit)
    btn.online = UnitIsConnected(unit)
    btn.dead = UnitIsDeadOrGhost(unit)
    if HealLane.CanScanAuras() then
        btn.debuff = nil
        btn.debuffIconTexture = nil
        if S.debuffBorder or S.debuffIcon then
            local genericIcon
            for i = 1, #HealLane.buttons do
                local name, _, icon, _, debuffType = HealLane.GetAura(unit, i, "HARMFUL")
                if HealLane.IsSecretValue(name) then break end
                if not name then break end
                if not genericIcon then genericIcon = icon end
                if not HealLane.IsSecretValue(debuffType) and debuffType then
                    for _, entry in pairs((S.dispel and S.dispel.spells) or {}) do
                        if entry.spell and entry.spell ~= "" and entry.types and entry.types[debuffType] then
                            for _, knownSpell in ipairs(HealLane.spells or {}) do
                                if knownSpell.name == entry.spell then
                                    btn.debuff = debuffType
                                    btn.debuffIconTexture = icon
                                    break
                                end
                            end
                            if btn.debuff then break end
                        end
                    end
                    if btn.debuff then break end
                end
            end
            if not btn.debuff and genericIcon then
                btn.debuff = "Unknown"
                btn.debuffIconTexture = genericIcon
            end
        end
        btn.missingBuff = false
        btn.trackedHots = nil
        local unitInCombat = UnitAffectingCombat and UnitAffectingCombat(unit)
        local canCheckCombat = S.checkBuffsInCombat
            or (not HealLane.IsSecretValue(unitInCombat) and not unitInCombat)
        if S.monitorMissingBuffs and S.trackBuffs and next(S.trackBuffs) and not btn.isPet
            and UnitIsVisible(unit)
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
                    if HealLane.BuffTargetMatches(btn, target) and HealLane.BuffLacking(buffs, buffName) then
                        btn.missingBuff = true
                        break
                    end
                end
            end
        end
        btn.nh = 0
        if S.showHots or S.showIncoming then
            for i = 1, #HealLane.buttons do
                local name, _, icon, _, _, duration, expires, caster, _, _, spellId = HealLane.GetAura(unit, i, "HELPFUL")
                if HealLane.IsSecretValue(name) then break end
                if not name then break end
                local fromPlayer = not HealLane.IsSecretValue(caster) and caster == "player"
                if fromPlayer and S.hots[name] and spellId and HealLane.LearnHotID(name, spellId) then
                    HealLane.RefreshNativeAuraFrames()
                end
                if fromPlayer and S.hots[name] and btn.nh < HealLane.MAX_HOTS then
                    btn.nh = btn.nh + 1
                    local h = btn.hots[btn.nh] or {}
                    btn.hots[btn.nh] = h
                    h.name = name
                    h.icon = icon
                    h.duration = duration or 0
                    h.expires = expires or 0
                    h.rate = HealLane.HotRate(name)
                end
            end
        end
    else
        btn.missingBuff = nil
        local oldCount = btn.nh or 0
        local kept = 0
        for i = 1, oldCount do
            local hot = btn.hots[i]
            local expires = hot and hot.expires
            local active = hot and (HealLane.IsSecretValue(expires)
                or (type(expires) == "number" and expires > now))
            if active then
                kept = kept + 1
                btn.hots[kept] = hot
            end
        end
        for i = kept + 1, oldCount do
            btn.hots[i] = nil
        end
        btn.nh = kept
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