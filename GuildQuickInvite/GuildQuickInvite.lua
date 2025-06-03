-- Guild Quick Invite (GQI)
-- Version: 1.1
-- Author: Zachary Kaiser & ChatGPT
-- Game Version: World of Warcraft 3.3.5 (WotLK)
-- Recruit whisper cooldown duration (6 hours)
local RECRUIT_COOLDOWN = 21600
local recruitCooldownDB = {}

-- Guild invite cooldown duration (6 hours)
local INVITE_COOLDOWN = 21600
local inviteCache = {}
local UpdateDropdown
local editBox

-- Timestamp Format Toggle
GuildQuickInviteUse24Hour = GuildQuickInviteUse24Hour or false

-- Persist cooldowns between sessions
GuildQuickInviteDB = GuildQuickInviteDB or {}

-- Tooltip Toggle Variable
if GuildQuickInviteShowTooltips == nil then GuildQuickInviteShowTooltips = true end

-- Helper to format remaining cooldown
-- Formats the remaining time in hours and minutes
local function FormatTimeRemaining(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    return string.format("%dh %dm", hours, minutes)
end

-- Function to format the timestamp based on user preference
local function FormatTime(timestamp)
    if GuildQuickInviteUse24Hour then
        return date("%b %d | %H:%M", timestamp)
    else
        return date("%b %d | %I:%M %p", timestamp)
    end
end

if not C_Timer then
    C_Timer = {}
    function C_Timer.After(delay, func)
        local waitFrame = CreateFrame("Frame")
        waitFrame:Hide()
        local total = 0
        waitFrame:SetScript("OnUpdate", function(self, elapsed)
            total = total + elapsed
            if total >= delay then
                func()
                self:SetScript("OnUpdate", nil)
                self:Hide()
            end
        end)
        waitFrame:Show()
    end
end


-- Slash command to toggle timestamp format
SLASH_GQITIME1 = "/gqitime"
SlashCmdList["GQITIME"] = function()
    GuildQuickInviteUse24Hour = not GuildQuickInviteUse24Hour
    local mode = GuildQuickInviteUse24Hour and "24-hour" or "12-hour"
    print("|cffffff00[GQI]|r Timestamp format set to: " .. mode)
    if GQIHistoryFrame and GQIHistoryFrame:IsShown() and RefreshHistoryUI then
        RefreshHistoryUI()
    end
end


-- Update function to mark if joined
local function MarkPlayerJoined(name)
    for _, entry in ipairs(gqiInviteHistory) do
        if entry.name == name and not entry.joined then
            entry.joined = true
        end
    end
end

function LogGuildInvite(name)
    table.insert(gqiInviteHistory, {
        name = name,
        method = "Guild Invite",
        time = time(),
        joined = false,
        declined = false
    })
end

function LogRecruitWhisper(name)
    table.insert(gqiInviteHistory, {
        name = name,
        method = "Recruit Whisper",
        time = time(),
        joined = false
    })
end

local function UpdateInviteStatus()
    local now = time()
    local timeout = 300 -- 5 minutes (adjust as needed)
    for _, entry in ipairs(gqiInviteHistory) do
        if not entry.joined and not entry.declined and
            (now - entry.time > timeout) then entry.declined = true end
    end
end

-- Background timer to check invite status regardless of UI
local GQI_BackgroundTimer = CreateFrame("Frame")
local gqiElapsed = 0
local gqiInterval = 60 -- seconds

GQI_BackgroundTimer:SetScript("OnUpdate", function(self, elapsed)
    gqiElapsed = gqiElapsed + elapsed
    if gqiElapsed >= gqiInterval then
        UpdateInviteStatus()
        gqiElapsed = 0
    end
end)

-- Timer to run status checks periodically
local timerFrame = CreateFrame("Frame")
local timer, interval = 0, 60

-- Every 60s we'll run UpdateInviteStatus
local function OnUpdate(self, elapsed)
    timer = timer + elapsed
    if timer >= interval then
        UpdateInviteStatus()
        timer = 0
    end
end

-- Only run the timer when the history UI is open
local function ToggleTimerFrame(enable)
    if enable then
        timer = 0
        timerFrame:SetScript("OnUpdate", OnUpdate)
    else
        timerFrame:SetScript("OnUpdate", nil)
    end
end

-- Hook for PLAYER_GUILD_UPDATE
local lastRoster = {} -- for join tracking
local function UpdateGuildRoster()
    local current = {}
    for i = 1, GetNumGuildMembers() do
        local name = GetGuildRosterInfo(i)
        if name then -- Check for nil before using as key
            current[name] = true
            if not lastRoster[name] then MarkPlayerJoined(name) end
        end
    end
    lastRoster = current
end

local rf = CreateFrame("Frame")
rf:RegisterEvent("GUILD_ROSTER_UPDATE")
rf:RegisterEvent("PLAYER_GUILD_UPDATE")
rf:SetScript("OnEvent", UpdateGuildRoster)

-- Improved and unified History GUI logic with icons and styling
SLASH_GQIHISTORY1 = "/gqihistory"
SlashCmdList["GQIHISTORY"] = function()
    if GQIHistoryFrame and GQIHistoryFrame:IsShown() then
        GQIHistoryFrame:Hide()
        return
    end

    function RefreshHistoryUI()
        for _, line in ipairs(GQIHistoryFrame.lines) do line:Hide() end
        wipe(GQIHistoryFrame.lines)

        local offsetY = -10
        -- Sorting configuration
        local sortConfig = {column = "time", ascending = false}

        -- Helper to compare values
        local function CompareValues(a, b, ascending)
            if type(a) == "string" and type(b) == "string" then
                a = a:lower()
                b = b:lower()
            end
            if ascending then
                return a < b
            else
                return a > b
            end
        end

        -- Utility: sort function
        -- Custom sort for each column
        local function SortHistory()
            table.sort(gqiInviteHistory, function(a, b)
                if sortConfig.column == "name" then
                    return CompareValues(a.name, b.name, sortConfig.ascending)
                elseif sortConfig.column == "method" then
                    local weight = {
                        ["Guild Invite"] = 1,
                        ["Recruit Whisper"] = 2
                    }
                    return CompareValues(weight[a.method] or 99,
                                         weight[b.method] or 99,
                                         sortConfig.ascending)
                elseif sortConfig.column == "status" then
                    local statusWeight = function(entry)
                        if entry.joined then
                            return 1
                        elseif entry.declined then
                            return 2
                        else
                            return 3
                        end
                    end
                    return CompareValues(statusWeight(a), statusWeight(b),
                                         sortConfig.ascending)
                elseif sortConfig.column == "time" then
                    return CompareValues(a.time, b.time, sortConfig.ascending)
                end
            end)
        end

        -- Header row
        local headers = {"#", "Name", "Method", "Status", "Date"}
        local headerLabels = {"#", "Name", "Method", "Status", "Date"}
        local headerKeys = {nil, "name", "method", "status", "time"}
        local xOffsets = {10, 40, 160, 260, 340}

        for i, label in ipairs(headerLabels) do
            if headerKeys[i] then
                local btn = CreateFrame("Button", nil, GQIHistoryFrame.content)
                btn:SetSize(100, 16)
                btn:SetPoint("TOPLEFT", xOffsets[i], offsetY)

                btn.text = btn:CreateFontString(nil, "OVERLAY",
                                                "GameFontHighlightSmall")
                btn.text:SetPoint("LEFT")
                btn.text:SetText(label)

                btn:SetScript("OnClick", function()
                    if sortConfig.column == headerKeys[i] then
                        sortConfig.ascending = not sortConfig.ascending
                    else
                        sortConfig.column = headerKeys[i]
                        sortConfig.ascending = true
                    end
                    SortHistory()
                    RefreshHistoryUI()
                end)

                table.insert(GQIHistoryFrame.lines, btn)
            else
                local staticHeader = GQIHistoryFrame.content:CreateFontString(
                                         nil, "OVERLAY",
                                         "GameFontHighlightSmall")
                staticHeader:SetPoint("TOPLEFT", xOffsets[i], offsetY)
                staticHeader:SetText(label)
                table.insert(GQIHistoryFrame.lines, staticHeader)
            end
        end

        offsetY = offsetY - 20

        for i, entry in ipairs(gqiInviteHistory) do
            local statusIcon, statusColor
            if entry.joined then
                statusIcon = "Interface\\RaidFrame\\ReadyCheck-Ready"
                statusColor = "|cff00ff00Joined|r"
            elseif entry.declined then
                statusIcon = "Interface\\RaidFrame\\ReadyCheck-NotReady"
                statusColor = "|cffff8800Declined|r"
            else
                statusIcon = "Interface\\RaidFrame\\ReadyCheck-Waiting"
                statusColor = "|cffff0000Pending|r"
            end

            local when = FormatTime(entry.time)

            -- Background stripe
            if i % 2 == 0 then
                local bg = GQIHistoryFrame.content:CreateTexture(nil,
                                                                 "BACKGROUND")
                bg:SetColorTexture(0, 0, 0, 0.1)
                bg:SetPoint("TOPLEFT", 5, offsetY + 5)
                bg:SetPoint("BOTTOMRIGHT", -5, offsetY - 15)
                table.insert(GQIHistoryFrame.lines, bg)
            end

            -- Index
            local indexText = GQIHistoryFrame.content:CreateFontString(nil,
                                                                       "OVERLAY",
                                                                       "GameFontNormal")
            indexText:SetPoint("TOPLEFT", xOffsets[1], offsetY)
            indexText:SetText(i .. ".")
            table.insert(GQIHistoryFrame.lines, indexText)

            -- Name
            local nameText = GQIHistoryFrame.content:CreateFontString(nil,
                                                                      "OVERLAY",
                                                                      "GameFontNormal")
            nameText:SetPoint("TOPLEFT", xOffsets[2], offsetY)
            nameText:SetText(entry.name)
            table.insert(GQIHistoryFrame.lines, nameText)

            -- Method
            local methodText = GQIHistoryFrame.content:CreateFontString(nil,
                                                                        "OVERLAY",
                                                                        "GameFontNormal")
            methodText:SetPoint("TOPLEFT", xOffsets[3], offsetY)
            methodText:SetText(entry.method)
            table.insert(GQIHistoryFrame.lines, methodText)

            -- Status + icon
            local statusText = GQIHistoryFrame.content:CreateFontString(nil,
                                                                        "OVERLAY",
                                                                        "GameFontNormal")
            statusText:SetPoint("TOPLEFT", xOffsets[4] + 20, offsetY)
            statusText:SetText(statusColor)
            table.insert(GQIHistoryFrame.lines, statusText)

            local icon = GQIHistoryFrame.content:CreateTexture(nil, "ARTWORK")
            icon:SetSize(16, 16)
            icon:SetPoint("TOPLEFT", xOffsets[4], offsetY - 2)
            icon:SetTexture(statusIcon)
            table.insert(GQIHistoryFrame.lines, icon)

            -- Timestamp
            local dateText = GQIHistoryFrame.content:CreateFontString(nil,
                                                                      "OVERLAY",
                                                                      "GameFontNormal")
            dateText:SetPoint("TOPRIGHT", -10, offsetY)
            dateText:SetText(when)
            table.insert(GQIHistoryFrame.lines, dateText)

            offsetY = offsetY - 20
        end

        GQIHistoryFrame.content:SetHeight(math.abs(offsetY))
    end

    if not GQIHistoryFrame then
        GQIHistoryFrame = CreateFrame("Frame", "GQIHistoryFrame", UIParent,
                                      "BackdropTemplate")
        GQIHistoryFrame:SetSize(500, 320)
        GQIHistoryFrame:SetPoint("CENTER")
        GQIHistoryFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = {left = 8, right = 8, top = 8, bottom = 8}
        })
        GQIHistoryFrame:SetMovable(true)
        GQIHistoryFrame:EnableMouse(true)
        GQIHistoryFrame:RegisterForDrag("LeftButton")
        GQIHistoryFrame:SetScript("OnDragStart", GQIHistoryFrame.StartMoving)
        GQIHistoryFrame:SetScript("OnDragStop",
                                  GQIHistoryFrame.StopMovingOrSizing)

        GQIHistoryFrame.title = GQIHistoryFrame:CreateFontString(nil, "OVERLAY",
                                                                 "GameFontNormalLarge")
        GQIHistoryFrame.title:SetPoint("TOP", 0, -10)
        GQIHistoryFrame.title:SetText("Guild Quick Invite - History")

        GQIHistoryFrame.scrollFrame = CreateFrame("ScrollFrame", nil,
                                                  GQIHistoryFrame,
                                                  "UIPanelScrollFrameTemplate")
        GQIHistoryFrame.scrollFrame:SetPoint("TOPLEFT", 12, -40)
        GQIHistoryFrame.scrollFrame:SetPoint("BOTTOMRIGHT", -30, 30)

        GQIHistoryFrame.content = CreateFrame("Frame", nil,
                                              GQIHistoryFrame.scrollFrame)
        GQIHistoryFrame.content:SetSize(460, 200)
        GQIHistoryFrame.scrollFrame:SetScrollChild(GQIHistoryFrame.content)
        GQIHistoryFrame.lines = {}

        local refreshBtn = CreateFrame("Button", nil, GQIHistoryFrame,
                                       "UIPanelButtonTemplate")
        refreshBtn:SetSize(80, 24)
        refreshBtn:SetPoint("BOTTOM", 0, 5)
        refreshBtn:SetText("Refresh")
        refreshBtn:SetScript("OnClick", RefreshHistoryUI)
    end

    RefreshHistoryUI()
    GQIHistoryFrame:Show()
