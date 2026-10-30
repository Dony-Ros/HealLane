local EvsHL = EvsHL

function EvsHL.BuildAppIcons(page)
    local S = EvsHL.S
    local H = EvsHL.ConfigHelpers -- MOVED INSIDE
    H.AddSlider(page, "HoT icon size", 25, -30, "hotSize", 8, 32, 1, EvsHL.ApplyVisuals)
    H.AddCheck(page, "Show role icon", 25, -75, "showRoleIcon", EvsHL.Refresh)
    H.AddCheck(page, "Show raid target icon", 260, -75, "showRaidIcon", EvsHL.Refresh)
    H.AddSlider(page, "Role icon scale", 25, -120, "roleIconScale", 0.5, 3, 0.1, EvsHL.ApplyVisuals)
    H.AddSlider(page, "Raid icon scale", 260, -120, "raidIconScale", 0.5, 3, 0.1, EvsHL.ApplyVisuals)
    
    H.Label(page, "HoT position", 25, -180)
    H.AddDropdown(page, 25, -200, 120, {
        { "TOPLEFT", "Top left" }, { "TOP", "Top" }, { "TOPRIGHT", "Top right" },
        { "LEFT", "Left" }, { "CENTER", "Center" }, { "RIGHT", "Right" },
        { "BOTTOMLEFT", "Bottom left" }, { "BOTTOM", "Bottom" }, { "BOTTOMRIGHT", "Bottom right" },
    }, function() return S.hotAnchor end, function(v) S.hotAnchor = v EvsHL.ApplyVisuals() end)

    H.Label(page, "Role icon anchor", 25, -255)
    H.AddDropdown(page, 25, -275, 120, {
        { "TOPLEFT", "Top left" }, { "TOP", "Top center" }, { "TOPRIGHT", "Top right" },
        { "LEFT", "Left" }, { "CENTER", "Center" }, { "RIGHT", "Right" },
        { "BOTTOMLEFT", "Bottom left" }, { "BOTTOM", "Bottom center" }, { "BOTTOMRIGHT", "Bottom right" },
    }, function() return S.roleIconAnchor or "TOPRIGHT" end, function(v)
        S.roleIconAnchor = v
        EvsHL.ApplyVisuals()
    end)

    H.Label(page, "Raid target icon anchor", 25, -325)
    H.AddDropdown(page, 25, -345, 120, {
        { "TOPLEFT", "Top left" }, { "TOP", "Top center" }, { "TOPRIGHT", "Top right" },
        { "LEFT", "Left" }, { "CENTER", "Center" }, { "RIGHT", "Right" },
        { "BOTTOMLEFT", "Bottom left" }, { "BOTTOM", "Bottom center" }, { "BOTTOMRIGHT", "Bottom right" },
    }, function() return S.raidTargetIconAnchor or "TOP" end, function(v)
        S.raidTargetIconAnchor = v
        EvsHL.ApplyVisuals()
    end)
end