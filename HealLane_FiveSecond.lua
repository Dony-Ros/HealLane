-- Five-second rule ring: a circular line around the player portrait that
-- empties over 5 seconds after every mana-spending cast.
local EvsHL = EvsHL

local DURATION = 5
local SEGMENTS = 90

local ring
local lines = {}
local endTime = 0
local shownCount = SEGMENTS
local lastCastAt = 0
local lastMana

local function FindPortrait()
    if PlayerFramePortrait then
        return PlayerFramePortrait
    end
    if not PlayerFrame then
        return nil
    end
    if PlayerFrame.portrait then
        return PlayerFrame.portrait
    end
    local content = PlayerFrame.PlayerFrameContent
    local main = content and content.PlayerFrameContentMain
    return main and (main.Portrait or main.portrait) or nil
end

local function Layout()
    local S = EvsHL.S
    if not (ring and S) then
        return
    end
    local portrait = FindPortrait()
    ring:ClearAllPoints()
    local size
    if portrait and portrait.GetWidth and portrait:GetWidth() > 1 then
        ring:SetPoint("CENTER", portrait, "CENTER", 0, 0)
        size = portrait:GetWidth()
    else
        ring:SetPoint("CENTER", PlayerFrame, "TOPLEFT", 52, -50)
        size = 58
    end
    local radius = size / 2 + (S.fsrOffset or 3)
    ring:SetSize(radius * 2, radius * 2)
    local color = S.fsrColor or EvsHL.DEFAULTS.fsrColor
    local thickness = S.fsrThickness or 3
    for i = 1, SEGMENTS do
        local line = lines[i]
        if not line then
            line = ring:CreateLine(nil, "OVERLAY")
            lines[i] = line
        end
        local a1 = math.pi / 2 - (i - 1) * 2 * math.pi / SEGMENTS
        local a2 = math.pi / 2 - i * 2 * math.pi / SEGMENTS
        line:SetThickness(thickness)
        line:SetColorTexture(color[1], color[2], color[3], 0.95)
        line:SetStartPoint("CENTER", ring, radius * math.cos(a1), radius * math.sin(a1))
        line:SetEndPoint("CENTER", ring, radius * math.cos(a2), radius * math.sin(a2))
    end
end

local function Ensure()
    if ring then
        return true
    end
    if not PlayerFrame then
        return false
    end
    ring = CreateFrame("Frame", "EvsHLFiveSecondRing", UIParent)
    ring:SetFrameStrata("HIGH")
    ring:SetFrameLevel(50)
    ring:EnableMouse(false)
    ring:Hide()
    ring:SetScript("OnUpdate", function()
        local remaining = endTime - GetTime()
        if remaining <= 0 or not PlayerFrame:IsShown() then
            ring:Hide()
            return
        end
        local visible = math.ceil(remaining / DURATION * SEGMENTS)
        if visible ~= shownCount then
            for i = 1, SEGMENTS do
                lines[i]:SetShown(i <= visible)
            end
            shownCount = visible
        end
    end)
    Layout()
    return true
end

local function Start()
    local S = EvsHL.S
    if not (S and S.fsrEnabled) or not Ensure() then
        return
    end
    endTime = GetTime() + DURATION
    shownCount = SEGMENTS
    for i = 1, SEGMENTS do
        lines[i]:Show()
    end
    ring:Show()
end

function EvsHL.FiveSecond_Apply(preview)
    local S = EvsHL.S
    if not S then
        return
    end
    if S.fsrEnabled then
        if Ensure() then
            Layout()
            if preview then
                Start()
            end
        end
    elseif ring then
        ring:Hide()
    end
end

local function SpendsMana(spellID)
    if type(spellID) ~= "number" or EvsHL.IsSecretValue(spellID) then
        return false
    end
    if not (C_Spell and C_Spell.GetSpellPowerCost) then
        return false
    end
    local ok, costs = pcall(C_Spell.GetSpellPowerCost, spellID)
    if not ok or type(costs) ~= "table" then
        return false
    end
    local mana = Enum and Enum.PowerType and Enum.PowerType.Mana or 0
    for _, entry in ipairs(costs) do
        if not EvsHL.IsSecretValue(entry.type) and entry.type == mana then
            local cost = entry.cost
            if EvsHL.IsSecretValue(cost) or (cost or 0) > 0 then
                return true
            end
        end
    end
    return false
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_DEAD")
events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
events:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
events:SetScript("OnEvent", function(_, event, unit, arg2, arg3)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        lastCastAt = GetTime()
        if SpendsMana(arg3) then
            Start()
        end
    elseif event == "UNIT_POWER_UPDATE" then
        if arg2 == "MANA" then
            local mana = UnitPower("player", Enum and Enum.PowerType and Enum.PowerType.Mana or 0)
            if not EvsHL.IsSecretValue(mana) then
                if lastMana and mana < lastMana and GetTime() - lastCastAt < 0.5 then
                    Start()
                end
                lastMana = mana
            end
        end
    elseif event == "PLAYER_DEAD" then
        if ring then
            ring:Hide()
        end
    else
        EvsHL.FiveSecond_Apply()
    end
end)

SLASH_HLFSR1 = "/hlfsr"
SlashCmdList["HLFSR"] = function()
    local S = EvsHL.S
    if not S then
        return
    end
    S.fsrEnabled = true
    EvsHL.FiveSecond_Apply(true)
end
