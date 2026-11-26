-- ================= STATUS EFFECTS OVERLAY =================
-- Finds the target player's model in nation_team or empire_team and
-- shows whichever status-effect StringValues they currently have.

local Workspace = game:GetService("Workspace")

-- ===========================
-- CONFIG
-- ===========================
local CONFIG = {
    targetName   = nil,           -- auto-detected (set a name here to force one)
    teamFolders  = { "nation_team", "empire_team" },
    updateRate   = 0.1,           -- seconds between reads of the model
    toggleKey    = 0x71,          -- F2
    position     = Vector2.new(20, 300),  -- top-left of the panel
    width        = 260,
    lineHeight   = 18,
}

-- only these StringValues count as status effects
local STATUS_EFFECTS = {
    buff_advance = "Advance",
    buff_defend  = "Defend",
    buff_focus   = "Focus",
    morale       = "Morale",
    buff_elite   = "Elite",
    flagbuff     = "Flag Buff",
}
local MAX_LINES = 18

-- chemicals: workspace name -> display name (stored in <model>.chems as IntValues)
local CHEMS = {
    bic      = "Bicardine",
    syn      = "Synaptizine",
    mep      = "Mephedrone",
    hyd      = "Hydrocodone",
    hal      = "Haloperidol",
    ama      = "Amatoxin",
    sickness = "Pox",
    tric      = "Tricordazine",
    per      = "Peridaxon",
}
local CHEM_ORDER = { "bic", "syn", "mep", "hyd", "hal", "ama", "sickness", "tri", "per" }
local CHEMS_FOLDER = "chems"

-- ===========================
-- STATE
-- ===========================
local enabled = true
local lastToggle = false
local currentTeam = nil
local currentModel = nil

-- ===========================
-- DRAWING
-- ===========================
local bg = Drawing.new("Square")
bg.Filled = true
bg.Color = Color3.fromRGB(20, 20, 20)
bg.Transparency = 0.6
bg.Position = CONFIG.position
bg.Size = Vector2.new(CONFIG.width, 30)
bg.ZIndex = 1
bg.Visible = true

local border = Drawing.new("Square")
border.Filled = false
border.Thickness = 1
border.Color = Color3.fromRGB(255, 200, 0)
border.Transparency = 1
border.Position = CONFIG.position
border.Size = Vector2.new(CONFIG.width, 30)
border.ZIndex = 2
border.Visible = true

local title = Drawing.new("Text")
title.Text = "Status Effects"
title.Size = 15
title.Color = Color3.fromRGB(255, 200, 0)
title.Outline = true
title.Center = false
title.Font = Drawing.Fonts.UI
title.Position = CONFIG.position + Vector2.new(8, 5)
title.ZIndex = 3
title.Visible = true

local lines = {}
for i = 1, MAX_LINES do
    local t = Drawing.new("Text")
    t.Size = 14
    t.Color = Color3.fromRGB(255, 255, 255)
    t.Outline = true
    t.Center = false
    t.Font = Drawing.Fonts.UI
    t.ZIndex = 3
    t.Visible = false
    lines[i] = t
end

local function setPanelVisible(v)
    bg.Visible = v
    border.Visible = v
    title.Visible = v
    if not v then
        for i = 1, MAX_LINES do lines[i].Visible = false end
    end
end

-- ===========================
-- FINDING THE PLAYER
-- ===========================
local Players = game:GetService("Players")

