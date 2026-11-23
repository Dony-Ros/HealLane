local EvsHL = EvsHL
function EvsHL.BuildAppHealing(page)
    local S = EvsHL.S
    local H = EvsHL.ConfigHelpers
    local barBox = H.Section(page, "Health bar", -4, 152)
    H.AddSlider(barBox, "Damaged opacity", 20, -44, "barAlpha", 0, 1, 0.05, EvsHL.ApplyVisuals)
    H.AddSlider(barBox, "Full health opacity", 250, -44, "barAlphaFull", 0, 1, 0.05, EvsHL.ApplyVisuals)
    H.AddColor(barBox, "Damaged Health Color", 14, -88, "thresholdColor", EvsHL.ApplyVisuals)
    H.AddColor(barBox, "Health Bar Color", 243, -88, "barColor", EvsHL.ApplyVisuals)
    H.AddCheck(barBox, "Change bar color below max health", 8, -114, "lowHealthColor", EvsHL.ApplyVisuals)
    H.AddColor(barBox, "Safe nearby color", 243, -120, "nearbyColor", EvsHL.Refresh)
    local incomingBox = H.Section(page, "Incoming heals", -164, 154)
    H.AddCheck(incomingBox, "Show heal prediction bar", 8, -28, "showHealPrediction", EvsHL.ApplyVisuals)
    H.AddColor(incomingBox, "Prediction color", 243, -30, "healPredictionColor", EvsHL.ApplyVisuals)
    H.AddSlider(incomingBox, "HoT lookahead (sec)", 20, -68, "hotLookahead", 1, 10, 1, EvsHL.ApplyVisuals)
    H.AddCheck(incomingBox, "Track casts and HoTs", 8, -112, "showIncoming", EvsHL.ApplyVisuals)
    H.AddColor(incomingBox, "Tracked heal color", 243, -114, "incomingColor", EvsHL.ApplyVisuals)
    local aggroBox = H.Section(page, "Aggro", -328, 66)
    H.AddCheck(aggroBox, "Aggro highlight", 8, -26, "aggroHighlight", EvsHL.ApplyVisuals)
    H.AddColor(aggroBox, "Aggro color", 243, -30, "aggroColor", EvsHL.ApplyVisuals)
    H.AddButton(page, "Reset healing appearance", 0, 0, 190, function()
        for _, key in ipairs({
            "barAlpha", "barAlphaFull", "hotLookahead", "thresholdColor", "barColor", "nearbyColor",
            "lowHealthColor", "aggroHighlight", "aggroColor", "showHealPrediction", "healPredictionColor",
            "showIncoming", "incomingColor",
        }) do
            local default = EvsHL.DEFAULTS[key]
            if type(default) == "table" then
                if type(S[key]) ~= "table" then S[key] = {} end
                for i = 1, #default do S[key][i] = default[i] end
            else
                S[key] = default
            end
        end
        EvsHL.ApplyVisuals()
        EvsHL.Refresh()
        EvsHL.SyncConfig()
    end, "BOTTOMLEFT", nil, 15, 15)
end
