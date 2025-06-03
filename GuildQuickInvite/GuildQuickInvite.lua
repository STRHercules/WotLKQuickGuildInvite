local INVITE_COOLDOWN = 21600 -- 6 hours in seconds
local inviteCache = {}
local UpdateDropdown
local editBox

SLASH_GQI1 = "/gqi"
SlashCmdList["GQI"] = function(msg)
    if not msg or msg == "" then
        print("|cffffff00[GQI]|r Current recruitment message: " ..
                  (GuildQuickInviteRecruitMsg or "Not set."))
    else
        GuildQuickInviteRecruitMsg = msg
        print("|cffffff00[GQI]|r Recruitment message updated!")
    end
end

-- On login, cleanup expired invites
local function CleanExpiredInvites()
    for name, timestamp in pairs(GuildQuickInviteDB) do
        if (time() - timestamp) > INVITE_COOLDOWN then
            GuildQuickInviteDB[name] = nil
        end
    end
end

local function HasCooldownExpired(name)
    local lastInvite = GuildQuickInviteDB[name]
    if not lastInvite then return true end
    return (time() - lastInvite) > INVITE_COOLDOWN
end

local function SendRecruitWhisper(name)
    local message = GuildQuickInviteActiveMessage
    if not message or message == "" then
        -- Fallback to the simple slash command message
        message = GuildQuickInviteRecruitMsg
    end
    if not message or message == "" then
        print(
            "|cffff0000[GQI]|r No recruitment message set. Use /gqi <message> to set one.")
        return
    end
    SendChatMessage(message, "WHISPER", nil, name)
    print("|cffffff00[GQI]|r Whisper sent to " .. name)
end

local function AddGuildInviteOption(unit)
    if UIDROPDOWNMENU_MENU_LEVEL ~= 1 then return end
    if not UnitIsPlayer(unit) or not UnitIsFriend("player", unit) then return end

    local name, server = UnitName(unit)
    if server and server ~= "" then name = name .. "-" .. server end

    if name and CanGuildInvite() and not UnitIsUnit("player", unit) then
        -- Invite to Guild
        local inviteInfo = UIDropDownMenu_CreateInfo()
        if HasCooldownExpired(name) then
            inviteInfo.text = "|cff00ff00Invite to Guild|r"
            inviteInfo.func = function()
                GuildInvite(name)
                GuildQuickInviteDB[name] = time()
                print("Guild invite sent to " .. name .. ". Cooldown started.")
            end
        else
            inviteInfo.text = "|cffff0000Already Invited (Cooldown)|r"
            inviteInfo.notClickable = true
        end
        inviteInfo.notCheckable = true
        UIDropDownMenu_AddButton(inviteInfo, UIDROPDOWNMENU_MENU_LEVEL)

        -- Recruit Whisper
        local recruitInfo = UIDropDownMenu_CreateInfo()
        recruitInfo.text = "|cffffff00Recruit|r"
        recruitInfo.func = function() SendRecruitWhisper(name) end
        recruitInfo.notCheckable = true
        UIDropDownMenu_AddButton(recruitInfo, UIDROPDOWNMENU_MENU_LEVEL)
    end
end

hooksecurefunc("UnitPopup_ShowMenu", function(dropdownMenu, which, unit)
    AddGuildInviteOption(unit)
end)

-- Create a frame to catch events
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "GuildQuickInvite" then
        GuildQuickInviteDB = GuildQuickInviteDB or {}
        GuildQuickInviteMessages = GuildQuickInviteMessages or {}
        GuildQuickInviteActiveMessage = GuildQuickInviteActiveMessage or ""
        GuildQuickInviteRecruitMsg = GuildQuickInviteRecruitMsg or ""
        CleanExpiredInvites()
        print(
            "|cffffff00[GQI]|r Addon loaded. Use /gqi <message> to set your recruitment message.")
    end
end)

-- CHAT MENU SUPPORT

