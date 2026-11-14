local ADDON_NAME, ns = ...

local MAX_USER_PRESETS = 12
local MAX_NAME_LENGTH = 24
local ORIGINAL_PRESET_NAME = "Original Settings"
-- Blizzard's menu sliders rewrite the engine CVars underneath them, so the engine layer is written a moment later.
local ENGINE_DELAY = 0.2
local CONTEXT_DELAY = 1
-- Blizzard's own raid/battleground copies would replace an applied preset inside raids and PvP.
local RAID_SETTINGS_CVAR = "RAIDsettingsEnabled"

local SLIDER_CVARS = {
    "graphicsShadowQuality", "graphicsLiquidDetail", "graphicsParticleDensity", "graphicsSSAO",
    "graphicsDepthEffects", "graphicsComputeEffects", "graphicsOutlineMode", "graphicsTextureResolution",
    "graphicsSpellDensity", "graphicsProjectedTextures", "graphicsViewDistance", "graphicsEnvironmentDetail",
    "graphicsGroundClutter",
    "ResampleAlwaysSharpen", "vsync", "gxVSync", "gxTripleBuffer", "maxFPSBk",
}

local ENGINE_CVARS = {
    "RenderScale", "ResampleQuality", "ResampleSharpness",
    "groundEffectDensity", "groundEffectDist", "groundEffectFade",
    "farclip", "horizonStart", "horizonClip", "terrainLodDist", "lodObjectFadeScale", "lodObjectCullSize",
    "wmoLodDist", "entityLodDist", "maxLightDist",
    "shadowMode", "shadowRt", "shadowTextureSize", "shadowNumCascades", "shadowBlendCascades", "shadowSoft",
    "SSAO", "sunShafts", "volumeFog", "volumeFogLevel", "volumeFogInterior", "bloomEnable", "ffxGlow", "projectedTextures",
    "reflectionMode", "reflectionDownscale", "refraction", "waterDetail", "rippleDetail",
    "textureFilteringMode", "terrainMipLevel",
    "weatherDensity", "particleDensity", "particleMTDensity", "particulatesEnabled", "DepthBasedOpacity",
}

local IS_ENGINE_CVAR = {}
for _, name in ipairs(ENGINE_CVARS) do
    IS_ENGINE_CVAR[name] = true
end

local BUILTIN_PRESETS = {
    {
        id = "fps", label = "FPS Settings", builtin = true,
        cvars = {
            { "graphicsShadowQuality",      "1" },
            { "graphicsLiquidDetail",       "0" },
            { "graphicsParticleDensity",    "5" },
            { "graphicsSSAO",               "0" },
            { "graphicsDepthEffects",       "0" },
            { "graphicsComputeEffects",     "0" },
            { "graphicsOutlineMode",        "0" },
            { "graphicsTextureResolution",  "2" },
            { "graphicsSpellDensity",       "1" },
            { "graphicsProjectedTextures",  "1" },
            { "graphicsViewDistance",       "1" },
            { "graphicsEnvironmentDetail",  "1" },
            { "graphicsGroundClutter",      "1" },
            { "ResampleAlwaysSharpen",      "1" },
            { "vsync",                      "0" },
            { "gxVSync",                    "0" },
            { "gxTripleBuffer",             "0" },
            { "maxFPSBk",                   "30" },
        },
    },
    {
        id = "inari", label = "Inari Graphics", builtin = true,
        cvars = {
            { "graphicsShadowQuality",      "2" },
            { "graphicsLiquidDetail",       "1" },
            { "graphicsParticleDensity",    "5" },
            { "graphicsSSAO",               "1" },
            { "graphicsDepthEffects",       "1" },
            { "graphicsComputeEffects",     "1" },
            { "graphicsOutlineMode",        "0" },
            { "graphicsTextureResolution",  "2" },
            { "graphicsSpellDensity",       "2" },
            { "graphicsProjectedTextures",  "1" },
            { "graphicsViewDistance",       "5" },
            { "graphicsEnvironmentDetail",  "5" },
            { "graphicsGroundClutter",      "3" },
            { "ResampleAlwaysSharpen",      "1" },
        },
    },
}

local CONTEXTS = { "world", "dungeon", "raid" }
local CONTEXT_LABELS = { world = "Open World", dungeon = "Dungeon", raid = "Raid" }
-- Arenas count as dungeons and battlegrounds as raids: the group size is what drives the cost.
local INSTANCE_CONTEXT = { party = "dungeon", scenario = "dungeon", arena = "dungeon", raid = "raid", pvp = "raid" }

