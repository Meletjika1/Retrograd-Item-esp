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

local function getAddress(instance)
    return instance.Address
end

local function updateEsp()
    -- Build a set of current drop addresses
    local currentAddresses = {}
    local children = drops:GetChildren()
    for _, drop in ipairs(children) do
        local addr = getAddress(drop)
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
        local addr = getAddress(drop)
        if not espObjects[addr] then
            local part = drop:FindFirstChildOfClass("BasePart")
            if part == nil then
                part = drop:FindFirstChildWhichIsA("BasePart")
            end
            if part == nil then
                part = drop
            end
            createEsp(part, drop.Name, addr)
        end
    end

    -- Update positions
    for address, esp in pairs(espObjects) do
        local part = esp.part
        if part ~= nil then
            if part.Position ~= nil then
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
end

while true do
    updateEsp()
    task.wait(0.05)
end
