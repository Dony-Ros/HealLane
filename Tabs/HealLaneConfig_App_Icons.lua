local HealLane = HealLane
function HealLane.BuildAppIcons(page)
    local S = HealLane.S
    local H = HealLane.ConfigHelpers
    local hotBox = H.Section(page, "HoT & debuff icons", -4, 180)
    H.AddCheck(hotBox, "Show HoT icons", 8, -26, "showHots", HealLane.ApplyVisuals)
    H.AddSlider(hotBox, "HoT icon size", 20, -80, "hotSize", 8, 32, 1, HealLane.ApplyVisuals)
    H.Field(hotBox, "HoT position", 20, -124, 120, {
        { "TOPLEFT", "Top left" }, { "TOP", "Top" }, { "TOPRIGHT", "Top right" },
        { "LEFT", "Left" }, { "CENTER", "Center" }, { "RIGHT", "Right" },
        { "BOTTOMLEFT", "Bottom left" }, { "BOTTOM", "Bottom" }, { "BOTTOMRIGHT", "Bottom right" },
    }, function() return S.hotAnchor end, function(v) S.hotAnchor = v HealLane.ApplyVisuals() end)
    H.Field(hotBox, "Debuff icon position", 250, -124, 120, {
        { "TOPLEFT", "Top left" }, { "TOP", "Top" }, { "TOPRIGHT", "Top right" },
        { "LEFT", "Center left" }, { "CENTER", "Center" }, { "RIGHT", "Center right" },
        { "BOTTOMLEFT", "Bottom left" }, { "BOTTOM", "Bottom" }, { "BOTTOMRIGHT", "Bottom right" },
    }, function() return S.debuffIconAnchor or "BOTTOMLEFT" end, function(v)
        S.debuffIconAnchor = v
        HealLane.ApplyVisuals()
    end)
    local roleBox = H.Section(page, "Role icon", -192, 124)
    H.AddCheck(roleBox, "Show role icon", 8, -26, "showRoleIcon", HealLane.Refresh)
    H.AddSlider(roleBox, "Role icon scale", 20, -84, "roleIconScale", 0.5, 3, 0.1, HealLane.ApplyVisuals)
    H.Field(roleBox, "Role icon anchor", 250, -34, 120, {
        { "TOPLEFT", "Top left" }, { "TOP", "Top center" }, { "TOPRIGHT", "Top right" },
        { "LEFT", "Left" }, { "CENTER", "Center" }, { "RIGHT", "Right" },
        { "BOTTOMLEFT", "Bottom left" }, { "BOTTOM", "Bottom center" }, { "BOTTOMRIGHT", "Bottom right" },
    }, function() return S.roleIconAnchor or "TOPRIGHT" end, function(v)
        S.roleIconAnchor = v
        HealLane.ApplyVisuals()
    end)
    local raidBox = H.Section(page, "Raid target icon", -324, 124)
    H.AddCheck(raidBox, "Show raid target icon", 8, -26, "showRaidIcon", HealLane.Refresh)
    H.AddSlider(raidBox, "Raid icon scale", 20, -84, "raidIconScale", 0.5, 3, 0.1, HealLane.ApplyVisuals)
    H.Field(raidBox, "Raid target icon anchor", 250, -34, 120, {
        { "TOPLEFT", "Top left" }, { "TOP", "Top center" }, { "TOPRIGHT", "Top right" },
        { "LEFT", "Left" }, { "CENTER", "Center" }, { "RIGHT", "Right" },
        { "BOTTOMLEFT", "Bottom left" }, { "BOTTOM", "Bottom center" }, { "BOTTOMRIGHT", "Bottom right" },
    }, function() return S.raidTargetIconAnchor or "TOP" end, function(v)
        S.raidTargetIconAnchor = v
        HealLane.ApplyVisuals()
    end)
end