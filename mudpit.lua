local Players          = game:GetService("Players")
local WorkspaceService = game:GetService("Workspace")
local LocalPlayer      = Players.LocalPlayer

local CONFIG = {
    maxDistance  = 500,
    boxColor     = Color3.fromRGB(255, 60, 60),
    textColor    = Color3.fromRGB(255, 255, 255),
    healthHigh   = Color3.fromRGB(0,   220, 80),
    healthMid    = Color3.fromRGB(255, 200, 0),
    healthLow    = Color3.fromRGB(255, 50,  50),
    scanInterval = 2,
}

local espObjects = {}
local allEntries = {}
local lastScanTime = 0
local maxDistSq = CONFIG.maxDistance * CONFIG.maxDistance

local function lerpColor(a, b, t)
    return Color3.new(
        a.R + (b.R - a.R) * t,
        a.G + (b.G - a.G) * t,
        a.B + (b.B - a.B) * t
    )
end

local function hpColor(pct)
    if pct >= 0.5 then
        return lerpColor(CONFIG.healthMid, CONFIG.healthHigh, (pct - 0.5) * 2)
    else
        return lerpColor(CONFIG.healthLow, CONFIG.healthMid, pct * 2)
    end
end

local function hideEntry(e)
    e.box.Visible       = false
    e.nameLabel.Visible = false
    e.hpLabel.Visible   = false
    e.hpBar.Visible     = false
    e.hpBarBg.Visible   = false
end

local function removeEntry(address)
    local e = espObjects[address]
    if not e then return end
    e.box:Remove()
    e.nameLabel:Remove()
    e.hpLabel:Remove()
    e.hpBar:Remove()
    e.hpBarBg:Remove()
    espObjects[address] = nil
end

local function createEntry(npc, address)
    local hrp      = npc:FindFirstChild("HumanoidRootPart")
    local humanoid = npc:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end

    local box = Drawing.new("Square")
    box.Color     = CONFIG.boxColor
    box.Filled    = false
    box.Thickness = 1
    box.Visible   = false

    local nameLabel = Drawing.new("Text")
    nameLabel.Text    = npc.Name
    nameLabel.Color   = CONFIG.textColor
    nameLabel.Outline = true
    nameLabel.Center  = true
    nameLabel.Font    = Drawing.Fonts.SystemBold
    nameLabel.Size    = 14
    nameLabel.Visible = false

    local hpLabel = Drawing.new("Text")
    hpLabel.Color   = CONFIG.textColor
    hpLabel.Outline = true
    hpLabel.Center  = true
    hpLabel.Font    = Drawing.Fonts.System
    hpLabel.Size    = 12
    hpLabel.Visible = false

    local hpBarBg = Drawing.new("Square")
    hpBarBg.Color   = Color3.fromRGB(30, 30, 30)
    hpBarBg.Filled  = true
    hpBarBg.Visible = false

    local hpBar = Drawing.new("Square")
    hpBar.Filled  = true
    hpBar.Visible = false

    espObjects[address] = {
        box         = box,
        nameLabel   = nameLabel,
        hpLabel     = hpLabel,
        hpBar       = hpBar,
        hpBarBg     = hpBarBg,
        npc         = npc,
        hrp         = hrp,
        humanoid    = humanoid,
        lastHpText  = "",
        dead        = false,
    }
end

local function rebuildEntryList()
    allEntries = {}
    for _, entry in pairs(espObjects) do
        table.insert(allEntries, entry)
    end
end

local function scanNPCs()
    -- prune dead entries
    for address, entry in pairs(espObjects) do
        if entry.dead or not entry.npc or not entry.npc.Parent then
            removeEntry(address)
        end
    end
    -- discover new ones
    local folder = WorkspaceService:FindFirstChild("Enemies")
    if folder then
        for _, npc in ipairs(folder:GetChildren()) do
            if npc.ClassName == "Model" and not espObjects[npc.Address] then
                createEntry(npc, npc.Address)
            end
        end
    end
    rebuildEntryList()
