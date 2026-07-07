local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/sh0tzik/another1hproject/main/supremacy.lua?t=" .. tostring(tick())))()

-- Initial Silent Aim Configuration
_G.Avidbot_SilentAim = _G.Avidbot_SilentAim or {}
_G.Avidbot_SilentAim.enabled = false
_G.Avidbot_SilentAim.esp = false
_G.Avidbot_SilentAim.c4esp = false
_G.Avidbot_SilentAim.showfov = false
_G.Avidbot_SilentAim.autoshoot = false
_G.Avidbot_SilentAim.hitchance = 65
_G.Avidbot_SilentAim.missspread = 5

--[[
	WARNING: Heads up! This script has not been verified by ScriptBlox. Use at your own risk!
]]
-- Missspread its just for legit stuff like for example lets say your hitchance is 50 itll miss 50% of the time but if you want people to believe your actually shooting missspread makes it so it LOOKS like your missing because your missing next to them but not actually hitting them its crazy >~<

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")
local Teams = game:GetService("Teams")

local guardsTeam = Teams:FindFirstChild("Guards")
local inmatesTeam = Teams:FindFirstChild("Inmates")
local criminalsTeam = Teams:FindFirstChild("Criminals")



local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Exclude
wallParams.IgnoreWater = true
wallParams.RespectCanCollide = false
wallParams.CollisionGroup = "ClientBullet"

local projectileParams = RaycastParams.new()
projectileParams.FilterType = Enum.RaycastFilterType.Exclude
projectileParams.IgnoreWater = true
projectileParams.RespectCanCollide = false
projectileParams.CollisionGroup = "ClientBullet"

local currentGun = nil
local rng = Random.new()
local lastShotTime = 0
local lastShotResult = false
local shotCooldown = 1 / 30
local currentTarget = nil
local targetSwitchTime = 0
local currentStickiness = 0
local randomPartCache = {}
local lastTouchAimPos = nil
local storedAimMaxDistanceBeforeDistanceHitchance = tonumber(_G.Avidbot_SilentAim.aimmaxdist) or 0
local distanceHitchanceForcesAimMaxDistance = false
local activeTouch = nil
local lastAutoShoot = 0
local cachedBulletsLabel = nil
local targetAcquiredTime = 0
local lastAutoTarget = nil
local playerSettings = ReplicatedStorage:FindFirstChild("PlayerSettings")
local mobileCursorOffset = 0
local isInsideDynThumbFrame = nil
local giverPressedRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("GiverPressed")
local trackedGrabbables = {}
local firstSeenGrabbables = {}
local lastAutoGrab = 0

do
    local sharedModules = ReplicatedStorage:FindFirstChild("SharedModules")
    local dynThumbModule = sharedModules and sharedModules:FindFirstChild("isInsideDynThumbFrame")
    if dynThumbModule then
        local ok, result = pcall(require, dynThumbModule)
        if ok and typeof(result) == "function" then
            isInsideDynThumbFrame = result
        end
    end
end

local fovCircle = Drawing.new("Circle")
fovCircle.Color = Color3.fromRGB(255, 0, 0)
fovCircle.Radius = _G.Avidbot_SilentAim.fov
fovCircle.Transparency = 0.8
fovCircle.Filled = false
fovCircle.NumSides = 64
fovCircle.Thickness = 1
fovCircle.Visible = _G.Avidbot_SilentAim.showfov and _G.Avidbot_SilentAim.enabled

local targetLine = Drawing.new("Line")
targetLine.Color = Color3.fromRGB(0, 255, 0)
targetLine.Thickness = 1
targetLine.Transparency = 0.5
targetLine.Visible = false

local visuals = {container = nil}
local espCache = {}

local function resetAimState()
    lastShotTime = 0
    lastShotResult = false
    currentTarget = nil
    targetSwitchTime = 0
    currentStickiness = 0
    lastAutoShoot = 0
    lastAutoTarget = nil
    targetAcquiredTime = 0
    cachedBulletsLabel = nil
end

local function getHud()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    local home = playerGui and playerGui:FindFirstChild("Home")
    return home and home:FindFirstChild("hud") or nil
end

local function getMobileGunFrame()
    local hud = getHud()
    return hud and hud:FindFirstChild("MobileGunFrame") or nil
end

local function getMobileCursor()
    local mobileGunFrame = getMobileGunFrame()
    return mobileGunFrame and mobileGunFrame:FindFirstChild("MobileCursor") or nil
end

local function updateMobileCursorOffset()
    if not playerSettings then
        mobileCursorOffset = 0
        return
    end
    local offset = playerSettings:GetAttribute("MobileCursorOffset")
    if typeof(offset) == "number" then
        mobileCursorOffset = offset * 15
    else
        mobileCursorOffset = 0
    end
end

if playerSettings then
    updateMobileCursorOffset()
    playerSettings:GetAttributeChangedSignal("MobileCursorOffset"):Connect(updateMobileCursorOffset)
end

local function isIgnoredTouchPosition(position)
    if isInsideDynThumbFrame and isInsideDynThumbFrame(position.X, position.Y) then
        return true
    end
    local mobileGunFrame = getMobileGunFrame()
    local ignoreTouchArea = mobileGunFrame and mobileGunFrame:FindFirstChild("IgnoreTouchArea")
    if not ignoreTouchArea then
        return false
    end
    local x = position.X
    local y = position.Y
    local left = ignoreTouchArea.AbsolutePosition.X
    local right = left + ignoreTouchArea.AbsoluteSize.X
    local top = ignoreTouchArea.AbsolutePosition.Y
    local bottom = top + ignoreTouchArea.AbsoluteSize.Y
    return left <= x and x <= right and top <= y and y <= bottom
end

local function getAimScreenPosition(camera)
    camera = camera or workspace.CurrentCamera
    if not camera then
        return UserInputService:GetMouseLocation()
    end
    
    local lastInput = UserInputService:GetLastInputType()
    if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
        local viewportSize = camera.ViewportSize
        return Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    end
    
    if lastInput == Enum.UserInputType.Touch then
        local mobileCursor = getMobileCursor()
        if mobileCursor and mobileCursor.Visible then
            local pos = mobileCursor.AbsolutePosition
            local size = mobileCursor.AbsoluteSize
            return Vector2.new(pos.X + size.X / 2, pos.Y + size.Y / 2)
        end

        local viewportSize = camera.ViewportSize
        return Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    end
    
    return UserInputService:GetMouseLocation()
end

local function getScreenCenter(camera)
    camera = camera or workspace.CurrentCamera
    if not camera then
        return Vector2.zero
    end
    local viewportSize = camera.ViewportSize
    return Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
end

local function getFovScreenPosition(camera)
    if _G.Avidbot_SilentAim.staticfov then
        return getScreenCenter(camera)
    end
    return getAimScreenPosition(camera)
end

local function isSniper(gun)
    return gun and gun:GetAttribute("Behavior") == "Sniper"
end

local function isTaserGun(gun)
    return gun and (gun:GetAttribute("Behavior") == "Taser" or gun:GetAttribute("Projectile") == "Taser")
end

local function isShotgun(gun)
    return gun and (gun:GetAttribute("IsShotgun") or gun:GetAttribute("Behavior") == "Shotgun")
end

local function isAutomaticWeapon(gun)
    return gun and gun:GetAttribute("AutoFire") == true
end

local function normalizeWeaponSelector(value)
    return tostring(value or ""):lower():gsub("%s+", "")
end

local function gunMatchesAutoShootWeapon(gun)
    if not gun then
        return false
    end
    
    local selector = normalizeWeaponSelector(_G.Avidbot_SilentAim.autoshootweapon)
    if selector == "" or selector == "any" or selector == "all" then
        return true
    end
    
    local gunName = normalizeWeaponSelector(gun.Name)
    local behavior = normalizeWeaponSelector(gun:GetAttribute("Behavior"))
    local projectile = normalizeWeaponSelector(gun:GetAttribute("Projectile"))
    
    if selector == "taser" then
        return isTaserGun(gun) or gunName:find("taser", 1, true) ~= nil
    elseif selector == "shotgun" then
        return isShotgun(gun)
    elseif selector == "sniper" then
        return isSniper(gun)
    elseif selector == "auto" or selector == "automatic" then
        return isAutomaticWeapon(gun)
    end
    
    return selector == gunName or selector == behavior or selector == projectile