local function AddChatMenuInviteOption()
    local dropdown = FriendsFrameDropDown
    local name = UIDROPDOWNMENU_INIT_MENU and UIDROPDOWNMENU_INIT_MENU.name
    if not name or name == UnitName("player") then return end

    -- Sanitize name
    name = string.match(name, "([^%-]+)") or name

    if not CanGuildInvite() then return end

    if HasCooldownExpired(name) then
        local info = UIDropDownMenu_CreateInfo()
        info.text = "|cff00ff00Invite to Guild|r"
        info.func = function()
            GuildInvite(name)
            GuildQuickInviteDB[name] = time()
            print("Guild invite sent to " .. name .. ". Cooldown started.")
        end
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, 1)
    else
        local info = UIDropDownMenu_CreateInfo()
        info.text = "|cffff0000Already Invited (Cooldown)|r"
        info.notClickable = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, 1)
    end

    -- Add "Recruit" whisper option
    local recruitInfo = UIDropDownMenu_CreateInfo()
    recruitInfo.text = "|cffffff00Recruit|r"
    recruitInfo.func = function() SendRecruitWhisper(name) end
    recruitInfo.notCheckable = true
    UIDropDownMenu_AddButton(recruitInfo, UIDROPDOWNMENU_MENU_LEVEL)

end

-- Hook ONCE and ONLY ONCE
hooksecurefunc("FriendsFrameDropDown_Initialize", AddChatMenuInviteOption)

-- === Recruit Message Manager UI ===
local f = CreateFrame("Frame", "GQIFrame", UIParent, "BackdropTemplate")
f:SetSize(400, 200)
f:SetPoint("CENTER")
f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = {left = 11, right = 12, top = 12, bottom = 11}
})
-- Header text
local header = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
header:SetPoint("TOP", 0, -15)
header:SetText("|cff00ccffGuild Recruitment Messages|r") -- Light blue
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)
f:Hide()

-- Dropdown menu
local dropdown =
    CreateFrame("Frame", "GQIDropdown", f, "UIDropDownMenuTemplate")
dropdown:SetPoint("TOPLEFT", 20, -40)

local function DeleteSelectedMessage()
    local selected = GuildQuickInviteActiveMessage
    if not selected or selected == "" then return end

    for i, msg in ipairs(GuildQuickInviteMessages) do
        if msg == selected then
            table.remove(GuildQuickInviteMessages, i)
            print("|cffff0000[GQI]|r Deleted message: " .. selected)

            -- Update default to first available (or empty string)
            GuildQuickInviteActiveMessage = GuildQuickInviteMessages[1] or ""

            -- Refresh dropdown
            UpdateDropdown()
            UIDropDownMenu_SetSelectedValue(dropdown,
                                            GuildQuickInviteActiveMessage)
            UIDropDownMenu_SetText(dropdown, GuildQuickInviteActiveMessage or "")
            editBox:SetText("")
            return
        end
    end
end

StaticPopupDialogs["GQI_CONFIRM_DELETE"] = {
    text = "Are you sure you want to delete this message?",
    button1 = "Yes",
    button2 = "Cancel",
    OnAccept = function()
        local selected = GuildQuickInviteActiveMessage
        if not selected or selected == "" then return end

        for i, msg in ipairs(GuildQuickInviteMessages) do
            if msg == selected then
                table.remove(GuildQuickInviteMessages, i)
                print("|cffff0000[GQI]|r Deleted message: " .. selected)

                GuildQuickInviteActiveMessage =
                    GuildQuickInviteMessages[1] or ""
                UpdateDropdown()
                UIDropDownMenu_SetSelectedValue(dropdown,
                                                GuildQuickInviteActiveMessage)
                UIDropDownMenu_SetText(dropdown,
                                       GuildQuickInviteActiveMessage or "")
                editBox:SetText("")
                return
            end
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3
}

StaticPopupDialogs["GQI_CONFIRM_CLEAR_ALL"] = {
    text = "Are you sure you want to delete ALL saved messages?",
    button1 = "Yes",
    button2 = "Cancel",
    OnAccept = function()
        GuildQuickInviteMessages = {}
        GuildQuickInviteActiveMessage = ""
        UpdateDropdown()
        UIDropDownMenu_SetSelectedValue(dropdown, "")
        UIDropDownMenu_SetText(dropdown, "")
        editBox:SetText("")
        print("|cffff0000[GQI]|r All messages cleared.")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3
}