end

-- Slash Command for Summary
SLASH_GQISUMMARY1 = "/gqisummary"
SlashCmdList["GQISUMMARY"] = function()
    local joined, declined, pending = 0, 0, 0
    for _, entry in ipairs(gqiInviteHistory) do
        if entry.joined then
            joined = joined + 1
        elseif entry.declined then
            declined = declined + 1
        else
            pending = pending + 1
        end
    end
    local total = #gqiInviteHistory
    print(string.format(
              "|cffffff00[GQI]|r Invite Summary: %d Invited, %d Joined, %d Declined, %d Pending",
              total, joined, declined, pending))
end

-- Slash Command to clear Invite GUI History
SLASH_GQICLEARHISTORY1 = "/gqiclearhistory"
SlashCmdList["GQICLEARHISTORY"] = function()
    table.wipe(gqiInviteHistory)
    print("|cffff0000[GQI]|r Invite history cleared.")
end

-- Slash command to set or display the recruitment message
SLASH_GQI1 = "/gqi"
SlashCmdList["GQI"] = function(msg)
    if not msg or msg == "" then
        print("|cffffff00[GQI]|r Current recruitment message: " ..
                  (GuildQuickInviteRecruitMsg or "Not set."))
    else
        GuildQuickInviteRecruitMsg = msg
        GuildQuickInviteActiveMessage = msg -- Add this line!
        print("|cffffff00[GQI]|r Recruitment message updated!")
    end
