-- Mods tab: options for the optional HealLane mods (kept out of the General tab).
local HealLane = HealLane

function HealLane.BuildModsTab(page)
    local H = HealLane.ConfigHelpers
    local function Nothing() end

    local chatBox = H.Section(page, "Chat", -4, 92)
    H.AddCheck(chatBox, "Role icons before names in chat", 8, -26, "chatRoleIcons", Nothing)
    H.AddCheck(chatBox, "Flash alert when my name is mentioned in chat", 8, -54, "nameAlert", Nothing)
end
