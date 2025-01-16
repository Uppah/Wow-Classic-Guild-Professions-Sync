-- GuildProfessionsCore.lua
local prefix = "GuildProf"
local validProfessions = {
    "Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Herbalism",
    "Leatherworking", "Mining", "Skinning", "Tailoring"
}

local professions = {}
local guildData = {}
local guildMembers = {}
local currentFilter = nil -- Default: all professions

-- Helper Functions

local function tContains(tbl, item)
    if not tbl or not item then return false end
    for _, value in ipairs(tbl) do if value == item then return true end end
    return false
end

local function EnsureSelfInGuildData()
    local playerName = UnitName("player")
    if not guildData[playerName] then
        guildData[playerName] = {professions = professions or {}}
    else
        guildData[playerName].professions = professions or {}
    end
end

local function DetectProfessions()
    local detectedProfessions = {}
    for i = 1, GetNumSkillLines() do
        local skillName, _, _, skillRank = GetSkillLineInfo(i)
        if tContains(validProfessions, skillName) then
            table.insert(detectedProfessions,
                         {name = skillName, level = skillRank})
        end
    end
    professions = detectedProfessions
    EnsureSelfInGuildData()
end

local function UpdateGuildList()
    guildMembers = {}

    if IsInGuild() then
        for i = 1, GetNumGuildMembers() do
            local fullName, _, _, _, _, _, _, _, _, _, class =
                GetGuildRosterInfo(i)
            fullName = Ambiguate(fullName, "none")
            if fullName and class then
                guildMembers[fullName] = {class = class}
            end
        end
    end

    local playerName = UnitName("player")
    local _, playerClass = UnitClass("player")
    guildMembers[playerName] = {class = playerClass}
    EnsureSelfInGuildData()
end

-- UI Functions

local function UpdateUIContent()
    if not GuildProfessionsFrame then return end -- Ensure the frame exists
    local content = GuildProfessionsFrame.content

    -- Clear all previous UI elements
    if not content.uiElements then
        content.uiElements = {}
    else
        for _, element in ipairs(content.uiElements) do
            element:Hide()
            element:SetParent(nil)
        end
        wipe(content.uiElements)
    end

    local yOffset = -10
    local hasEntries = false

    for sender, data in pairs(guildData) do
        local professionsList = data.professions or {}
        local filteredProfessions = {}

        for _, profession in ipairs(professionsList) do
            if not currentFilter or currentFilter == profession.name then
                table.insert(filteredProfessions, profession)
            end
        end

        if #filteredProfessions > 0 then
            hasEntries = true

            local line = content:CreateFontString(nil, "OVERLAY",
                                                  "GameFontHighlightLarge")
            line:SetPoint("TOPLEFT", 10, yOffset)

            local class = guildMembers[sender] and guildMembers[sender].class
            local color = RAID_CLASS_COLORS[class] or {r = 1, g = 1, b = 1}
            local coloredName = "|cff" ..
                                    string.format("%02x%02x%02x", color.r * 255,
                                                  color.g * 255, color.b * 255) ..
                                    sender .. "|r"

            local profText = ""
            for _, profession in ipairs(filteredProfessions) do
                profText = profText .. profession.name .. " (" ..
                               profession.level .. "), "
            end
            profText = profText:sub(1, -3)

            line:SetText(coloredName .. ": " .. profText)
            yOffset = yOffset - 30

            table.insert(content.uiElements, line)
        end
    end

    if not hasEntries then
        content.noResults = content:CreateFontString(nil, "OVERLAY",
                                                     "GameFontHighlightLarge")
        content.noResults:SetPoint("TOPLEFT", 10, yOffset)
        content.noResults:SetText("No players match the selected profession.")
        content.noResults:Show()
        table.insert(content.uiElements, content.noResults)
    end
end

local function CreateFilterDropdown(parent)
    local dropdown = CreateFrame("Frame", "GuildProfessionsFilterDropdown",
                                 parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, -50)

    UIDropDownMenu_SetWidth(dropdown, 150)
    UIDropDownMenu_SetText(dropdown, "All Professions")

    local function OnClick(_, arg1)
        currentFilter = arg1
        UIDropDownMenu_SetText(dropdown, arg1 or "All Professions")
        UpdateUIContent()
    end

    UIDropDownMenu_Initialize(dropdown, function(_, level)
        local info = UIDropDownMenu_CreateInfo()

        -- "All Professions" option
        info.text = "All Professions"
        info.arg1 = nil
        info.func = OnClick
        info.checked = (currentFilter == nil)
        UIDropDownMenu_AddButton(info, level)

        -- Add each profession as a filter option
        for _, profession in ipairs(validProfessions) do
            info.text = profession
            info.arg1 = profession
            info.func = OnClick
            info.checked = (currentFilter == profession)
            UIDropDownMenu_AddButton(info, level)
        end
    end)
