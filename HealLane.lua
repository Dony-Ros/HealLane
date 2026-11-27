-- ============================================================
-- HealLane.lua (core)
-- Requires HealLane_Constants.lua to have run first (HealLane table,
-- DEFAULTS, MODS, Copy, Merge, IsSecretValue, SetTextureColor,
-- GetS all live there now).
-- ============================================================
local HealLane = _G.HealLane
-- ============================================================
-- Core spell/aura helpers
-- ============================================================
function HealLane.GetSpellInfo(spell)
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
function HealLane.GetSpellTexture(spell)
    if C_Spell and C_Spell.GetSpellTexture then
        return C_Spell.GetSpellTexture(spell)
    end
    if GetSpellTexture then return GetSpellTexture(spell) end
end
function HealLane.IsSpellInRange(spell, unit)
    local inRange
    if C_Spell and C_Spell.IsSpellInRange then
        inRange = C_Spell.IsSpellInRange(spell, unit)
    elseif IsSpellInRange then
        inRange = IsSpellInRange(spell, unit)
    end
    if inRange == true or inRange == 1 then return true end
    if inRange == false or inRange == 0 then return false end
end
function HealLane.CanScanAuras()
    if HealLane.nativeAuraSupported and InCombatLockdown and InCombatLockdown() then return false end
    if IsInInstance then
        local inInstance, instanceType = IsInInstance()
        if inInstance and (instanceType == "pvp" or instanceType == "arena") then
            return false
        end
    end
    return true
end
function HealLane.GetAura(unit, index, filter)
    if not HealLane.CanScanAuras() then return nil end
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
function HealLane.NumParty()
    if GetNumSubgroupMembers then return GetNumSubgroupMembers() end
    return GetNumPartyMembers and GetNumPartyMembers() or 0
end
function HealLane.NumRaid()
    if IsInRaid then return IsInRaid() and GetNumGroupMembers() or 0 end
    return GetNumRaidMembers and GetNumRaidMembers() or 0
end
function HealLane.CreateBackdropFrame(frameType, name, parent, template)
    if BackdropTemplateMixin then
        template = template and template ~= "" and (template .. ", BackdropTemplate") or "BackdropTemplate"
    end
    return CreateFrame(frameType, name, parent, template)
end
function HealLane.Fmt(n)
    if HealLane.IsSecretValue(n) then return "" end
    n = math.floor(n + 0.5)
    if n < 1000 then return tostring(n) end
    local k = n / 1000
    if k >= 10 then return string.format("%dk", math.floor(k + 0.5)) end
    return (string.format("%.1fk", k):gsub("%.0k", "k"))