end

local function renderEntry(e, playerPos)
    local hrp      = e.hrp
    local npc      = e.npc
    local humanoid = e.humanoid

    -- strict parent checks — no pcall needed if we check Parent first
    if not npc.Parent or not hrp.Parent or not humanoid.Parent then
        e.dead = true
        hideEntry(e)
        return
    end

    -- humanoid health check — dead NPCs can be removed
    if humanoid.Health <= 0 then
        e.dead = true
        hideEntry(e)
        return
    end

    local pos = hrp.Position

    -- distance cull
    if playerPos then
        local dx = pos.X - playerPos.X
        local dy = pos.Y - playerPos.Y
        local dz = pos.Z - playerPos.Z
        if dx*dx + dy*dy + dz*dz > maxDistSq then
            hideEntry(e)
            return
        end
    end

    -- on-screen gate: root first, cheapest rejection
    local rootPos, onScreen = WorldToScreen(pos)
    if not onScreen then
        hideEntry(e)
        return
    end

    -- head and feet only if root is confirmed on screen
    local headPos, headOn = WorldToScreen(Vector3.new(pos.X, pos.Y + 3.5, pos.Z))
    local feetPos         = WorldToScreen(Vector3.new(pos.X, pos.Y - 3.5, pos.Z))

    if not headOn or not headPos or not feetPos then
        hideEntry(e)
        return
    end

    local boxH = feetPos.Y - headPos.Y
    if boxH <= 2 then
        hideEntry(e)
        return
    end

    local boxW = boxH / 1.8
    local boxX = headPos.X - boxW / 2
    local boxY = headPos.Y

    e.box.Position = Vector2.new(boxX, boxY)
    e.box.Size     = Vector2.new(boxW, boxH)
    e.box.Visible  = true

    e.nameLabel.Position = Vector2.new(headPos.X, boxY - 16)
    e.nameLabel.Visible  = true

    local hp     = humanoid.Health
    local maxHp  = humanoid.MaxHealth
    local pct    = maxHp > 0 and math.clamp(hp / maxHp, 0, 1) or 0
    local hpCol  = hpColor(pct)
    local hpFloor = math.floor(hp)
    local hpText = hpFloor .. "/" .. math.floor(maxHp)

    if hpText ~= e.lastHpText then
        e.hpLabel.Text = hpText
        e.lastHpText   = hpText
    end
    e.hpLabel.Color    = hpCol
    e.hpLabel.Position = Vector2.new(headPos.X, feetPos.Y + 2)
    e.hpLabel.Visible  = true

    local barW  = 4
    local barX  = boxX + boxW + 2
    local fillH = boxH * pct

    e.hpBarBg.Position = Vector2.new(barX, boxY)
    e.hpBarBg.Size     = Vector2.new(barW, boxH)
    e.hpBarBg.Visible  = true

    e.hpBar.Position = Vector2.new(barX, boxY + boxH - fillH)
    e.hpBar.Size     = Vector2.new(barW, math.max(fillH, 0))
    e.hpBar.Color    = hpCol
    e.hpBar.Visible  = fillH > 0
end

-- ===========================
-- MAIN LOOP
-- ===========================
while true do
    task.wait(0.016)  -- cap at ~60fps, prevents loop running unconstrained

    local now = tick()
    if now - lastScanTime > CONFIG.scanInterval then
        scanNPCs()
        lastScanTime = now
    end

    local playerPos = nil
    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then playerPos = hrp.Position end
    end

    for i = 1, #allEntries do
        -- wrap each NPC in pcall so one crash can't freeze the whole loop
        local e = allEntries[i]
        local ok, err = pcall(renderEntry, e, playerPos)
        if not ok then
            e.dead = true
            hideEntry(e)
        end
    end
end