end

local function getLocalAimOriginPart()
    local character = LocalPlayer.Character
    if not character then
        return nil
    end
    return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
end

local function isWithinAimDistance(targetPos)
    local maxDistance = tonumber(_G.Avidbot_SilentAim.aimmaxdist) or 0
    if maxDistance <= 0 or not targetPos then
        return true
    end
    
    local originPart = getLocalAimOriginPart()
    if not originPart then
        return true
    end
    
    return (targetPos - originPart.Position).Magnitude <= maxDistance
end

local function syncDistanceHitchanceAimMaxDistance()
    local currentAimMaxDistance = tonumber(_G.Avidbot_SilentAim.aimmaxdist) or 0
    if _G.Avidbot_SilentAim.distancebasedhitchance then
        if currentAimMaxDistance > 0 then
            storedAimMaxDistanceBeforeDistanceHitchance = currentAimMaxDistance
        elseif storedAimMaxDistanceBeforeDistanceHitchance <= 0 then
            storedAimMaxDistanceBeforeDistanceHitchance = 100
        end
        _G.Avidbot_SilentAim.aimmaxdist = 0
        distanceHitchanceForcesAimMaxDistance = true
    elseif distanceHitchanceForcesAimMaxDistance then
        _G.Avidbot_SilentAim.aimmaxdist = tonumber(storedAimMaxDistanceBeforeDistanceHitchance) or 0
        distanceHitchanceForcesAimMaxDistance = false
    else
        storedAimMaxDistanceBeforeDistanceHitchance = currentAimMaxDistance
    end
end

local function shouldBypassHitchance(gun)
    return gun ~= nil and _G.Avidbot_SilentAim.hitchanceAutoOnly and not isAutomaticWeapon(gun)
end

local function getLocalHumanoid()
    local character = LocalPlayer.Character
    return character and character:FindFirstChildOfClass("Humanoid") or nil
end

local function isSniperStable(gun)
    if not isSniper(gun) then
        return true
    end
    if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
        return false
    end
    local humanoid = getLocalHumanoid()
    return not humanoid or humanoid:GetState() ~= Enum.HumanoidStateType.Freefall
end

local function getFireOriginPosition()
    local myChar = LocalPlayer.Character
    local myHead = myChar and myChar:FindFirstChild("Head")
    if not myHead then return nil end
    
    local muzzle = currentGun and currentGun:FindFirstChild("Muzzle")
    return muzzle and muzzle.Position or myHead.Position
end

local function isInCurrentGunRange(targetPos, originPos)
    if not currentGun or not targetPos then return true end
    
    local range = currentGun:GetAttribute("Range")
    if typeof(range) ~= "number" or range <= 0 then return true end
    
    originPos = originPos or getFireOriginPosition()
    if not originPos then return true end
    
    return (targetPos - originPos).Magnitude <= range + 5
end

local function isSupportedGrabbable(obj)
    if not obj or not obj:IsA("Model") then
        return false
    end
    
    local name = obj.Name:lower()
    return name:find("keycard", 1, true) ~= nil or name == "m9"
end

local function shouldAutoGrabItem(obj)
    if not _G.Avidbot_SilentAim.autograb or not obj or not obj:IsA("Model") then
        return false
    end
    
    local name = obj.Name:lower()
    if name:find("keycard", 1, true) ~= nil then
        return _G.Avidbot_SilentAim.autograbkeycard
    end
    if name == "m9" then
        return _G.Avidbot_SilentAim.autograbm9
    end
    
    return false
end

local function isOwnedGrabbable(obj)
    local ancestor = obj and obj.Parent
    while ancestor and ancestor ~= workspace do
        if ancestor:FindFirstChildOfClass("Humanoid") then
            return true
        end
        if ancestor.Name == "Backpack" then
            return true
        end
        ancestor = ancestor.Parent
    end
    return false
end

local function getGrabbablePart(model)
    if not model then
        return nil
    end
    return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function distSq(a, b)
    local delta = a - b
    return delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
end

local function trackGrabbable(obj)
    if isSupportedGrabbable(obj) then
        trackedGrabbables[obj] = true
    end
end

local function untrackGrabbable(obj)
    trackedGrabbables[obj] = nil
    firstSeenGrabbables[obj] = nil
end

local function updateAutoGrab(now)
    if not _G.Avidbot_SilentAim.autograb or not giverPressedRemote then
        return
    end
    if now - lastAutoGrab < 0.05 then
        return
    end
    
    local root = getLocalAimOriginPart()
    if not root then
        return
    end
    
    local grabDistance = math.clamp(tonumber(_G.Avidbot_SilentAim.autograbdistance) or 0, 0, 12)
    if grabDistance <= 0 then
        return
    end
    
    local requiredDelay = math.max(tonumber(_G.Avidbot_SilentAim.autograbdelay) or 0, 0)
    local grabDistanceSq = grabDistance * grabDistance
    
    for item in pairs(trackedGrabbables) do
        if not item or not item.Parent then
            untrackGrabbable(item)
        elseif not shouldAutoGrabItem(item) then
            firstSeenGrabbables[item] = nil
        elseif isOwnedGrabbable(item) then
            firstSeenGrabbables[item] = nil
        else
            local part = getGrabbablePart(item)
            if part and distSq(root.Position, part.Position) <= grabDistanceSq then
                if not firstSeenGrabbables[item] then
                    firstSeenGrabbables[item] = now
                elseif now - firstSeenGrabbables[item] >= requiredDelay then
                    lastAutoGrab = now
                    firstSeenGrabbables[item] = nil
                    pcall(giverPressedRemote.FireServer, giverPressedRemote, item)
                    return
                end
            else
                firstSeenGrabbables[item] = nil
            end
        end
    end
end

local function shouldUseInstantAcquireDelay(gun)
    if not gun then
        return false
    end
    local lastInput = UserInputService:GetLastInputType()
    return lastInput == Enum.UserInputType.Touch or lastInput == Enum.UserInputType.Gamepad1 or isShotgun(gun)
end

local function simulateProjectileImpact(startPos, aimPos, gun)
    if not gun or not startPos or not aimPos then
        return nil, aimPos
    end
    local behavior = gun:GetAttribute("Behavior")
    local spread = gun:GetAttribute("SpreadRadius") or 0
    local range = gun:GetAttribute("Range") or 1500
    local randomScale = rng:NextNumber()
    if behavior == "Sniper" or behavior == "Shotgun" then
        randomScale = math.sqrt(randomScale)
    end
    local baseCFrame = CFrame.new(startPos, aimPos)
    local rollAngle = math.rad(360 - 720 * rng:NextNumber())
    local direction = (baseCFrame * CFrame.Angles(0, 0, rollAngle) * CFrame.Angles(0, randomScale * spread, 0)).LookVector * range
    projectileParams.FilterDescendantsInstances = {LocalPlayer.Character}
    local result = workspace:Raycast(startPos, direction, projectileParams)
    if result then
        return result.Instance, result.Position
    end
    return nil, startPos + direction
end

local function makeVisuals()
    local container
    local guiParent = (gethui and gethui()) or CoreGui
    local existing = guiParent:FindFirstChild("SilentAimESP") or CoreGui:FindFirstChild("SilentAimESP")
    if existing then
        existing:Destroy()
    end
    if gethui then
        local screen = Instance.new("ScreenGui")
        screen.Name = "SilentAimESP"
        screen.ResetOnSpawn = false
        screen.Parent = gethui()
        container = screen
    elseif syn and syn.protect_gui then
        local screen = Instance.new("ScreenGui")
        screen.Name = "SilentAimESP"
        screen.ResetOnSpawn = false
        syn.protect_gui(screen)
        screen.Parent = CoreGui
        container = screen
    else
        local screen = Instance.new("ScreenGui")
        screen.Name = "SilentAimESP"
        screen.ResetOnSpawn = false
        screen.Parent = CoreGui
        container = screen
    end
    visuals.container = container
end

