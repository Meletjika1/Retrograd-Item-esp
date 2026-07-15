local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- ===========================
-- CONFIG
-- ===========================
local CONFIG = {
    color = Color3.fromRGB(0, 255, 255), -- cyan
    scanInterval = 0.5,
    toggleKey = 0x71, -- F2
}

local pagesFolder = Workspace:WaitForChild("MAP"):WaitForChild("Pages")

print("Page ESP: Pages folder found -", pagesFolder ~= nil)

-- ===========================
-- STATE
-- ===========================
local espObjects = {} -- part -> { label, box, part }
local allEntries = {}
local lastScanTime = 0
local enabled = true
local lastToggle = false

-- ===========================
-- DRAWING
-- ===========================
local function hideEntry(e)
    e.label.Visible = false
    e.box.Visible = false
end

local function removeEntry(part)
    local e = espObjects[part]
    if not e then return end
    e.label:Remove()
    e.box:Remove()
    espObjects[part] = nil
end

local function createEntry(part, sourceName)
    local label = Drawing.new("Text")
    label.Text = "Page"
    label.Color = CONFIG.color
    label.Outline = true
    label.Center = true
    label.Font = Drawing.Fonts.UI
    label.Size = 14
    label.Visible = false

    local box = Drawing.new("Square")
    box.Color = CONFIG.color
    box.Filled = false
    box.Thickness = 1
    box.Visible = false

    espObjects[part] = { label = label, box = box, part = part, sourceName = sourceName }
end

local function rebuildEntryList()
    allEntries = {}
    for _, entry in pairs(espObjects) do
        table.insert(allEntries, entry)
    end
end

-- ===========================
-- SCAN
-- ===========================
local function findSpawnPart(pageSpawn)
    -- PageSpawn itself might be the trackable part, or it might contain one
    if pageSpawn:IsA("BasePart") then
        return pageSpawn
    end
    local part = pageSpawn:FindFirstChildWhichIsA("BasePart")
    if part then return part end
    for _, d in pairs(pageSpawn:GetDescendants()) do
        if d:IsA("BasePart") then
            return d
        end
    end
    return nil
end

local function scanPages()
    if not pagesFolder or not pagesFolder.Parent then
        return
    end

    local currentParts = {}

    for _, child in ipairs(pagesFolder:GetChildren()) do
        if child.Name == "PageSpawn" or child.Name == "Page" then
            local part = findSpawnPart(child)
            if part then
                currentParts[part] = true
                if not espObjects[part] then
                    createEntry(part, child.Name)
                end
            end
        end
    end

    for part, _ in pairs(espObjects) do
        if not currentParts[part] or not part.Parent then
            removeEntry(part)
        end
    end

    rebuildEntryList()
end

-- ===========================
-- MAIN LOOP
-- ===========================
scanPages()
print("Page ESP loaded - " .. #allEntries .. " page spawns found. F2 to toggle.")

while true do
    task.wait(1/75)

    local toggleDown = false
    pcall(function() toggleDown = iskeypressed(CONFIG.toggleKey) end)
    if toggleDown and not lastToggle then
        enabled = not enabled
        print("Page ESP: " .. (enabled and "ENABLED" or "DISABLED"))
        if not enabled then
            for _, e in ipairs(allEntries) do hideEntry(e) end
        end
    end
    lastToggle = toggleDown

    if enabled then
        local now = tick()
        if now - lastScanTime > CONFIG.scanInterval then
            pcall(scanPages)
            lastScanTime = now
        end

        for i = 1, #allEntries do
            local e = allEntries[i]
            local part = e.part

            local ok = pcall(function()
                if not part or not part.Parent then
                    hideEntry(e)
                    return
                end

                local pos = part.Position
                local screenPos, onScreen = WorldToScreen(pos)

                if not onScreen then
                    hideEntry(e)
                    return
                end

                local boxSize = Vector2.new(30, 30)
                e.box.Position = Vector2.new(
                    screenPos.X - boxSize.X / 2,
                    screenPos.Y - boxSize.Y / 2
                )
                e.box.Size = boxSize
                e.box.Visible = true

                e.label.Position = Vector2.new(screenPos.X, screenPos.Y - 20)
                e.label.Visible = true
            end)

            if not ok then
                hideEntry(e)
            end
        end
    end
end
