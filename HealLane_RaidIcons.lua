-- Raid target marker textures and unit-button updates.
local EvsHL = EvsHL

EvsHL.Raid_Textures = {
    [1] = [[Interface\Addons\HealLane\Textures\raid\1\Star.tga]],
    [2] = [[Interface\Addons\HealLane\Textures\raid\1\Circle.tga]],
    [3] = [[Interface\Addons\HealLane\Textures\raid\1\Diamond.tga]],
    [4] = [[Interface\Addons\HealLane\Textures\raid\1\Triangle.tga]],
    [5] = [[Interface\Addons\HealLane\Textures\raid\1\Moon.tga]],
    [6] = [[Interface\Addons\HealLane\Textures\raid\1\Square.tga]],
    [7] = [[Interface\Addons\HealLane\Textures\raid\1\Cross.tga]],
    [8] = [[Interface\Addons\HealLane\Textures\raid\1\Skull.tga]],
}

function EvsHL.UpdateUnitRaidIcon(btn)
    local icon = btn.raidTargetIcon
    local S = EvsHL.S
    if btn.sim or not btn.unit or not S or not S.showRaidIcon or not GetRaidTargetIndex then
        icon:Hide()
        return
    end

    local ok, iconIndex = pcall(GetRaidTargetIndex, btn.unit)
    if not ok then
        icon:Hide()
        return
    end

    if EvsHL.IsSecretValue(iconIndex) then
        if not SetRaidTargetIconTexture then
            icon:Hide()
            return
        end
        icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        SetRaidTargetIconTexture(icon, iconIndex)
        icon:Show()
        return
    end

    local texture = type(iconIndex) == "number" and EvsHL.Raid_Textures[iconIndex]
    if not texture then
        icon:Hide()
        return
    end

    icon:SetTexCoord(0, 1, 0, 1)
    icon:SetTexture(texture)
    icon:Show()
end

function EvsHL.QueueUpdateUnitRaidIcons()
    for i = 1, #EvsHL.buttons do
        local btn = EvsHL.buttons[i]
        if btn and btn:IsShown() and btn.unit then
            EvsHL.UpdateUnitRaidIcon(btn)
        end
    end
end