end

-- Slash command to reset cooldown data
SLASH_GQIRESET1 = "/gqireset"
SlashCmdList["GQIRESET"] = function()
    GuildQuickInviteDB = {}
    GuildQuickInviteRecruitDB = {}
    print("|cffff0000[GQI]|r Cooldown data has been reset.")
end

-- Slash command to update cooldown timers
SLASH_GQICOOLDOWN1 = "/gqicooldown"
SlashCmdList["GQICOOLDOWN"] = function(msg)
    local newCD = tonumber(msg)
    if not newCD or newCD < 30 then
        print(
            "|cffff0000[GQI]|r Please enter a cooldown of at least 30 minutes. Example: /gqicooldown 60")
        return
    end
    local seconds = newCD * 60
    INVITE_COOLDOWN = seconds
    RECRUIT_COOLDOWN = seconds
    print("|cff00ff00[GQI]|r Cooldowns updated to " .. newCD .. " minutes.")
end

-- Slash command to toggle tooltip cooldowns
SLASH_GQITOOLTIP1 = "/gqitooltip"
SlashCmdList["GQITOOLTIP"] = function()
    GuildQuickInviteShowTooltips = not GuildQuickInviteShowTooltips
    if GuildQuickInviteShowTooltips then
        print("|cff00ff00[GQI]|r Tooltip cooldowns are now |cffffff00ENABLED|r.")
    else
        print(
            "|cff00ff00[GQI]|r Tooltip cooldowns are now |cffff0000DISABLED|r.")
    end
