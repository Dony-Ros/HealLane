local HealLane = HealLane

function HealLane.BuildProfilesTab(page)
    local H = HealLane.ConfigHelpers

    local profileBox = H.Section(page, "Profiles", -34, 190)

    H.Label(profileBox, "Select / apply profile", 20, -24)
    H.Label(profileBox, "New profile name", 250, -24)

    local name = CreateFrame("EditBox", nil, profileBox, "InputBoxTemplate")
    name:SetSize(210, 24)
    name:SetPoint("TOPLEFT", 250, -54)
    name:SetAutoFocus(false)
    name:SetMaxLetters(32)
    name:SetText("")

    local status = HealLane.CreateFontString(profileBox, nil, "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("TOPLEFT", 250, -82)
    status:SetWidth(210)
    status:SetJustifyH("LEFT")

    local function refreshStatus()
        local active = HealLane.baseDB and HealLane.baseDB.profileName or "Default"
        status:SetText("Active profile: " .. active)
        H.WrapText(status, 210)
    end

    local refreshProfileOptions

    local profileOptions = {}
    for _, profileName in ipairs(HealLane.ProfileNames()) do
        profileOptions[#profileOptions + 1] = { value = profileName, label = profileName }
    end
    local profileDropdown
    profileDropdown = H.AddDropdown(profileBox, 20, -46, 220, profileOptions,
        function() return HealLane.baseDB and HealLane.baseDB.profileName or "Default" end,
        function(profileName)
            local active = HealLane.baseDB and HealLane.baseDB.profileName or "Default"
            if profileName == active then
                profileDropdown:SetValue(active)
                return
            end
            HealLane.RequestProfileSwitch(profileName, profileDropdown, name, refreshStatus, refreshProfileOptions)
        end)


    local function selectedName()
        local value = name:GetText()
        return HealLane.CreateProfileName(value)
    end

    HealLane.AddConfigWidget(refreshStatus)
    refreshProfileOptions = function()
        local options = {}
        for _, profileName in ipairs(HealLane.ProfileNames()) do
            options[#options + 1] = { value = profileName, label = profileName }
        end
        profileDropdown:SetOptions(options)
        profileDropdown:SetValue(HealLane.baseDB and HealLane.baseDB.profileName or "Default")
    end

    refreshProfileOptions()
    refreshStatus()

    H.AddButton(profileBox, "Save current", 20, -112, 115, function()
        local active = HealLane.baseDB and HealLane.baseDB.profileName or "Default"
        local ok, err = HealLane.SaveProfile(active)
        if not ok then status:SetText(err) else refreshStatus() refreshProfileOptions() end
    end)

    H.AddButton(profileBox, "Create / copy", 145, -112, 115, function()
        local target = selectedName()
        if not target then
            status:SetText("Enter a profile name.")
            return
        end
        if HealLane.SaveProfile(target) then
            refreshStatus()
            refreshProfileOptions()
            profileDropdown:SetValue(target)
            name:SetText("")
            status:SetText("Profile created: " .. target)
        end
    end)

    H.AddButton(profileBox, "Apply", 270, -112, 75, function()
        local target = selectedName()
        if target then
            HealLane.RequestProfileSwitch(target, profileDropdown, name, refreshStatus, refreshProfileOptions)
        else
            status:SetText("Enter a profile name to apply.")
        end
    end)

    H.AddButton(profileBox, "Delete", 355, -112, 75, function()
        local target = selectedName()
        if not target then
            status:SetText("Enter a profile name to delete.")
            return
        end
        HealLane.DeleteProfile(target)
        name:SetText("")
        refreshStatus()
        refreshProfileOptions()
    end)

    refreshStatus()

    local pvpBox = H.Section(page, "PvP settings", -232, 210)
    local pvpStatus = HealLane.CreateFontString(pvpBox, nil, "OVERLAY", "GameFontNormalSmall")
    pvpStatus:SetPoint("TOPLEFT", 20, -28)
    pvpStatus:SetWidth(420)

    local sizeText = "Not in a Battleground"
    if HealLane.activePvpSize then sizeText = "Active PvP size: " .. HealLane.activePvpSize .. " players" end
    pvpStatus:SetText(sizeText)

    H.Label(pvpBox, "Reset a PvP size bucket", 20, -58)
    for i, size in ipairs({ 10, 25, 40 }) do
        H.AddButton(pvpBox, tostring(size) .. " players", 20 + (i - 1) * 145, -92, 125, function()
            HealLane.CapturePvpChanges()
            HealLane.baseDB.pvp[tostring(size)] = {}
            if HealLane.activePvpSize == tostring(size) then HealLane.ApplyPvpSettings(size) end
            pvpStatus:SetText("Reset PvP settings for " .. size .. " players.")
        end)
    end

    local explainOne = H.Label(pvpBox, "Any setting changed here while in a Battleground is stored in the active 10/25/40 PvP bucket.", 20, -132)
    H.WrapText(explainOne, 420)
    local explainTwo = H.Label(pvpBox, "General/Mods keys marked as global remain shared across PvP and the normal profile.", 20, -156)
    H.WrapText(explainTwo, 420)
end
