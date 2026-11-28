-- ============================================================
-- HealLane_Constants.lua
-- Creates the global HealLane namespace and defines every shared
-- constant + tiny helper. MUST load before any other HealLane
-- module (it is the very first <Script> in HealLane.xml).
-- ============================================================
local HealLane = {}
_G.HealLane = HealLane

-- ============================================================
-- Shared tiny helpers (defined here so every module can use them
-- regardless of load order).
-- ============================================================
local function IsSecretValue(value)
    return issecretvalue and issecretvalue(value) or false
end
HealLane.IsSecretValue = IsSecretValue

local function HealLaneModUI()
    local library = _G.HealLaneModUI or _G.GameUtilityUI
    if type(library) == "table" then
        return library
    end
end

function HealLane.ApplyPixelPerfectFontString(fontString)
    local library = HealLaneModUI()
    if library and type(library.ApplyPixelPerfectFontString) == "function" then
        return library:ApplyPixelPerfectFontString(fontString)
    end
    return fontString
end

function HealLane.CreateFontString(parent, name, layer, template)
    local library = HealLaneModUI()
    if library and type(library.CreatePixelPerfectFontString) == "function" then
        return library:CreatePixelPerfectFontString(parent, name, layer, template)
    end
    return HealLane.ApplyPixelPerfectFontString(parent:CreateFontString(name, layer, template))
end

local function Copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = Copy(x) end
    return t
end
HealLane.Copy = Copy

