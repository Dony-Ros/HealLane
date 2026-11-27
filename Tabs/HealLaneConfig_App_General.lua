local HealLane = HealLane
function HealLane.BuildAppGeneral(page)
    local S = HealLane.S
    local H = HealLane.ConfigHelpers
    local directionBox = H.Section(page, "Direction", -4, 90)
    H.Field(directionBox, "Frame Layout Direction", 20, -30, 120, {
        { "TOPRIGHT", "Right to Left" },
        { "TOPLEFT", "Left to Right" },
    }, function() return S.frameAnchor end, function(v)
        S.frameAnchor = v
        HealLane.Refresh()
    end)
    H.Field(directionBox, "Health Bar Direction", 250, -30, 120, {
        { "LEFT", "Left to Right" },
        { "RIGHT", "Right to Left" },
    }, function() return S.barsAnchor end, function(v)
        S.barsAnchor = v
        HealLane.ApplyVisuals()
        HealLane.Refresh()
    end)
    local rangeBox = H.Section(page, "Range", -102, 160)
    H.AddSlider(rangeBox, "Range fade starts (yd)", 20, -44, "rangeFadeDistance", 10, 120, 5, HealLane.ApplyVisuals)
    H.AddSlider(rangeBox, "Far fade distance (yd)", 20, -82, "farFadeDistance", 200, 1000, 10, HealLane.ApplyVisuals)
    local instanceAlpha = H.AddSlider(rangeBox, "Instance out-of-range alpha", 20, -120, "rangeFallbackAlpha", 0.05, 1, 0.05, HealLane.ApplyVisuals)
    H.Tooltip(instanceAlpha, "In instances, unchecked group units fade to this alpha too.")
end