local function makeEsp(player)
    if espCache[player] then return espCache[player] end
    
    local esp = Instance.new("BillboardGui")
    esp.Name = "ESP_" .. player.Name
    esp.AlwaysOnTop = true
    esp.Size = UDim2.new(0, 20, 0, 20)
    esp.StudsOffset = Vector3.new(0, 3, 0)
    esp.LightInfluence = 0
    
    local diamond = Instance.new("Frame")
    diamond.Name = "Diamond"
    diamond.BackgroundColor3 = _G.Avidbot_SilentAim.espcolor
    diamond.BorderSizePixel = 0
    diamond.Size = UDim2.new(0, 10, 0, 10)
    diamond.Position = UDim2.new(0.5, -5, 0.5, -5)
    diamond.Rotation = 45
    diamond.Parent = esp
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.new(0, 0, 0)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.3
    stroke.Parent = diamond
    
    local distLabel = Instance.new("TextLabel")
    distLabel.Name = "DistanceLabel"
    distLabel.BackgroundTransparency = 1
    distLabel.Size = UDim2.new(0, 60, 0, 16)
    distLabel.Position = UDim2.new(0.5, -30, 1, 2)
    distLabel.Font = Enum.Font.GothamBold
    distLabel.TextSize = 11
    distLabel.TextColor3 = Color3.new(1, 1, 1)
    distLabel.TextStrokeTransparency = 0.5
    distLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    distLabel.Text = ""
    distLabel.Parent = esp
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.BackgroundTransparency = 1
    nameLabel.Size = UDim2.new(0, 100, 0, 14)
    nameLabel.Position = UDim2.new(0.5, -50, 0, -16)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 10
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.TextStrokeTransparency = 0.5
    nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLabel.Text = player.Name
    nameLabel.Parent = esp
    
    espCache[player] = esp
    return esp
end

local function removeEsp(player)
    local e = espCache[player]
    if e then e:Destroy() espCache[player] = nil end
    if player and player.Character then
        randomPartCache[player.Character] = nil
    end
    if currentTarget == player then
        currentTarget = nil
    end
    if lastAutoTarget == player then
        lastAutoTarget = nil
    end
end

local function shouldShowEsp(player)
    if not player or player == LocalPlayer or not player.Character then return false end
    
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    local myChar = LocalPlayer.Character
    if not myChar then return false end
    local myHrp = myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return false end
    
    local distance = (hrp.Position - myHrp.Position).Magnitude
    local espMaxDistance = tonumber(_G.Avidbot_SilentAim.espmaxdist) or 0
    if espMaxDistance > 0 and distance > espMaxDistance then return false end
    
    local myTeam = LocalPlayer.Team
    local theirTeam = player.Team
    
    if theirTeam == myTeam then
        if not _G.Avidbot_SilentAim.espshowteam then return false end
        return true
    end
    
    if _G.Avidbot_SilentAim.espteamcheck then
        local imCrimOrInmate = (myTeam == criminalsTeam or myTeam == inmatesTeam)
        local theyCrimOrInmate = (theirTeam == criminalsTeam or theirTeam == inmatesTeam)
        if imCrimOrInmate and theyCrimOrInmate then return false end
    end
    
    if theirTeam == guardsTeam then return _G.Avidbot_SilentAim.esptargets.guards
    elseif theirTeam == inmatesTeam then return _G.Avidbot_SilentAim.esptargets.inmates
    elseif theirTeam == criminalsTeam then return _G.Avidbot_SilentAim.esptargets.criminals end
    
    return false
end

local function updateEsp()
    if not _G.Avidbot_SilentAim.esp or not visuals.container then
        for _, e in pairs(espCache) do e.Parent = nil end
        return
    end
    
    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    
    for _, player in ipairs(Players:GetPlayers()) do
        local show = shouldShowEsp(player)
        
        if show then
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local head = char and char:FindFirstChild("Head")
            
            if hrp and head then
                local esp = makeEsp(player)
                esp.Adornee = head
                esp.Parent = visuals.container
                
                local d = esp:FindFirstChild("Diamond")
                if d and _G.Avidbot_SilentAim.espuseteamcolors then
                    local t = player.Team
                    if t == LocalPlayer.Team then d.BackgroundColor3 = _G.Avidbot_SilentAim.espteam
                    elseif t == guardsTeam then d.BackgroundColor3 = _G.Avidbot_SilentAim.espguards
                    elseif t == inmatesTeam then d.BackgroundColor3 = _G.Avidbot_SilentAim.espinmates
                    elseif t == criminalsTeam then d.BackgroundColor3 = _G.Avidbot_SilentAim.espcriminals
                    else d.BackgroundColor3 = _G.Avidbot_SilentAim.espcolor end
                end
                
                if _G.Avidbot_SilentAim.espshowdist and myHrp then
                    local label = esp:FindFirstChild("DistanceLabel")
                    if label then
                        label.Text = math.floor((hrp.Position - myHrp.Position).Magnitude) .. "m"
                        label.Visible = true
                    end
                else
                    local label = esp:FindFirstChild("DistanceLabel")
                    if label then
                        label.Visible = false
                    end
                end
            end
        else
            local e = espCache[player]
            if e then e.Parent = nil end
        end
    end
end

local c4espCache = {}

local function makeC4Esp(c4Part)
    if c4espCache[c4Part] then return c4espCache[c4Part] end
    
    local esp = Instance.new("BillboardGui")
    esp.Name = "C4ESP_" .. tostring(c4Part)
    esp.AlwaysOnTop = true
    esp.Size = UDim2.new(0, 24, 0, 24)
    esp.StudsOffset = Vector3.new(0, 1, 0)
    esp.LightInfluence = 0
    
    local icon = Instance.new("Frame")
    icon.Name = "Icon"
    icon.BackgroundColor3 = _G.Avidbot_SilentAim.c4espcolor
    icon.BorderSizePixel = 0
    icon.Size = UDim2.new(0, 14, 0, 14)
    icon.Position = UDim2.new(0.5, -7, 0.5, -7)
    icon.Rotation = 45
    icon.Parent = esp
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.new(0, 0, 0)
    stroke.Thickness = 2
    stroke.Transparency = 0.2
    stroke.Parent = icon
    
    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(0, 60, 0, 14)
    label.Position = UDim2.new(0.5, -30, 1, 2)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 11
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0.5
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.Text = "C4"
    label.Parent = esp
    
    local distLabel = Instance.new("TextLabel")
    distLabel.Name = "DistLabel"
    distLabel.BackgroundTransparency = 1
    distLabel.Size = UDim2.new(0, 60, 0, 12)
    distLabel.Position = UDim2.new(0.5, -30, 1, 16)
    distLabel.Font = Enum.Font.GothamBold
    distLabel.TextSize = 10
    distLabel.TextColor3 = _G.Avidbot_SilentAim.c4espcolor
    distLabel.TextStrokeTransparency = 0.5
    distLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    distLabel.Text = ""
    distLabel.Parent = esp
    
    c4espCache[c4Part] = esp
    return esp
end

local trackedC4s = {}

local function isC4Part(part)
    if not part or not part:IsA("BasePart") then return false end
    local name = part.Name:lower()
    local parentName = part.Parent and part.Parent.Name:lower() or ""
    return name == "explosive" or name == "c4" or name == "clientc4" or 
        parentName:find("c4") or name:find("c4")
end

local function onDescendantAdded(desc)
    if isC4Part(desc) then
        trackedC4s[desc] = true
    end
end

local function onDescendantRemoving(desc)
    trackedC4s[desc] = nil
    if c4espCache[desc] then
        c4espCache[desc]:Destroy()
        c4espCache[desc] = nil
    end
end

for _, desc in ipairs(workspace:GetDescendants()) do
    if isC4Part(desc) then trackedC4s[desc] = true end
    trackGrabbable(desc)
end
workspace.DescendantAdded:Connect(onDescendantAdded)
workspace.DescendantRemoving:Connect(onDescendantRemoving)
workspace.DescendantAdded:Connect(trackGrabbable)
workspace.DescendantRemoving:Connect(untrackGrabbable)

