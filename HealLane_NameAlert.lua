-- Name alert: briefly flashes a message in the middle of the screen when
-- someone mentions your character name in chat (full name, name, or first 3 or 4 letters).
local EvsHL = EvsHL

local HOLD, FADE = 2.5, 0.6
local CHAT_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE",
    "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_BATTLEGROUND", "CHAT_MSG_BATTLEGROUND_LEADER",
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_CHANNEL", "CHAT_MSG_COMMUNITIES_CHANNEL",
}

local alert, text, shownAt

local function Ensure()
    if alert then
        return
    end
    alert = CreateFrame("Frame", "EvsHLNameAlert", UIParent)
    alert:SetSize(700, 60)
    alert:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    alert:SetFrameStrata("FULLSCREEN_DIALOG")
    alert:EnableMouse(false)
    alert:Hide()
    text = alert:CreateFontString(nil, "OVERLAY")
    text:SetFont(EvsHL.FONT, 24, "OUTLINE")
    text:SetPoint("CENTER")
    text:SetWidth(680)
    alert:SetScript("OnUpdate", function(self)
        local t = GetTime() - shownAt
        if t >= HOLD + FADE then
            self:Hide()
            return
        end
        self:SetAlpha(t <= HOLD and 1 or 1 - (t - HOLD) / FADE)
    end)
end

local function Clean(msg)
    msg = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    msg = msg:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", "")
    if #msg > 90 then
        msg = msg:sub(1, 87) .. "..."
    end
    return msg
end

local function ShowAlert(sender, msg)
    Ensure()
    local who = sender and sender:match("^[^-]+") or "?"
    text:SetText("|cffffd100" .. who .. "|r: " .. Clean(msg))
    shownAt = GetTime()
    alert:SetAlpha(1)
    alert:Show()
end

local function Normalize(s)
    return " " .. s:lower():gsub("[%p%c]", " ") .. " "
end

local function Aliases()
    local name = UnitName("player")
    if not name or name == "" then
        return nil
    end
    local realm = GetNormalizedRealmName and GetNormalizedRealmName() or ""
    local char = "[%z\1-\127\194-\244][\128-\191]*"
    local first3 = name:match("^" .. char:rep(3))
    local first4 = name:match("^" .. char:rep(4))
    return name:lower(), realm ~= "" and (name .. "-" .. realm):lower() or nil,
        first3 and first3:lower() or nil, first4 and first4:lower() or nil
end

local function Mentions(msg)
    local lowerName, full, first3, first4 = Aliases()
    if not lowerName then
        return false
    end
    local plain = msg:lower()
    if full and plain:find(full, 1, true) then
        return true
    end
    local padded = Normalize(msg)
    if padded:find(" " .. lowerName .. " ", 1, true) then
        return true
    end
    for _, alias in ipairs({ first3 or false, first4 or false }) do
        if alias and alias ~= lowerName and padded:find(" " .. alias .. " ", 1, true) then
            return true
        end
    end
    return false
end

local events = CreateFrame("Frame")
for _, event in ipairs(CHAT_EVENTS) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, msg, sender)
    local S = EvsHL.S
    if not (S and S.nameAlert) then
        return
    end
    if type(msg) ~= "string" or EvsHL.IsSecretValue(msg) then
        return
    end
    if type(sender) == "string" and not EvsHL.IsSecretValue(sender) then
        local me = UnitName("player")
        if sender == me or sender:match("^[^-]+") == me then
            return
        end
    end
    local ok, hit = pcall(Mentions, msg)
    if ok and hit then
        ShowAlert(sender, msg)
    end
end)

SLASH_HLALERT1 = "/hlalert"
SlashCmdList["HLALERT"] = function()
    ShowAlert("Someone", "Hey " .. (UnitName("player") or "you") .. ", this is a test alert")
end