-- Auto-confirm the "replace existing enchant" prompt (handy while leveling Enchanting).
-- Confirming is a restricted action, so it has to run inside the click that applies the
-- enchant. This is tried from the event and again right after the item-click functions.
local EvsHL = EvsHL

local debugOn = false
local function Log(...)
    if debugOn then
        DEFAULT_CHAT_FRAME:AddMessage("HealLane enchant: " .. strjoin(" ", tostringall(...)))
    end
end

local function PopupButton()
    for i = 1, STATICPOPUP_NUMDIALOGS or 4 do
        local popup = _G["StaticPopup" .. i]
        if popup and popup:IsShown() and popup.which == "REPLACE_ENCHANT" then
            return _G["StaticPopup" .. i .. "Button1"]
        end
    end
end

local function Enabled()
    local S = EvsHL.S
    return S and S.autoReplaceEnchant
end

local function Confirm(source)
    local replace = C_Item and C_Item.ReplaceEnchant or ReplaceEnchant
    if replace then
        local ok, err = pcall(replace)
        Log(source, "ReplaceEnchant ok=" .. tostring(ok), ok and "" or tostring(err))
    else
        Log(source, "no ReplaceEnchant function")
    end
    local button = PopupButton()
    if button then
        local ok, err = pcall(button.Click, button)
        Log(source, "popup click ok=" .. tostring(ok), ok and "" or tostring(err))
    end
end

local function AfterClick(name)
    return function()
        if Enabled() and PopupButton() then
            Confirm("after " .. name)
        end
    end
end

local function HookFunction(owner, key, label)
    if owner and type(owner[key]) == "function" then
        hooksecurefunc(owner, key, AfterClick(label))
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("REPLACE_ENCHANT")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        HookFunction(C_Container, "UseContainerItem", "UseContainerItem")
        HookFunction(C_Container, "PickupContainerItem", "PickupContainerItem")
        HookFunction(_G, "UseContainerItem", "UseContainerItem")
        HookFunction(_G, "PickupContainerItem", "PickupContainerItem")
        HookFunction(_G, "PickupInventoryItem", "PickupInventoryItem")
        HookFunction(_G, "UseInventoryItem", "UseInventoryItem")
        if hooksecurefunc and StaticPopup_Show then
            hooksecurefunc("StaticPopup_Show", function(which)
                if which == "REPLACE_ENCHANT" and Enabled() then
                    Log("StaticPopup_Show REPLACE_ENCHANT")
                    Confirm("popup show")
                end
            end)
        end
        return
    end
    Log("REPLACE_ENCHANT event fired, enabled=" .. tostring(Enabled() and true or false))
    if Enabled() then
        Confirm("event")
        if C_Timer then
            C_Timer.After(0, function()
                if PopupButton() then
                    Confirm("next frame")
                end
            end)
        end
    end
end)

SLASH_HLENCHANT1 = "/hlenchant"
SlashCmdList["HLENCHANT"] = function()
    debugOn = not debugOn
    DEFAULT_CHAT_FRAME:AddMessage("HealLane enchant debug " .. (debugOn and "on" or "off")
        .. " (auto-confirm setting is " .. (Enabled() and "on" or "off") .. ")")
end