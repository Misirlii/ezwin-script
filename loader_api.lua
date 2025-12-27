--[[
    EZWIN LOADER v4.0 - API VERSION
    Otomatik HWID Kilitleme + Backend API
    Her key sadece 1 cihazda çalışır!
]]--

-- API URL
local API_URL = "https://ezwin-api.vercel.app"
-- GitHub'daki script URL'si (GitHub kullanıcı adını değiştir!)
local SCRIPT_URL = "https://raw.githubusercontent.com/Misirlii/ezwin-script/main/ezwin.lua"

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

-- HWID Oluştur
local function GetHWID()
    local hwid = ""
    pcall(function()
        hwid = tostring(game:GetService("RbxAnalyticsService"):GetClientId())
    end)
    if hwid == "" or hwid == "nil" then
        hwid = tostring(LocalPlayer.UserId) .. "-" .. tostring(game.PlaceId)
    end
    return hwid
end

local PLAYER_HWID = GetHWID()

-- HTTP POST isteği
local function HttpPost(url, data)
    local success, result = pcall(function()
        local req = (syn and syn.request) or (http and http.request) or http_request or request
        if req then
            local response = req({
                Url = url,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode(data)
            })
            return HttpService:JSONDecode(response.Body)
        end
    end)
    return success and result or nil
end

-- HTTP GET isteği
local function HttpGet(url)
    local success, result = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(url))
    end)
    return success and result or nil
end

