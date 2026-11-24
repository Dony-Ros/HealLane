-- ============================================================
-- HealLane.lua (core)
-- Requires HealLane_Constants.lua to have run first (EvsHL table,
-- DEFAULTS, MODS, Copy, Merge, IsSecretValue, SetTextureColor,
-- GetS all live there now).
-- ============================================================
local EvsHL = _G.EvsHL
-- ============================================================
-- Core spell/aura helpers
-- ============================================================
function EvsHL.GetSpellInfo(spell)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spell)
        if info then
            local rank = info.rank
            if (not rank or rank == "") and GetSpellInfo then
                local _, legacyRank = GetSpellInfo(spell)
                rank = legacyRank
            end
            return info.name, rank, info.iconID or info.originalIconID, info.castTime,
                info.minRange, info.maxRange, info.spellID
        end
        return nil
    end
    if GetSpellInfo then return GetSpellInfo(spell) end
end
function EvsHL.GetSpellTexture(spell)
    if C_Spell and C_Spell.GetSpellTexture then
        return C_Spell.GetSpellTexture(spell)
    end
    if GetSpellTexture then return GetSpellTexture(spell) end
end
function EvsHL.IsSpellInRange(spell, unit)
    local inRange
    if C_Spell and C_Spell.IsSpellInRange then
        inRange = C_Spell.IsSpellInRange(spell, unit)
    elseif IsSpellInRange then
        inRange = IsSpellInRange(spell, unit)
    end
    if inRange == true or inRange == 1 then return true end
    if inRange == false or inRange == 0 then return false end
end
function EvsHL.CanScanAuras()
    if EvsHL.nativeAuraSupported and InCombatLockdown and InCombatLockdown() then return false end
    if IsInInstance then
        local inInstance, instanceType = IsInInstance()
        if inInstance and (instanceType == "pvp" or instanceType == "arena") then
            return false
        end
    end
    return true
end
function EvsHL.GetAura(unit, index, filter)
    if not EvsHL.CanScanAuras() then return nil end
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
        if not aura then return nil end
        return aura.name, nil, aura.icon, aura.applications, aura.dispelName,
            aura.duration, aura.expirationTime, aura.sourceUnit, aura.isStealable,
            aura.nameplateShowPersonal, aura.spellId, aura.canApplyAura,
            aura.isBossAura, aura.isFromPlayerOrPlayerPet, aura.nameplateShowAll,
            aura.timeMod, aura.points
    end
    local getAura = filter == "HARMFUL" and (UnitDebuff or UnitAura) or (UnitBuff or UnitAura)
    if getAura then return getAura(unit, index, filter) end
end
function EvsHL.NumParty()
    if GetNumSubgroupMembers then return GetNumSubgroupMembers() end
    return GetNumPartyMembers and GetNumPartyMembers() or 0
end
function EvsHL.NumRaid()
    if IsInRaid then return IsInRaid() and GetNumGroupMembers() or 0 end
    return GetNumRaidMembers and GetNumRaidMembers() or 0
end
function EvsHL.CreateBackdropFrame(frameType, name, parent, template)
    if BackdropTemplateMixin then
        template = template and template ~= "" and (template .. ", BackdropTemplate") or "BackdropTemplate"
    end
    return CreateFrame(frameType, name, parent, template)
end
function EvsHL.Fmt(n)
    if EvsHL.IsSecretValue(n) then return "" end
    n = math.floor(n + 0.5)
    if n < 1000 then return tostring(n) end
    local k = n / 1000
    if k >= 10 then return string.format("%dk", math.floor(k + 0.5)) end
    return (string.format("%.1fk", k):gsub("%.0k", "k"))
