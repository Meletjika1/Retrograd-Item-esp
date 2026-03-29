local workspace = game:GetService("Workspace")
local Players   = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local drops  = workspace:FindFirstChild("Game"):FindFirstChild("Loot"):FindFirstChild("drops")
local wsPlayers = workspace:FindFirstChild("Players")

-- ===========================
-- ITEM ESP
-- ===========================
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

local function resolveDrop(drop)
    local rawName = drop.Name or ""
    local cls     = drop.ClassName

    if cls == "Part" or cls == "MeshPart" then
        local worldmodel = drop:GetAttribute("worldmodel")
        local name = (worldmodel and worldmodel ~= "") and worldmodel or rawName
        return name, drop
    end

    if cls == "Model" then
        if rawName == "phys_base" then
            local intPart = drop:FindFirstChild("int")
            if intPart then
                local worldmodel = intPart:GetAttribute("worldmodel")
                local name = (worldmodel and worldmodel ~= "") and worldmodel or rawName
                return name, intPart
            end
            return rawName, drop:FindFirstChildWhichIsA("BasePart")

        elseif rawName:sub(1, 5) == "phys_" then
            local name = rawName:sub(6)
            return name, drop:FindFirstChildWhichIsA("BasePart")
        end

        return rawName, drop:FindFirstChildWhichIsA("BasePart")
    end

    return rawName, nil
end

local function updateItemEsp()
    local currentAddresses = {}
    local children = drops:GetChildren()

    for _, drop in ipairs(children) do
        currentAddresses[drop.Address] = true
    end

    for address, _ in pairs(espObjects) do
        if not currentAddresses[address] then
            removeEsp(address)
        end
    end

    for _, drop in ipairs(children) do
        local addr = drop.Address
        if not espObjects[addr] then
            local name, part = resolveDrop(drop)
            if part ~= nil then
                createEsp(part, name, addr)
            end
        end
    end

    for _, esp in pairs(espObjects) do
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

-- ===========================
-- TRAITOR ESP
-- ===========================
local traitorEsp = {}

local function removeTraitorEsp(name)
    if traitorEsp[name] then
        traitorEsp[name].label:Remove()
        traitorEsp[name].box:Remove()
        traitorEsp[name] = nil
    end
end

local function createTraitorEsp(name)
    local label = Drawing.new("Text")
    label.Color   = Color3.fromRGB(255, 50, 50)
    label.Outline = true
    label.Center  = true
    label.Visible = false
    label.Font    = Drawing.Fonts.SystemBold
    label.Size    = 14
    label.Text    = name .. " [T]"

    local box = Drawing.new("Square")
    box.Color     = Color3.fromRGB(255, 50, 50)
    box.Filled    = false
    box.Thickness = 1
    box.Visible   = false

    traitorEsp[name] = { label = label, box = box }
end

local function updateTraitorEsp()
    if wsPlayers == nil then
        wsPlayers = workspace:FindFirstChild("Players")
        if wsPlayers == nil then return end
    end

    -- Build set of current traitors
    local currentTraitors = {}
    for _, wsChar in ipairs(wsPlayers:GetChildren()) do
        local playerName = wsChar.Name
        -- skip ourselves
        if playerName ~= LocalPlayer.Name then
            local role = wsChar:GetAttribute("rg_team")
            if role and role:lower() == "traitor" then
                currentTraitors[playerName] = wsChar
            end
        end
    end

    -- Remove ESP for players who are no longer traitors / left
    for name, _ in pairs(traitorEsp) do
        if not currentTraitors[name] then
            removeTraitorEsp(name)
        end
    end

    -- Add ESP for new traitors
    for name, _ in pairs(currentTraitors) do
        if not traitorEsp[name] then
            createTraitorEsp(name)
        end
    end

    -- Update traitor positions
    for name, esp in pairs(traitorEsp) do
        local wsChar = currentTraitors[name]
        if wsChar then
            local hrp = wsChar:FindFirstChild("HumanoidRootPart")
            if hrp and hrp.Position then
                local screenPos, onScreen = WorldToScreen(hrp.Position)
                if onScreen then
                    esp.label.Position = Vector2.new(screenPos.X, screenPos.Y - 20)
                    esp.label.Visible  = true
                    local boxSize = Vector2.new(30, 30)
                    esp.box.Position = Vector2.new(
                        screenPos.X - boxSize.X / 2,
                        screenPos.Y - boxSize.Y / 2
                    )
                    esp.box.Size    = boxSize
                    esp.box.Visible = true
                else
                    esp.label.Visible = false
                    esp.box.Visible   = false
                end
            else
                esp.label.Visible = false
                esp.box.Visible   = false
            end
        end
    end
end

-- ===========================
-- MAIN LOOP
-- ===========================
while true do
    updateItemEsp()
    updateTraitorEsp()
    task.wait(0.05)
end
