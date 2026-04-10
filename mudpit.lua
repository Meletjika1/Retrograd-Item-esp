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

local espObjects   = {}
local allEntries   = {}
local lastScanTime = 0

local function getEnemiesFolder()
    return WorkspaceService:FindFirstChild("Enemies")
end

local function getPlayerRootPos()
    local char = LocalPlayer.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.Position
end

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
    hpLabel.Text    = ""
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
        box       = box,
        nameLabel = nameLabel,
        hpLabel   = hpLabel,
        hpBar     = hpBar,
        hpBarBg   = hpBarBg,
        npc       = npc,
        hrp       = hrp,
        humanoid  = humanoid,
    }
end

local function rebuildEntryList()
    allEntries = {}
    for _, entry in pairs(espObjects) do
        table.insert(allEntries, entry)
    end
end

local function scanNPCs()
    for address, entry in pairs(espObjects) do
        if not entry.npc or not entry.npc.Parent then
            removeEntry(address)
        end
    end

    local folder = getEnemiesFolder()
    if folder then
        for _, npc in ipairs(folder:GetChildren()) do
            if npc.ClassName == "Model" then
                local addr = npc.Address
                if not espObjects[addr] then
                    createEntry(npc, addr)
                end
            end
        end
    end

    rebuildEntryList()
end

-- ===========================
-- MAIN LOOP
-- ===========================
while true do
    task.wait()

    local now = tick()
    if now - lastScanTime > CONFIG.scanInterval then
        scanNPCs()
        lastScanTime = now
    end

    local playerPos = getPlayerRootPos()
    local maxDist   = CONFIG.maxDistance

    for _, e in ipairs(allEntries) do
        local npc      = e.npc
        local hrp      = e.hrp
        local humanoid = e.humanoid

        -- Guard: NPC or HRP destroyed/deparented
        if not (npc and npc.Parent and hrp and hrp.Parent) then
            hideEntry(e)
        else
            -- Guard: Position can be nil if part is mid-destruction
            local ok, pos = pcall(function() return hrp.Position end)
            if not ok or pos == nil then
                hideEntry(e)
            else
                -- Distance check
                local inRange = true
                if maxDist > 0 and playerPos then
                    local dx = pos.X - playerPos.X
                    local dy = pos.Y - playerPos.Y
                    local dz = pos.Z - playerPos.Z
                    if dx*dx + dy*dy + dz*dz > maxDist * maxDist then
                        inRange = false
                    end
                end

                if not inRange then
                    hideEntry(e)
                else
                    local headPos, headOn = WorldToScreen(Vector3.new(pos.X, pos.Y + 3.5, pos.Z))
                    local feetPos, feetOn = WorldToScreen(Vector3.new(pos.X, pos.Y - 3.5, pos.Z))

                    if not (headPos and feetPos and headOn) then
                        hideEntry(e)
                    else
                        local boxH = feetPos.Y - headPos.Y

                        if boxH <= 2 then
                            hideEntry(e)
                        else
                            local boxW = boxH / 1.8
                            local boxX = headPos.X - boxW / 2
                            local boxY = headPos.Y

                            e.box.Position = Vector2.new(boxX, boxY)
                            e.box.Size     = Vector2.new(boxW, boxH)
                            e.box.Visible  = true

                            e.nameLabel.Text     = npc.Name
                            e.nameLabel.Position = Vector2.new(headPos.X, boxY - 16)
                            e.nameLabel.Visible  = true

                            -- HP — pcall in case humanoid is also mid-destruction
                            local hpOk, hp, maxHp = pcall(function()
                                return humanoid.Health, humanoid.MaxHealth
                            end)
                            if not hpOk then
                                hp    = 0
                                maxHp = 1
                            end
                            local pct   = (maxHp > 0) and math.clamp(hp / maxHp, 0, 1) or 0
                            local hpCol = hpColor(pct)

                            e.hpLabel.Text     = math.floor(hp) .. " / " .. math.floor(maxHp)
                            e.hpLabel.Color    = hpCol
                            e.hpLabel.Position = Vector2.new(headPos.X, feetPos.Y + 2)
                            e.hpLabel.Visible  = true

                            local barW      = 4
                            local barX      = boxX + boxW + 2
                            local barTotalH = boxH
                            local fillH     = barTotalH * pct

                            e.hpBarBg.Position = Vector2.new(barX, boxY)
                            e.hpBarBg.Size     = Vector2.new(barW, barTotalH)
                            e.hpBarBg.Visible  = true

                            e.hpBar.Position = Vector2.new(barX, boxY + barTotalH - fillH)
                            e.hpBar.Size     = Vector2.new(barW, math.max(fillH, 0))
                            e.hpBar.Color    = hpCol
                            e.hpBar.Visible  = fillH > 0
                        end
                    end
                end
            end
        end
    end
end
