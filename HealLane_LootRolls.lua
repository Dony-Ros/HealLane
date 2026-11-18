-- Loot roll tooltips: hovering Need / Greed / Disenchant / Transmog on a roll
-- frame lists which group members picked that option.
local EvsHL = EvsHL

local LABELS = { need = "Need", greed = "Greed", disenchant = "Disenchant", transmog = "Transmog" }

local stateNames
local function StateCategory(state)
    if not stateNames then
        stateNames = {}
        local enum = Enum and Enum.EncounterLootDropRollState
        if enum then
            for name, value in pairs(enum) do
                stateNames[value] = name:lower()
            end
        end
    end
    local name = stateNames[state]
    if not name then
        return nil
    end
    if name:find("need") then return "need" end
    if name:find("greed") then return "greed" end
    if name:find("disenchant") then return "disenchant" end
    if name:find("transmog") then return "transmog" end
    return nil
end

local function NewResult()
    return { need = {}, greed = {}, disenchant = {}, transmog = {} }
end

local function Add(result, category, name, class, roll)
    if category and name and result[category] then
        local list = result[category]
        list[#list + 1] = { name = name:match("^[^-]+") or name, class = class, roll = roll }
    end
end

-- Classic-style history: items indexed by position, players by index.
local function ChoicesLegacy(rollID)
    local H = C_LootHistory
    for i = 1, H.GetNumItems() do
        local id, _, numPlayers = H.GetItem(i)
        if id == rollID then
            local result = NewResult()
            for p = 1, numPlayers or 0 do
                local name, class, rollType, roll = H.GetPlayerInfo(i, p)
                local category = rollType == 1 and "need" or rollType == 2 and "greed"
                    or rollType == 3 and "disenchant" or nil
                Add(result, category, name, class, roll)
            end
            return result
        end
    end
end

-- Encounter-based history: drops per encounter, roll infos per drop.
local function ChoicesEncounter(rollID)
    local H = C_LootHistory
    local link = GetLootRollItemLink and GetLootRollItemLink(rollID)
    local exact, fallback
    for _, encounter in ipairs(H.GetAllEncounterInfos() or {}) do
        local encounterID = encounter.encounterID
        for _, drop in ipairs(H.GetSortedDropsForEncounter(encounterID) or {}) do
            local sameLink = link and drop.itemHyperlink == link
            if drop.lootListID == rollID and (not link or sameLink) then
                exact = { encounterID, drop.lootListID }
            elseif sameLink then
                fallback = { encounterID, drop.lootListID }
            end
        end
    end
    local pick = exact or fallback
    if not pick then
        return nil
    end
    local info = H.GetSortedInfoForDrop(pick[1], pick[2])
    if not info then
        return nil
    end
    local result = NewResult()
    for _, roll in ipairs(info.rollInfos or {}) do
        Add(result, StateCategory(roll.state), roll.playerName, roll.playerClass, roll.roll)
    end
    return result
end

local function GetChoices(rollID)
    local H = C_LootHistory
    if not H then
        return nil
    end
    if H.GetNumItems and H.GetItem and H.GetPlayerInfo then
        return ChoicesLegacy(rollID)
    end
    if H.GetAllEncounterInfos and H.GetSortedDropsForEncounter and H.GetSortedInfoForDrop then
        return ChoicesEncounter(rollID)
    end
end

local function RollIDOf(frame)
    local id = frame.rollID or frame.rollid or frame.rollId
    if type(id) == "number" then
        return id
    end
end

local function FindRollID(button)
    local frame = button
    while frame do
        local id = RollIDOf(frame)
        if id then
            return id
        end
        frame = frame:GetParent()
    end
end

local function AppendTooltip(button, category)
    local rollID = FindRollID(button)
    if not rollID then
        return
    end
    local result = GetChoices(rollID)
    if not result then
        return
    end
    local list = result[category]
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(LABELS[category] .. " (" .. #list .. ")", 1, 0.82, 0)
    if #list == 0 then
        GameTooltip:AddLine("No one yet", 0.6, 0.6, 0.6)
    end
    for _, entry in ipairs(list) do
        local color = entry.class and RAID_CLASS_COLORS[entry.class] or { r = 1, g = 1, b = 1 }
        local roll = entry.roll and tostring(entry.roll) or ""
        GameTooltip:AddDoubleLine(entry.name, roll, color.r, color.g, color.b, 1, 1, 1)
    end
    GameTooltip:Show()
end

local function HookButton(button, category)
    if not button or button.evsLootHooked then
        return
    end
    button.evsLootHooked = true
    button:HookScript("OnEnter", function(self)
        local S = EvsHL.S
        if not (S and S.lootRollTooltip) then
            return
        end
        pcall(AppendTooltip, self, category)
    end)
end

local function CategoryFromName(text)
    if type(text) ~= "string" then
        return nil
    end
    text = text:lower()
    if text:find("need") then return "need" end
    if text:find("greed") then return "greed" end
    if text:find("disenchant") or text:find("enchant") then return "disenchant" end
    if text:find("transmog") then return "transmog" end
end

local function CategoryFromIcon(button)
    local tex = button.GetNormalTexture and button:GetNormalTexture()
    local path = tex and tex.GetTexture and tex:GetTexture()
    if type(path) ~= "string" then
        return nil
    end
    path = path:lower()
    if path:find("dice") then return "need" end
    if path:find("coin") then return "greed" end
    if path:find("grouploot%-de") or path:find("disenchant") then return "disenchant" end
end

local hooked = {}

local function HookRollFrame(frame)
    for key, value in pairs(frame) do
        if type(key) == "string" and type(value) == "table" and value.HookScript and value.GetObjectType then
            local category = CategoryFromName(key)
            if category then
                HookButton(value, category)
                hooked[#hooked + 1] = { frame = frame:GetName() or "?", key = key, category = category }
            end
        end
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        if child.HookScript and child.GetObjectType and child:GetObjectType() == "Button" then
            local category = CategoryFromName(child:GetName()) or CategoryFromIcon(child)
            if category then
                HookButton(child, category)
                hooked[#hooked + 1] = { frame = frame:GetName() or "?", key = child:GetName() or "child", category = category }
            end
        end
    end
end

local function HookFrames()
    wipe(hooked)
    local frame = EnumerateFrames()
    while frame do
        if not (frame.IsForbidden and frame:IsForbidden()) and RollIDOf(frame) then
            pcall(HookRollFrame, frame)
        end
        frame = EnumerateFrames(frame)
    end
end

SLASH_HLLOOT1 = "/hlloot"
SlashCmdList["HLLOOT"] = function()
    HookFrames()
    local say = function(msg) DEFAULT_CHAT_FRAME:AddMessage("HealLane loot: " .. msg) end
    if #hooked == 0 then
        say("no roll frames with a roll ID found (start a roll first). Loot-related frames:")
        local frame = EnumerateFrames()
        local shown = 0
        while frame and shown < 15 do
            local name = frame.GetName and frame:GetName()
            if name and (name:lower():find("loot") or name:lower():find("roll")) then
                say("  " .. name .. " (" .. frame:GetObjectType() .. ")")
                shown = shown + 1
            end
            frame = EnumerateFrames(frame)
        end
        return
    end
    for _, entry in ipairs(hooked) do
        say(entry.frame .. " -> " .. entry.key .. " = " .. entry.category)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("START_LOOT_ROLL")
events:SetScript("OnEvent", function(_, event)
    HookFrames()
    if event == "START_LOOT_ROLL" and C_Timer then
        C_Timer.After(0.2, HookFrames)
        C_Timer.After(1, HookFrames)
    end
end)