local ADDON_NAME, ns = ...

local UI = {}
ns.UI = UI

local MEDIA = "Interface\\AddOns\\Henge\\Media\\"

UI.Media = {
    Logo = MEDIA .. "logo.png",
    Font = MEDIA .. "Gilroy-Regular.ttf",
    FontSemiBold = MEDIA .. "Gilroy-SemiBold.ttf",
    FontBold = MEDIA .. "Gilroy-Bold.ttf",
}

UI.Theme = {
    bg = { 0x0C / 255, 0x0A / 255, 0x0C / 255, 0.98 },
    header = { 0x12 / 255, 0x0E / 255, 0x12 / 255, 1.00 },
    panel = { 0x10 / 255, 0x0C / 255, 0x10 / 255, 1.00 },
    row = { 0x18 / 255, 0x13 / 255, 0x18 / 255, 1.00 },
    rowHover = { 0x22 / 255, 0x1A / 255, 0x22 / 255, 1.00 },
    line = { 0x3A / 255, 0x2C / 255, 0x32 / 255, 1.00 },
    accent = { 0xE8 / 255, 0xA4 / 255, 0xB8 / 255, 1.00 },
    accentDim = { 0xE8 / 255, 0xA4 / 255, 0xB8 / 255, 0.18 },
    accentBarely = { 0xE8 / 255, 0xA4 / 255, 0xB8 / 255, 0.08 },
    ink = { 0x0C / 255, 0x0A / 255, 0x0C / 255, 1.00 },
    text = { 0xFF / 255, 0xFF / 255, 0xFF / 255, 1.00 },
    muted = { 0xA0 / 255, 0x8A / 255, 0x94 / 255, 1.00 },
    subtle = { 0x7A / 255, 0x68 / 255, 0x72 / 255, 1.00 },
    success = { 0x7E / 255, 0xC8 / 255, 0xB0 / 255, 1.00 },
    error = { 0xE0 / 255, 0x6B / 255, 0x7A / 255, 1.00 },
}

local function Unpack(color, alpha)
    return color[1], color[2], color[3], alpha or color[4] or 1
end

local function Color(target, color)
    target:SetTextColor(Unpack(color))
end

local function ApplyTexture(frame, key, layer, color, alpha)
    local texture = frame[key]
    if not texture then
        texture = frame:CreateTexture(nil, layer or "BACKGROUND")
        texture:SetAllPoints()
        frame[key] = texture
    end
    texture:SetColorTexture(Unpack(color, alpha))
    return texture
end

local function SetFlatBackground(frame, color, alpha)
    return ApplyTexture(frame, "_hengeBg", "BACKGROUND", color, alpha)
end

local function FontPath(weight)
    if weight == "bold" then return UI.Media.FontBold end
    if weight == "semibold" then return UI.Media.FontSemiBold end
    return UI.Media.Font
end

local function ApplyFont(fontString, path, size, flags)
    if not fontString or type(path) ~= "string" or path == "" then return false end
    -- SetFont raises if the file is missing. The success boolean is not evidence
    -- the face can draw, so only the raise matters.
    return pcall(fontString.SetFont, fontString, path, size or 12, flags or "")
end

local function SetFont(fontString, size, weight, flags)
    size = size or 12
    fontString._hengeFontSize = size
    fontString._hengeFontWeight = weight
    fontString._hengeFontFlags = flags
    if ApplyFont(fontString, FontPath(weight), size, flags) then
        return true
    end
    if weight ~= "bold" and ApplyFont(fontString, UI.Media.FontBold, size, flags) then
        return true
    end
    if ApplyFont(fontString, UI.Media.Font, size, flags) then
        return true
    end
    return ApplyFont(fontString, STANDARD_TEXT_FONT, size, flags)
end

local function PixelSize(frame, value)
    if PixelUtil and PixelUtil.GetNearestPixelSize and frame then
        local scale = frame:GetEffectiveScale()
        if scale and scale > 0 then
            return PixelUtil.GetNearestPixelSize(value, scale)
        end
    end
    return value
