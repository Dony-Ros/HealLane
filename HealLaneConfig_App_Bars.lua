local EvsHL = EvsHL

function EvsHL.BuildAppBars(page)
    local S = EvsHL.S
    local H = EvsHL.ConfigHelpers -- MOVED INSIDE
    H.AddSlider(page, "Columns", 25, -30, "cols", 1, 10, 1, EvsHL.Refresh)
    H.AddSlider(page, "Button width", 25, -80, "width", 60, 250, 5, EvsHL.Refresh)
    H.AddSlider(page, "Button height", 25, -130, "height", 20, 100, 2, EvsHL.Refresh)
    H.AddSlider(page, "Spacing", 25, -180, "padding", 0, 20, 1, EvsHL.Refresh)
    H.AddSlider(page, "Scale", 25, -230, "scale", 0.5, 2, 0.05, EvsHL.ApplyVisuals)
    H.AddSlider(page, "Container background", 260, -30, "bgAlpha", 0, 1, 0.05, EvsHL.ApplyVisuals)
    H.AddSlider(page, "Button background", 260, -80, "btnAlpha", 0, 1, 0.05, EvsHL.ApplyVisuals)
end