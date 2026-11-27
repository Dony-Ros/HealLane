-- Role detection, role icons, and the Shift+wheel role menu.
local HealLane = HealLane
local function NormalizeRole(role)
    if type(role) ~= "string" or HealLane.IsSecretValue(role) then return nil end
    role = string.upper(role)
    if role == "TANK" or role == "MAINTANK" then return "TANK" end
    if role == "HEALER" then return "HEALER" end
    if role == "DAMAGER" or role == "DPS" then return "DAMAGER" end
end
local function AssignedRole(unit)
    if not unit then return nil end
    if UnitGroupRolesAssigned then
        local ok, role, isHeal, isDPS = pcall(UnitGroupRolesAssigned, unit)
        if ok then
            local normalized = NormalizeRole(role)
            if normalized then return normalized end
            if role == true and not HealLane.IsSecretValue(role) then return "TANK" end
            if isHeal == true and not HealLane.IsSecretValue(isHeal) then return "HEALER" end
            if isDPS == true and not HealLane.IsSecretValue(isDPS) then return "DAMAGER" end
        end
    end
    local raidIndex = tonumber(unit:match("^raid(%d+)$"))
    if raidIndex and GetRaidRosterInfo then
        local ok, _, _, _, _, _, _, _, _, _, raidRole, _, combatRole = pcall(GetRaidRosterInfo, raidIndex)
        if ok then
            local normalized = NormalizeRole(raidRole) or NormalizeRole(combatRole)
            if normalized then return normalized end
        end
    end
    if GetPartyAssignment then
        local ok, isMainTank = pcall(GetPartyAssignment, "MAINTANK", unit)
        if ok and isMainTank == true then return "TANK" end
    end
    if UnitIsUnit(unit, "player") then
        if GetLFGRoles then
            local ok, _, tank, healer, dps = pcall(GetLFGRoles)
            if ok then
                if tank == true then return "TANK" end
                if healer == true then return "HEALER" end
                if dps == true then return "DAMAGER" end
            end
        end
        if GetSpecialization and GetSpecializationRole then
            local ok, spec = pcall(GetSpecialization)
            if ok and spec then
                local okRole, specRole = pcall(GetSpecializationRole, spec)
                if okRole then return NormalizeRole(specRole) end
            end
        end
    end
end
local function UnitRole(unit)
    local S = HealLane.S
    local guid = UnitGUID and UnitGUID(unit)
    if HealLane.IsSecretValue(guid) or type(guid) ~= "string" then guid = nil end
    local override = guid and S and S.roleOverrides and S.roleOverrides[guid]
    if override == "TANK" or override == "HEALER" then return override end
    local role = AssignedRole(unit)
    if role == "TANK" or role == "HEALER" then return role end
    return "DPS"
end
local function IsTank(unit) return UnitRole(unit) == "TANK" end
local function IsHeal(unit) return UnitRole(unit) == "HEALER" end
local function IsDPS(unit)  return UnitRole(unit) == "DPS" end
-- 1 = tank, 2 = player, 3 = healer, 4 = everyone else
local function RolePriority(unit)
    if not UnitExists(unit) then return 4 end
    if IsTank(unit) then return 1 end
    if UnitIsUnit(unit, "player") then return 2 end
    if IsHeal(unit) then return 3 end
    if IsDPS(unit) then return 4 end
    return 4
end
local function SimRole(i, count)
    local tanks = count >= 10 and 2 or 1
    local extraHealers = math.max(math.floor(count / 5) - 1, 0)
    if i <= tanks then return "TANK" end
    if i == tanks + 1 then return "PLAYER" end
    if i <= tanks + 1 + extraHealers then return "HEALER" end
    return "DPS"
end
-- Expose to other modules
HealLane.UnitRole     = UnitRole
HealLane.IsTank       = IsTank
HealLane.IsHeal       = IsHeal
HealLane.IsDPS        = IsDPS
HealLane.RolePriority = RolePriority
HealLane.SimRole      = SimRole
HealLane.AssignedRole = AssignedRole
HealLane.Role_Icons = {
    ["TANK"]   = [[Interface\Addons\HealLane\Textures\role\1\tank.tga]],
    ["HEALER"] = [[Interface\Addons\HealLane\Textures\role\1\healer.tga]],
    ["DPS"]    = [[Interface\Addons\HealLane\Textures\role\1\dps.tga]],
    ["CUSTOM"] = [[Interface\Addons\HealLane\Textures\role\1\dps.tga]],
}
local function IsGrouped()
    return HealLane.NumRaid() > 0 or HealLane.NumParty() > 0