local function updateC4Esp()
    if not _G.Avidbot_SilentAim.c4esp or not visuals.container then
        for _, e in pairs(c4espCache) do e.Parent = nil end
        return
    end
    
    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    
    for part in pairs(trackedC4s) do
        if part and part:IsDescendantOf(workspace) then
            local dist = 0
            if myHrp then
                dist = (part.Position - myHrp.Position).Magnitude
            end
            
            local c4MaxDistance = tonumber(_G.Avidbot_SilentAim.c4espmaxdist) or 0
            if c4MaxDistance <= 0 or dist <= c4MaxDistance then
                local esp = makeC4Esp(part)
                esp.Adornee = part
                esp.Parent = visuals.container
                
                if _G.Avidbot_SilentAim.c4espshowdist and myHrp then
                    local distLabel = esp:FindFirstChild("DistLabel")
                    if distLabel then
                        distLabel.Text = math.floor(dist) .. "m"
                    end
                else
                    local distLabel = esp:FindFirstChild("DistLabel")
                    if distLabel then
                        distLabel.Text = ""
                    end
                end
            else
                local e = c4espCache[part]
                if e then e.Parent = nil end
            end
        else
            trackedC4s[part] = nil
            if c4espCache[part] then
                c4espCache[part]:Destroy()
                c4espCache[part] = nil
            end
        end
    end
end

makeVisuals()


local partMap = {
    ["Torso"] = {"Torso"},
    ["LeftArm"] = {"Left Arm"},
    ["RightArm"] = {"Right Arm"},
    ["LeftLeg"] = {"Left Leg"},
    ["RightLeg"] = {"Right Leg"}
}

local function normalizePartName(name)
    return tostring(name or ""):gsub("%s+", "")
end

local function getPart(char, name)
    if not char then return nil end
    local p = char:FindFirstChild(name)
    if p then return p end
    
    local maps = partMap[normalizePartName(name)]
    if maps then
        for _, n in ipairs(maps) do
            local part = char:FindFirstChild(n)
            if part then return part end
        end
    end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
end

local function getTaserTargetPart(char)
    if not char then return nil end
    return char:FindFirstChild("Torso")
        or char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("Head")
end

