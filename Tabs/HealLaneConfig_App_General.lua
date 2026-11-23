local EvsHL = EvsHL
function EvsHL.BuildAppGeneral(page)
    local S = EvsHL.S
    local H = EvsHL.ConfigHelpers
    local directionBox = H.Section(page, "Direction", -4, 90)
    H.Field(directionBox, "Frame Layout Direction", 20, -30, 120, {
        { "TOPRIGHT", "Right to Left" },
        { "TOPLEFT", "Left to Right" },
    }, function() return S.frameAnchor end, function(v)
        S.frameAnchor = v
        EvsHL.Refresh()
    end)
    H.Field(directionBox, "Health Bar Direction", 250, -30, 120, {
        { "LEFT", "Left to Right" },
        { "RIGHT", "Right to Left" },
    }, function() return S.barsAnchor end, function(v)
        S.barsAnchor = v
        EvsHL.ApplyVisuals()
        EvsHL.Refresh()
    end)
    local rangeBox = H.Section(page, "Range", -102, 160)
    H.AddSlider(rangeBox, "Range fade starts (yd)", 20, -44, "rangeFadeDistance", 10, 120, 5, EvsHL.ApplyVisuals)
    H.AddSlider(rangeBox, "Far fade distance (yd)", 20, -82, "farFadeDistance", 200, 1000, 10, EvsHL.ApplyVisuals)
    H.AddSlider(rangeBox, "Instance out-of-range alpha", 20, -120, "rangeFallbackAlpha", 0.05, 1, 0.05, EvsHL.ApplyVisuals)
    H.Note(rangeBox, "Instances fade unchecked group units too.", 20, -148)
end
