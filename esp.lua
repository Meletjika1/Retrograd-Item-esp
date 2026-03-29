local drops = game:GetService("Workspace"):FindFirstChild("Game"):FindFirstChild("Loot"):FindFirstChild("drops")

local espObjects = {}

local function removeEsp(address)
    if espObjects[address] then
        espObjects[address].label:Remove()
        espObjects[address].box:Remove()
        espObjects[address] = nil
    end
end

local function createEsp(part, name, address)
    local label = Drawing.new("Text")
    label.Color = Color3.fromRGB(255, 255, 0)
    label.Outline = true
    label.Center = true
    label.Visible = false
    label.Font = Drawing.Fonts.SystemBold
    label.Size = 14
    label.Text = name

    local box = Drawing.new("Square")
    box.Color = Color3.fromRGB(255, 255, 0)
    box.Filled = false
    box.Thickness = 1
    box.Visible = false

    espObjects[address] = { label = label, box = box, part = part }
end

-- Resolves a drop instance into (displayName, anchorPart).
--
-- static_base  → Part with a "worldmodel" attribute
-- phys_base    → Model containing a Part named "int" with a "worldmodel" attribute
-- phys_<Name>  → Model whose name encodes the item name after the "phys_" prefix
local function resolveDrop(drop)
    local rawName = drop.Name or ""
    local cls     = drop.ClassName

    -- static_base: a Part/MeshPart with worldmodel attribute
    if cls == "Part" or cls == "MeshPart" then
        local worldmodel = drop:GetAttribute("worldmodel")
        local name = (worldmodel and worldmodel ~= "") and worldmodel or rawName
        return name, drop
    end

    -- phys_base: a Model — two sub-cases
    if cls == "Model" then
        if rawName == "phys_base" then
            -- read worldmodel from the child Part named "int"
            local intPart = drop:FindFirstChild("int")
            if intPart then
                local worldmodel = intPart:GetAttribute("worldmodel")
                local name = (worldmodel and worldmodel ~= "") and worldmodel or rawName
                return name, intPart
            end
            -- fallback: anchor to any BasePart inside
            return rawName, drop:FindFirstChildWhichIsA("BasePart")

        elseif rawName:sub(1, 5) == "phys_" then
            -- name is encoded in the instance name — strip the prefix
            local name = rawName:sub(6)
            return name, drop:FindFirstChildWhichIsA("BasePart")
        end

        -- unknown model style: use as-is
        return rawName, drop:FindFirstChildWhichIsA("BasePart")
    end

    return rawName, nil
end

local function updateEsp()
    local currentAddresses = {}
    local children = drops:GetChildren()

    for _, drop in ipairs(children) do
        local addr = drop.Address
        currentAddresses[addr] = true
    end

    -- Remove ESP for drops that no longer exist
    for address, _ in pairs(espObjects) do
        if not currentAddresses[address] then
            removeEsp(address)
        end
    end

    -- Add ESP for new drops
    for _, drop in ipairs(children) do
        local addr = drop.Address
        if not espObjects[addr] then
            local name, part = resolveDrop(drop)
            if part ~= nil then
                createEsp(part, name, addr)
            end
        end
    end

    -- Update positions
    for address, esp in pairs(espObjects) do
        local part = esp.part
        if part ~= nil and part.Position ~= nil then
            local screenPos, onScreen = WorldToScreen(part.Position)
            if onScreen then
                esp.label.Position = Vector2.new(screenPos.X, screenPos.Y - 20)
                esp.label.Visible = true
                local boxSize = Vector2.new(30, 30)
                esp.box.Position = Vector2.new(
                    screenPos.X - boxSize.X / 2,
                    screenPos.Y - boxSize.Y / 2
                )
                esp.box.Size = boxSize
                esp.box.Visible = true
            else
                esp.label.Visible = false
                esp.box.Visible = false
            end
        end
    end
end

while true do
    updateEsp()
    task.wait(0.05)
end
