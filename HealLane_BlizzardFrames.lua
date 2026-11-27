local HealLane = HealLane
local frames = {
    { name = "CompactRaidFrameContainer", setting = "hideBlizzardRaidFrames" },
    { name = "RaidFrame", setting = "hideBlizzardRaidFrames" },
}
local trackedFrames = {}
local restorePending = false

local function HookHide(frame, setting)
    frame:HookScript("OnShow", function(self)
        local currentSettings = HealLane.S
        if currentSettings and currentSettings[setting] and not InCombatLockdown() then
            local state = trackedFrames[self]
            if state then state.wasShown = true end
            self:Hide()
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
        if not inCombat and frame:IsShown() then
            state.wasShown = true
            frame:Hide()
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
    for index = 1, 5 do
        ApplyFrame(_G["CompactPartyFrameMember" .. index], "hideBlizzardPartyFrames", S, inCombat)
    end
    if restorePending and not inCombat then restorePending = false end
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

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:SetScript("OnEvent", function() Apply() end)