end
-- ============================================================
-- Init / saved variables
-- ============================================================
local DATABASE_VERSION = 2
local function Init()
    if type(HealLaneDB) ~= "table" then HealLaneDB = {} end
    if type(HealLaneProfileDB) ~= "table" then HealLaneProfileDB = {} end
    if type(HealLaneProfileDB.profiles) ~= "table" then HealLaneProfileDB.profiles = {} end
    local db = HealLaneDB
    if type(db.clicks) ~= "table" then db.clicks = HealLane.Copy(HealLane.DEFAULTS.clicks) end
    if type(db.clickRanks) ~= "table" then db.clickRanks = {} end
    if type(db.clickSets) ~= "table" then db.clickSets = {} end
    if type(db.activeClickSet) ~= "string" or db.activeClickSet == "" then db.activeClickSet = "Default" end
    if not db.clickSets["Default"] then
        db.clickSets["Default"] = HealLane.CreateClickSetSnapshot(db)
    elseif db.clickSets[db.activeClickSet] == nil then
        db.activeClickSet = "Default"
    end
    db.ver = DATABASE_VERSION
    HealLane.Merge(db, HealLane.DEFAULTS)
    if type(db.pvp) ~= "table" then db.pvp = {} end
    db.pvp["10"] = type(db.pvp["10"]) == "table" and db.pvp["10"] or {}
    db.pvp["25"] = type(db.pvp["25"]) == "table" and db.pvp["25"] or {}
    db.pvp["40"] = type(db.pvp["40"] or nil) == "table" and db.pvp["40"] or {}
    for _, key in ipairs({
        "debuffCurseColor", "debuffPoisonColor", "debuffDiseaseColor", "debuffMagicColor",
        "debuffBleedColor", "aggroColor", "thresholdColor", "barColor", "nearbyColor",
    }) do
        if type(db[key]) ~= "table" then
            db[key] = HealLane.Copy(HealLane.DEFAULTS[key])
        else
            for i = 1, 3 do
                if db[key][i] == nil then db[key][i] = HealLane.DEFAULTS[key][i] end
            end
        end
    end
    if type(db.ignoredDebuffs) ~= "table" then db.ignoredDebuffs = {} end
    if type(db.profileName) ~= "string" or db.profileName == "" then db.profileName = "Default" end
    if not HealLaneProfileDB.profiles["Default"] then
        HealLaneProfileDB.profiles["Default"] = HealLane.CreateProfileSnapshot(db)
    end
    if not HealLaneProfileDB.profiles[db.profileName] then
        HealLaneProfileDB.profiles[db.profileName] = HealLane.CreateProfileSnapshot(db)
    end
    HealLane.S = db
    HealLane.baseDB = db
    HealLane.activePvpSize = nil
    HealLane.profileBaseline = HealLane.Copy(HealLaneProfileDB.profiles[db.profileName]
        or HealLane.CreateProfileSnapshot(db))
    HealLane.nativeAuraSupported = HealLane.ProbeNativeAuraSupport and HealLane.ProbeNativeAuraSupport() or false
    if not HealLane.nativeAuraSupported and HealLane.WarnNativeAura then
        HealLane.WarnNativeAura("unsupported",
            "this client has no native AuraContainer; HoTs and debuffs cannot be refreshed during combat.")
    end
    HealLane.ApplyPosition()
    if HealLane.ApplyBlizzardRaidFrames then HealLane.ApplyBlizzardRaidFrames() end
end
function HealLane.CreateClickSetSnapshot(db)
    db = db or HealLane.baseDB or HealLane.S
    if not db then return {} end
    return {
        clicks = HealLane.Copy(db.clicks or HealLane.DEFAULTS.clicks),
        clickRanks = HealLane.Copy(db.clickRanks or {}),
        resSpell = db.resSpell or "",
        autoDownrank = db.autoDownrank and true or false,
    }
end

function HealLane.EnsureClickSets()
    local db = HealLane.baseDB or HealLane.S
    if not db then return end
    if type(db.clickSets) ~= "table" then db.clickSets = {} end
    if type(db.activeClickSet) ~= "string" or db.activeClickSet == "" then db.activeClickSet = "Default" end
    if not db.clickSets["Default"] then db.clickSets["Default"] = HealLane.CreateClickSetSnapshot(db) end
    if not db.clickSets[db.activeClickSet] then db.activeClickSet = "Default" end
end