end

-- Slash command to update macro channel
SLASH_GQICHANNEL1 = "/gqichannel"
SlashCmdList["GQICHANNEL"] = function(msg)
    if not msg or msg == "" then
        print("|cffffff00[GQI]|r Current macro channel: " ..
                  GuildQuickInviteMacroChannel)
        return
    end
    if not msg:match("^/%d+$") then
        print("|cffff0000[GQI]|r Invalid channel. Use format like /1, /2, etc.")
        return
    end
    GuildQuickInviteMacroChannel = msg
    print("|cff00ff00[GQI]|r Macro channel set to " .. msg)
end

-- On login, cleanup expired invites
-- Removes expired invites from the cooldown database
local function CleanExpiredInvites()
    for name, timestamp in pairs(GuildQuickInviteDB) do
        if (time() - timestamp) > INVITE_COOLDOWN then
            GuildQuickInviteDB[name] = nil
        end
    end
end

-- Clean old recruit cooldowns on login
-- Removes expired recruit cooldowns from the database
local function CleanRecruitCooldowns()
    local now = time()
    for name, timestamp in pairs(recruitCooldownDB) do
        if (now - timestamp) > RECRUIT_COOLDOWN then
            recruitCooldownDB[name] = nil
        end
    end
end

-- Checks if the cooldown for inviting a player has expired
local function HasCooldownExpired(name)
    local lastInvite = GuildQuickInviteDB[name]
    if not lastInvite then return true end
    return (time() - lastInvite) > INVITE_COOLDOWN