local function getTargetPart(char)
    if not char then return nil end

    if isTaserGun(currentGun) then
        return getTaserTargetPart(char)
    end
    
    if _G.Avidbot_SilentAim.shieldbreaker then
        local shield = char:FindFirstChild("RiotShieldPart")
        if shield and shield:IsA("BasePart") then
            local hp = shield:GetAttribute("Health")
            if hp and hp > 0 then
                local myChar = LocalPlayer.Character
                local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                local theirHrp = char:FindFirstChild("HumanoidRootPart")
                
                if myHrp and theirHrp then
                    local toMe = (myHrp.Position - theirHrp.Position).Unit
                    local theirLook = theirHrp.CFrame.LookVector
                    local dot = toMe:Dot(theirLook)
                    
                    if dot > _G.Avidbot_SilentAim.shieldfrontangle then
                        if _G.Avidbot_SilentAim.shieldrandomhead and rng:NextInteger(1, 100) <= _G.Avidbot_SilentAim.shieldheadchance then
                            return getPart(char, "Head")
                        end
                        return shield
                    end
                end
            end
        end
    end
    
    local partName
    if _G.Avidbot_SilentAim.randomparts then
        local cached = randomPartCache[char]
        if cached and cached.part and cached.part.Parent == char and cached.expiresAt > os.clock() then
            return cached.part
        end
        
        local list = _G.Avidbot_SilentAim.partslist
        partName = (list and #list > 0) and list[rng:NextInteger(1, #list)] or "Head"
    else
        partName = _G.Avidbot_SilentAim.aimpart
    end
    
    local part = getPart(char, partName)
    if _G.Avidbot_SilentAim.randomparts and part then
        randomPartCache[char] = {
            part = part,
            partName = partName,
            expiresAt = os.clock() + 0.15
        }
    end
    return part
end

local function isDead(player)
    if not player or not player.Character then return true end
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    return not humanoid or humanoid.Health <= 0
end

local function isStanding(player)
    if not player or not player.Character then return false end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local vel = hrp.AssemblyLinearVelocity
    return Vector2.new(vel.X, vel.Z).Magnitude <= _G.Avidbot_SilentAim.stillthreshold
end

local function hasForceField(player)
    if not player or not player.Character then return false end
    return player.Character:FindFirstChildOfClass("ForceField") ~= nil
end

local function isInVehicle(player)
    if not player or not player.Character then return false end
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    return humanoid.SeatPart ~= nil
end

local function wallBetween(startPos, endPos, targetChar)
    local myChar = LocalPlayer.Character
    if not myChar then return true end
    
    local filter = {myChar}
    if targetChar then table.insert(filter, targetChar) end
    wallParams.FilterDescendantsInstances = filter
    
    local direction = endPos - startPos
    local distance = direction.Magnitude
    if distance <= 0.001 then return false end
    local unit = direction.Unit
    
    local currentStart = startPos
    local remaining = distance
    
    for _ = 1, 10 do
        local result = workspace:Raycast(currentStart, unit * remaining, wallParams)
        if not result then return false end
        
        local hit = result.Instance
        if hit.Transparency < 0.8 and hit.CanCollide then return true end
        
        local hitDist = (result.Position - currentStart).Magnitude
        remaining = remaining - hitDist - 0.01
        if remaining <= 0 then return false end
        
        currentStart = result.Position + unit * 0.01
    end
    return false
end

local function quickCheck(player)
    if not player or player == LocalPlayer or not player.Character then return false end
    local targetPart = getTargetPart(player.Character)
    if not targetPart then return false end
    if not isWithinAimDistance(targetPart.Position) then return false end
    if not isInCurrentGunRange(targetPart.Position) then return false end
    if _G.Avidbot_SilentAim.deathcheck and isDead(player) then return false end
    if _G.Avidbot_SilentAim.ffcheck and hasForceField(player) then return false end
    if _G.Avidbot_SilentAim.vehiclecheck and isInVehicle(player) then return false end
    if _G.Avidbot_SilentAim.teamcheck and player.Team == LocalPlayer.Team then return false end
    if _G.Avidbot_SilentAim.criminalsnoinnmates then
        if LocalPlayer.Team == criminalsTeam and player.Team == inmatesTeam then return false end
    end
    if _G.Avidbot_SilentAim.inmatesnocriminals then
        if LocalPlayer.Team == inmatesTeam and player.Team == criminalsTeam then return false end
    end
    
    if _G.Avidbot_SilentAim.hostilecheck or _G.Avidbot_SilentAim.trespasscheck then
        local isTaser = isTaserGun(currentGun)
        local bypassHostile = _G.Avidbot_SilentAim.taserbypasshostile and isTaser
        local bypassTrespass = _G.Avidbot_SilentAim.taserbypasstrespass and isTaser
        local targetChar = player.Character
        
        if LocalPlayer.Team == guardsTeam and player.Team == inmatesTeam then
            local hostile = targetChar:GetAttribute("Hostile")
            local trespass = targetChar:GetAttribute("Trespassing")
            
            if _G.Avidbot_SilentAim.hostilecheck and _G.Avidbot_SilentAim.trespasscheck then
                if not bypassHostile and not bypassTrespass then
                    if not hostile and not trespass then return false end
                end
            elseif _G.Avidbot_SilentAim.hostilecheck and not bypassHostile then
                if not hostile then return false end
            elseif _G.Avidbot_SilentAim.trespasscheck and not bypassTrespass then
                if not trespass then return false end
            end
        end
    end
    return true
end

local function fullCheck(player)
    if not quickCheck(player) then return false end
    
    if _G.Avidbot_SilentAim.wallcheck then
        local myChar = LocalPlayer.Character
        local myHead = myChar and myChar:FindFirstChild("Head")
        local targetPart = getTargetPart(player.Character)
        if myHead and targetPart then
            if wallBetween(myHead.Position, targetPart.Position, player.Character) then
                return false
            end
        end
    end
    return true
end

local function rollHit(chanceOverride)
    lastShotTime = os.clock()
    local chance = math.clamp(tonumber(chanceOverride) or tonumber(_G.Avidbot_SilentAim.hitchance) or 0, 0, 100)
    if chance >= 100 then
        lastShotResult = true
    elseif chance <= 0 then
        lastShotResult = false
    else
        lastShotResult = rng:NextInteger(1, 100) <= chance
    end
    return lastShotResult
end

local function getDistanceBasedHitChance(targetPart, originPos)
    local baseChance = math.clamp(tonumber(_G.Avidbot_SilentAim.hitchance) or 0, 0, 100)
    if not _G.Avidbot_SilentAim.distancebasedhitchance then
        return baseChance
    end
    if not targetPart then
        return baseChance
    end
    local origin = originPos or getFireOriginPosition()
    if not origin then
        local originPart = getLocalAimOriginPart()
        origin = originPart and originPart.Position or nil
    end
    if not origin then
        return baseChance
    end
    local distance = (targetPart.Position - origin).Magnitude
    local selectedChance = baseChance
    local points = {
        {distance = math.max(tonumber(_G.Avidbot_SilentAim.distancehitchance1dist) or 0, 0), chance = math.clamp(tonumber(_G.Avidbot_SilentAim.distancehitchance1value) or baseChance, 0, 100)},
        {distance = math.max(tonumber(_G.Avidbot_SilentAim.distancehitchance2dist) or 0, 0), chance = math.clamp(tonumber(_G.Avidbot_SilentAim.distancehitchance2value) or baseChance, 0, 100)},
        {distance = math.max(tonumber(_G.Avidbot_SilentAim.distancehitchance3dist) or 0, 0), chance = math.clamp(tonumber(_G.Avidbot_SilentAim.distancehitchance3value) or baseChance, 0, 100)},
        {distance = math.max(tonumber(_G.Avidbot_SilentAim.distancehitchance4dist) or 0, 0), chance = math.clamp(tonumber(_G.Avidbot_SilentAim.distancehitchance4value) or baseChance, 0, 100)},
        {distance = math.max(tonumber(_G.Avidbot_SilentAim.distancehitchance5dist) or 0, 0), chance = math.clamp(tonumber(_G.Avidbot_SilentAim.distancehitchance5value) or baseChance, 0, 100)}
    }
    table.sort(points, function(a, b)
        return a.distance < b.distance
    end)
    for _, point in ipairs(points) do
        if point.distance > 0 and distance >= point.distance then
            selectedChance = point.chance
        end
    end
    return selectedChance
end

local function getMissPos(startPos, targetPartOrPos)
    local targetPart = typeof(targetPartOrPos) == "Instance" and targetPartOrPos:IsA("BasePart") and targetPartOrPos or nil
    local targetPos = targetPart and targetPart.Position or targetPartOrPos
    if not targetPos then return startPos end
    
    local toTarget = targetPos - startPos
    if toTarget.Magnitude <= 0.001 then
        return targetPos + Vector3.new(_G.Avidbot_SilentAim.missspread + 6, 0, 0)
    end
    
    local direction = toTarget.Unit
    local reference = math.abs(direction.Y) > 0.98 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
    local right = direction:Cross(reference)
    if right.Magnitude <= 0.001 then
        right = Vector3.new(0, 0, 1)
    else
        right = right.Unit
    end
    
    local up = right:Cross(direction)
    if up.Magnitude <= 0.001 then
        up = Vector3.new(0, 1, 0)
    else
        up = up.Unit
    end
    
    local partRadius = targetPart and math.max(targetPart.Size.X, targetPart.Size.Y, targetPart.Size.Z) * 0.75 or 2
    local missRadius = math.max(_G.Avidbot_SilentAim.missspread, partRadius + 3)
    local angle = rng:NextNumber(0, math.pi * 2)
    local offset = right * math.cos(angle) * missRadius + up * math.sin(angle) * missRadius
    return targetPos + offset
end

local function getFovTargetPriority(player)
    if not _G.Avidbot_SilentAim.prioritizecriminals then
        return 0
    end
    if player.Team == criminalsTeam then
        return 0
    end
    if player.Team == inmatesTeam then
        return 1
    end
    return 0
end

local function getClosest(fovRadius)
    fovRadius = fovRadius or _G.Avidbot_SilentAim.fov
    local camera = workspace.CurrentCamera
    if not camera then return nil, nil end
    
    local aimPos = getFovScreenPosition(camera)
    
    local now = os.clock()
    
    if _G.Avidbot_SilentAim.targetstickiness and currentTarget and (now - targetSwitchTime) < currentStickiness then
        if fullCheck(currentTarget) then
            local part = getTargetPart(currentTarget.Character)
            if part then
                local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
                if onScreen and screenPos.Z > 0 then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - aimPos).Magnitude
                    if dist < fovRadius then
                        return currentTarget, part.Position
                    end
                end
            end
        end
    end
    
    local candidates = {}
    
    for _, player in ipairs(Players:GetPlayers()) do
        if quickCheck(player) then
            local part = getTargetPart(player.Character)
            if part then
                local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
                if onScreen and screenPos.Z > 0 then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - aimPos).Magnitude
                    if dist < fovRadius then
                        candidates[#candidates + 1] = {
                            player = player,
                            dist = dist,
                            part = part,
                            priority = getFovTargetPriority(player)
                        }
                    end
                end
            end
        end
    end
    
    if _G.Avidbot_SilentAim.prioritizeclosest then
        table.sort(candidates, function(a, b)
            if a.priority ~= b.priority then
                return a.priority < b.priority
            end
            return a.dist < b.dist
        end)
    else
        local bestPriority = math.huge
        for _, candidate in ipairs(candidates) do
            if candidate.priority < bestPriority then
                bestPriority = candidate.priority
            end
        end
        if bestPriority < math.huge then
            local prioritizedCandidates = {}
            for _, candidate in ipairs(candidates) do
                if candidate.priority == bestPriority then
                    prioritizedCandidates[#prioritizedCandidates + 1] = candidate
                end
            end
            candidates = prioritizedCandidates
        end
        for i = #candidates, 2, -1 do
            local j = rng:NextInteger(1, i)
            candidates[i], candidates[j] = candidates[j], candidates[i]
        end
    end
    
    for _, candidate in ipairs(candidates) do
        if fullCheck(candidate.player) then
            local part = getTargetPart(candidate.player.Character)
            if not part then
                continue
            end
            if candidate.player ~= currentTarget then
                currentTarget = candidate.player
                targetSwitchTime = now
                if _G.Avidbot_SilentAim.targetstickinessrandom then
                    currentStickiness = rng:NextNumber(_G.Avidbot_SilentAim.targetstickinessmin, _G.Avidbot_SilentAim.targetstickinessmax)
                else
                    currentStickiness = _G.Avidbot_SilentAim.targetstickinessduration
                end
            end
            return candidate.player, part.Position
        end
    end
    
    currentTarget = nil
    return nil, nil
end
local ShootEvent = ReplicatedStorage:WaitForChild("GunRemotes"):WaitForChild("ShootEvent")
local ReloadRemote = ReplicatedStorage:WaitForChild("GunRemotes"):WaitForChild("FuncReload")
local Debris = game:GetService("Debris")
local lastReloadRequest = 0

local function createBulletTrail(startPos, endPos, isTaser)
    local distance = (endPos - startPos).Magnitude
    local trail = Instance.new("Part")
    trail.Name = "BulletTrail"
    trail.Anchored = true
    trail.CanCollide = false
    trail.CanQuery = false
    trail.CanTouch = false
    trail.Material = Enum.Material.Neon
    trail.Size = Vector3.new(0.1, 0.1, distance)
    trail.CFrame = CFrame.new(startPos, endPos) * CFrame.new(0, 0, -distance / 2)
    trail.Transparency = 0.5
    
    if isTaser then
        trail.BrickColor = BrickColor.new("Cyan")
        trail.Size = Vector3.new(0.2, 0.2, distance)
        local light = Instance.new("SurfaceLight")
        light.Color = Color3.fromRGB(0, 234, 255)
        light.Range = 7
        light.Brightness = 5
        light.Face = Enum.NormalId.Bottom
        light.Parent = trail
    else
        trail.BrickColor = BrickColor.Yellow()
    end
    
    trail.Parent = workspace
    Debris:AddItem(trail, isTaser and 0.8 or 0.1)
end

local function getBulletsLabel()
    if cachedBulletsLabel and cachedBulletsLabel.Parent then
        return cachedBulletsLabel
    end
    
    cachedBulletsLabel = nil
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    local home = playerGui and playerGui:FindFirstChild("Home")
    local hud = home and home:FindFirstChild("hud")
    local bottomRight = hud and hud:FindFirstChild("BottomRightFrame")
    local gunFrame = bottomRight and bottomRight:FindFirstChild("GunFrame")
    cachedBulletsLabel = gunFrame and gunFrame:FindFirstChild("BulletsLabel") or nil
    return cachedBulletsLabel
end

local function requestReload(gun)
    local now = os.clock()
    if now - lastReloadRequest < 0.5 then
        return
    end
    if not gun or gun:GetAttribute("Local_ReloadSession") ~= 0 then
        return
    end
    local storedAmmo = gun:GetAttribute("StoredAmmo")
    if typeof(storedAmmo) == "number" and storedAmmo <= 0 then
        return
    end
    lastReloadRequest = now
    task.spawn(function()
        pcall(function()
            ReloadRemote:InvokeServer()
        end)
    end)
end

local function autoShoot()
    local gun = currentGun
    if not _G.Avidbot_SilentAim.autoshoot or not _G.Avidbot_SilentAim.enabled or not gun then return end
    if gun.Parent ~= LocalPlayer.Character then return end
    if not gunMatchesAutoShootWeapon(gun) then
        lastAutoTarget = nil
        return
    end
    
    local now = os.clock()
    local reloadSession = gun:GetAttribute("Local_ReloadSession") or 0
    if reloadSession ~= 0 or gun:GetAttribute("Local_IsShooting") then return end
    if not isSniperStable(gun) then return end
    
    local fireRate = math.max(gun:GetAttribute("FireRate") or 0, _G.Avidbot_SilentAim.autoshootdelay)
    if now - lastAutoShoot < fireRate then return end
    
    local myChar = LocalPlayer.Character
    if not myChar then return end
    local myHead = myChar:FindFirstChild("Head")
    if not myHead then return end
    
    local muzzle = gun:FindFirstChild("Muzzle")
    local startPos = muzzle and muzzle.Position or myHead.Position
    
    local target, targetPos = getClosest(_G.Avidbot_SilentAim.fov)
    if not target or not fullCheck(target) then 
        lastAutoTarget = nil
        return 
    end
    
    if target ~= lastAutoTarget then
        targetAcquiredTime = now
        lastAutoTarget = target
    end
    
    local acquireDelay = shouldUseInstantAcquireDelay(gun) and 0 or _G.Avidbot_SilentAim.autoshootstartdelay
    local requiredDelay = math.max(acquireDelay, gun:GetAttribute("ChargeTime") or 0)
    if now - targetAcquiredTime < requiredDelay then return end
    
    local targetPart = getTargetPart(target.Character)
    if not targetPart then return end
    
    local weaponRange = gun:GetAttribute("Range")
    if weaponRange and (targetPart.Position - startPos).Magnitude > weaponRange + 5 then
        return
    end
    
    local ammo = gun:GetAttribute("Local_CurrentAmmo") or gun:GetAttribute("CurrentAmmo") or 0
    if ammo <= 0 then
        requestReload(gun)
        return
    end
    
    lastAutoShoot = now
    
    local isTaser = isTaserGun(gun)
    local sniper = isSniper(gun)
    local shotgun = isShotgun(gun)
    local shouldHit = false
    
    if _G.Avidbot_SilentAim.taseralwayshit and isTaser then
        shouldHit = true
    elseif _G.Avidbot_SilentAim.ifplayerstill and isStanding(target) then
        shouldHit = true
    elseif shouldBypassHitchance(gun) then
        shouldHit = true
    else
        shouldHit = rollHit(getDistanceBasedHitChance(targetPart, startPos))
    end
    
    local projectileCount = gun:GetAttribute("ProjectileCount") or 1
    local shots = {}
    
    for i = 1, projectileCount do
        local aimPoint
        if shouldHit then
            aimPoint = targetPart.Position
        else
            if _G.Avidbot_SilentAim.missspread > 0 then
                aimPoint = getMissPos(startPos, targetPart)
            else
                return
            end
        end

        local hitPart = shouldHit and targetPart or nil
        local finalPos = aimPoint

        if shouldHit then
            if isTaser then
                local simulatedHit, simulatedPos = simulateProjectileImpact(startPos, aimPoint, gun)
                finalPos = simulatedPos
                hitPart = simulatedHit or targetPart
            elseif shotgun and _G.Avidbot_SilentAim.shotgunnaturalspread then
                local simulatedHit, simulatedPos = simulateProjectileImpact(startPos, aimPoint, gun)
                finalPos = simulatedPos
                hitPart = simulatedHit or targetPart
            end
        end

        shots[i] = {myHead.Position, finalPos, hitPart}
        createBulletTrail(startPos, finalPos, isTaser)
    end
    
    ShootEvent:FireServer(shots)
    if gun ~= currentGun or gun.Parent ~= LocalPlayer.Character then return end
    
    local newAmmo = ammo - 1
    gun:SetAttribute("Local_CurrentAmmo", newAmmo)
    
    local bulletsLabel = getBulletsLabel()
    if bulletsLabel then
        if sniper then
            bulletsLabel.Text = newAmmo .. " | " .. (gun:GetAttribute("StoredAmmo") or 0)
        else
            bulletsLabel.Text = newAmmo .. "/" .. (gun:GetAttribute("MaxAmmo") or 30)
        end
    end
    
    local handle = gun:FindFirstChild("Handle")
    if handle then
        local shootSound = handle:FindFirstChild("ShootSound")
        if shootSound then
            local sound = shootSound:Clone()
            sound.Parent = handle
            sound:Play()
            Debris:AddItem(sound, 2)
        end
    end
end

local function getGun()
    local char = LocalPlayer.Character
    if not char then return nil end
    local children = char:GetChildren()
    for index = #children, 1, -1 do
        local tool = children[index]
        if tool:IsA("Tool") and tool:GetAttribute("ToolType") == "Gun" then
            return tool
        end
    end
    return nil
end

local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 3
        })
    end)