end

local function SnapSize(region, width, height)
    if PixelUtil and PixelUtil.SetSize then
        PixelUtil.SetSize(region, width, height)
        return
    end
    region:SetSize(width, height)
end

local function SnapWidth(region, width)
    if PixelUtil and PixelUtil.SetWidth then
        PixelUtil.SetWidth(region, width)
        return
    end
    region:SetWidth(width)
end

local function SnapHeight(region, height)
    if PixelUtil and PixelUtil.SetHeight then
        PixelUtil.SetHeight(region, height)
        return
    end
    region:SetHeight(height)
end

local function AddBorder(frame, thickness)
    thickness = thickness or 2
    local border = frame._hengeBorder
    if not border then
        border = {}
        frame._hengeBorder = border
        local function Edge(key)
            local tex = frame:CreateTexture(nil, "BORDER")
            tex:SetColorTexture(Unpack(UI.Theme.line))
            border[key] = tex
            return tex
        end
        border.top = Edge("top")
        border.bottom = Edge("bottom")
        border.left = Edge("left")
        border.right = Edge("right")
    end

    local size = PixelSize(frame, thickness)
    border.top:ClearAllPoints()
    border.top:SetPoint("TOPLEFT")
    border.top:SetPoint("TOPRIGHT")
    SnapHeight(border.top, size)

    border.bottom:ClearAllPoints()
    border.bottom:SetPoint("BOTTOMLEFT")
    border.bottom:SetPoint("BOTTOMRIGHT")
    SnapHeight(border.bottom, size)

    border.left:ClearAllPoints()
    border.left:SetPoint("TOPLEFT")
    border.left:SetPoint("BOTTOMLEFT")
    SnapWidth(border.left, size)

    border.right:ClearAllPoints()
    border.right:SetPoint("TOPRIGHT")
    border.right:SetPoint("BOTTOMRIGHT")
    SnapWidth(border.right, size)
    return border
end

local function SetBorderColor(frame, color, alpha)
    local border = frame._hengeBorder
    if not border then return end
    for _, key in ipairs({ "top", "bottom", "left", "right" }) do
        local tex = border[key]
        if tex then tex:SetColorTexture(Unpack(color, alpha)) end
    end
end

local function SetBorderShown(frame, shown)
    local border = frame._hengeBorder
    if not border then return end
    for _, key in ipairs({ "top", "bottom", "left", "right" }) do
        local tex = border[key]
        if tex then tex:SetShown(shown) end
    end
end

local function RegisterEscape(frame)
    if not frame or not frame.GetName then return end
    local name = frame:GetName()
    if not name or name == "" then return end
    UISpecialFrames = UISpecialFrames or {}
    for _, existing in ipairs(UISpecialFrames) do
        if existing == name then return end
    end
    tinsert(UISpecialFrames, name)
end

local function FadeIn(frame, duration)
    if UIFrameFadeIn then
        UIFrameFadeIn(frame, duration or 0.10, 0, 1)
        return
    end
    frame:SetAlpha(1)
end

local function AddonVersion()
    local getter = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    if getter then
        return getter(ADDON_NAME, "Version") or ""
    end
    return ""
end

function UI:SetFrameColor(frame, color)
    SetFlatBackground(frame, color or self.Theme.row)
end

function UI:SetTextColor(fontString, kind)
    Color(fontString, self.Theme[kind or "text"] or self.Theme.text)
end

function UI:SetStatusColor(fontString, ok)
    Color(fontString, ok and self.Theme.success or self.Theme.error)
end

function UI:CreateText(parent, text, size, kind, weight)
    local fontString = parent:CreateFontString(nil, "OVERLAY")
    fontString:SetDrawLayer("OVERLAY", 7)
    SetFont(fontString, size or 12, weight)
    fontString:SetJustifyH("LEFT")
    fontString:SetJustifyV("MIDDLE")
    fontString:SetText(text or "")
    self:SetTextColor(fontString, kind or "text")
    return fontString
end