-- Words the slash command reads as an action, so no preset name may start with them.
local RESERVED_NAMES = {
    next = true, toggle = true, cycle = true, swap = true, list = true, help = true, status = true,
    save = true, add = true, delete = true, remove = true, set = true, none = true,
}

local listeners = {}
local applySerial = 0
local pendingApply
local contextSerial = 0
local started = false
local loginPending = false

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffe8a4b8Henge:|r " .. tostring(msg))
end

local function EnsureDB()
    if type(HengeDB) ~= "table" then HengeDB = {} end
    local db = HengeDB
    if type(db.presets) ~= "table" then db.presets = {} end
    if type(db.slots) ~= "table" then db.slots = {} end
    if type(db.characters) ~= "table" then db.characters = {} end
    if type(db.active) ~= "string" then db.active = nil end
    if type(db.baseline) ~= "table" then db.baseline = nil end
    if type(db.restore) ~= "table" or type(db.restore.cvars) ~= "table" then db.restore = nil end
    if not CONTEXT_LABELS[db.context] then db.context = nil end
    if not CONTEXT_LABELS[db.activeBy] then db.activeBy = nil end
    return db
end

local function NotifyChanged()
    for _, listener in ipairs(listeners) do
        listener()
    end
end

local function GetValue(name)
    if C_CVar and C_CVar.GetCVar then
        local value = C_CVar.GetCVar(name)
        if value ~= nil then return value end
    end
    if GetCVar then
        local ok, value = pcall(GetCVar, name)
        if ok then return value end
    end
    return nil
end

local function SameValue(a, b)
    a, b = tostring(a), tostring(b)
    if a == b then return true end
    local numberA, numberB = tonumber(a), tonumber(b)
    return numberA ~= nil and numberB ~= nil and math.abs(numberA - numberB) < 0.0001
end

-- Returns "missing" when this client has no such CVar, "rejected" when the client kept another value.
local function SetValue(name, value)
    if GetValue(name) == nil then return "missing" end
    local setter = C_CVar and C_CVar.SetCVar or SetCVar
    local ok = pcall(setter, name, tostring(value))
    if ok and SameValue(GetValue(name), value) then return nil end
    return "rejected"
end

-- The live value of every CVar a preset can hold, sliders first so a later apply keeps that order.
local function Snapshot()
    local cvars = {}
    for _, list in ipairs({ SLIDER_CVARS, ENGINE_CVARS }) do
        for _, name in ipairs(list) do
            local value = GetValue(name)
            if value ~= nil then
                cvars[#cvars + 1] = { name, tostring(value) }
            end
        end
    end
    return cvars
end

-- CVars this client does not have are ignored, so a preset still matches on the other game flavour.
local function Matches(cvars)
    for _, cvar in ipairs(cvars) do
        local value = GetValue(cvar[1])
        if value ~= nil and not SameValue(value, cvar[2]) then
            return false
        end
    end
    return true
end

local combatFrame = CreateFrame("Frame")
combatFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    local fn = pendingApply
    pendingApply = nil
    if fn then fn() end
end)

-- Runs fn now, or once combat ends. Only the latest waiting call survives.
local function WhenOutOfCombat(fn)
    if not InCombatLockdown() then
        fn()
        return true
    end
    pendingApply = fn
    combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    return false
end

-- Writes the slider layer, then the engine layer. A newer call cancels one still in flight.
-- Returns true when the write has to wait for combat to end.
local function WriteCVars(cvars, onDone)
    applySerial = applySerial + 1
    local serial = applySerial
    local rejected = 0
    HengeDB.baseline = nil

    local function WriteLayer(engine)
        for _, cvar in ipairs(cvars) do
            if (IS_ENGINE_CVAR[cvar[1]] or false) == engine and SetValue(cvar[1], cvar[2]) == "rejected" then
                rejected = rejected + 1
            end
        end
    end

    local function WriteEngine()
        if serial ~= applySerial then return end
        WriteLayer(true)
        HengeDB.baseline = Snapshot()
        if onDone then onDone(rejected) end
        NotifyChanged()
    end

    local ran = WhenOutOfCombat(function()
        if serial ~= applySerial then return end
        SetValue(RAID_SETTINGS_CVAR, "0")
        WriteLayer(false)
        C_Timer.After(ENGINE_DELAY, function()
            if serial == applySerial then WhenOutOfCombat(WriteEngine) end
        end)
    end)
    return not ran
end

