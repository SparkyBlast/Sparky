local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")

local TARGET_COORD = Vector3.new(1073.00, 19.93, 22984.00)
local BEHIND_OFFSET = 5
local DETECTION_RANGE = 17
local ALT_SPACING_X = 2.0
local ALT_SPACING_Z = 4.0
local ALTS_PER_ROW = 3

local isMain = LocalPlayer.Name == MAIN_USERNAME

print("========================================")
print("Player: " .. LocalPlayer.Name)
print("Is Main: " .. tostring(isMain))
print("Main Username: " .. MAIN_USERNAME)
print("========================================")

local function getAltIndex()
    for i, name in ipairs(ALT_USERNAMES) do
        if LocalPlayer.Name == name then
            return i
        end
    end
    return 1
end

local function getChar(plr)
    return plr and plr.Character
end

local function getHRP(char)
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function teleportTo(pos)
    local char = getChar(LocalPlayer)
    local hrp = getHRP(char)
    if hrp then
        hrp.CFrame = CFrame.new(pos)
    end
end

local function disableCollision(char)
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end

local function resetChar()
    local char = getChar(LocalPlayer)
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.Health = 0
        end
    end
end

local function isMainInRange(altChar)
    local mainPlr = Players:FindFirstChild(MAIN_USERNAME)
    if not mainPlr then return false end
    
    local mainChar = getChar(mainPlr)
    local altHrp = getHRP(altChar)
    local mainHrp = getHRP(mainChar)
    
    if not altHrp or not mainHrp then return false end
    
    local dist = (mainHrp.Position - altHrp.Position).Magnitude
    return dist <= DETECTION_RANGE
end

local function isAltAtFarmLocation(altPlr)
    local altChar = getChar(altPlr)
    local altHrp = getHRP(altChar)
    if not altHrp then return false end
    
    local dist = (altHrp.Position - TARGET_COORD).Magnitude
    return dist <= 20
end

local function isAltDead(altPlr)
    local char = getChar(altPlr)
    if not char then return true end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return not hum or hum.Health <= 0
end

local function pressKey(key)
    VirtualInputManager:SendKeyEvent(true, key, false, game)
    task.wait(0.05)
    VirtualInputManager:SendKeyEvent(false, key, false, game)
end

local function aimAtTarget(targetPos)
    local char = getChar(LocalPlayer)
    local hrp = getHRP(char)
    if hrp then
        local lookCFrame = CFrame.new(hrp.Position, targetPos)
        hrp.CFrame = lookCFrame
        
        local camera = workspace.CurrentCamera
        if camera then
            camera.CFrame = CFrame.new(camera.CFrame.Position, targetPos)
        end
    end
end

local function aimCameraAtAlts()
    local camera = workspace.CurrentCamera
    if camera then
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame = CFrame.new(camera.CFrame.Position, TARGET_COORD)
    end
end

if isMain then
    print("[MAIN] Active - Starting attack cycle")
    
    RunService.RenderStepped:Connect(function()
        aimCameraAtAlts()
    end)
    
    task.spawn(function()
        while task.wait(0.01) do
            local hasAliveAlts = false
            for _, altName in ipairs(ALT_USERNAMES) do
                local altPlr = Players:FindFirstChild(altName)
                if altPlr and isAltAtFarmLocation(altPlr) and not isAltDead(altPlr) then
                    hasAliveAlts = true
                    break
                end
            end
            
            if hasAliveAlts then
                local mainChar = getChar(LocalPlayer)
                local mainHum = mainChar and mainChar:FindFirstChildOfClass("Humanoid")
                
                if mainChar and mainHum and mainHum.Health > 0 then
                    local targetAlt = nil
                    for _, altName in ipairs(ALT_USERNAMES) do
                        local altPlr = Players:FindFirstChild(altName)
                        if altPlr and isAltAtFarmLocation(altPlr) and not isAltDead(altPlr) then
                            targetAlt = altPlr
                            break
                        end
                    end
                    
                    if targetAlt then
                        local targetChar = getChar(targetAlt)
                        local targetHrp = getHRP(targetChar)
                        
                        if targetHrp then
                            local altPosition = targetHrp.Position
                            local behindPos = altPosition - Vector3.new(0, 0, BEHIND_OFFSET)
                            
                            print("[MAIN] Teleporting behind alts")
                            teleportTo(behindPos + Vector3.new(0, 2, 0))
                            
                            task.wait(0.5)
                            
                            print("[MAIN] Aiming at alts")
                            aimAtTarget(altPosition)
                            
                            task.wait(0.5)
                            
                            print("[MAIN] Waiting for alts to die...")
                            local allAltsDead = false
                            while not allAltsDead do
                                allAltsDead = true
                                for _, altName in ipairs(ALT_USERNAMES) do
                                    local altPlr = Players:FindFirstChild(altName)
                                    if altPlr and isAltAtFarmLocation(altPlr) and not isAltDead(altPlr) then
                                        allAltsDead = false
                                        break
                                    end
                                end
                                task.wait(0.01)
                            end
                            
                            print("[MAIN] All alts dead! Pressing ability...")
                            task.wait(0.7)
                            pressKey(Enum.KeyCode.Three)
                            task.wait(1.5)
                            print("[MAIN] Resetting...")
                            resetChar()
                            task.wait(2.0)
                        end
                    end
                end
            end
        end
    end)
    
    LocalPlayer.CharacterAdded:Connect(function(char)
        print("[MAIN] Respawned")
        task.wait(0.5)
    end)

else
    print("[ALT] Active - " .. LocalPlayer.Name)
    
    local myIndex = getAltIndex()
    local row = math.floor((myIndex - 1) / ALTS_PER_ROW)
    local col = (myIndex - 1) % ALTS_PER_ROW
    
    local xOffset = (col - (ALTS_PER_ROW - 1) / 2) * ALT_SPACING_X
    local zOffset = row * ALT_SPACING_Z
    local myOffset = Vector3.new(xOffset, 0, zOffset)
    
    print("[ALT] My position: Row " .. row .. ", Col " .. col)
    
    task.spawn(function()
        while task.wait(0.03) do
            local char = getChar(LocalPlayer)
            if char then
                disableCollision(char)
                teleportTo(TARGET_COORD + myOffset)
            end
            
            if char then
                if isMainInRange(char) then
                    print("[ALT] Main detected! Waiting for iframes...")
                    task.wait(2.0)
                    print("[ALT] Resetting now!")
                    resetChar()
                    task.wait(1.5)
                end
            end
        end
    end)
    
    LocalPlayer.CharacterAdded:Connect(function(char)
        print("[ALT] Respawned")
        task.wait(0.5)
        disableCollision(char)
        for i = 1, 5 do
            task.wait(0.05)
            teleportTo(TARGET_COORD + myOffset)
        end
    end)
end

print("Script loaded successfully")
