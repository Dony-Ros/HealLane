-- Party chat role icons: puts a small tank / healer / DPS icon before the
-- sender's name in party (and instance) chat lines.
local EvsHL = EvsHL

local ICONS = {
    TANK = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:0:19:22:41|t",
    HEALER = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:20:39:1:20|t",
    DAMAGER = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:20:39:22:41|t",
}

local function UnitRole(unit)
    if EvsHL.IsTank and EvsHL.IsTank(unit) then
        return "TANK"
    end
    if EvsHL.IsHeal and EvsHL.IsHeal(unit) then
        return "HEALER"
    end
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
    if role == "TANK" or role == "HEALER" then
        return role
    end
    return "DAMAGER"
end

-- Extend RoleOfName to cover raid members (covers raid + BG)
local function RoleOfName(linkName)
    local units = { "player" }
    for i = 1, 4 do
        units[#units + 1] = "party" .. i
    end
    -- Raid covers raid and battleground rosters (max 40)
    for i = 1, 40 do
        units[#units + 1] = "raid" .. i
    end
    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            local name = UnitName(unit)
            local full = GetUnitName and GetUnitName(unit, true)
            if not EvsHL.IsSecretValue(name) and not EvsHL.IsSecretValue(full) then
                if name == linkName or full == linkName then
                    return UnitRole(unit)
                end
            end
        end
    end
end

local function Decorate(text)
    local S = EvsHL.S
    if not (S and S.chatRoleIcons) then return text end
    if type(text) ~= "string" or EvsHL.IsSecretValue(text) then return text end

    local start, _, name = text:find("|Hplayer:([^:|]+)")
    if not start then return text end

    local role = RoleOfName(name)
    if not role then return text end

    return text:sub(1, start - 1) .. ICONS[role] .. " " .. text:sub(start)
end

local function HookFrame(frame)
    if not frame or frame.evsRoleIconsHooked then
        return
    end
    frame.evsRoleIconsHooked = true
    local original = frame.AddMessage
    frame.AddMessage = function(self, text, ...)
        local ok, result = pcall(Decorate, text)
        if ok then
            text = result
        end
        return original(self, text, ...)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
    for i = 1, NUM_CHAT_WINDOWS or 10 do
        HookFrame(_G["ChatFrame" .. i])
    end
end)