end
-- ============================================================
-- Init / saved variables
-- ============================================================
local function Init()
    EVS_SetingsHealCharacter = EVS_SetingsHealCharacter or {}
    local S = EVS_SetingsHealCharacter
    local old = S.ver or 0
    if old < 3 and not S.hpMode then S.hpMode = S.healthText == false and "none" or "max" end
    if old < 4 and type(S.thresholdColor) == "table"
        and S.thresholdColor[1] == 0.1 and S.thresholdColor[2] == 1 and S.thresholdColor[3] == 0.1 then
        S.thresholdColor = EvsHL.Copy(EvsHL.DEFAULTS.thresholdColor)
    end
    if old < 5 and type(S.thresholdColor) == "table"
        and S.thresholdColor[1] == 1 and S.thresholdColor[2] == 0.2 and S.thresholdColor[3] == 0.1 then
        S.thresholdColor = { 0.1, 1, 0.1 }
    end
    if old < 6 then
        local p = S.debuffPoisonColor
        if type(p) == "table" and math.abs((p[1] or 0) - 0.05) < 0.01
            and math.abs((p[2] or 0) - 0.48) < 0.01 and math.abs((p[3] or 0) - 0.12) < 0.01 then
            S.debuffPoisonColor = { 0, 0.35, 0.15 }
        end
        if type(S.trackBuffs) == "table" then
            for k, v in pairs(S.trackBuffs) do
                if v == true then S.trackBuffs[k] = "any" end
            end
        end
    end
    if old < 9 and S.rangeFallbackAlpha == 0.3 then S.rangeFallbackAlpha = 0.05 end
    if old < 10 then
        S.clicks = type(S.clicks) == "table" and S.clicks or {}
        if S.clicks["shift-6"] == nil then S.clicks["shift-6"] = "a:role" end
        if S.clicks["shift-7"] == nil then S.clicks["shift-7"] = "a:role" end
    end
    S.ver = 10
    S.healthText = nil
    EvsHL.Merge(S, EvsHL.DEFAULTS)
    for _, key in ipairs({
        "debuffCurseColor", "debuffPoisonColor", "debuffDiseaseColor", "debuffMagicColor",
        "debuffBleedColor", "aggroColor", "thresholdColor", "barColor", "nearbyColor",
    }) do
        if type(S[key]) ~= "table" then
            S[key] = EvsHL.Copy(EvsHL.DEFAULTS[key])
        else
            for i = 1, 3 do
                if S[key][i] == nil then S[key][i] = EvsHL.DEFAULTS[key][i] end
            end
        end
    end
    if type(S.ignoredDebuffs) ~= "table" then S.ignoredDebuffs = {} end
    EvsHL.S = S
    EvsHL.nativeAuraSupported = EvsHL.ProbeNativeAuraSupport and EvsHL.ProbeNativeAuraSupport() or false
    if not EvsHL.nativeAuraSupported and EvsHL.WarnNativeAura then
        EvsHL.WarnNativeAura("unsupported",
            "this client has no native AuraContainer; HoTs and debuffs cannot be refreshed during combat.")
    end
    EvsHL.ApplyPosition()
    if EvsHL.ApplyBlizzardRaidFrames then EvsHL.ApplyBlizzardRaidFrames() end
end
function EvsHL.SetSimulation(count)
    EvsHL.simCount = count or 0
    EvsHL.Refresh()
end
function EvsHL.ResetPosition()
    local S = EvsHL.S
    if not S then return end
    S.pos = nil
    EvsHL.ApplyPosition()
end
function EvsHL.ResetAll()
    local S = EvsHL.S
    if not S then return end
    wipe(S)
    EvsHL.Merge(S, EvsHL.DEFAULTS)
    S.ver = 10
    EvsHL.ApplyPosition()
    if EvsHL.ApplyBlizzardRaidFrames then EvsHL.ApplyBlizzardRaidFrames(true) end
    EvsHL.Refresh()
end
-- ============================================================
-- OnUpdate driver
-- ============================================================
local lastTargetName = nil
local lastTargetWasSecret = false
local acc = 0
local rosterRefreshRemaining
function EvsHL.SetRosterRefreshRemaining(v) rosterRefreshRemaining = v end
function EvsHL.GetRosterRefreshRemaining() return rosterRefreshRemaining end
function EvsHL.ClearRosterRefreshRemaining() rosterRefreshRemaining = nil end
-- ============================================================
-- OnUpdate driver
-- ============================================================
local lastTempTargetState = false
local acc = 0
local rosterRefreshRemaining
function EvsHL.SetRosterRefreshRemaining(v) rosterRefreshRemaining = v end
function EvsHL.GetRosterRefreshRemaining() return rosterRefreshRemaining end
function EvsHL.ClearRosterRefreshRemaining() rosterRefreshRemaining = nil end
local function OnUpdate(_, elapsed)
    local S = EvsHL.S
    if not S then return end
    if rosterRefreshRemaining then
        rosterRefreshRemaining = rosterRefreshRemaining - elapsed
        if rosterRefreshRemaining <= 0 then
            rosterRefreshRemaining = nil
            EvsHL.Refresh()
        end
    end
    if S.showTempTarget then
        -- Determine whether a temp-target button would be added, using
        -- only non-secret boolean APIs (UnitName on a hostile NPC returns
        -- a secret string which cannot be compared in tainted code).
        local shouldShow = UnitExists("target")
            and UnitIsFriend("player", "target")
            and not UnitInParty("target")
            and not UnitInRaid("target")
            and not UnitIsUnit("target", "player")
        local state = shouldShow and true or false
        if state ~= lastTempTargetState then
            lastTempTargetState = state
            if not InCombatLockdown() then EvsHL.Refresh() end
        end
    end
    acc = acc + elapsed
    if acc < (EvsHL.activeCount and EvsHL.activeCount > 5 and 0.2 or 0.1) then return end
    acc = 0
    for i = 1, #EvsHL.buttons do
        local btn = EvsHL.buttons[i]
        if btn and btn:IsShown() and btn.unit then EvsHL.UpdateButton(btn) end
    end
