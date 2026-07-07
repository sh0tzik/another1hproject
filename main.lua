local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/sh0tzik/another1hproject/main/Avidbot.lua?t=" .. tostring(tick())))()

local Window = Library:Window({
    Name = "Avidbot",
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
        Library:Notification("Hello from Avidbot!", 3, Color3.fromRGB(255, 105, 180))
    end
})

local PlayersTab = Window:Page({
    Name = "Players",
    Columns = 1
})

-- PlayerList must be on a page with 1 column
PlayersTab:PlayerList()
local SettingsTab = Window:Page({
    Name = "Settings",
    Columns = 2
})

local ConfigSection = SettingsTab:Section({
    Name = "Configuration",
    Side = 1
})

local ConfigName = ConfigSection:Textbox({
    Name = "Config Name",
    Flag = "ConfigName",
    Placeholder = "Enter name...",
    Callback = function(Value) end
})

local ConfigListbox = ConfigSection:Listbox({
    Name = "Available Configs",
    Flag = "ConfigList",
    Items = {},
    Size = 5,
    Callback = function(Option) end
})

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
            if type(name) == "table" then name = name[1] end -- If multi-select is off, it might be a string or table depending on implementation
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

-- Initial load
Library:RefreshConfigsList(ConfigListbox)

Library:Watermark("Avidbot | v1.0")

-- Library:Notification(Text, Duration, Color, {IconId, IconColor})
Library:Notification("Successfully loaded Avidbot!", 5, Color3.fromRGB(255, 105, 180))

Library:KeybindList()
