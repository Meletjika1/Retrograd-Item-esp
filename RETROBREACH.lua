local WorkspaceService = game:GetService("Workspace")
local Players          = game:GetService("Players")
local LocalPlayer      = Players.LocalPlayer

-- ===========================
-- EXACT ITEM LOOKUP TABLES
-- ===========================
local WEAPON_SET = {
    ["hk416"]=true,["uzi"]=true,["saiga-12"]=true,["as val"]=true,
    ["bizon"]=true,["m4 super 90"]=true,["usas-12"]=true,
    ["desert eagle"]=true,["double barrel"]=true,["rsh-12"]=true,
    ["ksm-23m"]=true,["f2000"]=true,["m110"]=true,["mp9"]=true,
    ["aks-74u"]=true,["mac-10"]=true,["mp5"]=true,["mp7a1"]=true,
    ["mossberg"]=true,["mk14 ebr"]=true,["micro uzi"]=true,
    ["scar-h"]=true,["scar-l"]=true,["sg-552"]=true,
    ["beretta m9"]=true,["sawed-off"]=true,["awp"]=true,
    ["ump-45"]=true,["m1911"]=true,["aug"]=true,["ak-74"]=true,
    ["honey badger"]=true,["m249"]=true,["g36"]=true,["p90"]=true,
    ["vss"]=true,["spas-12"]=true,["usp"]=true,["ash-12"]=true,
    ["aa-12"]=true,["m4a1"]=true,["five-seven"]=true,["uts-15"]=true,
    ["mp443"]=true,["kriss vector"]=true,["l85a2"]=true,["m16"]=true,
    ["m82a1"]=true,["psg-1"]=true,["mp5sd"]=true,["rpk"]=true,
    ["g17"]=true,["beretta 93r"]=true,["akm"]=true,["makarov"]=true,
    ["famas"]=true,["xm8"]=true,
}
local GRENADE_SET = {
    ["flashbang"]=true,["frag grenade"]=true,
    ["incendiary grenade"]=true,["smoke grenade"]=true,
}
local KEYCARD_SET = {
    ["zone manager card"]=true,["engineer card"]=true,
    ["major scientist card"]=true,["scientist card"]=true,
    ["doctor card"]=true,["hacking device"]=true,
    ["o5 council card"]=true,["facility manager card"]=true,
    ["janitor card"]=true,["mtf operative card"]=true,
    ["guard card"]=true,["lieutenant card"]=true,
    ["medical specialist card"]=true,["containment engineer card"]=true,
    ["commander card"]=true,
}
local AMMO_SET = {
    ["primammo"]=true,["secammo"]=true,
}
local CAT_COLOR = {
    weapon  = Color3.fromRGB(255, 220, 0),
    grenade = Color3.fromRGB(160, 0,   255),
    keycard = Color3.fromRGB(0,   120, 255),
    ammo    = Color3.fromRGB(0,   220, 80),
}

local function resolveCategory(name)
    local lower = name:lower()
    if WEAPON_SET[lower]  then return "weapon"  end
    if GRENADE_SET[lower] then return "grenade" end
    if KEYCARD_SET[lower] then return "keycard" end
    if AMMO_SET[lower]    then return "ammo"    end
    return nil
end

local function getAnchorPart(instance)
    local cls = instance.ClassName
    if cls == "MeshPart" then return instance end
    if cls == "Model" then
        return instance:FindFirstChild("_Handle")
            or instance:FindFirstChild("Handle")
    end
    return nil
end

-- ===========================
-- STATE
-- ===========================
-- allEntries is a flat array of structs — no table lookups in hot path
-- struct: { label, box, part, dead }
local espObjects   = {}   -- address -> entry (for dedup during scan)
local allEntries   = {}   -- flat array iterated every frame
local lastScanTime = 0
local SCAN_INTERVAL = 1.5  -- scan less often, renders are still per-frame

