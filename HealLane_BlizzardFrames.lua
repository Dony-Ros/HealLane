local HealLane = HealLane
local frames = {
    { name = "CompactRaidFrameContainer", setting = "hideBlizzardRaidFrames" },
    { name = "CompactRaidFrameManager", setting = "hideBlizzardRaidFrames" },
    { name = "RaidFrame", setting = "hideBlizzardRaidFrames" },
    { name = "CompactPartyFrame", setting = "hideBlizzardPartyFrames" },
    { name = "PartyFrame", setting = "hideBlizzardPartyFrames" },
}
local trackedFrames = {}
local restorePending = false
local hidePending = false

local function HookHide(frame, setting)
    frame:HookScript("OnShow", function(self)
        local currentSettings = HealLane.S
        if currentSettings and currentSettings[setting] then
            if InCombatLockdown() then
                hidePending = true
            else
                local state = trackedFrames[self]
                if state then state.wasShown = true end
                self:Hide()
            end
        end
    end)
end

local function ApplyFrame(frame, setting, settings, inCombat)
    if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end

    local state = trackedFrames[frame]
    if not state then
        state = { wasShown = frame:IsShown() }
        trackedFrames[frame] = state
        HookHide(frame, setting)
    end
    if settings and settings[setting] then
        if frame:IsShown() then
            if inCombat then
                hidePending = true
            else
                state.wasShown = true
                frame:Hide()
            end
        end
    elseif restorePending and not inCombat and state.wasShown and not frame:IsShown() then
        frame:Show()
    end
end

local function Apply(restore)
    local S = HealLane.S
    if restore then restorePending = true end
    local inCombat = InCombatLockdown()
    for _, entry in ipairs(frames) do
        ApplyFrame(_G[entry.name], entry.setting, S, inCombat)
    end
    for index = 1, 40 do
        ApplyFrame(_G["CompactPartyFrameMember" .. index], "hideBlizzardPartyFrames", S, inCombat)
    end
    if restorePending and not inCombat then restorePending = false end
    if hidePending and not inCombat then hidePending = false end
end

HealLane.ApplyBlizzardRaidFrames = function(restore) Apply(restore) end
HealLane.SetBlizzardPartyFramesHidden = function()
    Apply(not (HealLane.S and HealLane.S.hideBlizzardPartyFrames))
end
HealLane.SetBlizzardRaidFramesHidden = function()
    Apply(not (HealLane.S and HealLane.S.hideBlizzardRaidFrames))
end

local function HideUnwantedErrorMessages()
    local frame = UIErrorsFrame
    local originalOnEvent = frame and frame:GetScript("OnEvent")
    if not originalOnEvent then return end

    local hiddenMessages = {}
    for _, message in pairs({
        energy = ERR_OUT_OF_ENERGY,
        range = ERR_OUT_OF_RANGE,
    }) do
        if type(message) == "string" then
            hiddenMessages[message] = true
        end
    end

    frame:SetScript("OnEvent", function(self, event, ...)
        if event == "UI_ERROR_MESSAGE" then
            local errorType, message = ...
            message = message or errorType
            if type(message) == "string" and not HealLane.IsSecretValue(message)
                and hiddenMessages[message] then
                return
            end
        end
        return originalOnEvent(self, event, ...)
    end)
end

HideUnwantedErrorMessages()

local function ScheduleHideRetries()
    if C_Timer and C_Timer.After then
        C_Timer.After(0.1, function()
            if not InCombatLockdown() then Apply() end
        end)
        C_Timer.After(0.5, function()
            if not InCombatLockdown() then Apply() end
        end)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("RAID_ROSTER_UPDATE")
events:RegisterEvent("PARTY_MEMBER_ENABLE")
events:RegisterEvent("PARTY_MEMBER_DISABLE")
events:SetScript("OnEvent", function(_, event)
    Apply()
    if event == "PLAYER_REGEN_ENABLED" or event == "GROUP_ROSTER_UPDATE"
        or event == "RAID_ROSTER_UPDATE" then
        ScheduleHideRetries()
    end
end)
