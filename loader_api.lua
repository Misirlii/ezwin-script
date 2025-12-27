local API_URL = "https://ezwin-api.vercel.app"
local SCRIPT_URL = "https://raw.githubusercontent.com/Misirlii/ezwin-script/main/ezwin.lua"

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

local function GetHWID()
    local hwid = ""
    pcall(function() hwid = tostring(game:GetService("RbxAnalyticsService"):GetClientId()) end)
    if hwid == "" or hwid == "nil" then hwid = tostring(LocalPlayer.UserId) .. "-" .. tostring(game.PlaceId) end
    return hwid
end

local PLAYER_HWID = GetHWID()

local function HttpPost(url, data)
    local s, r = pcall(function()
        local req = (syn and syn.request) or (http and http.request) or http_request or request
        if req then
            local res = req({Url = url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
            return HttpService:JSONDecode(res.Body)
        end
    end)
    return s and r or nil
end

local function HttpGet(url)
    local s, r = pcall(function() return HttpService:JSONDecode(game:HttpGet(url)) end)
    return s and r or nil
end

local config = HttpGet(API_URL .. "/config")
if not config then warn("[EZWIN] API baglanti hatasi!") return end

if config.maintenance then
    local G = Instance.new("ScreenGui", CoreGui) G.Name = "EZWIN_Maint"
    local F = Instance.new("Frame", G) F.Size = UDim2.new(0,400,0,150) F.Position = UDim2.new(0.5,-200,0.5,-75) F.BackgroundColor3 = Color3.fromRGB(30,30,40)
    Instance.new("UICorner", F).CornerRadius = UDim.new(0,12)
    local T = Instance.new("TextLabel", F) T.Size = UDim2.new(1,0,1,0) T.BackgroundTransparency = 1 T.Text = "BAKIM MODU\n\n"..config.maintenance_message T.TextColor3 = Color3.new(1,1,1) T.Font = Enum.Font.GothamBold T.TextSize = 18 T.TextWrapped = true
    return
end

local KeyGui = Instance.new("ScreenGui", CoreGui) KeyGui.Name = "EZWIN_Key"
local Blur = Instance.new("Frame", KeyGui) Blur.Size = UDim2.new(1,0,1,0) Blur.BackgroundColor3 = Color3.new(0,0,0) Blur.BackgroundTransparency = 0.4
local Main = Instance.new("Frame", KeyGui) Main.Size = UDim2.new(0,380,0,280) Main.Position = UDim2.new(0.5,-190,0.5,-140) Main.BackgroundColor3 = Color3.fromRGB(20,20,30)
Instance.new("UICorner", Main).CornerRadius = UDim.new(0,12)

local Title = Instance.new("TextLabel", Main) Title.Size = UDim2.new(1,0,0,40) Title.BackgroundTransparency = 1 Title.Text = "EZWIN KEY SYSTEM" Title.TextColor3 = Color3.new(1,1,1) Title.Font = Enum.Font.GothamBlack Title.TextSize = 18

local InputFrame = Instance.new("Frame", Main) InputFrame.Size = UDim2.new(0,320,0,40) InputFrame.Position = UDim2.new(0.5,-160,0,60) InputFrame.BackgroundColor3 = Color3.fromRGB(35,35,50)
Instance.new("UICorner", InputFrame).CornerRadius = UDim.new(0,8)
local KeyInput = Instance.new("TextBox", InputFrame) KeyInput.Size = UDim2.new(1,-16,1,0) KeyInput.Position = UDim2.new(0,8,0,0) KeyInput.BackgroundTransparency = 1 KeyInput.Text = "" KeyInput.PlaceholderText = "Key girin..." KeyInput.PlaceholderColor3 = Color3.fromRGB(100,100,120) KeyInput.TextColor3 = Color3.new(1,1,1) KeyInput.Font = Enum.Font.Gotham KeyInput.TextSize = 14

local Status = Instance.new("TextLabel", Main) Status.Size = UDim2.new(1,0,0,20) Status.Position = UDim2.new(0,0,0,110) Status.BackgroundTransparency = 1 Status.Text = "" Status.Font = Enum.Font.Gotham Status.TextSize = 12

local VerifyBtn = Instance.new("TextButton", Main) VerifyBtn.Size = UDim2.new(0,150,0,40) VerifyBtn.Position = UDim2.new(0.5,-160,0,145) VerifyBtn.BackgroundColor3 = Color3.fromRGB(80,200,80) VerifyBtn.Text = "DOGRULA" VerifyBtn.TextColor3 = Color3.new(1,1,1) VerifyBtn.Font = Enum.Font.GothamBold VerifyBtn.TextSize = 14
Instance.new("UICorner", VerifyBtn).CornerRadius = UDim.new(0,8)

local GetKeyBtn = Instance.new("TextButton", Main) GetKeyBtn.Size = UDim2.new(0,150,0,40) GetKeyBtn.Position = UDim2.new(0.5,10,0,145) GetKeyBtn.BackgroundColor3 = Color3.fromRGB(80,120,220) GetKeyBtn.Text = "KEY AL" GetKeyBtn.TextColor3 = Color3.new(1,1,1) GetKeyBtn.Font = Enum.Font.GothamBold GetKeyBtn.TextSize = 14
Instance.new("UICorner", GetKeyBtn).CornerRadius = UDim.new(0,8)

local HWIDLbl = Instance.new("TextLabel", Main) HWIDLbl.Size = UDim2.new(1,0,0,15) HWIDLbl.Position = UDim2.new(0,0,0,200) HWIDLbl.BackgroundTransparency = 1 HWIDLbl.Text = "HWID: "..string.sub(PLAYER_HWID,1,25).."..." HWIDLbl.TextColor3 = Color3.fromRGB(80,80,100) HWIDLbl.Font = Enum.Font.Gotham HWIDLbl.TextSize = 9

local verified = false

VerifyBtn.MouseButton1Click:Connect(function()
    local key = KeyInput.Text
    if key == "" then Status.Text = "Key girin!" Status.TextColor3 = Color3.fromRGB(255,200,50) return end
    Status.Text = "Dogrulaniyor..." Status.TextColor3 = Color3.fromRGB(150,150,255)
    local result = HttpPost(API_URL.."/verify", {key = key, hwid = PLAYER_HWID})
    if not result then Status.Text = "API hatasi!" Status.TextColor3 = Color3.fromRGB(255,100,100) return end
    if result.success then
        Status.Text = result.message Status.TextColor3 = Color3.fromRGB(100,255,100)
        verified = true
        task.wait(0.5) KeyGui:Destroy()
    else
        Status.Text = result.message Status.TextColor3 = Color3.fromRGB(255,100,100)
    end
end)

GetKeyBtn.MouseButton1Click:Connect(function() pcall(function() setclipboard(config.linkvertise_link or "") end) Status.Text = "Link kopyalandi!" Status.TextColor3 = Color3.fromRGB(100,200,255) end)
KeyInput.FocusLost:Connect(function(e) if e then VerifyBtn.MouseButton1Click:Fire() end end)

repeat task.wait(0.1) until verified
local s, e = pcall(function() loadstring(game:HttpGet(SCRIPT_URL))() end)
if not s then warn("[EZWIN] Script hatasi: "..tostring(e)) end
