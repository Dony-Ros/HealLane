local EvsHL = EvsHL

function EvsHL.BuildAppIncoming(page)
    local S = EvsHL.S
    local H = EvsHL.ConfigHelpers -- MOVED INSIDE
    H.AddCheck(page, "Enable incoming heals", 25, -30, "showIncoming", EvsHL.ApplyVisuals)
    H.AddColor(page, "Incoming heal color", 25, -70, "incomingColor", EvsHL.ApplyVisuals)
end