end

-- Sends a recruitment whisper to the specified player if not on cooldown
local function SendRecruitWhisper(name)
    if not name or name == "" then return end
    local now = time()
    if recruitCooldownDB[name] and (now - recruitCooldownDB[name]) <
        RECRUIT_COOLDOWN then
        print("|cffff0000[GQI]|r " .. name .. " is still on recruit cooldown.")
        return
    end

    local message = GuildQuickInviteActiveMessage
    if not message or message == "" then
        print(
            "|cffff0000[GQI]|r No recruitment message set. Use /gqi <message> to set one.")
        return
    end
    SendChatMessage(message, "WHISPER", nil, name)
    LogRecruitWhisper(name)
    recruitCooldownDB[name] = now
    print("|cffffff00[GQI]|r Whisper sent to " .. name)
end

-- Adds an option to the unit dropdown menu to invite to guild or send a recruit whisper
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
                LogGuildInvite(name)
                GuildQuickInviteDB[name] = time()
                print("Guild invite sent to " .. name .. ". Cooldown started.")
            end
        else
            local remaining = INVITE_COOLDOWN -
                                  (time() - GuildQuickInviteDB[name])
            inviteInfo.text = "|cffff0000Invited (Cooldown: " ..
                                  FormatTimeRemaining(remaining) .. ")|r"
            inviteInfo.notClickable = true
        end
        inviteInfo.notCheckable = true
        UIDropDownMenu_AddButton(inviteInfo, UIDROPDOWNMENU_MENU_LEVEL)

        -- Recruit Whisper
        local recruitInfo = UIDropDownMenu_CreateInfo()
        local now = time()
        if recruitCooldownDB[name] and (now - recruitCooldownDB[name]) <
            RECRUIT_COOLDOWN then
            local remaining = RECRUIT_COOLDOWN - (now - recruitCooldownDB[name])
            recruitInfo.text = "|cffff0000Recruit (Cooldown: " ..
                                   FormatTimeRemaining(remaining) .. ")|r"
            recruitInfo.notClickable = true
        else
            recruitInfo.text = "|cffffff00Recruit|r"
            recruitInfo.func = function() SendRecruitWhisper(name) end
        end
        recruitInfo.notCheckable = true
        UIDropDownMenu_AddButton(recruitInfo, UIDROPDOWNMENU_MENU_LEVEL)
    end
end