end

local function ShowGuildProfessions()
    if GuildProfessionsFrame then
        GuildProfessionsFrame:Show()
        UpdateUIContent()
        return
    end

    local frame = CreateFrame("Frame", "GuildProfessionsFrame", UIParent)
    frame:SetSize(600, 400)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

    local header = frame:CreateTexture(nil, "ARTWORK")
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    header:SetHeight(40)
    header:SetColorTexture(0.2, 0.2, 0.2, 1)

    local guildName = GetGuildInfo("player") or "No Guild"
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("CENTER", header, "CENTER", 0, 0)
    title:SetText(guildName .. " - Guild Professions")

    -- Sync Button
    local syncButton =
        CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    syncButton:SetSize(120, 30)
    syncButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -50)
    syncButton:SetText("Sync Professions")
    syncButton:SetScript("OnClick", function()
        C_ChatInfo.SendAddonMessage("GuildProf", "REQUEST_SYNC", "GUILD")
        print("Guild professions sync request sent!")
    end)

    -- Close Button
    local closeButton = CreateFrame("Button", nil, frame)
    closeButton:SetSize(30, 30)
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    local closeText = closeButton:CreateFontString(nil, "OVERLAY",
                                                   "GameFontHighlightLarge")
    closeText:SetPoint("CENTER", closeButton, "CENTER")
    closeText:SetText("X")
    closeText:SetFont(closeText:GetFont(), 20, "OUTLINE")
    closeButton:SetScript("OnClick", function() frame:Hide() end)
    closeButton:SetScript("OnEnter",
                          function() closeText:SetTextColor(1, 0, 0) end)
    closeButton:SetScript("OnLeave",
                          function() closeText:SetTextColor(1, 1, 1) end)

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame,
                                    "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -90)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(550, 800)
    scrollFrame:SetScrollChild(content)

    frame.content = content
    CreateFilterDropdown(frame)
    GuildProfessionsFrame = frame
    UpdateUIContent()
end

-- Logic Functions

local function BroadcastProfessions()
    local playerName = UnitName("player")
    local data = {}

    for _, profession in ipairs(professions) do
        table.insert(data, profession.name .. ":" .. profession.level)
    end

    local message = table.concat(data, ",")
    C_ChatInfo.SendAddonMessage(prefix, message, "GUILD")
end

local function OnAddonMessage(prefixReceived, message, channel, sender)
    if prefixReceived == prefix and channel == "GUILD" then
        local senderName = Ambiguate(sender, "none")

        -- Skip self
        local playerName = UnitName("player")
        if senderName == playerName then return end

        if guildMembers[senderName] then
            if message == "REQUEST_SYNC" then
                BroadcastProfessions()
            else
                local professionsList = {}
                for _, professionData in ipairs({strsplit(",", message)}) do
                    local name, level = strsplit(":", professionData)
                    if name and level then
                        table.insert(professionsList,
                                     {name = name, level = tonumber(level)})
                    end
                end

                guildData[senderName] = {professions = professionsList}
                if GuildProfessionsFrame and GuildProfessionsFrame:IsShown() then
                    UpdateUIContent()
                end
            end
        end
    end
end

-- Initialization Functions

local function OnLogin()
    print("GuildProfessions loaded!")
    C_ChatInfo.RegisterAddonMessagePrefix(prefix)
    DetectProfessions()
    UpdateGuildList()
    EnsureSelfInGuildData()
end

local function OnEvent(self, event, ...)
    if event == "PLAYER_LOGIN" then
        OnLogin()
    elseif event == "CHAT_MSG_ADDON" then
        OnAddonMessage(...)
    elseif event == "GUILD_ROSTER_UPDATE" then
        UpdateGuildList()
    end
end

-- Slash Commands

SLASH_GUILDPROF1 = "/guildprof"
SlashCmdList["GUILDPROF"] = function() ShowGuildProfessions() end

SLASH_GUILDSYNC1 = "/guildsync"
SlashCmdList["GUILDSYNC"] = function()
    C_ChatInfo.SendAddonMessage("GuildProf", "REQUEST_SYNC", "GUILD")
    print("Guild professions sync request sent!")
end

-- Register Events
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:SetScript("OnEvent", OnEvent)
