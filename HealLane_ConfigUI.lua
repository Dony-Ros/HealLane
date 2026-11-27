local HealLane = _G.HealLane
local ConfigUI = {}
HealLane.ConfigUI = ConfigUI

local DEFAULT_COLORS = {
    bg = { 0.09, 0.09, 0.10 },
    panel = { 0.12, 0.12, 0.13 },
    control = { 0.16, 0.16, 0.18 },
    border = { 0.22, 0.22, 0.25 },
    accent = { 0.36, 0.56, 0.96 },
    accentDim = { 0.17, 0.24, 0.38 },
    text = { 0.86, 0.86, 0.88 },
    muted = { 0.55, 0.55, 0.60 },
}

function ConfigUI:GetLibrary()
    local library = _G.HealLaneModUI or _G.GameUtilityUI
    if type(library) == "table" then return library end
end

function ConfigUI:GetColors()
    local addon = _G.HealLaneMod or _G.GameUtility
    return addon and addon.colors or DEFAULT_COLORS
end

function ConfigUI:WrapText(fontString, width)
    local library = self:GetLibrary()
    if library and library.WrapTextToWidth then
        return library:WrapTextToWidth(fontString, width)
    end
    if fontString then
        fontString:SetWidth(width)
        if fontString.SetWordWrap then fontString:SetWordWrap(true) end
    end
    return fontString
end

function ConfigUI:CreateBackdropFrame(frameType, name, parent, template)
    if BackdropTemplateMixin then
        template = template and template ~= "" and (template .. ", BackdropTemplate") or "BackdropTemplate"
    end
    return CreateFrame(frameType, name, parent, template)
end

function ConfigUI:CreateButton(parent, text, width, height, onClick)
    local library = self:GetLibrary()
    local button
    if library and library.CreateButton then
        button = library:CreateButton(parent, self:GetColors(), text, width, height)
    else
        button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        button:SetText(text or "")
    end
    button:SetSize(width, height)
    if onClick then button:SetScript("OnClick", onClick) end
    return button
end

function ConfigUI:CreateIconButton(parent, width, height, onClick)
    local library = self:GetLibrary()
    if library and library.CreateIconButton then
        return library:CreateIconButton(parent, self:GetColors(), width, height, onClick)
    end

    local button = self:CreateButton(parent, "", width, height, onClick)
    button.icon = button:CreateTexture(nil, "OVERLAY")
    local iconSize = math.max(1, math.min(height - 6, 20))
    button.icon:SetSize(iconSize, iconSize)
    button.icon:SetPoint("LEFT", 5, 0)
    button.icon:SetDrawLayer("OVERLAY")
    button.text = HealLane.CreateFontString(button, nil, "OVERLAY", "GameFontHighlight")
    button.text:SetPoint("LEFT", button.icon, "RIGHT", 8, 0)
    button.text:SetPoint("RIGHT", -6, 0)
    button.text:SetJustifyH("LEFT")
    return button
end

function ConfigUI:CreateTabButton(parent, text, width, height, onClick)
    local library = self:GetLibrary()
    if library and library.CreateTabButton then
        return library:CreateTabButton(parent, self:GetColors(), text, width, height, onClick)
    end

    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, height)
    button:SetText(text or "")
    button:SetScript("OnClick", onClick)
    self:SetTabSelected(button, false)
    return button
end

function ConfigUI:SetTooltip(element, text)
    if not element or not text or text == "" then return end

    local target = element.slider or element.button or element
    target.HealLaneTooltipText = text
    if target.HealLaneTooltipHooked then return end

    target.HealLaneTooltipHooked = true
    if target.EnableMouse then target:EnableMouse(true) end
    local onEnter = target:GetScript("OnEnter")
    local onLeave = target:GetScript("OnLeave")
    target:SetScript("OnEnter", function(self, ...)
        if onEnter then onEnter(self, ...) end
        local tooltipText = self.HealLaneTooltipText
        if not tooltipText then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(tooltipText)
        GameTooltip:Show()
    end)
    target:SetScript("OnLeave", function(self, ...)
        if onLeave then onLeave(self, ...) end
        GameTooltip:Hide()
    end)
end

