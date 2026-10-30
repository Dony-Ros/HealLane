local EvsHL = EvsHL

function EvsHL.BuildAppHealing(page)
    local S = EvsHL.S
    local H = EvsHL.ConfigHelpers -- MOVED INSIDE
    H.AddSlider(page, "Damaged opacity", 25, -30, "barAlpha", 0, 1, 0.05, EvsHL.ApplyVisuals)
    H.AddSlider(page, "Full health opacity", 25, -80, "barAlphaFull", 0, 1, 0.05, EvsHL.ApplyVisuals)
    H.AddSlider(page, "Incoming lookahead (sec)", 25, -130, "hotLookahead", 1, 10, 1, EvsHL.ApplyVisuals)
    H.AddSlider(page, "Bright color below (%)", 25, -180, "healthThreshold", 50, 100, 1, EvsHL.ApplyVisuals)
    H.AddColor(page, "Threshold Health Color", 25, -230, "thresholdColor", EvsHL.ApplyVisuals)
    H.AddColor(page, "Health Bar Color", 25, -280, "barColor", EvsHL.ApplyVisuals)
end