local function detectLocalName()
    -- 1) LocalPlayer
    local ok, name = pcall(function() return Players.LocalPlayer.Name end)
    if ok and type(name) == "string" and name ~= "" then return name end
    -- 2) camera subject (the humanoid you're viewing) -> its model
    local ok2, name2 = pcall(function()
        return Workspace.CurrentCamera.CameraSubject.Parent.Name
    end)
    if ok2 and type(name2) == "string" and name2 ~= "" then return name2 end
    return nil
end

local function findTargetModel()
    if not CONFIG.targetName then
        CONFIG.targetName = detectLocalName()
        if CONFIG.targetName then print("Detected local player: " .. CONFIG.targetName) end
    end
    if not CONFIG.targetName then return nil, nil end
    for _, folderName in ipairs(CONFIG.teamFolders) do
        local folder = Workspace:FindFirstChild(folderName)
        if folder then
            local model = folder:FindFirstChild(CONFIG.targetName)
            if model then
                return model, folderName
            end
        end
    end
    return nil, nil
end

-- ===========================
-- READING STATUS EFFECTS
-- ===========================
local function readEffects(model)
    local found = {}
    local ok, descendants = pcall(function() return model:GetDescendants() end)
    if not ok or not descendants then return found end

    for _, obj in ipairs(descendants) do
        local name = obj.Name
        if STATUS_EFFECTS[name] and obj.ClassName == "StringValue" and not found[name] then
            local vOk, value = pcall(function() return obj.Value end)
            found[name] = (vOk and value) or ""
        end
    end
    return found
end

-- ===========================
-- READING CHEMICALS
-- ===========================
local function getNum(obj, attr)
    local ok, v = pcall(function() return obj:GetAttribute(attr) end)
    if ok and type(v) == "number" then return v end
    -- fallback: a child value with that name
    local ok2, child = pcall(function() return obj:FindFirstChild(attr) end)
    if ok2 and child then
        local ok3, cv = pcall(function() return child.Value end)
        if ok3 and type(cv) == "number" then return cv end
    end
    return nil
end

-- returns { [key] = { count, left (lowest TickTimeLeft), duration (of that one) } }
local function readChems(model)
    local result = {}
    local ok, folder = pcall(function() return model:FindFirstChild(CHEMS_FOLDER) end)
    if not ok or not folder then return result end
    local ok2, kids = pcall(function() return folder:GetChildren() end)
    if not ok2 or not kids then return result end

    for _, c in ipairs(kids) do
        local key = string.lower(c.Name)
        if CHEMS[key] then
            local left = getNum(c, "TickTimeLeft")
            local dur = getNum(c, "Duration")
            local e = result[key]
            if not e then
                e = { count = 0, left = nil, duration = nil }
                result[key] = e
            end
            e.count = e.count + 1
            -- track the instance that will expire first
            if left and (not e.left or left < e.left) then
                e.left = left
                e.duration = dur
            elseif not e.left and dur then
                e.duration = dur
            end
        end
    end
    return result
end

-- ===========================
-- RENDER
-- ===========================
local ORDER = { "buff_advance", "buff_defend", "buff_focus", "morale", "buff_elite", "flagbuff" }
local WHITE  = Color3.fromRGB(255, 255, 255)
local GOLD   = Color3.fromRGB(255, 200, 0)
local ORANGE = Color3.fromRGB(255, 140, 0)
local GRAY   = Color3.fromRGB(170, 170, 170)
local RED    = Color3.fromRGB(255, 90, 90)

local function fmt(n)
    return string.format("%.1f", n)
end

local function render(effects, chems, teamName)
    if currentModel then
        local short = string.gsub(teamName, "_team", "")
        title.Text = tostring(CONFIG.targetName) .. " (" .. short .. ")"
    else
        title.Text = "Status Effects"
    end

    local rows = {}
    if not currentModel then
        rows[#rows + 1] = { (CONFIG.targetName and (CONFIG.targetName .. " not found") or "Detecting player..."), RED }
    else
        for _, key in ipairs(ORDER) do
            if effects[key] ~= nil then
                local text = STATUS_EFFECTS[key]
                if effects[key] ~= "" then text = text .. ": " .. tostring(effects[key]) end
                rows[#rows + 1] = { text, WHITE }
            end
        end

        local anyChem = false
        for _, key in ipairs(CHEM_ORDER) do
            if chems[key] then anyChem = true break end
        end
        if anyChem then
            rows[#rows + 1] = { "-- Chemicals --", GOLD }
            for _, key in ipairs(CHEM_ORDER) do
                local e = chems[key]
                if e then
                    local text = CHEMS[key] .. " x" .. e.count
                    local color = WHITE
                    if e.left then
                        text = text .. "  " .. fmt(e.left) .. "s"
                        if e.duration then text = text .. " / " .. fmt(e.duration) .. "s" end
                        if e.left <= 5 then color = ORANGE end
                    elseif e.duration then
                        text = text .. "  (" .. fmt(e.duration) .. "s)"
                    end
                    rows[#rows + 1] = { text, color }
                end
            end
        end

        if #rows == 0 then
            rows[1] = { "No active effects", GRAY }
        end
    end

    for i = 1, MAX_LINES do
        local row = rows[i]
        local line = lines[i]
        if row then
            line.Text = row[1]
            line.Color = row[2]
            line.Position = CONFIG.position + Vector2.new(8, 26 + (i - 1) * CONFIG.lineHeight)
            line.Visible = true
        else
            line.Visible = false
        end
    end

    local shown = math.min(#rows, MAX_LINES)
    local height = 30 + shown * CONFIG.lineHeight
    bg.Size = Vector2.new(CONFIG.width, height)
    border.Size = Vector2.new(CONFIG.width, height)
end

-- ===========================
-- MAIN LOOP
-- ===========================
print("Status overlay running (auto-detect player, F2 to toggle)")

local lastUpdate = 0
while true do
    wait(0.05)

    local toggleDown = false
    pcall(function() toggleDown = iskeypressed(CONFIG.toggleKey) end)
    if toggleDown and not lastToggle then
        enabled = not enabled
        setPanelVisible(enabled)
        print("Status overlay: " .. (enabled and "ENABLED" or "DISABLED"))
    end
    lastToggle = toggleDown

    if enabled then
        local now = os.clock()
        if now - lastUpdate >= CONFIG.updateRate then
            lastUpdate = now
            pcall(function()
                -- re-resolve every pass: the player can switch teams or respawn
                if not currentModel or not currentModel.Parent then
                    currentModel, currentTeam = findTargetModel()
                else
                    local m, t = findTargetModel()
                    if m ~= currentModel then
                        currentModel, currentTeam = m, t
                    end
                end

                local effects, chems = {}, {}
                if currentModel then
                    effects = readEffects(currentModel)
                    chems = readChems(currentModel)
                end
                render(effects, chems, currentTeam or "")
            end)
        end
    end
end
