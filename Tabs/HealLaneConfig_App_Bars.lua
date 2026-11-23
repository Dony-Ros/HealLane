local EvsHL = EvsHL
function EvsHL.BuildAppBars(page)
    local H = EvsHL.ConfigHelpers
    local layoutBox = H.Section(page, "Layout", -4, 180)
    H.AddSlider(layoutBox, "Columns", 20, -44, "cols", 1, 10, 1, EvsHL.Refresh)
    H.AddSlider(layoutBox, "Button width", 20, -92, "width", 60, 250, 5, EvsHL.Refresh)
    H.AddSlider(layoutBox, "Button height", 20, -140, "height", 20, 100, 2, EvsHL.Refresh)
    H.AddSlider(layoutBox, "Spacing", 250, -44, "padding", 0, 20, 1, EvsHL.Refresh)
    H.AddSlider(layoutBox, "Scale", 250, -92, "scale", 0.5, 2, 0.05, EvsHL.ApplyVisuals)
    local opacityBox = H.Section(page, "Background", -192, 118)
    H.AddSlider(opacityBox, "Container background", 20, -44, "bgAlpha", 0, 1, 0.05, EvsHL.ApplyVisuals)
    H.AddSlider(opacityBox, "Button background", 250, -44, "btnAlpha", 0, 1, 0.05, EvsHL.ApplyVisuals)
    H.AddCheck(opacityBox, "Container border", 8, -80, "showBorder", EvsHL.ApplyVisuals)
    local resourceBox = H.Section(page, "Resource bar", -316, 200)
    H.AddCheck(resourceBox, "Show resource bar", 8, -26, "showResourceBar", EvsHL.Refresh)
    H.AddSlider(resourceBox, "Width (%)", 20, -56, "resourceBarWidth", 20, 100, 5, EvsHL.ApplyVisuals)
    H.AddSlider(resourceBox, "Height", 250, -56, "resourceBarHeight", 1, 12, 1, EvsHL.ApplyVisuals)
    H.Field(resourceBox, "Anchor", 20, -96, 120, {
        { "TOPLEFT", "Top left" }, { "TOP", "Top center" }, { "TOPRIGHT", "Top right" },
        { "LEFT", "Center left" }, { "CENTER", "Center" }, { "RIGHT", "Center right" },
        { "BOTTOMLEFT", "Bottom left" }, { "BOTTOM", "Bottom center" }, { "BOTTOMRIGHT", "Bottom right" },
    }, function() return EvsHL.S.resourceBarAnchor or "BOTTOM" end, function(v)
        EvsHL.S.resourceBarAnchor = v
        EvsHL.ApplyVisuals()
    end)
    H.AddSlider(resourceBox, "X offset", 20, -148, "resourceBarOffsetX", -50, 50, 1, EvsHL.ApplyVisuals)
    H.AddSlider(resourceBox, "Y offset", 250, -148, "resourceBarOffsetY", -50, 50, 1, EvsHL.ApplyVisuals)
end