end

local lastGun = nil

syncDistanceHitchanceAimMaxDistance()

RunService.Heartbeat:Connect(function()
    local now = os.clock()
    syncDistanceHitchanceAimMaxDistance()
    currentGun = getGun()
    if currentGun ~= lastGun then
        resetAimState()
        lastGun = currentGun
    end
    updateAutoGrab(now)
    autoShoot()
end)

RunService.PreRender:Connect(function()
    local camera = workspace.CurrentCamera
    local fovPos = getFovScreenPosition(camera)
    
    fovCircle.Position = fovPos
    fovCircle.Radius = _G.Avidbot_SilentAim.fov
    fovCircle.Visible = _G.Avidbot_SilentAim.showfov and _G.Avidbot_SilentAim.enabled
    
    if _G.Avidbot_SilentAim.showtargetline and _G.Avidbot_SilentAim.enabled then
        local target, targetPos = getClosest()
        if target and targetPos and camera then
            local screenPos, onScreen = camera:WorldToViewportPoint(targetPos)
            if onScreen then
                targetLine.From = fovPos
                targetLine.To = Vector2.new(screenPos.X, screenPos.Y)
                targetLine.Visible = true
            else
                targetLine.Visible = false
            end
        else
            targetLine.Visible = false
        end
    else
        targetLine.Visible = false
    end
    
    updateEsp()
    updateC4Esp()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == _G.Avidbot_SilentAim.togglekey then
        _G.Avidbot_SilentAim.enabled = not _G.Avidbot_SilentAim.enabled
        notify("Silent Aim", "Enabled: " .. tostring(_G.Avidbot_SilentAim.enabled), 3)
    elseif input.KeyCode == _G.Avidbot_SilentAim.esptoggle then
        _G.Avidbot_SilentAim.esp = not _G.Avidbot_SilentAim.esp
        notify("ESP", "Enabled: " .. tostring(_G.Avidbot_SilentAim.esp), 3)
    elseif input.KeyCode == _G.Avidbot_SilentAim.c4esptoggle then
        _G.Avidbot_SilentAim.c4esp = not _G.Avidbot_SilentAim.c4esp
        notify("C4 ESP", "Enabled: " .. tostring(_G.Avidbot_SilentAim.c4esp), 3)
    end
end)

Players.PlayerRemoving:Connect(removeEsp)