-- Hook to add guild invite option to the unit popup menu
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
        recruitCooldownDB = GuildQuickInviteRecruitDB or {}
        GuildQuickInviteMacroChannel = GuildQuickInviteMacroChannel or "/2"
        CleanExpiredInvites()
        CleanRecruitCooldowns()
        GQI_HistoryDB = GQI_HistoryDB or {}
        gqiInviteHistory = GQI_HistoryDB
    elseif event == "PLAYER_LOGOUT" or event == "PLAYER_LEAVING_WORLD" then
        GQI_HistoryDB = gqiInviteHistory
        print(
            "|cffffff00[GQI]|r Addon loaded. Use /gqi <message> to set your recruitment message.")
    end
end)

-- Tooltip for cooldowns
-- Adds cooldown information to the tooltip for players
GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
    if not GuildQuickInviteShowTooltips then return end

    local name, unit = tooltip:GetUnit()
    if not name or not UnitIsPlayer(unit) or UnitIsUnit("player", unit) then
        return
    end

    local now = time()
    if GuildQuickInviteDB[name] and (now - GuildQuickInviteDB[name]) <
        INVITE_COOLDOWN then
        local remaining = INVITE_COOLDOWN - (now - GuildQuickInviteDB[name])
        tooltip:AddLine("|cffff0000Guild Invite Cooldown:|r " ..
                            FormatTimeRemaining(remaining))
    end
    if recruitCooldownDB[name] and (now - recruitCooldownDB[name]) <
        RECRUIT_COOLDOWN then
        local remaining = RECRUIT_COOLDOWN - (now - recruitCooldownDB[name])
        tooltip:AddLine("|cffff9900Recruit Cooldown:|r " ..
                            FormatTimeRemaining(remaining))
    end
end)

-- CHAT MENU SUPPORT

-- Adds an option to the chat menu to invite to guild or send a recruit whisper
local function AddChatMenuInviteOption()
    local dropdown = FriendsFrameDropDown
    local name = UIDROPDOWNMENU_INIT_MENU and UIDROPDOWNMENU_INIT_MENU.name
    if not name or name == UnitName("player") then return end

    name = string.match(name, "([^%-]+)") or name -- Strip realm

    if not CanGuildInvite() then return end

    -- Guild Invite Entry
    local info = UIDropDownMenu_CreateInfo()
    if HasCooldownExpired(name) then
        info.text = "|cff00ff00Invite to Guild|r"
        info.func = function()
            GuildInvite(name)
            LogGuildInvite(name)
            GuildQuickInviteDB[name] = time()
            print("Guild invite sent to " .. name .. ". Cooldown started.")
        end
    else
        local remaining = INVITE_COOLDOWN - (time() - GuildQuickInviteDB[name])
        info.text = "|cffff0000Invited (Cooldown: " ..
                        FormatTimeRemaining(remaining) .. ")|r"
        info.notClickable = true
    end
    info.notCheckable = true
    UIDropDownMenu_AddButton(info, 1)

    -- Recruit Entry
    local recruitInfo = UIDropDownMenu_CreateInfo()
    local now = time()
    if recruitCooldownDB[name] and (now - recruitCooldownDB[name]) <
        RECRUIT_COOLDOWN then
        local remaining = RECRUIT_COOLDOWN - (now - recruitCooldownDB[name])
        recruitInfo.text = "|cffff0000Recruit (Cooldown: " ..
                               FormatTimeRemaining(remaining) .. ")|r"
        recruitInfo.notClickable = true
    else
        recruitInfo.text = "|cffffff00Recruit|r"
        recruitInfo.func = function() SendRecruitWhisper(name) end
    end
    recruitInfo.notCheckable = true
    UIDropDownMenu_AddButton(recruitInfo, 1)
end

-- Re-hook to apply changes
hooksecurefunc("FriendsFrameDropDown_Initialize", AddChatMenuInviteOption)

-- === Recruit Message Manager UI ===
-- Creates a frame for the recruit message manager UI
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

-- Dropdown menu for selecting recruitment messages
local dropdown =
    CreateFrame("Frame", "GQIDropdown", f, "UIDropDownMenuTemplate")
dropdown:SetPoint("TOPLEFT", 20, -40)

-- Deletes the currently selected recruitment message
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