function UpdateDropdown()
    local function OnClick(self)
        GuildQuickInviteActiveMessage = self.value
        UIDropDownMenu_SetSelectedValue(dropdown, self.value)
        print("|cffffff00[GQI]|r Active message set.")
    end

    UIDropDownMenu_Initialize(dropdown, function(self, level)
        for _, msg in ipairs(GuildQuickInviteMessages) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = msg
            info.value = msg
            info.func = OnClick
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    UIDropDownMenu_SetWidth(dropdown, 300)
    UIDropDownMenu_SetButtonWidth(dropdown, 300)
    UIDropDownMenu_SetSelectedValue(dropdown, GuildQuickInviteActiveMessage)
    UIDropDownMenu_JustifyText(dropdown, "LEFT")

    -- 🧼 Force immediate refresh
    UIDropDownMenu_Initialize(dropdown, dropdown.initialize)
end

-- Input box
editBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
editBox:SetSize(280, 25)
editBox:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 20, -10)
editBox:SetAutoFocus(false)
editBox:SetScript("OnEscapePressed", editBox.ClearFocus)

-- Save button
local saveBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
saveBtn:SetSize(80, 25)
saveBtn:SetPoint("TOPLEFT", editBox, "BOTTOMLEFT", 0, -10)
saveBtn:SetText("Save")
saveBtn:SetScript("OnClick", function()
    local msg = editBox:GetText()
    if msg ~= "" then
        table.insert(GuildQuickInviteMessages, msg)
        GuildQuickInviteActiveMessage = msg
        editBox:SetText("")
        UpdateDropdown()
        print("|cff00ff00[GQI]|r Message saved.")
    end
end)

-- Delete button
local deleteBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
deleteBtn:SetSize(80, 25)
deleteBtn:SetPoint("LEFT", saveBtn, "RIGHT", 10, 0)
deleteBtn:SetText("Delete")
deleteBtn:SetScript("OnClick",
                    function() StaticPopup_Show("GQI_CONFIRM_DELETE") end)

-- Clear All button
local clearAllBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
clearAllBtn:SetSize(100, 25)
clearAllBtn:SetPoint("LEFT", deleteBtn, "RIGHT", 10, 0)
clearAllBtn:SetText("Clear All")
clearAllBtn:SetScript("OnClick",
                      function() StaticPopup_Show("GQI_CONFIRM_CLEAR_ALL") end)

-- Close button
local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
closeBtn:SetSize(60, 22)
closeBtn:SetPoint("BOTTOMRIGHT", -10, 10)
closeBtn:SetText("Close")
closeBtn:SetScript("OnClick", function() f:Hide() end)

-- Slash command to open
SLASH_GQIMSG1 = "/gqimsg"
SlashCmdList["GQIMSG"] = function()
    f:Show()
    UpdateDropdown()
end

if IsAddOnLoaded("ElvUI") then
    local E, L, V, P, G = unpack(ElvUI)
    local S = E:GetModule("Skins")
    if S and S.HandleFrame then
        S:HandleFrame(f, true)
        f:SetTemplate("Transparent")
    else
        if S and S.HandleButton then
            S:HandleButton(saveBtn)
            S:HandleButton(deleteBtn)
            S:HandleButton(clearAllBtn)
            S:HandleButton(closeBtn)
        end
    end
end

-- Fade out when not focused
local FADE_OUT_ALPHA = 0.4
local FADE_IN_ALPHA = 1.0
local FADE_TIME = 0.3

local function IsMouseOverFrame(frame)
    return frame:IsShown() and frame:IsMouseOver(1, -1, -1, 1)
end

f:SetScript("OnUpdate", function(self, elapsed)
    if not self:IsShown() then return end

    if IsMouseOverFrame(self) then
        if self:GetAlpha() < FADE_IN_ALPHA then
            UIFrameFadeIn(self, FADE_TIME, self:GetAlpha(), FADE_IN_ALPHA)
        end
    else
        if self:GetAlpha() > FADE_OUT_ALPHA then
            UIFrameFadeOut(self, FADE_TIME, self:GetAlpha(), FADE_OUT_ALPHA)
        end
    end
end)