local function ApplyButtonVisual(button)
    if button._disabled then
        button:SetAlpha(0.42)
        return
    end
    button:SetAlpha(1)
    if button.variant == "primary" or button.choiceActive then
        local alpha = 1
        if button._pressed then
            alpha = 0.70
        elseif button._hovered then
            alpha = 0.86
        end
        SetFlatBackground(button, UI.Theme.accent, alpha)
        SetBorderShown(button, false)
        if button.label then button.label:SetTextColor(Unpack(UI.Theme.ink)) end
        if button.activeIndicator then button.activeIndicator:Hide() end
        return
    end

    SetFlatBackground(button, UI.Theme.bg, 0)
    if button.variant == "link" then
        SetBorderShown(button, false)
    else
        SetBorderShown(button, true)
        if button._pressed then
            SetBorderColor(button, UI.Theme.accent, 0.70)
        elseif button._hovered then
            SetBorderColor(button, UI.Theme.accent)
        else
            SetBorderColor(button, UI.Theme.line)
        end
    end
    if button.label then
        if button._hovered then
            UI:SetTextColor(button.label, "text")
        else
            UI:SetTextColor(button.label, "muted")
        end
    end
    if button.activeIndicator then
        button.activeIndicator:Hide()
    end
end

function UI:CreateButton(parent, label, variant)
    local button = CreateFrame("Button", nil, parent)
    SnapSize(button, 150, 32)
    button:RegisterForClicks("LeftButtonUp")
    button:EnableMouse(true)
    button.variant = variant or "ghost"
    button._labelText = label or ""
    SetFlatBackground(button, self.Theme.bg, 0)
    AddBorder(button, 2)

    button.label = self:CreateText(button, button._labelText, 12, "text", "bold")
    button.label:SetPoint("CENTER")
    button.label:SetJustifyH("CENTER")
    button.label:SetJustifyV("MIDDLE")
    button.label:SetWordWrap(false)

    button.activeIndicator = button:CreateTexture(nil, "ARTWORK")
    button.activeIndicator:SetPoint("TOPLEFT")
    button.activeIndicator:SetPoint("BOTTOMLEFT")
    SnapWidth(button.activeIndicator, PixelSize(button, 2))
    button.activeIndicator:SetColorTexture(Unpack(self.Theme.accent))
    button.activeIndicator:Hide()

    function button:SetOnClick(callback)
        self._hengeOnClick = callback
    end

    function button:SetLabel(text)
        self._labelText = text or ""
        SetFont(self.label, self.label._hengeFontSize or 12, "bold", self.label._hengeFontFlags)
        self.label:SetText(self._labelText)
    end

    function button:SetChoiceActive(active)
        self.choiceActive = active and true or false
        ApplyButtonVisual(self)
    end

    function button:SetEnabledState(enabled)
        self._disabled = not enabled
        self:EnableMouse(enabled and true or false)
        if self.Enable then
            if enabled then self:Enable() else self:Disable() end
        end
        ApplyButtonVisual(self)
    end

    button:SetScript("OnEnter", function(self)
        self._hovered = true
        ApplyButtonVisual(self)
    end)
    button:SetScript("OnLeave", function(self)
        self._hovered = false
        self._pressed = false
        ApplyButtonVisual(self)
    end)
    button:SetScript("OnMouseDown", function(self, mouseButton)
        if self._disabled or mouseButton ~= "LeftButton" then return end
        self._pressed = true
        ApplyButtonVisual(self)
    end)
    button:SetScript("OnMouseUp", function(self)
        self._pressed = false
        ApplyButtonVisual(self)
    end)
    button:SetScript("OnClick", function(self)
        if self._disabled then return end
        if self._hengeOnClick then self:_hengeOnClick() end
    end)

    ApplyButtonVisual(button)
    return button
end

function UI:CreatePrimaryButton(parent, label)
    return self:CreateButton(parent, label, "primary")
end

function UI:CreateGhostButton(parent, label)
    return self:CreateButton(parent, label, "ghost")
end

