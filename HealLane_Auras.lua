-- Combat-safe native AuraContainer integration (HoTs + dispel icons).
local EvsHL = EvsHL
local S = nil  -- lazily pulled from EvsHL.S
local nativeAuraWarnings = EvsHL.nativeAuraWarnings
function EvsHL.WarnNativeAura(key, message)
    if nativeAuraWarnings[key] then return end
    nativeAuraWarnings[key] = true
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("HealLane: " .. message)
    end
end
function EvsHL.ProbeNativeAuraSupport()
    if not (AuraUtil and AuraUtil.IsValidFilterString) then return false end
    local ok, container = pcall(CreateFrame, "AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
    if not ok or not container or type(container.AddAuraSlot) ~= "function"
        or type(container.AddAuraGroup) ~= "function" or type(container.SetUnit) ~= "function"
        or type(container.SetEnabled) ~= "function" then
        if container and container.Hide then container:Hide() end
        return false
    end
    container:Hide()
    return true
end
local NATIVE_DISPEL_TYPES = { "Magic", "Curse", "Disease", "Poison", "Bleed" }
function EvsHL.GetDispelColor(typeName)
    local S = EvsHL.S
    local c = S and S[EvsHL.DEBUFF_COLOR_KEYS[typeName]]
    if c then return c end
    local f = EvsHL.DEBUFF_TYPE_COLORS[typeName] or { r = 1, g = 0, b = 0 }
    return { f.r, f.g, f.b }
end

local AddAuraSlot, ApplyHoTFlowLayout, BuildDispelSlotOptions, BuildHoTGroupOptions, BuildSingleDispelSlot, InitializeAuraIcon, InitializeAuraIconDuration, InitializeAuraIconTexture
local function GetNativeAuraSelection()
    local curS = EvsHL.S
    local knownSpells = {}
    for _, spell in ipairs(EvsHL.spells or {}) do
        knownSpells[spell.name] = spell
    end
    local hotEntries, seenIDs = {}, {}
    if curS.showHots then
        local names = {}
        for name, enabled in pairs(curS.hots or {}) do
            if enabled then names[#names + 1] = name end
        end
        table.sort(names)
        for _, name in ipairs(names) do
            local spell = knownSpells[name]
            local idSet = {}
            if spell then
                if type(spell.spellID) == "number" then idSet[spell.spellID] = true end
                for id in pairs(spell.spellIDs or {}) do idSet[id] = true end
            end
            for id in pairs((curS.hotIDs and curS.hotIDs[name]) or {}) do
                id = tonumber(id)
                if id then idSet[id] = true end
            end
            local idList = {}
            for id in pairs(idSet) do idList[#idList + 1] = id end
            table.sort(idList)
            if #idList > 0 then
                if #hotEntries < EvsHL.MAX_HOTS then
                    hotEntries[#hotEntries + 1] = { name = name, spellIDs = idList }
                end
            else
                EvsHL.WarnNativeAura("hot-spell-id",
                    "a selected HoT has no spell ID on this client and cannot be shown by the combat-safe aura display.")
            end
        end
    end
    local configuredTypes = {}
    for _, entry in pairs((curS.dispel and curS.dispel.spells) or {}) do
        if entry.spell and knownSpells[entry.spell] then
            for _, dispelType in ipairs(NATIVE_DISPEL_TYPES) do
                if entry.types and entry.types[dispelType] then configuredTypes[dispelType] = true end
            end
        end
    end
    local dispelTypes = {}
    for _, dispelType in ipairs(NATIVE_DISPEL_TYPES) do
        if configuredTypes[dispelType] then dispelTypes[#dispelTypes + 1] = dispelType end
    end
    local ignoredSpellIDs = {}
    for spellID in pairs(curS.ignoredDebuffs or {}) do
        spellID = tonumber(spellID)
        if spellID then ignoredSpellIDs[spellID] = true end
    end
    local signature = { tostring(curS.hotSize), tostring(curS.hotAnchor), tostring(curS.debuffIcon), tostring(curS.debuffIconAnchor) }
    for _, entry in ipairs(hotEntries) do
        signature[#signature + 1] = "h" .. table.concat(entry.spellIDs, ",")
    end
    for _, dispelType in ipairs(dispelTypes) do
        signature[#signature + 1] = "d" .. dispelType
        local color = EvsHL.GetDispelColor(dispelType)
        signature[#signature + 1] = "c" .. dispelType .. ":" .. tostring(color[1]) .. ","
            .. tostring(color[2]) .. "," .. tostring(color[3]) .. ":" .. tostring(curS.barAlpha)
    end
    local ignoredIDs = {}
    for spellID in pairs(ignoredSpellIDs) do ignoredIDs[#ignoredIDs + 1] = spellID end
    table.sort(ignoredIDs)
    for _, spellID in ipairs(ignoredIDs) do
        signature[#signature + 1] = "i" .. spellID
    end
    return table.concat(signature, ":"), hotEntries, dispelTypes, ignoredSpellIDs
end
local function PositionNativeAuraIcon(icon, btn, index, count, size, anchor)
    local v = anchor:find("TOP") and "TOP" or anchor:find("BOTTOM") and "BOTTOM" or ""
    local h = anchor:find("LEFT") and "LEFT" or anchor:find("RIGHT") and "RIGHT" or ""
    local gap = 1
    local y = v == "TOP" and -1 or v == "BOTTOM" and 1 or 0
    local total = math.max(count, 1) * size + (math.max(count, 1) - 1) * gap
    local step = (index - 1) * (size + gap)
    icon:ClearAllPoints()
    if h == "LEFT" then
        icon:SetPoint(v .. "LEFT", btn, v .. "LEFT", step, y)
    elseif h == "RIGHT" then
        icon:SetPoint(v .. "RIGHT", btn, v .. "RIGHT", -step, y)
    else
        icon:SetPoint(v .. "LEFT", btn, v ~= "" and v or "CENTER", -total / 2 + step, y)
    end
end
local function CreateHoTDurationOptions()
    if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter
        and Enum and Enum.NumericRuleFormatRounding) then
        EvsHL.WarnNativeAura("duration-format", "number-only HoT duration text is not supported by this client.")
        return nil
    end
    local ok, formatter = pcall(function()
        local numeric = C_StringUtil.CreateNumericRuleFormatter()
        numeric:AddBreakpoint({
            threshold = 0,
            step = 1,
            rounding = Enum.NumericRuleFormatRounding.Up,
            min = 1,
            format = "%d",
        })
        return numeric
    end)
    if not ok or not formatter then
        EvsHL.WarnNativeAura("duration-format", "could not create the number-only HoT duration formatter.")
        return nil
    end
    if C_AuraContainerUtil
        and type(C_AuraContainerUtil.ProcessCustomAuraButtonDurationTextOptions) == "function"
        and C_DurationUtil and C_DurationUtil.CreateDurationTextBinding then
        local bound, binding = pcall(C_DurationUtil.CreateDurationTextBinding)
        if bound and binding then
            local configured, err = pcall(function()
                binding:SetFormatter(formatter)
                binding:SetEnabled(true)
            end)
            if configured then return { binding = binding } end
            EvsHL.WarnNativeAura("duration-format", "could not configure HoT duration text: " .. tostring(err))
        end
    end
    return { formatter = formatter }
end
local function RetireNativeAuraContainer(btn)
    local container = btn.nativeAuraContainer
    btn.nativeDispelActive = nil
    if container then
        pcall(container.SetEnabled, container, false)
        container:Hide()
    end
    btn.nativeAuraContainer = nil
    btn.nativeDispelSlots = nil
    btn.nativeDispelActive = nil
    btn.nativeAuraSignature = nil
    btn.nativeAuraUnit = nil
    btn.nativeAurasActive = false
end
local function BuildHoTGroup(btn, container, hotEntries)
    local curS = EvsHL.S

    local sortMethods = _G.AuraContainerSortMethod
    local sortDirections = _G.AuraContainerSortDirection
    if not (sortMethods and sortMethods.AuraInstanceIDOnly
        and sortDirections and sortDirections.Normal) then
        EvsHL.WarnNativeAura("hot-sort", "this client cannot sort HoT icons by application order.")
        RetireNativeAuraContainer(btn)
        return false
    end

    if not AuraUtil.IsValidFilterString("HELPFUL|PLAYER") then
        EvsHL.WarnNativeAura("filter", "the native aura display rejected the HoT filter.")
        RetireNativeAuraContainer(btn)
        return false
    end

    local options = BuildHoTGroupOptions(btn, hotEntries, curS, sortMethods, sortDirections)
    ApplyHoTFlowLayout(container, curS, #hotEntries)

    local success, err = pcall(container.AddAuraGroup, container, "heallane-hots", "HELPFUL|PLAYER", options)
    if not success then
        EvsHL.WarnNativeAura("hot-group", "could not register the HoT aura group: " .. tostring(err))
        RetireNativeAuraContainer(btn)
        return false
    end
    return true
end

BuildHoTGroupOptions = function(btn, hotEntries, curS, sortMethods, sortDirections)
    local includeSpellIDs = {}
    for _, entry in ipairs(hotEntries) do
        for _, id in ipairs(entry.spellIDs) do
            includeSpellIDs[id] = true
        end
    end

    return {
        maxFrameCount = #hotEntries,
        candidateFilters = { includeSpellIDs = includeSpellIDs },
        sortMethod = sortMethods.AuraInstanceIDOnly,
        sortDirection = sortDirections.Normal,
        layout = {
            elementWidth = curS.hotSize,
            elementHeight = curS.hotSize,
            elementSpacing = 1,
            elementSpacingX = 1,
            elementSpacingY = 1,
            lineSpacing = 1,
            groupSpacing = 0,
        },
        initializeFrame = function(button)
            InitializeAuraIcon(button, curS.hotSize, function(icon)
                icon:ClearAllPoints()
            end, 1, nil, true)
        end,
    }
end
local function BuildDispelSlots(btn, container, dispelTypes, ignoredSpellIDs)
    btn.nativeDispelSlots = {}
    btn.nativeDispelActive = {}

    local dispelCount = #dispelTypes
    for i, dispelType in ipairs(dispelTypes) do
        if not BuildSingleDispelSlot(btn, container, i, dispelType, dispelCount, ignoredSpellIDs) then
            RetireNativeAuraContainer(btn)
            return false
        end
    end
    return true
end
BuildSingleDispelSlot = function(btn, container, index, typeName, dispelCount, ignoredSpellIDs)
    local curS = EvsHL.S
    local options = BuildDispelSlotOptions(btn, index, typeName, dispelCount, curS, ignoredSpellIDs)

    local success = AddAuraSlot(container, "heallane-dispel-" .. typeName, "HARMFUL", options)
    if not success then return false end

    return true
end
local function EnableNativeAuraContainer(btn, container)
    local enabled, err = pcall(container.SetEnabled, container, true)
    if not enabled then
        EvsHL.WarnNativeAura("enable", "could not enable the combat-safe aura display: " .. tostring(err))
        RetireNativeAuraContainer(btn)
        return false
    end
    return true
end
BuildDispelSlotOptions = function(btn, index, typeName, dispelCount, curS, ignoredSpellIDs)
    return {
        candidateFilters = {
            includeDispelTypes = { [typeName] = true },
            excludeSpellIDs = ignoredSpellIDs,
        },
        initializeFrame = function(button)
            InitializeAuraIcon(button, 14, function(icon)
                PositionNativeAuraIcon(icon, btn, index, dispelCount, 14, curS.debuffIconAnchor or "BOTTOMLEFT")
            end, curS.debuffIcon and 1 or 0, function(created)
                if created.healLaneTint then return end
                local fill = btn.healthBar.fill
                local tint = created:CreateTexture(nil, "BACKGROUND")
                tint:SetPoint("TOPLEFT", fill, "TOPLEFT")
                tint:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
                local c = EvsHL.GetDispelColor(typeName)
                EvsHL.SetTextureColor(tint, c[1], c[2], c[3], curS.barAlpha)
                created.healLaneTint = true
            end)
        end,
    }
end
ApplyHoTFlowLayout = function(container, curS, hotCount)
    local anchor = curS.hotAnchor
    local horizontal = anchor:find("RIGHT") and "Left" or "Right"
    local vertical = anchor:find("BOTTOM") and "Up" or "Down"
    local directions = AnchorUtil and AnchorUtil.FlowDirection

    if container.SetFlowLayoutAnchorPoint then
        pcall(container.SetFlowLayoutAnchorPoint, container, anchor)
    end

    if directions and container.SetFlowLayoutGrowthDirection then
        local primary, secondary = directions[horizontal], directions[vertical]
        if primary ~= nil and secondary ~= nil then
            pcall(container.SetFlowLayoutGrowthDirection, container, primary, secondary)
        end
    end

    if container.SetFlowLayoutMaximumLineSize then
        local size = hotCount * curS.hotSize + (hotCount - 1)
        pcall(container.SetFlowLayoutMaximumLineSize, container, size)
    end

    if container.SetFlowLayoutPadding then
        pcall(container.SetFlowLayoutPadding, container, 0, 0, 0, 0)
    end
end
AddAuraSlot = function(container, key, filter, options)
    if not AuraUtil.IsValidFilterString(filter) then
        EvsHL.WarnNativeAura("filter", "the native aura display rejected a filter; combat aura updates are unavailable.")
        return false
    end

    local added, slot = pcall(container.AddAuraSlot, container, key, filter, options)
    if not added or not slot then
        EvsHL.WarnNativeAura("slot", "could not register an aura filter; combat aura updates are unavailable: "
            .. tostring(slot))
        return false
    end
    return true, slot
end

InitializeAuraIcon = function(button, size, position, alpha, onCreated, showDuration)
    button:SetSize(size, size)
    button:ClearAllPoints()
    position(button)

    InitializeAuraIconTexture(button)
    if showDuration then
        InitializeAuraIconDuration(button, size)
    end

    button:SetAlpha(1)
    if button.healLaneAuraIcon then button.healLaneAuraIcon:SetAlpha(alpha) end
    if button.SetMouseClickEnabled then button:SetMouseClickEnabled(false) end
    if button.SetMouseMotionEnabled then button:SetMouseMotionEnabled(false) end
    if onCreated then onCreated(button) end
end
InitializeAuraIconTexture = function(button)
    local icon = button.healLaneAuraIcon
    if icon then return icon end

    icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if not button.SetIcon then error("AuraContainer slot does not support SetIcon") end
    button:SetIcon(icon)
    button.healLaneAuraIcon = icon
    return icon
end
InitializeAuraIconDuration = function(button, size)
    if not button.SetDurationText or button.healLaneDurationText then return end

    local durationOptions = CreateHoTDurationOptions()
    if not durationOptions then return end

    local durationText = button:CreateFontString(nil, "OVERLAY")
    durationText:SetPoint("CENTER", button, "CENTER", 0, 0)
    durationText:SetFont(EvsHL.FONT, math.max(7, math.floor(size * 0.55)), "OUTLINE")

    local ok, err = pcall(button.SetDurationText, button, durationText, durationOptions)
    if not ok then
        EvsHL.WarnNativeAura("duration-format", "could not attach HoT duration text: " .. tostring(err))
    end
    button.healLaneDurationText = durationText
end
local function CreateNativeAuraContainer(btn)
    local ok, container = pcall(CreateFrame, "AuraContainer", nil, btn, "CustomAuraContainerTemplate")
    if not ok or not container then
        EvsHL.WarnNativeAura("create", "could not create the combat-safe aura display; combat aura updates are unavailable.")
        return nil
    end

    btn.nativeAuraContainer = container
    container:SetAllPoints(btn)
    container:SetFrameLevel(btn:GetFrameLevel() + 8)
    if CustomAuraContainerAuraProcessingPolicy
        and container.SetAuraProcessingPolicy
        and CustomAuraContainerAuraProcessingPolicy.None ~= nil then
        pcall(container.SetAuraProcessingPolicy, container, CustomAuraContainerAuraProcessingPolicy.None)
    end

    local bound, bindError = pcall(container.SetUnit, container, btn.unit)
    if not bound then
        EvsHL.WarnNativeAura("unit", "could not bind the combat-safe aura display to a unit: " .. tostring(bindError))
        RetireNativeAuraContainer(btn)
        return nil
    end

    btn.nativeAuraUnit = btn.unit
    return container
end
local function BuildNativeAuraContainer(btn, signature, hotEntries, dispelTypes, ignoredSpellIDs)
    RetireNativeAuraContainer(btn)
    if #hotEntries == 0 and #dispelTypes == 0 then
        btn.nativeAuraSignature = signature
        return true
    end

    local container = CreateNativeAuraContainer(btn)
    if not container then return false end

    if #hotEntries > 0 and not BuildHoTGroup(btn, container, hotEntries) then
        return false
    end

    if not BuildDispelSlots(btn, container, dispelTypes, ignoredSpellIDs) then
        return false
    end

    if not EnableNativeAuraContainer(btn, container) then
        return false
    end

    container:Show()
    btn.nativeAuraSignature = signature
    return true
end
local function RefreshNativeAuraFrame(btn)
    if not EvsHL.nativeAuraSupported or InCombatLockdown() then return end
    local unit = btn.unit
    local active = unit and not btn.sim and btn:IsShown()
    if not active then
        if btn.nativeDispelActive then wipe(btn.nativeDispelActive) end
        if btn.nativeAuraContainer then
            pcall(btn.nativeAuraContainer.SetEnabled, btn.nativeAuraContainer, false)
            btn.nativeAuraContainer:Hide()
        end
        btn.nativeAurasActive = false
        return
    end
    local signature, hotEntries, dispelTypes, ignoredSpellIDs = GetNativeAuraSelection()
    if btn.nativeAuraSignature ~= signature then
        if not BuildNativeAuraContainer(btn, signature, hotEntries, dispelTypes, ignoredSpellIDs) then return end
    end
    local container = btn.nativeAuraContainer
    if not container then
        btn.nativeAurasActive = false
        return
    end
    if btn.nativeAuraUnit ~= unit then
        local ok, err = pcall(container.SetUnit, container, unit)
        if not ok then
            EvsHL.WarnNativeAura("unit", "could not bind the combat-safe aura display to a unit: " .. tostring(err))
            pcall(container.SetEnabled, container, false)
            if btn.nativeDispelActive then wipe(btn.nativeDispelActive) end
            btn.nativeAurasActive = false
            return
        end
        btn.nativeAuraUnit = unit
    end
    local ok, err = pcall(container.SetEnabled, container, true)
    if not ok then
        EvsHL.WarnNativeAura("enable", "could not enable the combat-safe aura display: " .. tostring(err))
        pcall(container.SetEnabled, container, false)
        if btn.nativeDispelActive then wipe(btn.nativeDispelActive) end
        btn.nativeAurasActive = false
        return
    end
    container:Show()
    btn.nativeAurasActive = true
end
function EvsHL.RefreshNativeAuraFrames()
    if not EvsHL.nativeAuraSupported or InCombatLockdown() then return end
    for _, btn in pairs(EvsHL.buttons) do
        RefreshNativeAuraFrame(btn)
    end
end