local function Merge(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then dst[k] = Copy(v) end
    end
end
HealLane.Merge = Merge

function HealLane.SetTextureColor(texture, r, g, b, a)
    if texture.SetColorTexture then
        texture:SetColorTexture(r, g, b, a)
    else
        texture:SetTexture(r, g, b, a)
    end
end

function HealLane.GetS() return HealLane.S end

-- ============================================================
-- Defaults / constants
-- ============================================================
HealLane.GLOBAL_SETTING_KEYS = {
    locked = true,
    chatRoleIcons = true,
    nameAlert = true,
    hideBlizzardPartyFrames = true,
    hideBlizzardRaidFrames = true,
}

HealLane.DEFAULTS = {
    profileName = "Default",
    pvp = { ["10"] = {}, ["25"] = {}, ["40"] = {} },
    locked = false,
    showPlayer = true,
    hideSolo = false,
    showHots = true,
    debuffBorder = true,
    buffBorder = true,
    aggroHighlight = true,
    lowHealthColor = true,
    classColor = true,
    hpMode = "none",
    fontSize = 10,
    fontFace = "Fonts\\FRIZQT__.TTF",
    fontOutline = "OUTLINE",
    fontMonochrome = false,
    fontShadow = false,
    fontShadowColor = { 0, 0, 0 },
    fontShadowOffsetX = 1,
    fontShadowOffsetY = -1,
    nameFontSize = 0,
    nameFontFace = "",
    nameFontOutline = "inherit",
    nameShadow = "inherit",
    nameShadowColor = { 0, 0, 0 },
    nameShadowOffsetX = 1,
    nameShadowOffsetY = -1,
    nameColorMode = "class",
    nameColor = { 1, 1, 1 },
    nameJustifyH = "CENTER",
    healthFontSize = 0,
    healthFontFace = "",
    healthFontOutline = "inherit",
    healthShadow = "inherit",
    healthShadowColor = { 0, 0, 0 },
    healthShadowOffsetX = 1,
    healthShadowOffsetY = -1,
    healthTextColorMode = "white",
    healthTextColor = { 1, 1, 1 },
    showBorder = false,
    showTooltip = false,
    hoverColor = { 1, 1, 1 },
    hotAnchor = "BOTTOMRIGHT",
    showRoleIcon = true,
    showRaidIcon = true,
    roleIconScale = 1,
    raidIconScale = 1,
    roleIconAnchor = "TOPRIGHT",
    raidTargetIconAnchor = "TOP",
    cols = 3,
    width = 125,
    height = 50,
    padding = 2,
    scale = 1,
    bgAlpha = 0.3,
    hotSize = 20,
    barAlpha = 0.85,
    barAlphaFull = 0.3,
    btnAlpha = 0.35,
    barColor = { 0.2, 0.9, 0.2 },
    nearbyColor = { 0.106, 0.482, 0.106 },
    showResourceBar = false,
    resourceBarWidth = 100,
    resourceBarHeight = 4,
    resourceBarAnchor = "BOTTOM",
    resourceBarOffsetX = 0,
    resourceBarOffsetY = 2,
    thresholdColor = { 0.1, 1, 0.1 },
    aggroColor = { 1, 0, 0 },
    rangeFadeDistance = 60,
    farFadeDistance = 200,
    rangeFallbackAlpha = 0.5,
    showIncoming = false,
    showHealPrediction = true,
    healPredictionColor = { 0.5, 1, 0.7 },
    incomingColor = { 0.3, 1, 0.5 },
    hotLookahead = 3,
    sortByRole = true,
    roleOverrides = {},
    debuffCurseColor = { 1, 0.45, 0.05 },
    debuffPoisonColor = { 0, 0.35, 0.15 },
    debuffDiseaseColor = { 0.62, 0.16, 0.82 },
    debuffMagicColor = { 0.65, 0.65, 0.65 },
    debuffBleedColor = { 0.9, 0.1, 0.1 },
    smartCast = true,
    clicks = {
        ["1"] = "a:target",
        ["2"] = "a:menu",
        ["shift-6"] = "a:role",
        ["shift-7"] = "a:role",
    },
    clickRanks = {},
    clickSets = {},
    activeClickSet = "Default",
    autoDownrank = false,
    hots = {},
    hotsSeen = {},
    hotIDs = {},
    dispel = { spells = {} },
    ignoredDebuffs = {},
    resSpell = "",
    trackBuffs = {},
    monitorMissingBuffs = true,
    buffExpireWarn = 0,
    checkBuffsInCombat = false,
    buffsMissingColor = { 1, 0.5, 0 },
    debuffColor = { 1, 0, 0 },
    debuffIcon = true,
    debuffIconAnchor = "BOTTOMLEFT",
    buffIcon = true,
    frameAnchor = "TOPRIGHT",
    barsAnchor = "LEFT",
    hideBlizzardPartyFrames = false,
    hideBlizzardRaidFrames = false,
    showTempTarget = true,
    showPets = false,
    chatRoleIcons = false,
    nameAlert = false,
}

-- WoW: Forever rank learning levels used by the optional target-level rank rule.
HealLane.SPELL_RANK_LEARN_LEVELS = {
    ["Chain Heal"] = { 40, 46, 54 },
    ["Flash Heal"] = { 20, 26, 32, 38, 44, 50, 56 },
    ["Flash of Light"] = { 20, 26, 34, 42, 50, 58 },
    ["Greater Heal"] = { 40, 46, 52, 58, 60 },
    ["Heal"] = { 16, 22, 28, 34 },
    ["Healing Touch"] = { 1, 8, 14, 20, 26, 32, 38, 44, 50, 56, 60 },
    ["Healing Wave"] = { 1, 6, 12, 18, 24, 32, 40, 48, 56, 60 },
    ["Holy Light"] = { 1, 6, 14, 22, 30, 38, 46, 54, 60 },
    ["Lesser Healing Wave"] = { 20, 28, 36, 44, 52, 60 },
    ["Power Word: Shield"] = { 6, 12, 18, 24, 30, 36, 42, 48, 54, 60 },
    ["Prayer of Healing"] = { 30, 40, 50, 60, 60 },
    ["Regrowth"] = { 12, 18, 24, 30, 36, 42, 48, 54, 60 },
    ["Rejuvenation"] = { 4, 10, 16, 22, 28, 34, 40, 46, 52, 58, 60 },
    ["Renew"] = { 8, 14, 20, 26, 32, 38, 44, 50, 56, 60 },
}

HealLane.KNOWN_HOTS = {
    ["Rejuvenation"] = true,
    ["Regrowth"] = true,
    ["Lifebloom"] = true,
    ["Wild Growth"] = true,
    ["Renew"] = true,
    ["Prayer of Mending"] = true,
    ["Power Word: Shield"] = true,
    ["Riptide"] = true,
    ["Earth Shield"] = true,
    ["Beacon of Light"] = true,
    ["Sacred Shield"] = true,
}

HealLane.MAX_UNITS = 40
HealLane.MAX_HOTS  = 8
HealLane.OUTER     = 4
HealLane.FLAT      = "Interface\\Buttons\\WHITE8x8"
HealLane.FONT      = "Fonts\\FRIZQT__.TTF"
HealLane.MODS      = { "", "shift-", "ctrl-", "alt-", "ctrl-shift-", "alt-shift-", "alt-ctrl-", "alt-ctrl-shift-" }

HealLane.DEBUFF_TYPE_COLORS = {
    Curse   = { r = 1,    g = 0.45, b = 0.05 },
    Poison  = { r = 0,    g = 0.35, b = 0.15 },
    Disease = { r = 0.62, g = 0.16, b = 0.82 },
    Magic   = { r = 0.65, g = 0.65, b = 0.65 },
    Bleed   = { r = 0.9,  g = 0.1,  b = 0.1  },
}
HealLane.DEBUFF_COLOR_KEYS = {
    Curse   = "debuffCurseColor",
    Poison  = "debuffPoisonColor",
    Disease = "debuffDiseaseColor",
    Magic   = "debuffMagicColor",
    Bleed   = "debuffBleedColor",
}

HealLane.BUFF_TARGETS = {
    { "any", "Anyone" },
    { "tank", "Tanks only" },
    { "healer", "Healers only" },
    { "dps", "DPS only" },
    { "self", "Myself only" },
}

HealLane.BUFF_EXPIRE_OPTIONS = {
    { 0, "Off" },
    { 30, "30 seconds" },
    { 60, "1 minute" },
    { 120, "2 minutes" },
    { 300, "5 minutes" },
    { 600, "10 minutes" },
}

-- Seconds left on an aura (math.huge when it has no expiration).
function HealLane.BuffRemaining(duration, expires)
    if HealLane.IsSecretValue(duration) or HealLane.IsSecretValue(expires) then return math.huge end
    if not duration or duration == 0 or not expires or expires == 0 then return math.huge end
    return expires - GetTime()
end

-- True when the buff is absent, or present but inside the expiry warning window.
local wildBuffEquivalents
local function GetWildBuffEquivalent(name)
    if not wildBuffEquivalents and HealLane.GetSpellInfo then
        local markName = HealLane.GetSpellInfo(1126)
        local giftName = HealLane.GetSpellInfo(21849)
        if type(markName) == "string" and type(giftName) == "string" then
            wildBuffEquivalents = {
                [markName] = giftName,
                [giftName] = markName,
            }
        end
    end
    return wildBuffEquivalents and wildBuffEquivalents[name]
end

function HealLane.BuffLacking(buffs, name)
    local remaining = buffs[name]
    if not remaining then
        local equivalent = GetWildBuffEquivalent(name)
        remaining = equivalent and buffs[equivalent]
    end
    if not remaining then return true end
    local warn = HealLane.S and HealLane.S.buffExpireWarn or 0
    return warn > 0 and remaining <= warn
end

function HealLane.RecordBuffAura(buffs, name, spellID, duration, expires)
    if HealLane.IsSecretValue(name) or type(name) ~= "string" then return false end
    local remaining = HealLane.BuffRemaining(duration, expires)
    buffs[name] = math.max(buffs[name] or 0, remaining)
    if type(spellID) == "number" and not HealLane.IsSecretValue(spellID) then
        for _, spell in ipairs(HealLane.spells or {}) do
            if type(spell.name) == "string" and spell.spellIDs and spell.spellIDs[spellID] then
                buffs[spell.name] = math.max(buffs[spell.name] or 0, remaining)
            end
        end
    end
    return true
end

-- Pets never need tracked buffs. Legacy `true` entries mean "any".
function HealLane.BuffTargetMatches(btn, target)
    if not target or btn.isPet then return false end
    if target == true or target == "any" then return true end
    if target == "tank" then return btn.role == "TANK" end
    if target == "healer" then return btn.role == "HEALER" end
    if target == "dps" then return btn.role == "DPS" end
    if target == "self" then return btn.unit ~= nil and UnitIsUnit(btn.unit, "player") and true or false end
    return true
end

-- ============================================================
-- Shared mutable state (populated by later modules / init).
-- ============================================================
HealLane.buttons      = {}
HealLane.pending      = false
HealLane.pendingCast  = nil
HealLane.nativeAuraSupported = false
HealLane.nativeAuraWarnings  = {}

-- Legacy aliases preserved for the config files & external addons.
HealLane.defaults = HealLane.DEFAULTS
HealLane.mods     = HealLane.MODS
HealLane.simCount = 0
HealLane.ver      = 0