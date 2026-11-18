local EvsHL = EvsHL
function EvsHL.BuildAppHealing(page)
    local S = EvsHL.S
    local H = EvsHL.ConfigHelpers -- MOVED INSIDE
    H.AddSlider(page, "Damaged opacity", 25, -30, "barAlpha", 0, 1, 0.05, EvsHL.ApplyVisuals)
    H.AddSlider(page, "Full health opacity", 25, -80, "barAlphaFull", 0, 1, 0.05, EvsHL.ApplyVisuals)
    H.AddSlider(page, "Incoming lookahead (sec)", 25, -130, "hotLookahead", 1, 10, 1, EvsHL.ApplyVisuals)
    H.AddColor(page, "Damaged Health Color", 25, -180, "thresholdColor", EvsHL.ApplyVisuals)
    H.AddColor(page, "Health Bar Color", 25, -230, "barColor", EvsHL.ApplyVisuals)
    H.AddCheck(page, "Change bar color below max health", 25, -280, "lowHealthColor", EvsHL.ApplyVisuals)
    H.AddCheck(page, "Aggro highlight", 25, -308, "aggroHighlight", EvsHL.ApplyVisuals)
    H.AddColor(page, "Aggro color", 25, -346, "aggroColor", EvsHL.ApplyVisuals)
    H.AddCheck(page, "Show incoming heal bar", 25, -384, "showHealPrediction", EvsHL.ApplyVisuals)
    H.AddColor(page, "Incoming heal color", 25, -412, "healPredictionColor", EvsHL.ApplyVisuals)
end