local function bindPlayer(player)
    player.CharacterRemoving:Connect(function(char)
        randomPartCache[char] = nil
        if currentTarget and currentTarget == player then
            currentTarget = nil
        end
        if lastAutoTarget and lastAutoTarget == player then
            lastAutoTarget = nil
        end
    end)
end

for _, player in ipairs(Players:GetPlayers()) do
    bindPlayer(player)
end
Players.PlayerAdded:Connect(bindPlayer)

local function clearEsp()
    for player, e in pairs(espCache) do
        if e then e:Destroy() end
        espCache[player] = nil
    end
    randomPartCache = {}
    currentTarget = nil
end

LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function()
    resetAimState()
    clearEsp()
end)

local function noUpvals(fn)
    return function(...) return fn(...) end
end

local origCastRay
local hooked = false

local function setupHook()
    local castRayFunc = filtergc("function", {Name = "castRay"}, true)
    if not castRayFunc then return false end
    
    origCastRay = hookfunction(castRayFunc, noUpvals(function(startPos, targetPos, ...)
        if not _G.Avidbot_SilentAim.enabled then return origCastRay(startPos, targetPos, ...) end
        
        local closest = getClosest(_G.Avidbot_SilentAim.fov)
        
        if closest and closest.Character then
            local gun = currentGun
            if not gun then
                return origCastRay(startPos, targetPos, ...)
            end
            local isTaser = isTaserGun(gun)
            local shotgun = isShotgun(gun)
            local sniperStable = isSniperStable(gun)
            local shouldHit = false
            local bypassHitchance = shouldBypassHitchance(gun)
            local targetPart = getTargetPart(closest.Character)
            
            if not targetPart then
                return origCastRay(startPos, targetPos, ...)
            end
            
            if not isInCurrentGunRange(targetPart.Position, startPos) then
                return origCastRay(startPos, targetPos, ...)
            end
            
            if _G.Avidbot_SilentAim.shotgungamehandled and shotgun then
                return origCastRay(startPos, targetPart.Position, ...)
            end
            
            if _G.Avidbot_SilentAim.taseralwayshit and isTaser then
                shouldHit = true
            elseif _G.Avidbot_SilentAim.ifplayerstill and isStanding(closest) then
                shouldHit = true
            elseif bypassHitchance then
                shouldHit = true
            else
                shouldHit = rollHit(getDistanceBasedHitChance(targetPart, startPos))
            end
            
            if shouldHit then
                if isSniper(gun) and not sniperStable then
                    return origCastRay(startPos, targetPart.Position, ...)
                end
                if isTaser then
                    return origCastRay(startPos, targetPart.Position, ...)
                end
                if _G.Avidbot_SilentAim.shotgunnaturalspread and shotgun then
                    return origCastRay(startPos, targetPart.Position, ...)
                end
                return targetPart, targetPart.Position
            else
                if _G.Avidbot_SilentAim.missspread > 0 then
                    local missPos = getMissPos(startPos, targetPart)
                    return origCastRay(startPos, missPos, ...)
                end
                return origCastRay(startPos, targetPos, ...)
            end
        end
        
        return origCastRay(startPos, targetPos, ...)
    end))
    return true
end

if not setupHook() then
    task.spawn(function()
        while not hooked do
            task.wait(0.5)
            if setupHook() then
                hooked = true
            end
        end
    end)
else
    hooked = true
end

notify("Silent Aim + ESP", "Loaded! RShift = Aim, RCtrl = ESP", 5)


local Window = Library:Window({
    Name = "Avidbot",
    Size = UDim2.new(0, 563, 0, 558),
    Resizeable = true,
    MinimumSize = Vector2.new(450, 400)
})

local RageTab = Window:Page({ Name = "Rage", Columns = 2 })
local LegitTab = Window:Page({ Name = "Legit", Columns = 2 })
local VisualsTab = Window:Page({ Name = "Visuals", Columns = 2 })
local MiscTab = Window:Page({ Name = "Misc", Columns = 2 })

-- ========================================================================
-- RAGE TAB
-- ========================================================================
local RageAimbot = RageTab:Section({ Name = "Aimbot", Side = 1 })
RageAimbot:Toggle({ Name = "Enabled", Flag = "Rage_AimbotEnabled", Default = false, Callback = function(State) end })
RageAimbot:Toggle({ Name = "Silent Aim", Flag = "Rage_SilentAim", Default = false, Callback = function(State) end })

local RageWeapon = RageTab:Section({ Name = "Weapon", Side = 2 })
RageWeapon:Toggle({ Name = "No Recoil", Flag = "Rage_NoRecoil", Default = false, Callback = function(State) end })
RageWeapon:Toggle({ Name = "No Spread", Flag = "Rage_NoSpread", Default = false, Callback = function(State) end })


-- ========================================================================
-- LEGIT TAB
-- ========================================================================
local LegitAimbot = LegitTab:Section({ Name = "Aimbot", Side = 1 })
local LegitAimToggle = LegitAimbot:Toggle({ Name = "Enabled", Flag = "Legit_AimbotEnabled", Default = false, Callback = function(State)
    _G.Avidbot_SilentAim.enabled = State
end })
LegitAimToggle:Keybind({ Name = "Aim Key", Flag = "Legit_AimKey", Mode = "Hold", Default = Enum.UserInputType.MouseButton2, Callback = function(State) end })
LegitAimbot:Slider({ Name = "Smoothing", Flag = "Legit_Smooth", Min = 1, Max = 10, Default = 5, Decimals = 1, Callback = function(Value) end })

LegitAimbot:Slider({ Name = "Hit Chance", Flag = "Legit_HitChance", Min = 0, Max = 100, Default = 65, Decimals = 0, Callback = function(Value)
    _G.Avidbot_SilentAim.hitchance = Value
end })

LegitAimbot:Slider({ Name = "Miss Spread", Flag = "Legit_MissSpread", Min = 0, Max = 20, Default = 5, Decimals = 0, Callback = function(Value)
    _G.Avidbot_SilentAim.missspread = Value
end })

LegitAimbot:Toggle({ Name = "Auto Shoot", Flag = "Legit_AutoShoot", Default = false, Callback = function(State)
    _G.Avidbot_SilentAim.autoshoot = State
end })

local LegitTriggerbot = LegitTab:Section({ Name = "Triggerbot", Side = 2 })
local TriggerToggle = LegitTriggerbot:Toggle({ Name = "Enabled", Flag = "Legit_TriggerbotEnabled", Default = false, Callback = function(State) end })


-- ========================================================================
-- VISUALS TAB
-- ========================================================================
local ESPSection = VisualsTab:Section({ Name = "ESP", Side = 1 })
ESPSection:Toggle({ Name = "Enabled", Flag = "ESP_Enabled", Default = false, Callback = function(State)
    _G.Avidbot_SilentAim.esp = State
end })
ESPSection:Toggle({ Name = "Boxes", Flag = "ESP_Boxes", Default = false, Callback = function(State) end }):Colorpicker({ Name = "Box Color", Flag = "ESP_BoxColor", Default = Color3.fromRGB(255, 255, 255), Callback = function(Color, Alpha) end })
ESPSection:Toggle({ Name = "Names", Flag = "ESP_Names", Default = false, Callback = function(State) end })
ESPSection:Toggle({ Name = "C4 & Grabbables ESP", Flag = "ESP_Items", Default = false, Callback = function(State)
    _G.Avidbot_SilentAim.c4esp = State
end })

local ChamsSection = VisualsTab:Section({ Name = "Chams", Side = 1 })
local ChamsToggle = ChamsSection:Toggle({ Name = "Chams Enabled", Flag = "Chams_Enabled", Default = false, Callback = function(State) end })
ChamsSection:Dropdown({ Name = "Material", Flag = "Chams_Material", Items = {"Plastic", "ForceField", "Neon", "Glass", "Metal", "Ice"}, Default = "ForceField", Multi = false, Callback = function() end })
ChamsToggle:Colorpicker({ Name = "Visible Color", Flag = "Chams_VisibleColor", Default = Color3.fromRGB(0, 255, 0), Callback = function() end })
ChamsToggle:Colorpicker({ Name = "Hidden Color", Flag = "Chams_HiddenColor", Default = Color3.fromRGB(255, 0, 0), Callback = function() end })