function ConfigUI:CreateDropdown(parent, name, width, options, selectedValue, onSelect)
    local library = self:GetLibrary()
    if library and library.CreateDropdown then
        return library:CreateDropdown(parent, self:GetColors(), nil, options, selectedValue, onSelect, width)
    end

    local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dropdown.options = options
    UIDropDownMenu_SetWidth(dropdown, width)
    function dropdown:SetValue(value)
        self.selectedValue = value
        for _, option in ipairs(self.options) do
            if option.value == value then
                UIDropDownMenu_SetText(self, option.label)
                return
            end
        end
        UIDropDownMenu_SetText(self, "")
    end
    function dropdown:SetOptions(newOptions)
        self.options = newOptions
        self:SetValue(self.selectedValue)
    end
    UIDropDownMenu_Initialize(dropdown, function(_, level)
        for _, option in ipairs(dropdown.options) do
            local item = option
            local info = UIDropDownMenu_CreateInfo()
            info.text = item.label
            info.checked = dropdown.selectedValue == item.value
            info.func = function()
                dropdown:SetValue(item.value)
                onSelect(item.value)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    dropdown:SetValue(selectedValue)
    return dropdown
end

function ConfigUI:CreateMultiDropdown(parent, name, width, options, getSummary, isSelected, onToggle)
    local library = self:GetLibrary()
    if library and library.CreateMultiDropdown then
        local values = {}
        for _, option in ipairs(options) do
            values[#values + 1] = { value = option, label = option }
        end
        return library:CreateMultiDropdown(parent, self:GetColors(), values, isSelected, onToggle, getSummary, width)
    end

    local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dropdown, width)
    function dropdown:Refresh()
        UIDropDownMenu_SetText(self, getSummary())
    end
    UIDropDownMenu_Initialize(dropdown, function(_, level)
        for _, option in ipairs(options) do
            local item = option
            local info = UIDropDownMenu_CreateInfo()
            info.text = item
            info.isNotRadio = true
            info.keepShownOnClick = true
            info.checked = function() return isSelected(item) end
            info.func = function()
                onToggle(item)
                dropdown:Refresh()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    dropdown:Refresh()
    return dropdown
end

function ConfigUI:CreateSlider(parent, name, label, width, minimum, maximum, step, value, onValueChanged)
    local library = self:GetLibrary()
    if library and library.CreateSlider then
        return library:CreateSlider(parent, self:GetColors(), label, minimum, maximum, step, value, onValueChanged, width)
    end

    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetWidth(width)
    slider:SetMinMaxValues(minimum, maximum)
    slider:SetValueStep(step)
    self:StyleSlider(slider)
    _G[name .. "Low"]:SetText(minimum)
    _G[name .. "High"]:SetText(maximum)
    local text = _G[name .. "Text"]
    slider:SetValue(value)
    text:SetText(label .. ": " .. slider:GetValue())
    slider:SetScript("OnValueChanged", function(self, currentValue)
        text:SetText(label .. ": " .. currentValue)
        if onValueChanged then onValueChanged(currentValue) end
    end)
    return slider
end

function ConfigUI:CreateCheckbox(parent, name, text, checked, onClick)
    local library = self:GetLibrary()
    if library and library.CreateCheckbox then
        return library:CreateCheckbox(parent, self:GetColors(), text, checked, onClick)
    end

    local checkbox = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    checkbox:SetChecked(checked and true or false)
    local label = name and _G[name .. "Text"]
    if label then
        label:SetText(text)
        checkbox:SetHitRectInsets(0, -label:GetStringWidth() - 4, 0, 0)
    end
    checkbox:SetScript("OnClick", function(self)
        onClick(self:GetChecked() and true or false)
    end)
    return checkbox
end

function ConfigUI:SetButtonSelected(button, selected)
    local library = self:GetLibrary()
    if not selected then
        self:StyleButton(button)
    end
    if library and library.SetButtonSelected then
        library:SetButtonSelected(button, self:GetColors(), selected)
    end
end

function ConfigUI:SetTabSelected(button, selected)
    local library = self:GetLibrary()
    if library and library.SetTabSelected then
        library:SetTabSelected(button, self:GetColors(), selected)
        return
    end

    button:SetEnabled(not selected)
end

function ConfigUI:StyleButton(button)
    if button and button.GetFontString then
        HealLane.ApplyPixelPerfectFontString(button:GetFontString())
    end
    local library = self:GetLibrary()
    if library and library.StyleButton then
        library:StyleButton(button, self:GetColors())
    end
end

function ConfigUI:StyleCheckbox(checkbox)
    local library = self:GetLibrary()
    if library and library.StyleCheckbox then
        library:StyleCheckbox(checkbox, self:GetColors())
    end
end

function ConfigUI:StylePanel(panel, background)
    local library = self:GetLibrary()
    if library and library.StylePanel then
        library:StylePanel(panel, self:GetColors(), background)
    end
end

function ConfigUI:StyleText(fontString, color)
    HealLane.ApplyPixelPerfectFontString(fontString)
    local library = self:GetLibrary()
    if library and library.StyleText then
        library:StyleText(fontString, self:GetColors(), color)
    end
end

function ConfigUI:StyleDropdown(dropdown)
    local library = self:GetLibrary()
    if library and library.StyleDropdown then
        library:StyleDropdown(dropdown, self:GetColors())
    end
end

function ConfigUI:StyleSlider(slider)
    local library = self:GetLibrary()
    if library and library.StyleSlider then
        library:StyleSlider(slider, self:GetColors())
    end
end

function ConfigUI:StyleEditBox(editBox)
    local library = self:GetLibrary()
    if library and library.StyleEditBox then
        library:StyleEditBox(editBox, self:GetColors())
    end
end