end
-- ============================================================
-- Event frame
-- ============================================================
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
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
    UNIT_PET = true,
}
for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
    "ZONE_CHANGED_NEW_AREA", "LFG_UPDATE", "LFG_ROLE_CHECK_SHOW", "LFG_ROLE_CHECK_HIDE", "LFG_ROLE_CHECK_ROLE_CHOSEN",
    "LFG_PROPOSAL_SHOW", "PLAYER_ROLES_ASSIGNED", "LFG_PROPOSAL_UPDATE", "LFG_PROPOSAL_SUCCEEDED", "ROLE_CHANGED_INFORM",
    "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "SPELL_TEXT_UPDATE", "UNIT_LEVEL", "PLAYER_LEVEL_UP",
    "UNIT_HEALTH", "UNIT_HEALTH_FREQUENT", "UNIT_MAXHEALTH", "UNIT_FLAGS", "UNIT_CONNECTION",
    "UNIT_THREAT_SITUATION_UPDATE", "UNIT_THREAT_LIST_UPDATE",
    "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED", "RAID_TARGET_UPDATE", "UNIT_PET" }) do
    pcall(frame.RegisterEvent, frame, e)
end
frame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4)
    local S = EvsHL.S
    if event == "ADDON_LOADED" then
        if arg1 == "HealLane" then Init() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if EvsHL.pending then
            EvsHL.Refresh()
        else
            EvsHL.ApplyVisuals()
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        for _, btn in pairs(EvsHL.buttons) do
            if btn.unit == "target" then
                btn.nh = 0
                btn.trackedHots = nil
                btn.incoming = nil
                btn.incomingSpell = nil
                btn.incomingEnd = nil
            end
        end
        if EvsHL.UpdateTargetOutline then EvsHL.UpdateTargetOutline() end
        if S and not InCombatLockdown() then EvsHL.Refresh() end
    elseif event == "UNIT_HEALTH" or event == "UNIT_HEALTH_FREQUENT"
        or event == "UNIT_MAXHEALTH" or event == "UNIT_FLAGS" or event == "UNIT_CONNECTION"
        or event == "UNIT_THREAT_SITUATION_UPDATE" or event == "UNIT_THREAT_LIST_UPDATE" then
        if S and type(arg1) == "string" then
            for _, btn in pairs(EvsHL.buttons) do
                if btn.unit and btn:IsShown() then
                    local matches = UnitIsUnit(btn.unit, arg1)
                    if not EvsHL.IsSecretValue(matches) and matches then
                        EvsHL.UpdateButton(btn)
                    end
                end
            end
        end
    elseif event == "UNIT_SPELLCAST_SENT" then
        if not S or not S.showIncoming then return end
        if arg1 == "player" then
            local clickTarget = EvsHL.pendingClickTarget
            local targetUnit = clickTarget and GetTime() - clickTarget.time <= 2 and clickTarget.unit
            EvsHL.pendingClickTarget = nil
            if type(arg4) == "number" then
                EvsHL.pendingCast = {
                    spell = EvsHL.SpellNameFromCastEvent(arg2, arg4),
                    target = arg2,
                    targetUnit = targetUnit,
                }
            else
                EvsHL.pendingCast = { spell = arg2, target = arg4, targetUnit = targetUnit }
            end
        else
            EvsHL.pendingCast = nil
        end
    elseif event == "UNIT_SPELLCAST_START" then
        if not S or not S.showIncoming then return end
        if arg1 == "player" then EvsHL.StartIncoming(EvsHL.SpellNameFromCastEvent(arg2, arg3)) end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if not S or not S.showIncoming or arg1 ~= "player" then return end
        local spell = EvsHL.SpellNameFromCastEvent(arg2, arg3)
        local pendingCast = EvsHL.pendingCast
        if pendingCast and pendingCast.spell == spell then
            EvsHL.TrackHotCast(pendingCast.target, spell, pendingCast.targetUnit)
        end
    elseif event == "UNIT_SPELLCAST_DELAYED" then
        if not S or not S.showIncoming then return end
        if arg1 == "player" then
            local _, _, _, _, _, endTime = UnitCastingInfo("player")
            local spell = EvsHL.SpellNameFromCastEvent(arg2, arg3)
            for _, btn in pairs(EvsHL.buttons) do
                if btn.incomingSpell == spell and endTime then btn.incomingEnd = endTime / 1000 end
            end
        end
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        if not S or not S.showIncoming then return end
        if arg1 == "player" then
            EvsHL.ClearIncoming(EvsHL.SpellNameFromCastEvent(arg2, arg3))
            EvsHL.pendingCast = nil
        end
    elseif event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" or event == "SPELL_TEXT_UPDATE" then
        if S then EvsHL.ScanSpells() end
    elseif event == "RAID_TARGET_UPDATE" then
        EvsHL.QueueUpdateUnitRaidIcons()
    else
        if rosterRefreshEvents[event] or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS"
            or event == "ZONE_CHANGED_NEW_AREA" then
            EvsHL.MarkOrderDirty()
        end
        if S and roleClearEvents[event] and EvsHL.NumRaid() == 0 and EvsHL.NumParty() == 0 then
            S.roleOverrides = {}
        end
        if event == "PLAYER_ENTERING_WORLD" and S then
            EvsHL.ScanSpells()
            EvsHL.Refresh()
        end
        if rosterRefreshEvents[event] then
            rosterRefreshRemaining = 0.3
        else
            EvsHL.Refresh()
        end
    end