-- Ana Loader
local function StartLoader()
    -- Config çek
    local config = HttpGet(API_URL .. "/config")
    if not config then
        warn("[EZWIN] API baglanti hatasi!")
        return
    end
    
    -- Bakım modu kontrolü
    if config.maintenance then
        local G = Instance.new("ScreenGui", CoreGui)
        G.Name = "EZWIN_Maint"
        local F = Instance.new("Frame", G)
        F.Size = UDim2.new(0, 400, 0, 180)
        F.Position = UDim2.new(0.5, -200, 0.5, -90)
        F.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        Instance.new("UICorner", F).CornerRadius = UDim.new(0, 12)
        Instance.new("UIStroke", F).Color = Color3.fromRGB(255, 100, 100)
        
        local T = Instance.new("TextLabel", F)
        T.Size = UDim2.new(1, 0, 0, 50)
        T.Position = UDim2.new(0, 0, 0, 30)
        T.BackgroundTransparency = 1
        T.Text = "🔧 BAKIM MODU"
        T.TextColor3 = Color3.fromRGB(255, 100, 100)
        T.Font = Enum.Font.GothamBlack
        T.TextSize = 24
        
        local M = Instance.new("TextLabel", F)
        M.Size = UDim2.new(1, -40, 0, 60)
        M.Position = UDim2.new(0, 20, 0, 90)
        M.BackgroundTransparency = 1
        M.Text = config.maintenance_message or "Sistem bakimda."
        M.TextColor3 = Color3.fromRGB(200, 200, 220)
        M.Font = Enum.Font.Gotham
        M.TextSize = 14
        M.TextWrapped = true
        return
    end
    
    -- Key UI
    local KeyGui = Instance.new("ScreenGui", CoreGui)
    KeyGui.Name = "EZWIN_Key"
    
    local Blur = Instance.new("Frame", KeyGui)
    Blur.Size = UDim2.new(1, 0, 1, 0)
    Blur.BackgroundColor3 = Color3.new(0, 0, 0)
    Blur.BackgroundTransparency = 0.4
    
    local Main = Instance.new("Frame", KeyGui)
    Main.Size = UDim2.new(0, 400, 0, 320)
    Main.Position = UDim2.new(0.5, -200, 0.5, -160)
    Main.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
    Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)
    Instance.new("UIStroke", Main).Color = Color3.fromRGB(100, 150, 255)
    
    local Title = Instance.new("TextLabel", Main)
    Title.Size = UDim2.new(1, 0, 0, 45)
    Title.BackgroundTransparency = 1
    Title.Text = "🔑 EZWIN KEY SYSTEM"
    Title.TextColor3 = Color3.new(1, 1, 1)
    Title.Font = Enum.Font.GothamBlack
    Title.TextSize = 20
    
    local Sub = Instance.new("TextLabel", Main)
    Sub.Size = UDim2.new(1, 0, 0, 18)
    Sub.Position = UDim2.new(0, 0, 0, 42)
    Sub.BackgroundTransparency = 1
    Sub.Text = "Her key tek cihaza kilitlenir"
    Sub.TextColor3 = Color3.fromRGB(150, 150, 180)
    Sub.Font = Enum.Font.Gotham
    Sub.TextSize = 11
    
    local InputFrame = Instance.new("Frame", Main)
    InputFrame.Size = UDim2.new(0, 340, 0, 42)
    InputFrame.Position = UDim2.new(0.5, -170, 0, 75)
    InputFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
    Instance.new("UICorner", InputFrame).CornerRadius = UDim.new(0, 8)
    
    local KeyInput = Instance.new("TextBox", InputFrame)
    KeyInput.Size = UDim2.new(1, -16, 1, 0)
    KeyInput.Position = UDim2.new(0, 8, 0, 0)
    KeyInput.BackgroundTransparency = 1
    KeyInput.Text = ""
    KeyInput.PlaceholderText = "Key'inizi girin..."
    KeyInput.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
    KeyInput.TextColor3 = Color3.new(1, 1, 1)
    KeyInput.Font = Enum.Font.GothamSemibold
    KeyInput.TextSize = 14
    
    local Status = Instance.new("TextLabel", Main)
    Status.Size = UDim2.new(1, 0, 0, 22)
    Status.Position = UDim2.new(0, 0, 0, 125)
    Status.BackgroundTransparency = 1
    Status.Text = ""
    Status.Font = Enum.Font.GothamSemibold
    Status.TextSize = 12
    
    local VerifyBtn = Instance.new("TextButton", Main)
    VerifyBtn.Size = UDim2.new(0, 160, 0, 42)
    VerifyBtn.Position = UDim2.new(0.5, -170, 0, 160)
    VerifyBtn.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
    VerifyBtn.Text = "✓ DOĞRULA"
    VerifyBtn.TextColor3 = Color3.new(1, 1, 1)
    VerifyBtn.Font = Enum.Font.GothamBold
    VerifyBtn.TextSize = 15
    Instance.new("UICorner", VerifyBtn).CornerRadius = UDim.new(0, 8)
    
    local GetKeyBtn = Instance.new("TextButton", Main)
    GetKeyBtn.Size = UDim2.new(0, 160, 0, 42)
    GetKeyBtn.Position = UDim2.new(0.5, 10, 0, 160)
    GetKeyBtn.BackgroundColor3 = Color3.fromRGB(80, 120, 220)
    GetKeyBtn.Text = "🔗 KEY AL"
    GetKeyBtn.TextColor3 = Color3.new(1, 1, 1)
    GetKeyBtn.Font = Enum.Font.GothamBold
    GetKeyBtn.TextSize = 15
    Instance.new("UICorner", GetKeyBtn).CornerRadius = UDim.new(0, 8)
    
    local DiscordBtn = Instance.new("TextButton", Main)
    DiscordBtn.Size = UDim2.new(0, 340, 0, 32)
    DiscordBtn.Position = UDim2.new(0.5, -170, 0, 215)
    DiscordBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
    DiscordBtn.Text = "💬 " .. (config.discord or "discord.gg/ezwin")
    DiscordBtn.TextColor3 = Color3.new(1, 1, 1)
    DiscordBtn.Font = Enum.Font.GothamSemibold
    DiscordBtn.TextSize = 13
    Instance.new("UICorner", DiscordBtn).CornerRadius = UDim.new(0, 8)
    
    local HWIDLbl = Instance.new("TextLabel", Main)
    HWIDLbl.Size = UDim2.new(1, 0, 0, 15)
    HWIDLbl.Position = UDim2.new(0, 0, 0, 260)
    HWIDLbl.BackgroundTransparency = 1
    HWIDLbl.Text = "HWID: " .. string.sub(PLAYER_HWID, 1, 25) .. "..."
    HWIDLbl.TextColor3 = Color3.fromRGB(60, 60, 80)
    HWIDLbl.Font = Enum.Font.Gotham
    HWIDLbl.TextSize = 9
    
    local VerLbl = Instance.new("TextLabel", Main)
    VerLbl.Size = UDim2.new(1, 0, 0, 15)
    VerLbl.Position = UDim2.new(0, 0, 0, 280)
    VerLbl.BackgroundTransparency = 1
    VerLbl.Text = "EZWIN v" .. (config.version or "3.0") .. " | API"
    VerLbl.TextColor3 = Color3.fromRGB(80, 80, 100)
    VerLbl.Font = Enum.Font.Gotham
    VerLbl.TextSize = 10
    
    local verified = false
    
    VerifyBtn.MouseButton1Click:Connect(function()
        local key = KeyInput.Text
        if key == "" then
            Status.Text = "⚠️ Key girin!"
            Status.TextColor3 = Color3.fromRGB(255, 200, 50)
            return
        end
        
        Status.Text = "⏳ Dogrulanıyor..."
        Status.TextColor3 = Color3.fromRGB(150, 150, 255)
        
        local result = HttpPost(API_URL .. "/verify", {key = key, hwid = PLAYER_HWID})
        
        if not result then
            Status.Text = "❌ API hatasi!"
            Status.TextColor3 = Color3.fromRGB(255, 100, 100)
            return
        end
        
        if result.success then
            Status.Text = "✅ " .. result.message
            Status.TextColor3 = Color3.fromRGB(100, 255, 100)
            verified = true
            
            TweenService:Create(Main, TweenInfo.new(0.4), {Position = UDim2.new(0.5, -200, -0.5, 0)}):Play()
            TweenService:Create(Blur, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
            task.wait(0.5)
            KeyGui:Destroy()
        else
            Status.Text = "❌ " .. result.message
            Status.TextColor3 = Color3.fromRGB(255, 100, 100)
            local orig = Main.Position
            for i = 1, 4 do
                Main.Position = orig + UDim2.new(0, math.random(-5, 5), 0, 0)
                task.wait(0.04)
            end
            Main.Position = orig
        end
    end)
    
    GetKeyBtn.MouseButton1Click:Connect(function()
        Status.Text = "🔗 Link kopyalandi!"
        Status.TextColor3 = Color3.fromRGB(100, 200, 255)
        pcall(function() setclipboard(config.linkvertise_link or "") end)
    end)
    
    DiscordBtn.MouseButton1Click:Connect(function()
        pcall(function() setclipboard(config.discord or "") end)
        Status.Text = "📋 Discord kopyalandi!"
        Status.TextColor3 = Color3.fromRGB(88, 101, 242)
    end)
    
    KeyInput.FocusLost:Connect(function(enter)
        if enter then VerifyBtn.MouseButton1Click:Fire() end
    end)
    
    repeat task.wait(0.1) until verified
    
    -- Script yükle
    local s, e = pcall(function()
        loadstring(game:HttpGet(SCRIPT_URL))()
    end)
    if not s then warn("[EZWIN] Script hatasi: " .. tostring(e)) end
end

StartLoader()