function UI:CreateWindow(name, parent, width, height, context)
    local frame = CreateFrame("Frame", name, parent or UIParent)
    SnapSize(frame, width or 880, height or 600)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    SetFlatBackground(frame, self.Theme.bg)
    AddBorder(frame, 2)
    RegisterEscape(frame)

    frame.header = CreateFrame("Frame", nil, frame)
    frame.header:SetPoint("TOPLEFT", 2, -2)
    frame.header:SetPoint("TOPRIGHT", -2, -2)
    SnapHeight(frame.header, 52)
    frame.header:EnableMouse(true)
    frame.header:RegisterForDrag("LeftButton")
    frame.header:SetScript("OnDragStart", function() frame:StartMoving() end)
    frame.header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    SetFlatBackground(frame.header, self.Theme.header)

    frame.headerRule = frame:CreateTexture(nil, "ARTWORK")
    frame.headerRule:SetColorTexture(Unpack(self.Theme.line))
    frame.headerRule:SetPoint("TOPLEFT", frame.header, "BOTTOMLEFT")
    frame.headerRule:SetPoint("TOPRIGHT", frame.header, "BOTTOMRIGHT")
    SnapHeight(frame.headerRule, PixelSize(frame, 2))

    frame.logo = frame.header:CreateTexture(nil, "ARTWORK")
    frame.logo:SetTexture(self.Media.Logo)
    SnapSize(frame.logo, 32, 32)
    frame.logo:SetPoint("LEFT", 16, 0)

    frame.title = self:CreateText(frame.header, "Henge", 16, "text", "bold")
    frame.title:SetPoint("LEFT", frame.logo, "RIGHT", 10, 1)

    frame.backButton = self:CreateGhostButton(frame.header, "<")
    SnapSize(frame.backButton, 28, 28)
    frame.backButton:SetPoint("LEFT", 12, 0)
    frame.backButton:Hide()

    frame.subtitle = self:CreateText(frame.header, context or "settings", 11, "accent", "bold")
    frame.subtitle:SetPoint("LEFT", frame.title, "RIGHT", 8, -1)

    frame.version = self:CreateText(frame.header, AddonVersion(), 11, "subtle", "bold")
    frame.version:SetPoint("RIGHT", -46, 0)
    frame.version:SetJustifyH("RIGHT")

    frame.closeButton = self:CreateGhostButton(frame.header, "x")
    SnapSize(frame.closeButton, 28, 28)
    frame.closeButton:SetPoint("RIGHT", -12, 0)
    frame.closeButton:SetOnClick(function()
        frame:Hide()
    end)

    frame.body = CreateFrame("Frame", nil, frame)
    frame.body:SetPoint("TOPLEFT", frame.header, "BOTTOMLEFT", 16, -16)
    frame.body:SetPoint("BOTTOMRIGHT", -16, 16)

    function frame:SetContext(text)
        self.subtitle:SetText(text or "")
        UI:SetTextColor(self.subtitle, "accent")
    end

    function frame:SetBackVisible(visible, onBack)
        self.backButton:SetShown(visible and true or false)
        self.logo:ClearAllPoints()
        if visible then
            self.logo:SetPoint("LEFT", self.backButton, "RIGHT", 8, 0)
            self.backButton:SetOnClick(function()
                if onBack then onBack() end
            end)
        else
            self.logo:SetPoint("LEFT", 16, 0)
        end
    end

    function frame:SetOnClose(callback)
        self._onClose = callback
        self.closeButton:SetOnClick(function()
            if self._onClose then self._onClose() end
            self:Hide()
        end)
    end

    frame:SetScript("OnShow", function(self)
        FadeIn(self, 0.10)
    end)

    return frame
end

function UI:CreateStatusRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    SnapHeight(row, 34)
    SetFlatBackground(row, self.Theme.row)

    row.text = self:CreateText(row, "", 12, "muted", "semibold")
    row.text:SetPoint("LEFT", 12, 0)
    row.text:SetPoint("RIGHT", -12, 0)

    function row:SetStatus(ok, message)
        self.text:SetText(message or "")
        UI:SetStatusColor(self.text, ok)
        self:Show()
    end

    function row:SetMuted(message)
        self.text:SetText(message or "")
        UI:SetTextColor(self.text, "muted")
        self:Show()
    end

    row:Hide()
    return row
