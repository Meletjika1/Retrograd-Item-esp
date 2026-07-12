local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- ===========================
-- CONFIG
-- ===========================
local CONFIG = {
    color = Color3.fromRGB(255, 40, 40),
    scanInterval = 0.5,   -- seconds between folder rescans
    maxDistance = 300,    -- studs
    toggleKey = 0x71,     -- F2
}

local localPlayer = Players.LocalPlayer
local charactersFolder = Workspace:WaitForChild("Characters")

-- ===========================
-- STATE
-- ===========================
local espObjects = {}  -- model -> { label, box, model, name }
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

local function removeEntry(model)
    local e = espObjects[model]
    if not e then return end
    e.label:Remove()
    e.box:Remove()
    espObjects[model] = nil
end

local function createEntry(model)
    local label = Drawing.new("Text")
    label.Text = model.Name
    label.Color = Color3.fromRGB(255, 255, 255)
    label.Outline = true
    label.Center = true
    label.Font = Drawing.Fonts.UI
    label.Size = 15
    label.Visible = false

    local box = Drawing.new("Square")
    box.Color = CONFIG.color
    box.Filled = false
    box.Thickness = 2
    box.Visible = false

    espObjects[model] = {
        label = label,
        box = box,
        model = model,
        name = model.Name,
    }
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
local function scanCharacters()
    local currentModels = {}

    for _, model in ipairs(charactersFolder:GetChildren()) do
        if model:IsA("Model") then
            local isMe = localPlayer and localPlayer.Character == model
            if not isMe then
                currentModels[model] = true
                if not espObjects[model] then
                    createEntry(model)
                end
            end
        end
    end

    for model, _ in pairs(espObjects) do
        if not currentModels[model] or not model.Parent then
            removeEntry(model)
        end
    end

    rebuildEntryList()
end

local function findTrackingPart(model)
    local hrp = model:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then return hrp end

    local torso = model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso")
    if torso and torso:IsA("BasePart") then return torso end

    if model.PrimaryPart then return model.PrimaryPart end

    for _, d in pairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            return d
        end
    end
    return nil
end

-- ===========================
-- MAIN LOOP
-- ===========================
scanCharacters()
print("NPC ESP loaded - " .. #allEntries .. " entries. F2 to toggle.")

while true do
    task.wait(1/75) -- fixed 75fps

    -- toggle
    local toggleDown = false
    pcall(function() toggleDown = iskeypressed(CONFIG.toggleKey) end)
    if toggleDown and not lastToggle then
        enabled = not enabled
        print("NPC ESP: " .. (enabled and "ENABLED" or "DISABLED"))
        if not enabled then
            for _, e in ipairs(allEntries) do hideEntry(e) end
        end
    end
    lastToggle = toggleDown

    if enabled then
        local now = tick()
        if now - lastScanTime > CONFIG.scanInterval then
            pcall(scanCharacters)
            lastScanTime = now
        end

        local playerPos
        if localPlayer and localPlayer.Character then
            local hrp = localPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then playerPos = hrp.Position end
        end

        -- single pass: gather part + distance, track closest per name
        local closestByName = {}
        local resolved = {}

        for i = 1, #allEntries do
            local e = allEntries[i]
            local model = e.model

            local ok = pcall(function()
                if not model.Parent then
                    hideEntry(e)
                    return
                end

                local humanoid = model:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.Health and humanoid.Health <= 0 then
                    hideEntry(e)
                    return
                end

                local part = findTrackingPart(model)
                if not part then
                    hideEntry(e)
                    return
                end

                local dist = playerPos and (part.Position - playerPos).Magnitude or 0
                if playerPos and dist > CONFIG.maxDistance then
                    hideEntry(e)
                    return
                end

                local cur = closestByName[e.name]
                if not cur or dist < cur.dist then
                    closestByName[e.name] = { e = e, part = part, dist = dist }
                end
                resolved[e] = true
            end)

            if not ok then
                hideEntry(e)
            end
        end

        -- only draw the closest instance per name
        for name, best in pairs(closestByName) do
            local e = best.e
            local part = best.part
            local dist = best.dist

            local ok = pcall(function()
                local pos = part.Position
                local rootPos, onScreen = WorldToScreen(pos)

                if not onScreen then
                    hideEntry(e)
                    return
                end

                local size = part.Size
                local sizeY = (size and size.Y) or 3

                local topPos, topOn = WorldToScreen(Vector3.new(pos.X, pos.Y + sizeY, pos.Z))
                local bottomPos, botOn = WorldToScreen(Vector3.new(pos.X, pos.Y - sizeY, pos.Z))

                local boxH
                if topOn and botOn and topPos and bottomPos then
                    boxH = math.abs(bottomPos.Y - topPos.Y)
                else
                    boxH = 3000 / math.max(dist, 5) -- fallback distance-based scale
                end
                boxH = math.clamp(boxH, 15, 250)
                local boxW = boxH / 2

                local boxX = rootPos.X - boxW / 2
                local boxY = rootPos.Y - boxH / 2

                e.box.Position = Vector2.new(boxX, boxY)
                e.box.Size = Vector2.new(boxW, boxH)
                e.box.Visible = true

                e.label.Position = Vector2.new(rootPos.X, boxY - 16)
                e.label.Visible = true
            end)

            if not ok then
                hideEntry(e)
            end
        end

        -- hide any entry that lost the "closest per name" contest
        for i = 1, #allEntries do
            local e = allEntries[i]
            local best = closestByName[e.name]
            if not best or best.e ~= e then
                if resolved[e] then
                    hideEntry(e)
                end
            end
        end
    end
end
