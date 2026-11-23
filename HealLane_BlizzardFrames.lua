local EvsHL = EvsHL
local frames = {
    { name = "CompactRaidFrameManager", setting = "hideBlizzardRaidFrames" },
    { name = "CompactRaidFrameContainer", setting = "hideBlizzardRaidFrames" },
    { name = "RaidFrame", setting = "hideBlizzardRaidFrames" },
    { name = "CompactPartyFrame", setting = "hideBlizzardPartyFrames" },
}
local trackedFrames = {}
local restorePending = false

local function HookHide(frame, setting)
    frame:HookScript("OnShow", function(self)
        local currentSettings = EvsHL.S
        if currentSettings and currentSettings[setting] and not InCombatLockdown() then
            self:Hide()
        end
    end)
end

local function Apply(restore)
    local S = EvsHL.S
    if restore then restorePending = true end
    local inCombat = InCombatLockdown()
    for _, entry in ipairs(frames) do
        local frame = _G[entry.name]
        local setting = entry.setting
        if frame and not (frame.IsForbidden and frame:IsForbidden()) then
            local state = trackedFrames[frame]
            if not state then
                state = { wasShown = frame:IsShown() }
                trackedFrames[frame] = state
                HookHide(frame, setting)
            end
            if S and S[setting] then
                if not inCombat and frame:IsShown() then
                    frame:Hide()
                end
            elseif restorePending and not inCombat and state.wasShown and not frame:IsShown() then
                frame:Show()
            end
        end
    end
    if restorePending and not inCombat then restorePending = false end
end

EvsHL.ApplyBlizzardRaidFrames = function(restore) Apply(restore) end
EvsHL.SetBlizzardPartyFramesHidden = function()
    Apply(not (EvsHL.S and EvsHL.S.hideBlizzardPartyFrames))
end
EvsHL.SetBlizzardRaidFramesHidden = function()
    Apply(not (EvsHL.S and EvsHL.S.hideBlizzardRaidFrames))
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function() Apply() end)
