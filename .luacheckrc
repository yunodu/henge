std = "lua51"
max_line_length = false
codes = true

ignore = {
    "211/ADDON_NAME", -- every file unpacks `...` the same way
    "212",            -- unused arguments (callback signatures)
    "432",            -- nested closures reuse `self`
}

-- Written by Henge.
globals = {
    "Henge",
    "HengeDB",
    "Henge_OnAddonCompartmentClick",
    "SLASH_HENGE1",
    "SlashCmdList",
    "UISpecialFrames",
}

read_globals = {
    "C_AddOns",
    "C_CVar",
    "C_Timer",
    "CreateFrame",
    "DEFAULT_CHAT_FRAME",
    "GetAddOnMetadata",
    "GetCVar",
    "GetNormalizedRealmName",
    "GetRealmName",
    "InCombatLockdown",
    "IsInInstance",
    "PixelUtil",
    "STANDARD_TEXT_FONT",
    "SetCVar",
    "UIFrameFadeIn",
    "UIParent",
    "UnitName",
    "tinsert",
    "tremove",
}
