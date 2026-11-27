-- Raid target marker textures and unit-button updates.
local HealLane = HealLane

HealLane.Raid_Textures = {
    [1] = [[Interface\Addons\HealLane\Textures\raid\1\Star.tga]],
    [2] = [[Interface\Addons\HealLane\Textures\raid\1\Circle.tga]],
    [3] = [[Interface\Addons\HealLane\Textures\raid\1\Diamond.tga]],
    [4] = [[Interface\Addons\HealLane\Textures\raid\1\Triangle.tga]],
    [5] = [[Interface\Addons\HealLane\Textures\raid\1\Moon.tga]],
    [6] = [[Interface\Addons\HealLane\Textures\raid\1\Square.tga]],
    [7] = [[Interface\Addons\HealLane\Textures\raid\1\Cross.tga]],
    [8] = [[Interface\Addons\HealLane\Textures\raid\1\Skull.tga]],
}

function HealLane.UpdateUnitRaidIcon(btn)
    local icon = btn.raidTargetIcon
    local S = HealLane.S
    if btn.sim or not btn.unit or not S or not S.showRaidIcon or not GetRaidTargetIndex then
        icon:Hide()
        return
    end

    local ok, iconIndex = pcall(GetRaidTargetIndex, btn.unit)
    if not ok then
        icon:Hide()
        return
    end

    if HealLane.IsSecretValue(iconIndex) then
        if not SetRaidTargetIconTexture then
            icon:Hide()
            return
        end
        icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        SetRaidTargetIconTexture(icon, iconIndex)
        icon:Show()
        return
    end

    local texture = type(iconIndex) == "number" and HealLane.Raid_Textures[iconIndex]
    if not texture then
        icon:Hide()
        return
    end

    icon:SetTexCoord(0, 1, 0, 1)
    icon:SetTexture(texture)
    icon:Show()
end

function HealLane.QueueUpdateUnitRaidIcons()
    for i = 1, #HealLane.buttons do
        local btn = HealLane.buttons[i]
        if btn and btn:IsShown() and btn.unit then
            HealLane.UpdateUnitRaidIcon(btn)
        end
    end
end
