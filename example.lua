local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/sh0tzik/another1hproject/main/supremacy.lua?t=" .. tostring(tick())))()

local Window = Library:Window({
    Name = "Supremacy Example",
    Size = UDim2.new(0, 563, 0, 558),
    Resizeable = true, -- Управляет тем, можно ли растягивать окно за правый нижний угол
    MinimumSize = Vector2.new(450, 400) -- Минимальный размер окна
})

local MainTab = Window:Page({
    Name = "Combat",
    Columns = 2
})

local MainSection = MainTab:Section({
    Name = "Aimbot",
    Side = 1
})

local AimbotToggle = MainSection:Toggle({
    Name = "Enable Aimbot",
    Flag = "AimbotEnabled",
    Default = false,
    Callback = function(State)
        print("Aimbot is now:", State)
    end
})

AimbotToggle:Keybind({
    Name = "Aimbot Keybind",
    Flag = "AimbotKeybind",
    Mode = "Toggle",
    Default = Enum.KeyCode.E,
    Callback = function(State)
        print("Aimbot Key pressed")
    end
})

AimbotToggle:Colorpicker({
    Name = "FOV Circle Color",
    Flag = "FOVColor",
    Default = Color3.fromRGB(255, 105, 180),
    Callback = function(Color, Alpha)
        print("FOV Color changed:", Color)
    end
})

local Dropdown = MainSection:Dropdown({
    Name = "Target Part",
    Flag = "TargetPart",
    Items = {"Head", "HumanoidRootPart", "Torso"},
    Default = "Head",
    MaxSize = 75,
    Multi = false,
    Callback = function(Value)
        print("Target part selected:", Value)
    end
})

local MiscSection = MainTab:Section({
    Name = "Character",
    Side = 2
})

MiscSection:Slider({
    Name = "WalkSpeed",
    Flag = "WalkSpeedSlider",
    Min = 16,
    Max = 120,
    Default = 16,
    Decimals = 0,
    Suffix = " WS",
    Callback = function(Value)
        print("WalkSpeed:", Value)
    end
})

MiscSection:Button({
    Name = "Print Hello",
    Risky = false,
    Callback = function()
        Library:Notification("Hello from Supremacy!", 3, Color3.fromRGB(255, 105, 180))
    end
})

local PlayersTab = Window:Page({
    Name = "Players",
    Columns = 1
})

-- PlayerList must be on a page with 1 column
PlayersTab:PlayerList()

Library:Watermark("Supremacy Example | v1.0")

-- Library:Notification(Text, Duration, Color, {IconId, IconColor})
Library:Notification("Successfully loaded Supremacy Example!", 5, Color3.fromRGB(255, 105, 180))

Library:KeybindList()
