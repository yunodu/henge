local ADDON_NAME, ns = ...

local ROW_STEP = 48

local frame
local Refresh

-- Rows below a section's fixed rows; the section grows and shrinks with the list.
local function FitSection(section, top, count)
    section.cursorY = top - count * ROW_STEP
    section:SetHeight(math.max(1, -section.cursorY))
end

local function Build()
    local ui = ns.UI
    frame = ui:CreateWindow("HengeFrame", UIParent, 700, 680, "graphics presets")

    local page = ui:CreatePage(frame.body, "Graphics presets",
        "Save your graphics settings as presets, swap between them, and let Henge pick one per location or character.")

    local function Report(ok, message)
        if ok then page:SetMuted(message) else page:SetStatus(false, message) end
        ns.Print(message)
    end

    local presetSection = page:AddSection("Presets")
    local currentRow = presetSection:AddInfoRow("Current", "")
    presetSection:AddInputRow("Name for your current graphics settings", "Save Preset", function(row, text)
        local ok, message = ns.SavePreset(text)
        if ok then row:SetText("") end
        Report(ok, message)
    end)

    local presetTop = presetSection.cursorY
    local presetRows = {}
    local function PresetRow(index)
        local row = presetRows[index]
        if row then return row end

        row = CreateFrame("Frame", nil, presetSection)
        row:SetHeight(40)
        row:SetPoint("TOPLEFT", 0, presetTop - (index - 1) * ROW_STEP)
        row:SetPoint("TOPRIGHT", 0, presetTop - (index - 1) * ROW_STEP)
        ui:SetFrameColor(row, ui.Theme.row)

        row.label = ui:CreateText(row, "", 12, "text", "semibold")
        row.label:SetPoint("LEFT", 14, 0)

        row.apply = ui:CreateGhostButton(row, "Apply")
        row.apply:SetSize(90, 24)
        row.apply:SetPoint("RIGHT", -12, 0)
        row.apply:SetOnClick(function()
            Report(ns.ApplyPreset(row.presetId))
        end)

        row.delete = ui:CreateGhostButton(row, "Delete")
        row.delete:SetSize(80, 24)
        row.delete:SetPoint("RIGHT", row.apply, "LEFT", -8, 0)
        row.delete:SetOnClick(function()
            Report(ns.DeletePreset(row.presetId))
        end)

        row.update = ui:CreateGhostButton(row, "Update")
        row.update:SetSize(80, 24)
        row.update:SetPoint("RIGHT", row.delete, "LEFT", -8, 0)
        row.update:SetOnClick(function()
            Report(ns.SavePreset(row.presetLabel))
        end)

        presetRows[index] = row
        return row
    end

    local locationSection = page:AddSection("Locations")
    locationSection:AddText("Henge switches to these presets when you arrive or log in. \"None\" leaves your settings alone; with no Open World preset, leaving an instance brings back what you had before.", 12, "muted", 44)
    local ownToggle = locationSection:AddToggle("This character uses its own locations", false, function(_, checked)
        Report(true, ns.SetOwnSlots(checked))
    end)
    local slotRows = {}
    for _, context in ipairs(ns.CONTEXTS) do
        slotRows[context] = locationSection:AddChoiceRow(ns.CONTEXT_LABELS[context], function(_, value)
            Report(ns.SetSlot(context, value or nil))
        end)
    end

    local characterSection = page:AddSection("Characters")
    local characterEmpty = characterSection:AddText("No character has its own locations yet.", 12, "muted", 0)
    local characterTop = characterSection.cursorY
    local characterRows = {}
    local function CharacterRow(index)
        local row = characterRows[index]
        if row then return row end

        row = CreateFrame("Frame", nil, characterSection)
        row:SetHeight(40)
        row:SetPoint("TOPLEFT", 0, characterTop - (index - 1) * ROW_STEP)
        row:SetPoint("TOPRIGHT", 0, characterTop - (index - 1) * ROW_STEP)
        ui:SetFrameColor(row, ui.Theme.row)

        row.forget = ui:CreateGhostButton(row, "Forget")
        row.forget:SetSize(80, 24)
        row.forget:SetPoint("RIGHT", -12, 0)
        row.forget:SetOnClick(function()
            Report(ns.ForgetCharacter(row.characterKey))
        end)

        row.label = ui:CreateText(row, "", 12, "text", "semibold")
        row.label:SetPoint("LEFT", 14, 8)
        row.summary = ui:CreateText(row, "", 11, "muted", "semibold")
        row.summary:SetPoint("LEFT", 14, -8)
        row.summary:SetPoint("RIGHT", row.forget, "LEFT", -12, -8)
        row.summary:SetJustifyH("LEFT")
        row.summary:SetWordWrap(false)

        characterRows[index] = row
        return row
    end

    Refresh = function()
        local db = ns.EnsureDB()
        local presets = ns.GetPresets()
        local current, _, modified = ns.GetCurrentPreset(presets)

        local currentText = current and current.label or "custom"
        if modified then
            currentText = currentText .. " (modified)"
        elseif current and db.activeBy and db.active == current.id then
            currentText = currentText .. ", set by " .. ns.CONTEXT_LABELS[db.activeBy]
        end
        currentRow.value:SetText(currentText)

        for index, preset in ipairs(presets) do
            local row = PresetRow(index)
            local active = current ~= nil and current.id == preset.id
            row.presetId = preset.id
            row.presetLabel = preset.label
            row.label:SetText(preset.label)
            row.apply:SetLabel(active and not modified and "Active" or "Apply")
            row.apply:SetChoiceActive(active and not modified)
            row.delete:SetShown(not preset.builtin)
            row.update:SetShown(active and modified and not preset.builtin)
            row:Show()
        end
        for index = #presets + 1, #presetRows do
            presetRows[index]:Hide()
        end
        FitSection(presetSection, presetTop, #presets)

        local slots, own = ns.ActiveSlots()
        ownToggle:SetChecked(own)
        local options = { { value = false, label = "None" } }
        for _, preset in ipairs(presets) do
            options[#options + 1] = { value = preset.id, label = preset.label }
        end
        for _, context in ipairs(ns.CONTEXTS) do
            slotRows[context]:SetOptions(options, ns.FindPreset(slots[context], presets) and slots[context] or false)
        end

        local characters = ns.GetCharacters()
        for index, character in ipairs(characters) do
            local row = CharacterRow(index)
            local parts = {}
            for _, context in ipairs(ns.CONTEXTS) do
                local preset = ns.FindPreset(character.slots[context], presets)
                parts[#parts + 1] = ns.CONTEXT_LABELS[context] .. ": " .. (preset and preset.label or "None")
            end
            row.characterKey = character.key
            row.label:SetText(character.key .. (character.current and " (this character)" or ""))
            row.summary:SetText(table.concat(parts, "   "))
            row:Show()
        end
        for index = #characters + 1, #characterRows do
            characterRows[index]:Hide()
        end
        characterEmpty:SetShown(#characters == 0)
        -- The empty-state line takes the place of one short row.
        if #characters == 0 then
            characterSection.cursorY = characterTop - 24
            characterSection:SetHeight(-characterSection.cursorY)
        else
            FitSection(characterSection, characterTop, #characters)
        end

        page:UpdateLayout()
    end

    frame:HookScript("OnShow", Refresh)
    ns.OnChanged(function()
        if frame:IsShown() then Refresh() end
    end)

    -- Settings changed in Blizzard's menu flip the current preset to "modified" while the window is open.
    local refreshQueued = false
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("CVAR_UPDATE")
    watcher:SetScript("OnEvent", function()
        if refreshQueued or not frame:IsShown() then return end
        refreshQueued = true
        C_Timer.After(0.3, function()
            refreshQueued = false
            if frame:IsShown() then Refresh() end
        end)
    end)
end

-- Opens the window, or closes it when it is already open.
function ns.OpenWindow()
    ns.EnsureDB()
    if not frame then
        Build()
        frame:Show()
        Refresh()
        return
    end
    frame:SetShown(not frame:IsShown())
end