end)
frame:SetScript("OnUpdate", OnUpdate)
-- ============================================================
-- /hlraid diagnostic slash
-- ============================================================
SLASH_HLRAID1 = "/hlraid"
SlashCmdList["HLRAID"] = function(msg)
    local S = EvsHL.S
    if not S then return end
    local say = function(text) DEFAULT_CHAT_FRAME:AddMessage("HealLane: " .. text) end
    if msg == "builtin" then
        S.raidIconBuiltin = not S.raidIconBuiltin
        say("built-in marker textures " .. (S.raidIconBuiltin and "on" or "off"))
        EvsHL.Refresh()
        return
    end
    for _, btn in ipairs(EvsHL.buttons) do
        if btn:IsShown() and btn.unit and not btn.sim then
            local ok, index = pcall(GetRaidTargetIndex, btn.unit)
            local secret = EvsHL.IsSecretValue(index)
            say(tostring(btn.unit) .. " ok=" .. tostring(ok) .. " secret=" .. tostring(secret)
                .. " index=" .. (secret and "restricted; not passed to marker API" or tostring(index))
                .. " shown=" .. tostring(btn.raidTargetIcon:IsShown())
                .. " tex=" .. tostring(btn.raidTargetIcon:GetTexture()))
            return
        end
    end
    say("no unit button shown")
end
SLASH_HLBUFF1 = "/hlbuff"
SlashCmdList["HLBUFF"] = function()
    local S = EvsHL.S
    local say = function(t) DEFAULT_CHAT_FRAME:AddMessage("HLBuff: " .. t) end
    say("native=" .. tostring(EvsHL.nativeAuraSupported) .. " canScan=" .. tostring(EvsHL.CanScanAuras())
        .. " monitor=" .. tostring(S.monitorMissingBuffs) .. " border=" .. tostring(S.buffBorder)
        .. " combatCheck=" .. tostring(S.checkBuffsInCombat))
    local n = 0
    for k, v in pairs(S.trackBuffs) do n = n + 1; say("track " .. k .. " -> " .. tostring(v)) end
    say("tracked=" .. n)
    for _, btn in ipairs(EvsHL.buttons) do
        if btn:IsShown() and btn.unit and not btn.sim then
            local buffs = {}
            for i = 1, 40 do
                local name, _, _, _, _, d, e, _, _, _, id = EvsHL.GetAura(btn.unit, i, "HELPFUL")
                if EvsHL.IsSecretValue(name) then break end
                if not name then break end
                EvsHL.RecordBuffAura(buffs, name, id, d, e)
            end
            local lacking = {}
            for b, t in pairs(S.trackBuffs) do
                lacking[#lacking + 1] = b .. ":match=" .. tostring(EvsHL.BuffTargetMatches(btn, t))
                    .. ",lack=" .. tostring(EvsHL.BuffLacking(buffs, b))
            end
            say(btn.unit .. " role=" .. tostring(btn.role) .. " pet=" .. tostring(btn.isPet)
                .. " visible=" .. tostring(UnitIsVisible(btn.unit)) .. " missing=" .. tostring(btn.missingBuff)
                .. " | " .. table.concat(lacking, "; "))
            return
        end
    end
end