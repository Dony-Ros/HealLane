local HealLane = HealLane
function HealLane.BuildAppBars(page)
    local H = HealLane.ConfigHelpers
    local layoutBox = H.Section(page, "Layout", -4, 180)
    H.AddSlider(layoutBox, "Columns", 20, -44, "cols", 1, 10, 1, HealLane.Refresh)
    H.AddSlider(layoutBox, "Button width", 20, -92, "width", 60, 250, 5, HealLane.Refresh)
    H.AddSlider(layoutBox, "Button height", 20, -140, "height", 20, 100, 2, HealLane.Refresh)
    H.AddSlider(layoutBox, "Spacing", 250, -44, "padding", 0, 20, 1, HealLane.Refresh)
    H.AddSlider(layoutBox, "Scale", 250, -92, "scale", 0.5, 2, 0.05, HealLane.ApplyVisuals)
    local opacityBox = H.Section(page, "Background", -192, 118)
    H.AddSlider(opacityBox, "Container background", 20, -44, "bgAlpha", 0, 1, 0.05, HealLane.ApplyVisuals)
    H.AddSlider(opacityBox, "Button background", 250, -44, "btnAlpha", 0, 1, 0.05, HealLane.ApplyVisuals)
    H.AddCheck(opacityBox, "Container border", 8, -80, "showBorder", HealLane.ApplyVisuals)
    local resourceBox = H.Section(page, "Resource bar", -316, 200)
    H.AddCheck(resourceBox, "Show resource bar", 8, -26, "showResourceBar", HealLane.Refresh)
    H.AddSlider(resourceBox, "Width (%)", 20, -56, "resourceBarWidth", 20, 100, 5, HealLane.ApplyVisuals)
    H.AddSlider(resourceBox, "Height", 250, -56, "resourceBarHeight", 1, 12, 1, HealLane.ApplyVisuals)
    H.Field(resourceBox, "Anchor", 20, -96, 120, {
        { "TOPLEFT", "Top left" }, { "TOP", "Top center" }, { "TOPRIGHT", "Top right" },
        { "LEFT", "Center left" }, { "CENTER", "Center" }, { "RIGHT", "Center right" },
        { "BOTTOMLEFT", "Bottom left" }, { "BOTTOM", "Bottom center" }, { "BOTTOMRIGHT", "Bottom right" },
    }, function() return HealLane.S.resourceBarAnchor or "BOTTOM" end, function(v)
        HealLane.S.resourceBarAnchor = v
        HealLane.ApplyVisuals()
    end)
    H.AddSlider(resourceBox, "X offset", 20, -148, "resourceBarOffsetX", -50, 50, 1, HealLane.ApplyVisuals)
    H.AddSlider(resourceBox, "Y offset", 250, -148, "resourceBarOffsetY", -50, 50, 1, HealLane.ApplyVisuals)
end