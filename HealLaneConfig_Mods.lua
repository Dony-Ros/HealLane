-- Mods tab: options for the optional HealLane mods (kept out of the General tab).
local EvsHL = EvsHL

function EvsHL.BuildModsTab(page)
    local H = EvsHL.ConfigHelpers

    local function FsrApply()
        if EvsHL.FiveSecond_Apply then EvsHL.FiveSecond_Apply(true) end
    end
    local function Nothing() end

    H.Label(page, "Player", 25, -10)
    H.AddCheck(page, "Five-second rule ring on player portrait", 20, -34, "fsrEnabled", FsrApply)
    H.AddColor(page, "Five-second ring color", 20, -66, "fsrColor", FsrApply)

    H.Label(page, "Chat", 25, -130)
    H.AddCheck(page, "Role icons before names in chat", 20, -154, "chatRoleIcons", Nothing)
    H.AddCheck(page, "Flash alert when my name is mentioned in chat", 20, -182, "nameAlert", Nothing)

    H.Label(page, "Loot", 25, -226)
    H.AddCheck(page, "Show who picked each option on loot rolls", 20, -250, "lootRollTooltip", Nothing)

    H.Label(page, "Crafting", 25, -294)
    H.AddCheck(page, "Auto-confirm replacing an existing enchant", 20, -318, "autoReplaceEnchant", Nothing)
end