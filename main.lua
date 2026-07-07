local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/sh0tzik/another1hproject/main/supremacy.lua?t=" .. tostring(tick())))()

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
local LegitAimToggle = LegitAimbot:Toggle({ Name = "Enabled", Flag = "Legit_AimbotEnabled", Default = false, Callback = function(State) end })
LegitAimToggle:Keybind({ Name = "Aim Key", Flag = "Legit_AimKey", Mode = "Hold", Default = Enum.UserInputType.MouseButton2, Callback = function(State) end })
LegitAimbot:Slider({ Name = "Smoothing", Flag = "Legit_Smooth", Min = 1, Max = 10, Default = 5, Decimals = 1, Callback = function(Value) end })

local LegitTriggerbot = LegitTab:Section({ Name = "Triggerbot", Side = 2 })
local TriggerToggle = LegitTriggerbot:Toggle({ Name = "Enabled", Flag = "Legit_TriggerbotEnabled", Default = false, Callback = function(State) end })


-- ========================================================================
-- VISUALS TAB
-- ========================================================================
local ESPSection = VisualsTab:Section({ Name = "ESP", Side = 1 })
ESPSection:Toggle({ Name = "Enabled", Flag = "ESP_Enabled", Default = false, Callback = function(State) end })
ESPSection:Toggle({ Name = "Boxes", Flag = "ESP_Boxes", Default = false, Callback = function(State) end }):Colorpicker({ Name = "Box Color", Flag = "ESP_BoxColor", Default = Color3.fromRGB(255, 255, 255), Callback = function(Color, Alpha) end })
ESPSection:Toggle({ Name = "Names", Flag = "ESP_Names", Default = false, Callback = function(State) end })

local ChamsSection = VisualsTab:Section({ Name = "Chams", Side = 1 })
ChamsSection:Toggle({ Name = "Chams Enabled", Flag = "Chams_Enabled", Default = false, Callback = function(State) end })
ChamsSection:Dropdown({ Name = "Material", Flag = "Chams_Material", Items = {"Plastic", "ForceField", "Neon", "Glass", "Metal", "Ice"}, Default = "ForceField", Multi = false, Callback = function() end })
ChamsSection:Colorpicker({ Name = "Visible Color", Flag = "Chams_VisibleColor", Default = Color3.fromRGB(0, 255, 0), Callback = function() end })
ChamsSection:Colorpicker({ Name = "Hidden Color", Flag = "Chams_HiddenColor", Default = Color3.fromRGB(255, 0, 0), Callback = function() end })
ChamsSection:Slider({ Name = "Transparency", Flag = "Chams_Transparency", Min = 0, Max = 100, Default = 50, Decimals = 0, Suffix = "%", Callback = function() end })

local ViewmodelSection = VisualsTab:Section({ Name = "Viewmodel", Side = 2 })
ViewmodelSection:Slider({ Name = "Field of View", Flag = "Visuals_FOV", Min = 70, Max = 120, Default = 90, Decimals = 0, Callback = function(Value) end })


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
MenuToggle:Keybind({ Name = "Toggle Menu", Flag = "MenuToggle", Mode = "Toggle", Default = Enum.KeyCode.RightShift, Callback = function(State) end })

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

local ChamsFolder = Instance.new("Folder")
ChamsFolder.Name = "Avidbot_Chams"
local success = pcall(function() ChamsFolder.Parent = CoreGui end)
if not success then ChamsFolder.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local Adornments = {}

local function GetAdornment(player, part)
    if not Adornments[player] then Adornments[player] = {} end
    if not Adornments[player][part] then
        local box = Instance.new("Part")
        box.Name = part.Name
        box.Anchored = true
        box.CanCollide = false
        box.Massless = true
        box.CastShadow = false
        box.Size = part.Size + Vector3.new(0.05, 0.05, 0.05)
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
    local visColor = Library.Flags["Chams_VisibleColor"] or Color3.fromRGB(0, 255, 0)
    local hidColor = Library.Flags["Chams_HiddenColor"] or Color3.fromRGB(255, 0, 0)
    local transparency = (Library.Flags["Chams_Transparency"] or 50) / 100
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
                rayParams.FilterDescendantsInstances = {myChar, character, Camera, ChamsFolder}

                for _, part in pairs(character:GetChildren()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        local box = GetAdornment(player, part)
                        box.Size = part.Size + Vector3.new(0.02, 0.02, 0.02)
                        box.CFrame = part.CFrame
                        box.Transparency = transparency
                        box.Material = materialEnum

                        local origin = Camera.CFrame.Position
                        local direction = (part.Position - origin)
                        local rayResult = workspace:Raycast(origin, direction, rayParams)

                        if rayResult then
                            box.Color = hidColor
                        else
                            box.Color = visColor
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