end

function UI:CreateToggleRow(parent, labelText)
    local row = CreateFrame("Button", nil, parent)
    SnapHeight(row, 40)
    row:RegisterForClicks("LeftButtonUp")
    row:EnableMouse(true)
    row.checked = false
    SetFlatBackground(row, self.Theme.row)

    row.label = self:CreateText(row, labelText, 12, "text", "semibold")
    row.label:SetPoint("LEFT", 14, 0)
    row.label:SetPoint("RIGHT", -74, 0)

    row.track = CreateFrame("Frame", nil, row)
    SnapSize(row.track, 44, 22)
    row.track:SetPoint("RIGHT", -12, 0)
    row.track.bg = row.track:CreateTexture(nil, "BACKGROUND")
    row.track.bg:SetAllPoints()

    row.thumb = row.track:CreateTexture(nil, "ARTWORK")
    SnapSize(row.thumb, 16, 16)
    row.thumb:SetColorTexture(Unpack(self.Theme.text))

    function row:Refresh()
        self.thumb:ClearAllPoints()
        if self.checked then
            self.track.bg:SetColorTexture(Unpack(UI.Theme.accent))
            self.thumb:SetPoint("RIGHT", self.track, "RIGHT", -3, 0)
        else
            self.track.bg:SetColorTexture(Unpack(UI.Theme.subtle, 0.55))
            self.thumb:SetPoint("LEFT", self.track, "LEFT", 3, 0)
        end
    end

    function row:SetChecked(value)
        self.checked = value and true or false
        self:Refresh()
    end

    function row:GetChecked()
        return self.checked
    end

    function row:SetOnChanged(callback)
        self._onChanged = callback
    end

    function row:SetOnClick(callback)
        self:SetOnChanged(callback)
    end

    row:SetScript("OnEnter", function(self)
        SetFlatBackground(self, UI.Theme.rowHover)
    end)
    row:SetScript("OnLeave", function(self)
        SetFlatBackground(self, UI.Theme.row)
    end)
    row:SetScript("OnClick", function(self)
        self:SetChecked(not self.checked)
        if self._onChanged then self:_onChanged(self.checked) end
    end)
    row:Refresh()
    return row
end

-- options: { { value = ..., label = ... }, ... }. The arrows step through them and wrap around.
function UI:CreateChoiceRow(parent, label, callback)
    local row = CreateFrame("Frame", nil, parent)
    SnapHeight(row, 40)
    SetFlatBackground(row, self.Theme.row)

    row.label = self:CreateText(row, label, 12, "text", "semibold")
    row.label:SetPoint("LEFT", 14, 0)

    row.next = self:CreateGhostButton(row, ">")
    SnapSize(row.next, 34, 24)
    row.next:SetPoint("RIGHT", -12, 0)

    row.previous = self:CreateGhostButton(row, "<")
    SnapSize(row.previous, 34, 24)
    row.previous:SetPoint("RIGHT", row.next, "LEFT", -176, 0)

    row.valueText = self:CreateText(row, "", 12, "text", "semibold")
    row.valueText:SetPoint("LEFT", row.previous, "RIGHT", 8, 0)
    row.valueText:SetPoint("RIGHT", row.next, "LEFT", -8, 0)
    row.valueText:SetJustifyH("CENTER")
    row.valueText:SetWordWrap(false)

    row.options = {}
    row.index = 1

    function row:SetOptions(options, value)
        self.options = options
        self.index = 1
        for index, option in ipairs(options) do
            if option.value == value then
                self.index = index
                break
            end
        end
        local current = options[self.index]
        self.valueText:SetText(current and current.label or "")
    end

    local function Step(delta)
        local count = #row.options
        if count == 0 then return end
        row.index = (row.index - 1 + delta) % count + 1
        local current = row.options[row.index]
        row.valueText:SetText(current.label)
        if callback then callback(row, current.value) end
    end
    row.previous:SetOnClick(function() Step(-1) end)
    row.next:SetOnClick(function() Step(1) end)
    return row