local ViewmodelSection = VisualsTab:Section({ Name = "Viewmodel", Side = 2 })
ViewmodelSection:Slider({ Name = "Field of View", Flag = "Visuals_FOV", Min = 70, Max = 120, Default = 90, Decimals = 0, Callback = function(Value)
    _G.Avidbot_SilentAim.fov = Value
end })
ViewmodelSection:Toggle({ Name = "Show FOV Circle", Flag = "Visuals_ShowFOV", Default = false, Callback = function(State)
    _G.Avidbot_SilentAim.showfov = State
end })


-- ========================================================================
-- MISC TAB
-- ========================================================================
local MovementSection = MiscTab:Section({ Name = "Movement", Side = 1 })
MovementSection:Slider({ Name = "WalkSpeed", Flag = "Misc_WalkSpeed", Min = 16, Max = 150, Default = 16, Decimals = 0, Suffix = " WS", Callback = function(Value) end })
MovementSection:Slider({ Name = "JumpPower", Flag = "Misc_JumpPower", Min = 50, Max = 200, Default = 50, Decimals = 0, Suffix = " JP", Callback = function(Value) end })

local ServerSection = MiscTab:Section({ Name = "Server", Side = 2 })
ServerSection:Button({ Name = "Rejoin", Callback = function() end })

-- ========================================================================
-- SETTINGS TAB
-- ========================================================================
local SettingsTab = Window:Page({ Name = "Settings", Columns = 2 })
local ConfigSection = SettingsTab:Section({ Name = "Configuration", Side = 1 })

local ConfigName = ConfigSection:Textbox({ Name = "Config Name", Flag = "ConfigName", Placeholder = "Enter name...", Callback = function(Value) end })
local ConfigListbox = ConfigSection:Listbox({ Name = "Available Configs", Flag = "ConfigList", Items = {}, Size = 5, Callback = function(Option) end })

ConfigSection:Button({
    Name = "Save Config",
    Callback = function()
        local name = Library.Flags["ConfigName"]
        if name and name ~= "" then
            Library:SaveConfig(name)
            Library:RefreshConfigsList(ConfigListbox)
        else
            Library:Notification("Please enter a config name!", 3, Color3.fromRGB(255, 0, 0))
        end
    end
})

ConfigSection:Button({
    Name = "Load Config",
    Callback = function()
        local name = Library.Flags["ConfigName"]
        if name == "" or name == nil then
            name = Library.Flags["ConfigList"]
            if type(name) == "table" then name = name[1] end
        end
        if name and name ~= "" then
            Library:LoadConfig(name)
        else
            Library:Notification("Please select or enter a config!", 3, Color3.fromRGB(255, 0, 0))
        end
    end
})

ConfigSection:Button({
    Name = "Delete Config",
    Callback = function()
        local name = Library.Flags["ConfigName"]
        if name == "" or name == nil then
            name = Library.Flags["ConfigList"]
            if type(name) == "table" then name = name[1] end
        end
        if name and name ~= "" then
            Library:DeleteConfig(name)
            Library:RefreshConfigsList(ConfigListbox)
        end
    end
})

ConfigSection:Button({
    Name = "Refresh Configs",
    Callback = function()
        Library:RefreshConfigsList(ConfigListbox)
    end
})

Library:RefreshConfigsList(ConfigListbox)

-- UI Settings
local MenuSection = SettingsTab:Section({ Name = "Menu", Side = 2 })
local MenuToggle = MenuSection:Toggle({ Name = "Menu Keybind", Flag = "MenuToggle_Dummy", Default = false })
MenuToggle:Keybind({ Name = "Toggle Menu", Flag = "MenuToggle", Mode = "Toggle", Default = Enum.KeyCode.Insert, Callback = function(State)
    Library.Window.Instance.Enabled = State
end })

Library:Watermark("Avidbot | v1.0")
Library:Notification("Successfully loaded Avidbot!", 5, Color3.fromRGB(150, 150, 255))
Library:KeybindList()

-- ========================================================================
-- CHAMS LOGIC
-- ========================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local success = pcall(function() 
    if CoreGui:FindFirstChild("Avidbot_ChamsGui") then
        CoreGui:FindFirstChild("Avidbot_ChamsGui"):Destroy()
    end
end)
if LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("Avidbot_ChamsGui") then
    LocalPlayer.PlayerGui.Avidbot_ChamsGui:Destroy()
end

local ChamsGui = Instance.new("ScreenGui")
ChamsGui.Name = "Avidbot_ChamsGui"
ChamsGui.IgnoreGuiInset = true
local success = pcall(function() ChamsGui.Parent = CoreGui end)
if not success then ChamsGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local Viewport = Instance.new("ViewportFrame")
Viewport.Size = UDim2.new(1, 0, 1, 0)
Viewport.BackgroundTransparency = 1
Viewport.CurrentCamera = Camera
Viewport.Parent = ChamsGui

local ChamsFolder = Instance.new("Folder")
ChamsFolder.Name = "Avidbot_Chams"
ChamsFolder.Parent = Viewport

local Adornments = {}

local function GetAdornment(player, part)
    if not Adornments[player] then Adornments[player] = {} end
    if not Adornments[player][part] then
        -- Clone the part to keep Meshes (Accessories, Hair, Custom Limbs)
        local box = part:Clone()
        
        -- Clean up the clone
        for _, child in pairs(box:GetChildren()) do
            if child:IsA("SpecialMesh") then
                child.TextureId = "" -- Remove texture to show color/material
            else
                child:Destroy() -- Remove scripts, welds, decals, etc.
            end
        end
        
        if box:IsA("MeshPart") then
            box.TextureID = ""
        end
        
        box.Name = part.Name
        box.Anchored = true
        box.CanCollide = false
        box.Massless = true
        box.CastShadow = false
        -- Remove any built-in size offset we had for generic parts
        box.Size = part.Size
        box.Parent = ChamsFolder
        Adornments[player][part] = box
    end
    return Adornments[player][part]
end

local function ClearAdornments(player)
    if Adornments[player] then
        for part, box in pairs(Adornments[player]) do
            box:Destroy()
        end
        Adornments[player] = nil
    end
end

RunService.RenderStepped:Connect(function()
    local enabled = Library.Flags["Chams_Enabled"]
    
    local visFlag = Library.Flags["Chams_VisibleColor"]
    local visColor = type(visFlag) == "table" and visFlag.Color or visFlag or Color3.fromRGB(0, 255, 0)
    local visAlpha = type(visFlag) == "table" and visFlag.Alpha or 0
    
    local hidFlag = Library.Flags["Chams_HiddenColor"]
    local hidColor = type(hidFlag) == "table" and hidFlag.Color or hidFlag or Color3.fromRGB(255, 0, 0)
    local hidAlpha = type(hidFlag) == "table" and hidFlag.Alpha or 0

    local materialType = Library.Flags["Chams_Material"] or "ForceField"
    
    local materialEnum = Enum.Material.ForceField
    pcall(function() materialEnum = Enum.Material[materialType] end)

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = player.Character
            if enabled and character and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0 then
                local myChar = LocalPlayer.Character
                local rayParams = RaycastParams.new()
                rayParams.FilterType = Enum.RaycastFilterType.Exclude
                
                local filterList = {character, Camera, ChamsFolder}
                if myChar then table.insert(filterList, myChar) end
                rayParams.FilterDescendantsInstances = filterList

                for _, part in pairs(character:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency < 1 then
                        local box = GetAdornment(player, part)
                        box.CFrame = part.CFrame
                        box.Material = materialEnum

                        local origin = Camera.CFrame.Position
                        local direction = (part.Position - origin)
                        local rayResult = workspace:Raycast(origin, direction, rayParams)

                        if rayResult then
                            box.Color = hidColor
                            box.Transparency = hidAlpha
                        else
                            box.Color = visColor
                            box.Transparency = visAlpha
                        end
                    end
                end
                
                -- Clean up destroyed parts
                for part, box in pairs(Adornments[player]) do
                    if not part.Parent then
                        box:Destroy()
                        Adornments[player][part] = nil
                    end
                end
            else
                ClearAdornments(player)
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    ClearAdornments(player)
end)
