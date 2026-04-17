local WorkspaceService = game:GetService("Workspace")

-- ===========================
-- CONFIG
-- ===========================
local CONFIG = {
    armoredWall = {
        color    = Color3.fromRGB(0, 180, 255),  -- blue
        label    = "Wall",
    },
    claymore = {
        color    = Color3.fromRGB(255, 60, 60),  -- red
        label    = "Claymore",
    },
    scanInterval = 0.5,  -- seconds between rescans
}

-- ===========================
-- STATE
-- ===========================
local espObjects   = {}  -- address -> { label, box, part, type }
local allEntries   = {}
local lastScanTime = 0

-- ===========================
-- DRAWING
-- ===========================
local function hideEntry(e)
    e.label.Visible = false
    e.box.Visible   = false
end

local function removeEntry(address)
    local e = espObjects[address]
    if not e then return end
    e.label:Remove()
    e.box:Remove()
    espObjects[address] = nil
end

local function createEntry(part, address, entryType)
    local cfg = CONFIG[entryType]

    local label = Drawing.new("Text")
    label.Text    = cfg.label
    label.Color   = cfg.color
    label.Outline = true
    label.Center  = true
    label.Font    = Drawing.Fonts.SystemBold
    label.Size    = 14
    label.Visible = false

    local box = Drawing.new("Square")
    box.Color     = cfg.color
    box.Filled    = false
    box.Thickness = 1
    box.Visible   = false

    espObjects[address] = {
        label   = label,
        box     = box,
        part    = part,
        type    = entryType,
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
local function scanDebris()
    local debris = WorkspaceService:FindFirstChild("Debris")
    if not debris then return end

    -- Track which addresses are currently valid
    local currentAddresses = {}

    for _, child in ipairs(debris:GetChildren()) do
        local entryType = nil
        local anchorPart = nil

        if child.ClassName == "Model" then
            if child.Name == "Armored Wall" then
                local part = child:FindFirstChild("shield3")
                if part then
                    entryType  = "armoredWall"
                    anchorPart = part
                end
            elseif child.Name == "claymore" then
                local part = child:FindFirstChild("main")
                if part then
                    entryType  = "claymore"
                    anchorPart = part
                end
            end
        end

        if anchorPart and entryType then
            local addr = anchorPart.Address
            currentAddresses[addr] = true
            if not espObjects[addr] then
                createEntry(anchorPart, addr, entryType)
            end
        end
    end

    -- Remove stale entries
    for address, _ in pairs(espObjects) do
        if not currentAddresses[address] then
            removeEntry(address)
        end
    end

    rebuildEntryList()
end

-- ===========================
-- MAIN LOOP
-- ===========================
while true do
    task.wait(0.016)

    local now = tick()
    if now - lastScanTime > CONFIG.scanInterval then
        pcall(scanDebris)
        lastScanTime = now
    end

    for i = 1, #allEntries do
        local e    = allEntries[i]
        local part = e.part

        local ok, err = pcall(function()
            if not part or not part.Parent then
                hideEntry(e)
                return
            end

            local pos = part.Position
            local rootPos, onScreen = WorldToScreen(pos)

            if not onScreen then
                hideEntry(e)
                return
            end

            -- Use part size to drive box dimensions on screen
            local topPos    = WorldToScreen(Vector3.new(pos.X, pos.Y + part.Size.Y / 2, pos.Z))
            local bottomPos = WorldToScreen(Vector3.new(pos.X, pos.Y - part.Size.Y / 2, pos.Z))

            if not topPos or not bottomPos then
                hideEntry(e)
                return
            end

            local boxH = math.abs(bottomPos.Y - topPos.Y)
            if boxH < 2 then
                hideEntry(e)
                return
            end

            local boxW = boxH * (part.Size.X / part.Size.Y)
            local boxX = rootPos.X - boxW / 2
            local boxY = topPos.Y

            e.box.Position = Vector2.new(boxX, boxY)
            e.box.Size     = Vector2.new(boxW, boxH)
            e.box.Visible  = true

            e.label.Position = Vector2.new(rootPos.X, boxY - 16)
            e.label.Visible  = true
        end)

        if not ok then
            hideEntry(e)
        end
    end
end
