local EvsHL = EvsHL

function EvsHL.BuildAppGeneral(page)
    local S = EvsHL.S
    local H = EvsHL.ConfigHelpers -- MOVED INSIDE
    H.Label(page, "Frame Layout Direction", 25, -30)
    H.AddDropdown(page, 25, -50, 120, {
        { "TOPRIGHT", "Right to Left" },
        { "TOPLEFT", "Left to Right" },
    }, function() return S.frameAnchor end, function(v)
        S.frameAnchor = v
        EvsHL.Refresh()
    end)

    H.Label(page, "Health Bar Direction", 25, -120)
    H.AddDropdown(page, 25, -140, 120, {
        { "LEFT", "Left to Right" },
        { "RIGHT", "Right to Left" },
    }, function() return S.barsAnchor end, function(v)
        S.barsAnchor = v
        EvsHL.ApplyVisuals()
        EvsHL.Refresh()
    end)
    H.AddSlider(page, "Range fade starts (yd)", 25, -200, "rangeFadeDistance", 10, 120, 5, EvsHL.ApplyVisuals)
end