-- Pre-cache V3/V2 constructors as locals to avoid global lookups each frame
local V3 = Vector3.new
local V2 = Vector2.new

local function getItemSpawns()
    return WorkspaceService:FindFirstChild("ItemSpawns")
end

-- ===========================
-- DRAWING (called only on scan, not per frame)
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

local function createEntry(instance, address)
    local name = instance.Name or ""
    local cat  = resolveCategory(name)
    if not cat then return end

    local anchorPart = getAnchorPart(instance)
    if not anchorPart then return end

    local color = CAT_COLOR[cat]

    local label = Drawing.new("Text")
    label.Text    = name
    label.Color   = color
    label.Outline = true
    label.Center  = true
    label.Font    = Drawing.Fonts.SystemBold
    label.Size    = 14
    label.Visible = false

    local box = Drawing.new("Square")
    box.Color     = color
    box.Filled    = false
    box.Thickness = 1
    box.Visible   = false

    espObjects[address] = {
        label    = label,
        box      = box,
        part     = anchorPart,
        instance = instance,
        dead     = false,
    }
end

local function rebuildEntryList()
    allEntries = {}
    for _, entry in pairs(espObjects) do
        table.insert(allEntries, entry)
    end
end

-- ===========================
-- SCAN (runs on interval, not per frame)
-- ===========================
local function scanItems()
    local folder = getItemSpawns()

    -- Prune entries whose instance is gone
    for address, entry in pairs(espObjects) do
        if entry.dead or not entry.instance or not entry.instance.Parent then
            removeEntry(address)
        end
    end

    if not folder then return end

    for _, instance in ipairs(folder:GetChildren()) do
        local cls = instance.ClassName
        if (cls == "Model" or cls == "MeshPart") and not espObjects[instance.Address] then
            createEntry(instance, instance.Address)
        end
    end

    rebuildEntryList()
end

-- ===========================
-- RENDER (called every frame, no pcall, no table creation)
-- ===========================
local function renderEntry(e)
    local part = e.part

    -- Fast checks before any property access
    if not part or not part.Parent then
        e.dead = true
        hideEntry(e)
        return
    end

    if not e.instance or not e.instance.Parent then
        e.dead = true
        hideEntry(e)
        return
    end

    local pos = part.Position
    if not pos then
        e.dead = true
        hideEntry(e)
        return
    end

    -- Root on-screen check first — cheapest rejection
    local rootPos, onScreen = WorldToScreen(pos)
    if not onScreen then
        hideEntry(e)
        return
    end

    -- Head/feet only if root confirmed on screen
    local headPos, headOn = WorldToScreen(V3(pos.X, pos.Y + 1.5, pos.Z))
    local feetPos         = WorldToScreen(V3(pos.X, pos.Y - 1.5, pos.Z))

    if not headOn or not headPos or not feetPos then
        hideEntry(e)
        return
    end

    local boxH = feetPos.Y - headPos.Y
    if boxH < 2 then
        hideEntry(e)
        return
    end

    local boxW = math.max(boxH, 20)
    local boxX = rootPos.X - boxW * 0.5
    local boxY = headPos.Y

    -- Write directly to drawings — no intermediate tables
    e.box.Position  = V2(boxX, boxY)
    e.box.Size      = V2(boxW, boxH)
    e.box.Visible   = true

    e.label.Position = V2(rootPos.X, boxY - 16)
    e.label.Visible  = true
end

-- ===========================
-- MAIN LOOP
-- ===========================
-- Render runs every frame. Scan runs on interval.
-- No pcall in the render loop — instead we mark entries dead
-- and let the next scan clean them up.
while true do
    task.wait(0.016)

    local now = tick()
    if now - lastScanTime > SCAN_INTERVAL then
        pcall(scanItems)  -- pcall only around the scan, not render
        lastScanTime = now
    end

    local n = #allEntries
    for i = 1, n do
        renderEntry(allEntries[i])
    end
end