function HealLane.ClickSetNames()
    HealLane.EnsureClickSets()
    local db = HealLane.baseDB or HealLane.S
    local names = {}
    for name in pairs(db.clickSets) do names[#names + 1] = name end
    table.sort(names)
    if not tContains(names, "Default") then table.insert(names, "Default") end
    table.sort(names)
    return names
end

function HealLane.SaveActiveClickSet()
    HealLane.EnsureClickSets()
    local db = HealLane.baseDB or HealLane.S
    local source = HealLane.S or db
    db.clickSets[db.activeClickSet] = HealLane.CreateClickSetSnapshot(source)
end

function HealLane.ApplyClickSet(name)
    name = type(name) == "string" and name:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if name == "" then return false end
    HealLane.SaveActiveClickSet()
    local db = HealLane.baseDB or HealLane.S
    if type(db.clickSets[name]) ~= "table" then return false end
    db.activeClickSet = name
    local set = db.clickSets[name]
    db.clicks = HealLane.Copy(set.clicks or HealLane.DEFAULTS.clicks)
    db.clickRanks = HealLane.Copy(set.clickRanks or {})
    db.resSpell = set.resSpell or ""
    db.autoDownrank = set.autoDownrank and true or false
    if HealLane.S and HealLane.S ~= db then
        HealLane.S.clicks = HealLane.Copy(db.clicks)
        HealLane.S.clickRanks = HealLane.Copy(db.clickRanks)
        HealLane.S.resSpell = db.resSpell
        HealLane.S.autoDownrank = db.autoDownrank
    end
    HealLane.AutoSaveActiveProfile()
    HealLane.Refresh()
    HealLane.SyncConfig()
    return true
end

function HealLane.CreateClickSet(name)
    name = type(name) == "string" and name:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if name == "" then return false end
    HealLane.SaveActiveClickSet()
    local db = HealLane.baseDB or HealLane.S
    db.clickSets[name] = HealLane.CreateClickSetSnapshot(db)
    db.activeClickSet = name
    HealLane.AutoSaveActiveProfile()
    HealLane.SyncConfig()
    return true
end

function HealLane.DeleteClickSet(name)
    name = type(name) == "string" and name:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if name == "" or name == "Default" then return false end
    local db = HealLane.baseDB or HealLane.S
    if not db.clickSets[name] then return false end
    db.clickSets[name] = nil
    if db.activeClickSet == name then
        db.activeClickSet = "Default"
        local set = db.clickSets.Default
        db.clicks = HealLane.Copy(set.clicks or HealLane.DEFAULTS.clicks)
        db.clickRanks = HealLane.Copy(set.clickRanks or {})
        db.resSpell = set.resSpell or ""
        db.autoDownrank = set.autoDownrank and true or false
        if HealLane.S and HealLane.S ~= db then
            HealLane.S.clicks = HealLane.Copy(db.clicks)
            HealLane.S.clickRanks = HealLane.Copy(db.clickRanks)
            HealLane.S.resSpell = db.resSpell
            HealLane.S.autoDownrank = db.autoDownrank
        end
    end
    HealLane.AutoSaveActiveProfile()
    HealLane.SyncConfig()
    return true
end

function HealLane.CreateProfileSnapshot(db)
    db = db or HealLane.baseDB or HealLane.S
    if not db then return {} end
    local snapshot = HealLane.Copy(db)
    snapshot.profileName = nil
    snapshot.pvp = nil
    snapshot.ver = nil
    snapshot.roleOverrides = {}
    snapshot.pvp = { ["10"] = {}, ["25"] = {}, ["40"] = {} }
    if type(db.pvp) == "table" then
        snapshot.pvp["10"] = HealLane.Copy(db.pvp["10"] or {})
        snapshot.pvp["25"] = HealLane.Copy(db.pvp["25"] or {})
        snapshot.pvp["40"] = HealLane.Copy(db.pvp["40"] or {})
    end
    return snapshot
end

function HealLane.CreateProfileName(name)
    name = type(name) == "string" and name:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if name == "" then return nil end
    return name
end

function HealLane.DeepEqual(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for key, value in pairs(a) do
        if not HealLane.DeepEqual(value, b[key]) then return false end
    end
    for key, value in pairs(b) do
        if not HealLane.DeepEqual(value, a[key]) then return false end
    end
    return true
end

function HealLane.HasUnsavedProfileChanges()
    if not HealLane.baseDB then return false end
    HealLane.CapturePvpChanges()
    local current = HealLane.CreateProfileSnapshot(HealLane.baseDB)
    return not HealLane.profileBaseline or not HealLane.DeepEqual(current, HealLane.profileBaseline)
end

function HealLane.SaveProfile(name)
    HealLane.CapturePvpChanges()
    name = HealLane.CreateProfileName(name)
    if not name then return false, "Enter a profile name." end
    HealLaneProfileDB.profiles[name] = HealLane.CreateProfileSnapshot(HealLane.baseDB or HealLane.S)
    HealLane.baseDB.profileName = name
    HealLane.profileBaseline = HealLane.Copy(HealLaneProfileDB.profiles[name])
    return true
end

function HealLane.ApplyProfile(name)
    name = HealLane.CreateProfileName(name)
    if not name or type(HealLaneProfileDB.profiles[name]) ~= "table" then return false end
    HealLane.CapturePvpChanges()
    local previousPvpSize = HealLane.activePvpSize
    HealLane.activePvpSize = nil
    local db = HealLane.baseDB
    wipe(db)
    for key, value in pairs(HealLaneProfileDB.profiles[name]) do
        db[key] = HealLane.Copy(value)
    end
    HealLane.Merge(db, HealLane.DEFAULTS)
    db.profileName = name
    db.ver = DATABASE_VERSION
    if type(db.pvp) ~= "table" then db.pvp = {} end
    db.pvp["10"] = type(db.pvp["10"]) == "table" and db.pvp["10"] or {}
    db.pvp["25"] = type(db.pvp["25"]) == "table" and db.pvp["25"] or {}
    db.pvp["40"] = type(db.pvp["40"]) == "table" and db.pvp["40"] or {}
    HealLane.Refresh()
    HealLane.ApplyPosition()
    HealLane.ApplyVisuals()
    HealLane.S = db
    if previousPvpSize then HealLane.ApplyPvpSettings(previousPvpSize) end
    HealLane.profileBaseline = HealLane.Copy(HealLaneProfileDB.profiles[name])
    return true
end

function HealLane.RequestProfileSwitch(name, dropdown, nameEdit, refreshStatus, refreshOptions)
    name = HealLane.CreateProfileName(name)
    if not name or type(HealLaneProfileDB.profiles[name]) ~= "table" then
        if dropdown then dropdown:SetValue(HealLane.baseDB.profileName or "Default") end
        return false
    end
    local active = HealLane.baseDB.profileName or "Default"
    if name == active then
        if dropdown then dropdown:SetValue(active) end
        return true
    end

    HealLane.AutoSaveActiveProfile()
    if HealLane.ApplyProfile(name) then
        if nameEdit then nameEdit:SetText("") end
        if dropdown then dropdown:SetValue(name) end
        if refreshOptions then refreshOptions() end
        if refreshStatus then refreshStatus() end
        return true
    end
    return false
end

function HealLane.DeleteProfile(name)
    name = HealLane.CreateProfileName(name)
    if not name or name == "Default" or not HealLaneProfileDB.profiles[name] then return false end
    HealLaneProfileDB.profiles[name] = nil
    if HealLane.baseDB.profileName == name then HealLane.ApplyProfile("Default") end
    return true
end

function HealLane.ProfileNames()
    if type(HealLaneProfileDB) ~= "table" then HealLaneProfileDB = {} end
    if type(HealLaneProfileDB.profiles) ~= "table" then HealLaneProfileDB.profiles = {} end
    if not HealLaneProfileDB.profiles["Default"] then
        HealLaneProfileDB.profiles["Default"] = HealLane.CreateProfileSnapshot(HealLane.baseDB)
    end
    if HealLane.baseDB and (not HealLane.baseDB.profileName or HealLane.baseDB.profileName == "") then
        HealLane.baseDB.profileName = "Default"
    end
    local names = {}
    for name in pairs(HealLaneProfileDB.profiles) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

function HealLane.AutoSaveActiveProfile()
    if not HealLane.baseDB then return end
    HealLane.CapturePvpChanges()
    HealLane.SaveActiveClickSet()
    local name = HealLane.baseDB.profileName or "Default"
    if name == "" then name = "Default" end
    HealLaneProfileDB.profiles[name] = HealLane.CreateProfileSnapshot(HealLane.baseDB)
    HealLane.profileBaseline = HealLane.Copy(HealLaneProfileDB.profiles[name])
end

function HealLane.CapturePvpChanges()
    if not HealLane.activePvpSize or not HealLane.baseDB or type(HealLane.S) ~= "table" then return end
    local size = tostring(HealLane.activePvpSize)
    local effective = HealLane.S
    for key in pairs(HealLane.GLOBAL_SETTING_KEYS) do
        HealLane.baseDB[key] = HealLane.Copy(effective[key])
    end
    local snapshot = {}
    for key, value in pairs(effective) do
        if not HealLane.GLOBAL_SETTING_KEYS[key] and key ~= "profileName" and key ~= "pvp" and key ~= "ver" then
            snapshot[key] = HealLane.Copy(value)
        end
    end
    HealLane.baseDB.pvp[size] = snapshot
end

function HealLane.ApplyPvpSettings(size)
    size = tostring(size)
    if size ~= "10" and size ~= "25" and size ~= "40" then size = "40" end
    HealLane.CapturePvpChanges()
    local db = HealLane.baseDB
    local effective = HealLane.Copy(db)
    if type(db.pvp[size]) == "table" then
        for key, value in pairs(db.pvp[size]) do effective[key] = HealLane.Copy(value) end
    end
    HealLane.S = effective
    HealLane.activePvpSize = size
    HealLane.Refresh()
    HealLane.ApplyPosition()
    HealLane.ApplyVisuals()
end

function HealLane.ExitPvpSettings()
    if not HealLane.activePvpSize then return end
    HealLane.CapturePvpChanges()
    HealLane.activePvpSize = nil
    HealLane.S = HealLane.baseDB
    HealLane.AutoSaveActiveProfile()
    HealLane.Refresh()
    HealLane.ApplyPosition()
    HealLane.ApplyVisuals()
end

function HealLane.SetSetting(key, value)
    if HealLane.activePvpSize and not HealLane.GLOBAL_SETTING_KEYS[key] then
        HealLane.S[key] = HealLane.Copy(value)
        HealLane.baseDB.pvp[tostring(HealLane.activePvpSize)][key] = HealLane.Copy(value)
    else
        HealLane.baseDB[key] = HealLane.Copy(value)
        HealLane.S[key] = HealLane.Copy(value)
    end
    HealLane.AutoSaveActiveProfile()
end

function HealLane.SetSimulation(count)
    HealLane.simCount = count or 0
    HealLane.Refresh()
end
function HealLane.ResetPosition()
    local db = HealLane.S
    if not db then return end
    db.pos = nil
    HealLane.ApplyPosition()
end
function HealLane.ResetAll()
    local db = HealLane.S
    if not db then return end
    wipe(db)
    HealLane.Merge(db, HealLane.DEFAULTS)
    db.ver = DATABASE_VERSION
    HealLane.EnsureClickSets()
    if type(db.clickSets) == "table" and not db.clickSets["Default"] then
        db.clickSets["Default"] = HealLane.CreateClickSetSnapshot(db)
    end
    HealLane.ApplyPosition()
    if HealLane.ApplyBlizzardRaidFrames then HealLane.ApplyBlizzardRaidFrames(true) end
    HealLane.AutoSaveActiveProfile()
    HealLane.SyncConfig()
    HealLane.Refresh()
end
-- ============================================================
-- OnUpdate driver
-- ============================================================
local lastTargetName = nil
local lastTargetWasSecret = false
local acc = 0
local rosterRefreshRemaining
function HealLane.SetRosterRefreshRemaining(v) rosterRefreshRemaining = v end
function HealLane.GetRosterRefreshRemaining() return rosterRefreshRemaining end
function HealLane.ClearRosterRefreshRemaining() rosterRefreshRemaining = nil end
-- ============================================================
-- OnUpdate driver
-- ============================================================
local lastTempTargetState = false
local acc = 0
local rosterRefreshRemaining
function HealLane.SetRosterRefreshRemaining(v) rosterRefreshRemaining = v end
function HealLane.GetRosterRefreshRemaining() return rosterRefreshRemaining end
function HealLane.ClearRosterRefreshRemaining() rosterRefreshRemaining = nil end
local function OnUpdate(_, elapsed)
    local db = HealLane.S
    if not db then return end
    if rosterRefreshRemaining then
        rosterRefreshRemaining = rosterRefreshRemaining - elapsed
        if rosterRefreshRemaining <= 0 then
            rosterRefreshRemaining = nil
            HealLane.Refresh()
        end
    end
    if db.showTempTarget then
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
            if not InCombatLockdown() then HealLane.Refresh() end
        end
    end
    acc = acc + elapsed
    if acc < (HealLane.activeCount and HealLane.activeCount > 5 and 0.2 or 0.1) then return end
    acc = 0
    for i = 1, #HealLane.buttons do
        local btn = HealLane.buttons[i]
        if btn and btn:IsShown() and btn.unit then HealLane.UpdateButton(btn) end
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
    local db = HealLane.S
    if event == "ADDON_LOADED" then
        if arg1 == "HealLane" then Init() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if HealLane.pending then
            HealLane.Refresh()
        else
            HealLane.ApplyVisuals()
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        for _, btn in pairs(HealLane.buttons) do
            if btn.unit == "target" then
                btn.nh = 0
                btn.trackedHots = nil
                btn.incoming = nil
                btn.incomingSpell = nil
                btn.incomingEnd = nil
            end
        end
        if HealLane.UpdateTargetOutline then HealLane.UpdateTargetOutline() end
        if db and not InCombatLockdown() then HealLane.Refresh() end
    elseif event == "UNIT_HEALTH" or event == "UNIT_HEALTH_FREQUENT"
        or event == "UNIT_MAXHEALTH" or event == "UNIT_FLAGS" or event == "UNIT_CONNECTION"
        or event == "UNIT_THREAT_SITUATION_UPDATE" or event == "UNIT_THREAT_LIST_UPDATE" then
        if db and type(arg1) == "string" then
            for _, btn in pairs(HealLane.buttons) do
                if btn.unit and btn:IsShown() then
                    local matches = UnitIsUnit(btn.unit, arg1)
                    if not HealLane.IsSecretValue(matches) and matches then
                        HealLane.UpdateButton(btn)
                    end
                end
            end
        end
    elseif event == "UNIT_SPELLCAST_SENT" then
        if not db or not db.showIncoming then return end
        if arg1 == "player" then
            local clickTarget = HealLane.pendingClickTarget
            local targetUnit = clickTarget and GetTime() - clickTarget.time <= 2 and clickTarget.unit
            HealLane.pendingClickTarget = nil
            if type(arg4) == "number" then
                HealLane.pendingCast = {
                    spell = HealLane.SpellNameFromCastEvent(arg2, arg4),
                    target = arg2,
                    targetUnit = targetUnit,
                }
            else
                HealLane.pendingCast = { spell = arg2, target = arg4, targetUnit = targetUnit }
            end
        else
            HealLane.pendingCast = nil
        end
    elseif event == "UNIT_SPELLCAST_START" then
        if not db or not db.showIncoming then return end
        if arg1 == "player" then HealLane.StartIncoming(HealLane.SpellNameFromCastEvent(arg2, arg3)) end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if not db or not db.showIncoming or arg1 ~= "player" then return end
        local spell = HealLane.SpellNameFromCastEvent(arg2, arg3)
        local pendingCast = HealLane.pendingCast
        if pendingCast and pendingCast.spell == spell then
            HealLane.TrackHotCast(pendingCast.target, spell, pendingCast.targetUnit)
        end
    elseif event == "UNIT_SPELLCAST_DELAYED" then
        if not db or not db.showIncoming then return end
        if arg1 == "player" then
            local _, _, _, _, _, endTime = UnitCastingInfo("player")
            local spell = HealLane.SpellNameFromCastEvent(arg2, arg3)
            for _, btn in pairs(HealLane.buttons) do
                if btn.incomingSpell == spell and endTime then btn.incomingEnd = endTime / 1000 end
            end
        end
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        if not db or not db.showIncoming then return end
        if arg1 == "player" then
            HealLane.ClearIncoming(HealLane.SpellNameFromCastEvent(arg2, arg3))
            HealLane.pendingCast = nil
        end
    elseif event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" or event == "SPELL_TEXT_UPDATE" then
        if db then HealLane.ScanSpells() end
    elseif event == "RAID_TARGET_UPDATE" then
        HealLane.QueueUpdateUnitRaidIcons()
    else
        if rosterRefreshEvents[event] or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS"
            or event == "ZONE_CHANGED_NEW_AREA" then
            HealLane.MarkOrderDirty()
        end
        if db and roleClearEvents[event] and HealLane.NumRaid() == 0 and HealLane.NumParty() == 0 then
            db.roleOverrides = {}
        end
        if (event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA"
            or event == "GROUP_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED"
            or event == "RAID_ROSTER_UPDATE") and db then
            HealLane.UpdatePvpContext()
        end
        if event == "PLAYER_ENTERING_WORLD" and db then
            HealLane.ScanSpells()
            HealLane.Refresh()
        end
        if rosterRefreshEvents[event] then
            rosterRefreshRemaining = 0.3
        else
            HealLane.Refresh()
        end
    end
end)
frame:SetScript("OnUpdate", OnUpdate)

function HealLane.UpdatePvpContext()
    local inInstance, instanceType = IsInInstance()
    if inInstance and instanceType == "pvp" then
        local count = HealLane.NumRaid()
        if count < 1 then count = HealLane.NumParty() + (UnitExists("player") and 1 or 0) end
        local size = 40
        if count <= 10 then size = 10
        elseif count <= 25 then size = 25 end
        if tostring(HealLane.activePvpSize) ~= tostring(size) then
            HealLane.ApplyPvpSettings(size)
        end
    elseif HealLane.activePvpSize then
        HealLane.ExitPvpSettings()
    end
end