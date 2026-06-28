-- Roblox Taxi Script - Synchronized Polling Version (Race Condition Patched)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local TaxiOffer = ReplicatedStorage.Remotes.Jobs.TaxiOffer
local TaxiUpdate = ReplicatedStorage.Remotes.Jobs.TaxiUpdate

local isEnabled = false
local isTeleporting = false
local offerConnection = nil
local updateConnection = nil

-- =====================
-- DESTROY OLD GUI
-- =====================
local oldGui = PlayerGui:FindFirstChild("TaxiGUI")
if oldGui then oldGui:Destroy() end

-- =====================
--        GUI
-- =====================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TaxiGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Enabled = true
ScreenGui.Parent = PlayerGui

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 210, 0, 190)
Frame.Position = UDim2.new(0, 20, 0, 20)
Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Frame.BorderSizePixel = 0
Frame.Active = true
Frame.Draggable = true
Frame.Parent = ScreenGui
Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 38)
Title.Position = UDim2.new(0, 0, 0, 0)
Title.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
Title.BorderSizePixel = 0
Title.Text = "🚕  Taxi Script"
Title.TextColor3 = Color3.fromRGB(255, 200, 0)
Title.TextScaled = true
Title.Font = Enum.Font.GothamBold
Title.Parent = Frame
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 10)

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -20, 0, 24)
StatusLabel.Position = UDim2.new(0, 10, 0, 44)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Status: OFF"
StatusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
StatusLabel.TextScaled = true
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = Frame

local ToggleButton = Instance.new("TextButton")
ToggleButton.Size = UDim2.new(1, -20, 0, 36)
ToggleButton.Position = UDim2.new(0, 10, 0, 72)
ToggleButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
ToggleButton.BorderSizePixel = 0
ToggleButton.Text = "Enable"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextScaled = true
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.Parent = Frame
Instance.new("UICorner", ToggleButton).CornerRadius = UDim.new(0, 7)

local TeleportButton = Instance.new("TextButton")
TeleportButton.Size = UDim2.new(1, -20, 0, 36)
TeleportButton.Position = UDim2.new(0, 10, 0, 114)
TeleportButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
TeleportButton.BorderSizePixel = 0
TeleportButton.Text = "🚀 Teleport"
TeleportButton.TextColor3 = Color3.fromRGB(100, 100, 100)
TeleportButton.TextScaled = true
TeleportButton.Font = Enum.Font.GothamBold
TeleportButton.Active = false
TeleportButton.Parent = Frame
Instance.new("UICorner", TeleportButton).CornerRadius = UDim.new(0, 7)

local LogLabel = Instance.new("TextLabel")
LogLabel.Size = UDim2.new(1, -20, 0, 20)
LogLabel.Position = UDim2.new(0, 10, 0, 155)
LogLabel.BackgroundTransparency = 1
LogLabel.Text = "Script is OFF"
LogLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
LogLabel.TextScaled = true
LogLabel.Font = Enum.Font.Gotham
LogLabel.TextXAlignment = Enum.TextXAlignment.Left
LogLabel.Parent = Frame

local ProgressLabel = Instance.new("TextLabel")
ProgressLabel.Size = UDim2.new(1, -20, 0, 18)
ProgressLabel.Position = UDim2.new(0, 10, 0, 170)
ProgressLabel.BackgroundTransparency = 1
ProgressLabel.Text = ""
ProgressLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
ProgressLabel.TextScaled = true
ProgressLabel.Font = Enum.Font.Gotham
ProgressLabel.TextXAlignment = Enum.TextXAlignment.Left
ProgressLabel.Parent = Frame

-- =====================
--      FUNCTIONS
-- =====================
local function log(msg)
    LogLabel.Text = msg
    print("[Taxi] " .. msg)
end

local function getTargetPosition()
    local anchor = workspace:FindFirstChild("TaxiTargetAnchor_1700_o9", true)
    if not anchor then
        for _, v in ipairs(workspace:GetDescendants()) do
            if v.Name:lower():find("taxi") or v.Name:find("1700") then
                if v:IsA("BasePart") then return Vector3.new(v.Position.X, v.Position.Y + 5, v.Position.Z) end
            end
        end
        return nil
    end

    local pos
    if anchor:IsA("BasePart") then
        pos = anchor.Position
    elseif anchor:IsA("Model") and anchor.PrimaryPart then
        pos = anchor.PrimaryPart.Position
    else
        for _, child in ipairs(anchor:GetDescendants()) do
            if child:IsA("BasePart") then
                pos = child.Position
                break
            end
        end
    end

    if not pos then return nil end
    return Vector3.new(pos.X, pos.Y + 5, pos.Z)
end