end

function UI:CreateInputRow(parent, placeholder, buttonLabel, callback)
    local row = CreateFrame("Frame", nil, parent)
    SnapHeight(row, 40)
    SetFlatBackground(row, self.Theme.row)

    row.button = self:CreateGhostButton(row, buttonLabel)
    SnapSize(row.button, 130, 24)
    row.button:SetPoint("RIGHT", -12, 0)

    row.edit = CreateFrame("EditBox", nil, row)
    row.edit:SetAutoFocus(false)
    row.edit:SetMaxLetters(40)
    row.edit:SetPoint("LEFT", 14, 0)
    row.edit:SetPoint("RIGHT", row.button, "LEFT", -12, 0)
    SnapHeight(row.edit, 24)
    SetFont(row.edit, 12, "semibold", "")
    row.edit:SetTextColor(Unpack(UI.Theme.text))

    row.placeholder = self:CreateText(row, placeholder, 12, "muted", "semibold")
    row.placeholder:SetPoint("LEFT", row.edit, "LEFT", 0, 0)

    local function Submit()
        row.edit:ClearFocus()
        if callback then callback(row, row.edit:GetText() or "") end
    end

    function row:SetText(text)
        self.edit:SetText(text or "")
    end

    row.edit:SetScript("OnTextChanged", function(self)
        row.placeholder:SetShown((self:GetText() or "") == "")
    end)
    row.edit:SetScript("OnEnterPressed", Submit)
    row.edit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    row.button:SetOnClick(Submit)
    return row
end

local function CreateScrollbar(scrollFrame)
    local bar = CreateFrame("Slider", nil, scrollFrame)
    bar:SetPoint("TOPRIGHT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", 0, 0)
    SnapWidth(bar, 4)
    bar:SetMinMaxValues(0, 1)
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(false)
    SetFlatBackground(bar, UI.Theme.panel)

    bar.thumb = bar:CreateTexture(nil, "ARTWORK")
    bar.thumb:SetColorTexture(Unpack(UI.Theme.accent))
    SnapWidth(bar.thumb, 4)
    bar:SetThumbTexture(bar.thumb)

    local function Sync()
        local range = scrollFrame:GetVerticalScrollRange() or 0
        if range <= 1 then
            bar:Hide()
            return
        end
        bar:Show()
        bar:SetMinMaxValues(0, range)
        bar:SetValue(scrollFrame:GetVerticalScroll() or 0)
        local height = math.max(24, (scrollFrame:GetHeight() / (scrollFrame:GetHeight() + range)) * scrollFrame:GetHeight())
        SnapHeight(bar.thumb, height)
    end

    bar:SetScript("OnValueChanged", function(_, value)
        scrollFrame:SetVerticalScroll(value)
    end)
    scrollFrame:HookScript("OnScrollRangeChanged", Sync)
    scrollFrame:HookScript("OnVerticalScroll", function(_, offset)
        bar:SetValue(offset or 0)
    end)
    bar.Sync = Sync
    bar:Hide()
    return bar
end