-- Built-ins first, then the user's own presets in the order they were saved.
local function GetPresets()
    local db = EnsureDB()
    local list = {}
    for index, preset in ipairs(BUILTIN_PRESETS) do
        list[index] = preset
    end
    for _, saved in ipairs(db.presets) do
        if type(saved) == "table" and type(saved.name) == "string" and type(saved.cvars) == "table" then
            list[#list + 1] = { id = string.lower(saved.name), label = saved.name, cvars = saved.cvars, saved = saved }
        end
    end
    return list
end

local function FindPreset(id, presets)
    if type(id) ~= "string" then return nil end
    id = string.lower(id)
    for index, preset in ipairs(presets or GetPresets()) do
        if preset.id == id then return preset, index end
    end
    return nil
end

-- Returns preset, index, modified. The preset is the last one applied if it still exists, otherwise
-- whichever preset the live CVars match. Modified means the settings changed since Henge wrote them.
local function GetCurrentPreset(presets)
    presets = presets or GetPresets()
    local preset, index = FindPreset(HengeDB.active, presets)
    if preset then
        return preset, index, HengeDB.baseline ~= nil and not Matches(HengeDB.baseline)
    end
    for position, candidate in ipairs(presets) do
        if Matches(candidate.cvars) then return candidate, position, false end
    end
    return nil
end

-- source is the location that asked for the preset, or nil for a swap made by hand.
-- Returns ok, message.
local function ApplyPreset(id, source)
    local preset = FindPreset(id)
    if not preset then
        return false, "no preset named \"" .. tostring(id) .. "\""
    end

    HengeDB.active = preset.id
    HengeDB.activeBy = source
    local queued = WriteCVars(preset.cvars, function(rejected)
        if not source and rejected > 0 then
            Print("\"" .. preset.label .. "\": " .. rejected .. " settings were not accepted by the client")
        end
    end)
    NotifyChanged()
    return true, "\"" .. preset.label .. "\" " .. (queued and "queued until combat ends" or "applied")
end

local function CyclePreset()
    local presets = GetPresets()
    local _, index = GetCurrentPreset(presets)
    return ApplyPreset(presets[(index or 0) % #presets + 1].id)
end

local function CleanName(name)
    return (tostring(name or ""):gsub("|", ""):gsub("%s+", " "):match("^%s*(.-)%s*$"))
end

-- Saves the live settings under name; an existing preset of that name is overwritten.
-- cvars lets a caller store settings other than the live ones.
local function SavePreset(name, cvars)
    local db = EnsureDB()
    name = CleanName(name)
    if name == "" then
        return false, "enter a name for the preset"
    end
    if #name > MAX_NAME_LENGTH then
        return false, "preset names are limited to " .. MAX_NAME_LENGTH .. " characters"
    end

    local id = string.lower(name)
    local existing = FindPreset(id)
    if RESERVED_NAMES[id:match("^%S+")] or (existing and existing.builtin) then
        return false, "\"" .. name .. "\" is reserved, pick another name"
    end
    if not existing and #db.presets >= MAX_USER_PRESETS then
        return false, "only " .. MAX_USER_PRESETS .. " own presets fit, delete one first"
    end

    local live = cvars == nil
    cvars = cvars or Snapshot()
    if existing then
        existing.saved.name = name
        existing.saved.cvars = cvars
    else
        db.presets[#db.presets + 1] = { name = name, cvars = cvars }
    end
    if live then
        db.active = id
        db.activeBy = nil
        db.baseline = Snapshot()
    end
    NotifyChanged()
    return true, "\"" .. name .. "\" " .. (existing and "updated" or "saved") .. ": " .. #cvars .. " settings"
end

local function ForEachSlotSet(fn)
    fn(HengeDB.slots)
    for _, slots in pairs(HengeDB.characters) do
        if type(slots) == "table" then fn(slots) end
    end
end

local function DeletePreset(id)
    local db = EnsureDB()
    local preset = FindPreset(id)
    if not preset then
        return false, "no preset named \"" .. tostring(id) .. "\""
    end
    if preset.builtin then
        return false, "\"" .. preset.label .. "\" is built in and cannot be deleted"
    end

    for index, saved in ipairs(db.presets) do
        if saved == preset.saved then
            tremove(db.presets, index)
            break
        end
    end
    local cleared = 0
    ForEachSlotSet(function(slots)
        for _, context in ipairs(CONTEXTS) do
            if slots[context] == preset.id then
                slots[context] = nil
                cleared = cleared + 1
            end
        end
    end)
    if db.active == preset.id then
        db.active = nil
        db.activeBy = nil
        db.baseline = nil
    end
    NotifyChanged()

    local message = "\"" .. preset.label .. "\" deleted"
    if cleared > 0 then
        message = message .. "; cleared from " .. cleared .. (cleared == 1 and " location" or " locations")
    end
    return true, message
end

local function CharacterKey()
    local realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName()
    return tostring(UnitName("player")) .. "-" .. tostring(realm)
end

-- Returns the slot set in effect for this character and whether it is the character's own.
local function ActiveSlots()
    local db = EnsureDB()
    local own = db.characters[CharacterKey()]
    if type(own) == "table" then return own, true end
    return db.slots, false
end

-- A character's own set starts as a copy of the account set.
local function SetOwnSlots(enabled)
    local db = EnsureDB()
    local key = CharacterKey()
    if enabled then
        if type(db.characters[key]) ~= "table" then
            db.characters[key] = { world = db.slots.world, dungeon = db.slots.dungeon, raid = db.slots.raid }
        end
    else
        db.characters[key] = nil
    end
    NotifyChanged()
    return enabled and "this character now has its own locations" or "this character follows the account locations again"
end

-- id nil empties the slot. A changed slot takes effect on the next arrival there or the next login.
local function SetSlot(context, id)
    if not CONTEXT_LABELS[context] then
        return false, "unknown location \"" .. tostring(context) .. "\""
    end
    local preset
    if id ~= nil then
        preset = FindPreset(id)
        if not preset then
            return false, "no preset named \"" .. tostring(id) .. "\""
        end
    end
    ActiveSlots()[context] = preset and preset.id or nil
    NotifyChanged()
    if not preset then
        return true, CONTEXT_LABELS[context] .. ": no preset, Henge leaves your settings alone there"
    end
    return true, CONTEXT_LABELS[context] .. " set to \"" .. preset.label .. "\"; applies on your next arrival or login"
end

local function GetCharacters()
    local db = EnsureDB()
    local current = CharacterKey()
    local list = {}
    for key, slots in pairs(db.characters) do
        if type(slots) == "table" then
            list[#list + 1] = { key = key, slots = slots, current = key == current }
        end
    end
    table.sort(list, function(a, b) return a.key < b.key end)
    return list
end

local function ForgetCharacter(key)
    local db = EnsureDB()
    if db.characters[key] == nil then
        return false, "no saved locations for " .. tostring(key)
    end
    db.characters[key] = nil
    NotifyChanged()
    return true, "forgot the locations of " .. key
end

local function DetectContext()
    local inInstance, instanceType = IsInInstance()
    return inInstance and INSTANCE_CONTEXT[instanceType] or "world"
end

-- Acts only when the kind of location changed, or at login, so a preset swapped by hand holds until then.
local function EvaluateContext(isLogin)
    local db = EnsureDB()
    local context = DetectContext()
    local previous = db.context or "world"
    db.context = context
    if context == previous and not isLogin then return end

    local slots = ActiveSlots()
    local preset = FindPreset(slots[context])

    -- With no Open World preset, remember what was in effect outside so leaving can put it back.
    if context ~= "world" and previous == "world" and not slots.world and not db.restore then
        db.restore = { active = db.active, cvars = Snapshot() }
    end
    db.activeBy = nil

    if preset then
        if context == "world" then db.restore = nil end
        if Matches(preset.cvars) then
            db.active = preset.id
            db.activeBy = context
            db.baseline = Snapshot()
            NotifyChanged()
        else
            local _, message = ApplyPreset(preset.id, context)
            Print(CONTEXT_LABELS[context] .. ": " .. message)
        end
    elseif context == "world" and db.restore then
        local restore = db.restore
        db.restore = nil
        db.active = type(restore.active) == "string" and restore.active or nil
        db.baseline = nil
        if Matches(restore.cvars) then
            db.baseline = Snapshot()
        else
            local queued = WriteCVars(restore.cvars)
            Print("Open World: your previous settings " .. (queued and "return when combat ends" or "restored"))
        end
        NotifyChanged()
    else
        NotifyChanged()
    end
end

-- First run: keep a way back to what the player had, and adopt presets saved in inari.
local function Startup()
    local db = EnsureDB()
    if not db.originalSaved then
        db.originalSaved = true
        if not FindPreset(ORIGINAL_PRESET_NAME) and SavePreset(ORIGINAL_PRESET_NAME) then
            Print("saved your current graphics settings as \"" .. ORIGINAL_PRESET_NAME .. "\"")
        end
    end

    local inari = _G.InariDB
    if not db.inariPresetsImported and type(inari) == "table" and type(inari.graphicsPresets) == "table" then
        db.inariPresetsImported = true
        local imported = 0
        for _, saved in ipairs(inari.graphicsPresets) do
            if type(saved) == "table" and type(saved.name) == "string" and type(saved.cvars) == "table"
                and not FindPreset(saved.name) then
                local cvars = {}
                for _, cvar in ipairs(saved.cvars) do
                    if type(cvar) == "table" and cvar[1] ~= RAID_SETTINGS_CVAR then
                        cvars[#cvars + 1] = { cvar[1], tostring(cvar[2]) }
                    end
                end
                if SavePreset(saved.name, cvars) then imported = imported + 1 end
            end
        end
        if imported > 0 then
            Print("imported " .. imported .. (imported == 1 and " preset" or " presets") .. " from inari")
        end
    end
end

local function PrintPresets()
    local presets = GetPresets()
    local current, _, modified = GetCurrentPreset(presets)
    local names = {}
    for index, preset in ipairs(presets) do
        names[index] = preset.builtin and preset.id or preset.label
    end
    local slots, own = ActiveSlots()
    local assigned = {}
    for _, context in ipairs(CONTEXTS) do
        local preset = FindPreset(slots[context], presets)
        assigned[#assigned + 1] = CONTEXT_LABELS[context] .. " = " .. (preset and preset.label or "none")
    end
    Print("current: " .. (current and current.label or "custom") .. (modified and " (modified)" or "")
        .. "; presets: " .. table.concat(names, ", "))
    Print((own and "this character's locations: " or "account locations: ") .. table.concat(assigned, ", "))
    -- No "|" in chat text: the client reads "|r" and "|c" as colour codes.
    Print("commands: /henge next, /henge <name>, /henge save <name>, /henge delete <name>, /henge set world/dungeon/raid <name> (or none)")
end

local function HandleCommand(arg)
    EnsureDB()
    arg = tostring(arg or ""):match("^%s*(.-)%s*$")
    local word, rest = arg:match("^(%S*)%s*(.-)$")
    word = string.lower(word)

    local _, message
    if word == "" then
        ns.OpenWindow()
        return
    elseif word == "list" or word == "help" or word == "status" then
        PrintPresets()
        return
    elseif word == "next" or word == "toggle" or word == "cycle" or word == "swap" then
        _, message = CyclePreset()
    elseif word == "save" or word == "add" then
        _, message = SavePreset(rest)
    elseif word == "delete" or word == "remove" then
        _, message = DeletePreset(rest)
    elseif word == "set" then
        local context, name = rest:match("^(%S*)%s*(.-)$")
        context = string.lower(context)
        if not CONTEXT_LABELS[context] or name == "" then
            message = "usage: /henge set world/dungeon/raid <name> (or none)"
        elseif string.lower(name) == "none" then
            _, message = SetSlot(context, nil)
        else
            _, message = SetSlot(context, name)
        end
    else
        _, message = ApplyPreset(arg)
    end
    Print(message)
end

SLASH_HENGE1 = "/henge"
SlashCmdList.HENGE = HandleCommand

function Henge_OnAddonCompartmentClick()
    ns.OpenWindow()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(_, _, isInitialLogin)
    EnsureDB()
    -- A login followed at once by another loading screen must still count as the login.
    if isInitialLogin then loginPending = true end
    contextSerial = contextSerial + 1
    local serial = contextSerial
    C_Timer.After(CONTEXT_DELAY, function()
        if serial ~= contextSerial then return end
        if not started then
            started = true
            Startup()
        end
        local isLogin = loginPending
        loginPending = false
        EvaluateContext(isLogin)
    end)
end)

ns.Print = Print
ns.EnsureDB = EnsureDB
ns.CONTEXTS = CONTEXTS
ns.CONTEXT_LABELS = CONTEXT_LABELS
ns.GetPresets = GetPresets
ns.FindPreset = FindPreset
ns.GetCurrentPreset = GetCurrentPreset
ns.ApplyPreset = ApplyPreset
ns.SavePreset = SavePreset
ns.DeletePreset = DeletePreset
ns.ActiveSlots = ActiveSlots
ns.SetOwnSlots = SetOwnSlots
ns.SetSlot = SetSlot
ns.GetCharacters = GetCharacters
ns.ForgetCharacter = ForgetCharacter
ns.CharacterKey = CharacterKey

-- fn runs whenever presets, locations or the active preset change.
function ns.OnChanged(fn)
    listeners[#listeners + 1] = fn
end

-- Entry points for other addons; inari hands its graphics commands over to these.
Henge = {
    Open = function() ns.OpenWindow() end,
    Command = HandleCommand,
}