-- Confirmation dialog for deleting a message
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

-- Confirmation dialog for clearing all messages
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

-- Updates the dropdown menu with the list of recruitment messages
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

-- Input box for editing recruitment messages
editBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
editBox:SetSize(280, 25)
editBox:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 20, -10)
editBox:SetAutoFocus(false)
editBox:SetScript("OnEscapePressed", editBox.ClearFocus)

-- Function to create a macro for the active recruit message
-- Creates a macro for the active recruitment message
local function CreateRecruitMacro()
    local message = GuildQuickInviteActiveMessage
    if not message or message == "" then
        print("|cffff0000[GQI]|r No active message to create macro for.")
        return
    end
    local shortMsg = string.sub(message, 1, 255)
    local macroName = "GQI_Recruit"
    local macroBody = GuildQuickInviteMacroChannel .. " " .. shortMsg
    local iconIndex = 1 -- Using icon index 1 as default, required by CreateMacro

    local macroIndex = GetMacroIndexByName(macroName)
    local numGlobal, numChar = GetNumMacros()
    local maxGlobal, maxChar = MAX_ACCOUNT_MACROS or 36,
                               MAX_CHARACTER_MACROS or 18

    if not numGlobal or not maxGlobal then
        print("|cffff0000[GQI]|r Could not retrieve macro limits.")
        return
    end

    if macroIndex > 0 then
        EditMacro(macroIndex, macroName, iconIndex, macroBody)
    else
        if numGlobal < maxGlobal then
            CreateMacro(macroName, iconIndex, macroBody, false)
        else
            print("|cffff0000[GQI]|r Cannot create macro: macro limit reached.")
        end
    end
end

-- Save button for saving recruitment messages
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

-- Delete button for deleting recruitment messages
local deleteBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
deleteBtn:SetSize(80, 25)
deleteBtn:SetPoint("LEFT", saveBtn, "RIGHT", 10, 0)
deleteBtn:SetText("Delete")
deleteBtn:SetScript("OnClick",
                    function() StaticPopup_Show("GQI_CONFIRM_DELETE") end)

-- Create Macro button for creating a macro for the active recruitment message
local macroBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
macroBtn:SetSize(100, 25)
macroBtn:SetPoint("LEFT", saveBtn, "RIGHT", 0, -40)
macroBtn:SetText("Bind Macro")
macroBtn:SetScript("OnClick", function()
    CreateRecruitMacro()
    print("|cff00ff00[GQI]|r Macro created for active message.")
end)

-- Clear All button for clearing all recruitment messages
local clearAllBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
clearAllBtn:SetSize(100, 25)
clearAllBtn:SetPoint("LEFT", deleteBtn, "RIGHT", 10, 0)
clearAllBtn:SetText("Clear All")
clearAllBtn:SetScript("OnClick",
                      function() StaticPopup_Show("GQI_CONFIRM_CLEAR_ALL") end)

-- Close button for closing the recruit message manager UI
local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
closeBtn:SetSize(60, 22)
closeBtn:SetPoint("BOTTOMRIGHT", -10, 10)
closeBtn:SetText("Close")
closeBtn:SetScript("OnClick", function() f:Hide() end)

-- Slash command to open the recruit message manager UI
SLASH_GQIMSG1 = "/gqimsg"
SlashCmdList["GQIMSG"] = function()
    f:Show()
    UpdateDropdown()
end

-- Apply ElvUI skin if available
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
            S:HandleButton(macroBtn)
            S:HandleButton(refreshBtn)
        end
    end
end

-- Fade out when not focused
local FADE_OUT_ALPHA = 0.4
local FADE_IN_ALPHA = 1.0
local FADE_TIME = 0.3

-- Checks if the mouse is over the frame
local function IsMouseOverFrame(frame)
    return frame:IsShown() and frame:IsMouseOver(1, -1, -1, 1)
end

-- Fades the frame in or out based on mouse position
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

local sf = CreateFrame("Frame")
sf:RegisterEvent("PLAYER_LOGOUT")
sf:RegisterEvent("PLAYER_LEAVING_WORLD")
sf:SetScript("OnEvent", function() GQI_HistoryDB = gqiInviteHistory end)