function UI:CreateSection(parentPage, titleText, maxWidth)
    local section = CreateFrame("Frame", nil, parentPage.scrollChild)
    section:SetWidth(maxWidth or parentPage.maxSectionWidth or 620)
    section.cursorY = 0
    section.rows = {}

    local function Advance(self, amount)
        self.cursorY = self.cursorY - amount
        self:SetHeight(math.max(1, math.abs(self.cursorY)))
    end

    if titleText and titleText ~= "" then
        section.title = self:CreateText(section, titleText, 11, "muted", "semibold")
        section.title:SetPoint("TOPLEFT", 0, section.cursorY)
        section.underline = section:CreateTexture(nil, "ARTWORK")
        section.underline:SetColorTexture(Unpack(self.Theme.accent))
        SnapSize(section.underline, 28, PixelSize(section, 2))
        section.underline:SetPoint("TOPLEFT", section.title, "BOTTOMLEFT", 0, -4)
        Advance(section, 28)
    end

    function section:AddToggle(label, checked, callback)
        local row = UI:CreateToggleRow(self, label)
        row:SetPoint("TOPLEFT", 0, self.cursorY)
        row:SetPoint("TOPRIGHT", 0, self.cursorY)
        row:SetChecked(checked)
        row:SetOnChanged(callback)
        self.rows[#self.rows + 1] = row
        Advance(self, 48)
        return row
    end

    function section:AddInfoRow(label, value)
        local row = CreateFrame("Frame", nil, self)
        row:SetPoint("TOPLEFT", 0, self.cursorY)
        row:SetPoint("TOPRIGHT", 0, self.cursorY)
        SnapHeight(row, 40)
        UI:SetFrameColor(row, UI.Theme.row)

        row.label = UI:CreateText(row, label, 12, "muted", "semibold")
        row.label:SetPoint("LEFT", 14, 0)

        row.value = UI:CreateText(row, value, 12, "text", "semibold")
        row.value:SetPoint("RIGHT", -14, 0)
        row.value:SetJustifyH("RIGHT")

        self.rows[#self.rows + 1] = row
        Advance(self, 48)
        return row
    end

    function section:AddButtonRow(buttons, align)
        local row = CreateFrame("Frame", nil, self)
        row:SetPoint("TOPLEFT", 0, self.cursorY)
        row:SetPoint("TOPRIGHT", 0, self.cursorY)
        SnapHeight(row, 34)
        row.buttons = {}

        local totalWidth = 0
        for index, data in ipairs(buttons) do
            totalWidth = totalWidth + (data.width or 150)
            if index > 1 then totalWidth = totalWidth + 8 end
        end

        local previous
        for _, data in ipairs(buttons) do
            local button
            if data.variant == "primary" then
                button = UI:CreatePrimaryButton(row, data.label)
            else
                button = UI:CreateGhostButton(row, data.label)
            end
            SnapSize(button, data.width or 150, 34)
            button:SetOnClick(data.onClick)
            row.buttons[#row.buttons + 1] = button
            if previous then
                button:SetPoint("LEFT", previous, "RIGHT", 8, 0)
            elseif align == "right" then
                button:SetPoint("TOPLEFT", row, "TOPRIGHT", -totalWidth, 0)
            else
                button:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
            end
            previous = button
        end

        self.rows[#self.rows + 1] = row
        Advance(self, 48)
        return row
    end

    function section:AddChoiceRow(label, callback)
        local row = UI:CreateChoiceRow(self, label, callback)
        row:SetPoint("TOPLEFT", 0, self.cursorY)
        row:SetPoint("TOPRIGHT", 0, self.cursorY)
        self.rows[#self.rows + 1] = row
        Advance(self, 48)
        return row
    end

    function section:AddInputRow(placeholder, buttonLabel, callback)
        local row = UI:CreateInputRow(self, placeholder, buttonLabel, callback)
        row:SetPoint("TOPLEFT", 0, self.cursorY)
        row:SetPoint("TOPRIGHT", 0, self.cursorY)
        self.rows[#self.rows + 1] = row
        Advance(self, 48)
        return row
    end

    function section:AddText(text, size, kind, height)
        local line = UI:CreateText(self, text, size or 13, kind or "text", "semibold")
        line:SetPoint("TOPLEFT", 0, self.cursorY)
        line:SetPoint("RIGHT", 0, 0)
        line:SetWordWrap(true)
        line:SetSpacing(4)
        self.rows[#self.rows + 1] = line
        Advance(self, height or 48)
        return line
    end

    return section
end

function UI:CreatePage(parent, titleText, descriptionText, maxSectionWidth)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page.maxSectionWidth = maxSectionWidth or 620
    page.sections = {}
    page.splitRows = {}
    page:Show()

    page.header = self:CreateText(page, titleText, 20, "text", "bold")
    page.header:SetPoint("TOPLEFT", 0, 0)
    page.header:SetPoint("RIGHT", 0, 0)

    page.description = self:CreateText(page, descriptionText or "", 12, "muted", "semibold")
    page.description:SetPoint("TOPLEFT", page.header, "BOTTOMLEFT", 0, -8)
    page.description:SetPoint("RIGHT", 0, 0)
    page.description:SetWordWrap(true)
    page.description:SetSpacing(3)

    page.toast = self:CreateStatusRow(page)
    page.toast:SetPoint("BOTTOMLEFT", 0, 0)
    page.toast:SetPoint("BOTTOMRIGHT", 0, 0)
    SnapHeight(page.toast, 34)

    page.scrollFrame = CreateFrame("ScrollFrame", nil, page)
    page.scrollFrame:SetPoint("TOPLEFT", page.description, "BOTTOMLEFT", 0, -18)
    page.scrollFrame:SetPoint("BOTTOMRIGHT", page.toast, "TOPRIGHT", -10, 12)
    page.scrollFrame:EnableMouseWheel(true)
    page.scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        local nextScroll = current - (delta * 42)
        if nextScroll < 0 then nextScroll = 0 end
        if nextScroll > maxScroll then nextScroll = maxScroll end
        self:SetVerticalScroll(nextScroll)
    end)

    page.scrollChild = CreateFrame("Frame", nil, page.scrollFrame)
    page.scrollChild:SetSize(page.maxSectionWidth, 1)
    page.scrollFrame:SetScrollChild(page.scrollChild)
    page.scrollbar = CreateScrollbar(page.scrollFrame)

    local toastTimer
    local function ShowToast(setter, a, b)
        setter(page.toast, a, b)
        if toastTimer then toastTimer:Cancel() end
        toastTimer = C_Timer.NewTimer(3.5, function()
            if page.toast then page.toast:Hide() end
        end)
    end

    function page:SetStatus(ok, message)
        ShowToast(page.toast.SetStatus, ok, message)
    end

    function page:SetMuted(message)
        ShowToast(page.toast.SetMuted, message)
    end

    function page:AddSection(title, sectionMaxWidth)
        local section = UI:CreateSection(self, title, sectionMaxWidth or self.maxSectionWidth)
        self.sections[#self.sections + 1] = section
        return section
    end

    function page:AddSplit(leftTitle, rightTitle)
        local width = math.floor((self.maxSectionWidth - 16) / 2)
        local left = UI:CreateSection(self, leftTitle, width)
        local right = UI:CreateSection(self, rightTitle, width)
        self.sections[#self.sections + 1] = left
        self.sections[#self.sections + 1] = right
        self.splitRows[#self.splitRows + 1] = { left = left, right = right }
        left._splitPartner = right
        right._splitPartner = left
        return left, right
    end

    function page:UpdateLayout()
        local currentY = 0
        local width = self.maxSectionWidth
        local seen = {}
        for _, section in ipairs(self.sections) do
            if not seen[section] then
                section:ClearAllPoints()
                if section._splitPartner then
                    local partner = section._splitPartner
                    seen[section] = true
                    seen[partner] = true
                    local left = section
                    local right = partner
                    for _, split in ipairs(self.splitRows) do
                        if split.left == section or split.right == section then
                            left, right = split.left, split.right
                            break
                        end
                    end
                    left:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 0, currentY)
                    right:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", left:GetWidth() + 16, currentY)
                    width = math.max(width, left:GetWidth() + right:GetWidth() + 16)
                    currentY = currentY - math.max(left:GetHeight(), right:GetHeight()) - 24
                else
                    seen[section] = true
                    section:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 0, currentY)
                    width = math.max(width, section:GetWidth())
                    currentY = currentY - section:GetHeight() - 24
                end
            end
        end
        self.scrollChild:SetWidth(width)
        self.scrollChild:SetHeight(math.max(1, math.abs(currentY)))
        if self.scrollbar and self.scrollbar.Sync then
            self.scrollbar:Sync()
        end
    end

    return page
end