end
function HealLane.UpdateUnitRoleIcon(btn)
    local S = HealLane.S
    if btn.sim then
        local role = HealLane.SimRole(btn.sim, HealLane.simCount or 0)
        if role == "PLAYER" then role = "HEALER" end
        btn.role = role
        if S.showRoleIcon and HealLane.Role_Icons[role] then
            btn.roleIcon:SetTexture(HealLane.Role_Icons[role])
            btn.roleIcon:Show()
        else
            btn.roleIcon:Hide()
        end
        return
    end
    if not btn.unit then
        btn.roleIcon:Hide()
        return
    end
    if not S.showRoleIcon or not IsGrouped() then
        btn.roleIcon:Hide()
        return
    end
    if btn.role then
        btn.roleIcon:Show()
        btn.roleIcon:SetTexture(HealLane.Role_Icons[btn.role])
    else
        btn.roleIcon:Hide()
    end
end
-- Configurable role-menu bindings -----------------------------
local roleMenuFrame = CreateFrame("Frame", "HealLaneRoleMenu", UIParent, "UIDropDownMenuTemplate")
local roleMenuClickSlots = {
    LeftButton = 1,
    RightButton = 2,
    MiddleButton = 3,
    Button4 = 4,
    Button5 = 5,
}
function HealLane.IsRoleMenuBinding(slot)
    local S = HealLane.S
    if not S or not S.clicks then return false end
    local ctrl = IsControlKeyDown()
    local alt = IsAltKeyDown()
    local shift = IsShiftKeyDown()
    local prefix
    if ctrl and alt and shift then
        prefix = "alt-ctrl-shift-"
    elseif alt and ctrl then
        prefix = "alt-ctrl-"
    elseif alt and shift then
        prefix = "alt-shift-"
    elseif ctrl and shift then
        prefix = "ctrl-shift-"
    elseif alt then
        prefix = "alt-"
    elseif ctrl then
        prefix = "ctrl-"
    elseif shift then
        prefix = "shift-"
    else
        prefix = ""
    end
    return S.clicks[prefix .. slot] == "a:role"
end
function HealLane.IsRoleMenuClick(button)
    local slot = roleMenuClickSlots[button]
    return slot and HealLane.IsRoleMenuBinding(slot) or false
end
function HealLane.ShowRoleMenu(btn)
    local S = HealLane.S
    local unit = btn.unit
    if not unit or btn.sim then return end
    local guid = UnitGUID and UnitGUID(unit)
    if HealLane.IsSecretValue(guid) or type(guid) ~= "string" then guid = nil end
    local manualRole = guid and S.roleOverrides and S.roleOverrides[guid]
    UIDropDownMenu_Initialize(roleMenuFrame, function(self, level)
        local tankInfo = UIDropDownMenu_CreateInfo()
        tankInfo.text = manualRole == "TANK" and "Remove tank" or "Add tank"
        tankInfo.func = function()
            if guid then
                S.roleOverrides = S.roleOverrides or {}
                if manualRole == "TANK" then
                    S.roleOverrides[guid] = nil
                else
                    S.roleOverrides[guid] = "TANK"
                end
                btn.role = HealLane.UnitRole(unit)
                HealLane.UpdateUnitRoleIcon(btn)
                HealLane.MarkOrderDirty()
                HealLane.Refresh()
            end
        end
        UIDropDownMenu_AddButton(tankInfo, level)
        local healerInfo = UIDropDownMenu_CreateInfo()
        healerInfo.text = manualRole == "HEALER" and "Remove heal" or "Add heal"
        healerInfo.func = function()
            if guid then
                S.roleOverrides = S.roleOverrides or {}
                if manualRole == "HEALER" then
                    S.roleOverrides[guid] = nil
                else
                    S.roleOverrides[guid] = "HEALER"
                end
                btn.role = HealLane.UnitRole(unit)
                HealLane.UpdateUnitRoleIcon(btn)
                HealLane.MarkOrderDirty()
                HealLane.Refresh()
            end
        end
        UIDropDownMenu_AddButton(healerInfo, level)
        local focusInfo = UIDropDownMenu_CreateInfo()
        focusInfo.text = "Set Focus"
        focusInfo.func = function()
            if InCombatLockdown() then
                DEFAULT_CHAT_FRAME:AddMessage("HealLane: Set Focus is unavailable during combat.")
            elseif FocusUnit then
                FocusUnit(unit)
            end
        end
        UIDropDownMenu_AddButton(focusInfo, level)
    end, "MENU")
    ToggleDropDownMenu(1, nil, roleMenuFrame, "cursor")
end