local function waitForTargetPosition(timeoutSeconds)
    local elapsed = 0
    while elapsed < timeoutSeconds do
        local pos = getTargetPosition()
        if pos then return pos end
        task.wait(0.5)
        elapsed = elapsed + 0.5
    end
    return nil
end

local function hardFreezeVehicle(vehicle)
    for _, part in ipairs(vehicle:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = true
            part.CanCollide = false
            part.Velocity = Vector3.zero
            part.RotVelocity = Vector3.zero
        end
    end
    if vehicle.PrimaryPart then
        vehicle.PrimaryPart.Anchored = true
        vehicle.PrimaryPart.Velocity = Vector3.zero
        vehicle.PrimaryPart.RotVelocity = Vector3.zero
    end
end

local function hardUnfreezeVehicle(vehicle)
    for _, part in ipairs(vehicle:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = false
            part.CanCollide = true
            part.Velocity = Vector3.zero
            part.RotVelocity = Vector3.zero
        end
    end
    if vehicle.PrimaryPart then
        vehicle.PrimaryPart.Anchored = false
        vehicle.PrimaryPart.Velocity = Vector3.zero
        vehicle.PrimaryPart.RotVelocity = Vector3.zero
    end
end

local function freezeCharacter(character, frozen)
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = frozen
            part.Velocity = Vector3.zero
            part.RotVelocity = Vector3.zero
        end
    end
end

local function smoothDrift(fromPos, toPos, vehicle, hrp, character, duration)
    local steps = 200
    local charOffset = hrp.Position - fromPos
    local slowdownStart = 0.60

    for i = 1, steps do
        if not isEnabled then break end

        local alpha = i / steps
        local stepTime
        
        if alpha < slowdownStart then
            stepTime = (duration * 0.3) / (steps * slowdownStart)
        elseif alpha < 0.85 then
            stepTime = (duration * 0.3) / (steps * 0.25)
        else
            stepTime = (duration * 0.4) / (steps * 0.15)
        end

        local t = alpha < 0.5 and (4 * alpha * alpha * alpha) or (1 - (-2 * alpha + 2)^3 / 2)
        local newPos = fromPos:Lerp(toPos, t)

        if vehicle and vehicle.PrimaryPart then
            vehicle:SetPrimaryPartCFrame(CFrame.new(newPos))
            hrp.CFrame = CFrame.new(newPos + charOffset)
            
            for _, part in ipairs(vehicle:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Velocity = Vector3.zero
                    part.RotVelocity = Vector3.zero
                end
            end
        else
            hrp.CFrame = CFrame.new(newPos)
        end

        if alpha >= 0.85 then
            ProgressLabel.Text = "🐢 Almost there..."
        elseif alpha >= slowdownStart then
            ProgressLabel.Text = "🔄 Slowing down..."
        else
            ProgressLabel.Text = string.format("Moving... %d%%", math.floor(alpha * 100))
        end

        task.wait(stepTime)
    end

    if vehicle and vehicle.PrimaryPart then
        vehicle:SetPrimaryPartCFrame(CFrame.new(toPos))
        hrp.CFrame = CFrame.new(toPos + charOffset)
    else
        hrp.CFrame = CFrame.new(toPos)
    end

    ProgressLabel.Text = "✅ Arrived!"
    task.wait(1)
    ProgressLabel.Text = ""
end

local function driftTo(targetPos)
    local character = LocalPlayer.Character
    if not character then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local seat = humanoid and humanoid.SeatPart
    local vehicle = seat and seat:FindFirstAncestorOfClass("Model")

    if vehicle and vehicle.PrimaryPart then
        hardFreezeVehicle(vehicle)
        freezeCharacter(character, true)
        task.wait(0.3)

        local fromPos = vehicle.PrimaryPart.Position
        smoothDrift(fromPos, targetPos, vehicle, hrp, character, 5)

        hardFreezeVehicle(vehicle)
        freezeCharacter(character, true)
        task.wait(0.5)

        freezeCharacter(character, false)
        task.wait(0.3)

        hardUnfreezeVehicle(vehicle)
        task.wait(0.5)
        seat:Sit(humanoid)
    else
        local fromPos = hrp.Position
        smoothDrift(fromPos, targetPos, nil, hrp, character, 5)
    end
end

-- =====================
-- CORE LOGIC PIPELINE
-- =====================
local function teleportToAnchor()
    if isTeleporting then return end
    isTeleporting = true
    TeleportButton.Text = "Moving..."
    TeleportButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    TeleportButton.Active = false

    -- === PHASE 1: TELEPORT TO PASSERBY (PICKUP) ===
    log("Waiting for game to drop pickup marker...")
    local pickupPos = waitForTargetPosition(6) 
    
    if not pickupPos then
        log("Error: Pickup anchor never spawned! Resetting.")
        isTeleporting = false
        TeleportButton.Text = "🚀 Teleport"
        TeleportButton.BackgroundColor3 = Color3.fromRGB(30, 130, 60)
        TeleportButton.Active = true
        return
    end

    log("Teleporting to pickup point...")
    driftTo(pickupPos)
    log("Arrived at pickup!")

    log("Securing passenger object...")
    task.wait(3.5)

    if not isEnabled then isTeleporting = false return end

    -- === PHASE 2: TELEPORT TO DESTINATION (DROPOFF) ===
    log("Waiting for game to drop destination marker...")
    local dropoffPos = waitForTargetPosition(6)
    
    if not dropoffPos then
        log("Error: Dropoff anchor never spawned! Resetting.")
        isTeleporting = false
        TeleportButton.Text = "🚀 Teleport"
        TeleportButton.BackgroundColor3 = Color3.fromRGB(30, 130, 60)
        TeleportButton.Active = true
        return
    end

    log("Teleporting to destination...")
    driftTo(dropoffPos)
    log("Arrived at dropoff destination!")

    -- State Reset Configuration
    isTeleporting = false
    TeleportButton.Text = "🚀 Teleport"
    TeleportButton.BackgroundColor3 = Color3.fromRGB(30, 130, 60)
    TeleportButton.Active = true
    log("Job finished! Listening for incoming system offers...")
end

-- =====================
--   VIRTUAL MOUSE DRIVER
-- =====================
local function autoClickElement(guiElement)
    if guiElement and guiElement.AbsolutePosition then
        local x = guiElement.AbsolutePosition.X + (guiElement.AbsoluteSize.X / 2)
        local y = guiElement.AbsolutePosition.Y + (guiElement.AbsoluteSize.Y / 2) + 58 
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end
end

local function findAndClickAccept()
    for _, desc in ipairs(PlayerGui:GetDescendants()) do
        if desc:IsA("TextButton") or desc:IsA("ImageButton") then
            local name = desc.Name:lower()
            local text = desc:IsA("TextButton") and desc.Text:lower() or ""
            
            if name:find("accept") or text:find("accept") or name:find("confirm") or text:find("confirm") then
                if desc.Visible and desc.AbsolutePosition.X > 0 then
                    autoClickElement(desc)
                    return true
                end
            end
        end
    end
    return false
end

-- =====================
--   HOOK SYSTEM TOGGLE
-- =====================
local function enableScript()
    isEnabled = true
    ToggleButton.Text = "Disable"
    ToggleButton.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
    StatusLabel.Text = "Status: ON"
    StatusLabel.TextColor3 = Color3.fromRGB(80, 255, 80)
    TeleportButton.BackgroundColor3 = Color3.fromRGB(30, 130, 60)
    TeleportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    TeleportButton.Active = true
    log("Awaiting engine signals...")

    updateConnection = TaxiUpdate.OnClientEvent:Connect(function()
        -- Handled explicitly in offerConnection now to prevent double-firing
    end)

    -- Intercept offer, click, sync delay, and launch sequence
    offerConnection = TaxiOffer.OnClientEvent:Connect(function(name, fare)
        if not isEnabled or isTeleporting then return end
        log("Intercepted offer from client: " .. tostring(name))

        task.spawn(function()
            task.wait(0.15) 
            local success = findAndClickAccept()
            
            if not success then
                task.wait(0.3) 
                success = findAndClickAccept()
            end

            if success then
                log("Button clicked! Waiting for server sync...")
                
                -- THE FIX: Wait 1.5 seconds so the game deletes the old drop-off 
                -- marker and officially registers the new pickup marker.
                task.wait(1.5) 
                
                teleportToAnchor()
            else
                log("Could not find UI button.")
            end
        end)
    end)
end

local function disableScript()
    isEnabled = false
    isTeleporting = false
    ToggleButton.Text = "Enable"
    ToggleButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    StatusLabel.Text = "Status: OFF"
    StatusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
    TeleportButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    TeleportButton.TextColor3 = Color3.fromRGB(100, 100, 100)
    TeleportButton.Active = false
    TeleportButton.Text = "🚀 Teleport"
    ProgressLabel.Text = ""
    log("Script is OFF")

    if offerConnection then offerConnection:Disconnect() offerConnection = nil end
    if updateConnection then updateConnection:Disconnect() updateConnection = nil end
end

ToggleButton.MouseButton1Click:Connect(function()
    if isEnabled then disableScript() else enableScript() end
end)

TeleportButton.MouseButton1Click:Connect(function()
    if not isEnabled or isTeleporting then return end
    teleportToAnchor()
end)

print("[Taxi] Synchronized System Loaded Successfully.")
