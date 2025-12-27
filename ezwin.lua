--[[
    EZWIN v3.0 PROFESSIONAL
    Premium Features: Advanced ESP, Movement, Visuals, Game Copier
    Hotkeys: Insert = Toggle Menu | RightShift = Quick Toggle
    
    BU SCRIPT LOADER ÜZERINDEN ÇALIŞTIRILMALIDIR!
    Direkt çalıştırma için loader.lua kullanın.
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer

-- Wait for camera to be ready
local Camera = workspace.CurrentCamera
if not Camera then
    Camera = workspace:WaitForChild("CurrentCamera", 10) or workspace.CurrentCamera
end
repeat task.wait() until Camera

local Config = {
    Fly = false, FlySpeed = 50,
    Speed = false, SpeedValue = 50,
    Jump = false, JumpValue = 100,
    Noclip = false, InfiniteJump = false,
    Hitbox = false, HitboxSize = 15, HitboxInvisible = false,
    Fullbright = false, NoFog = false,
    ESP = {
        Enabled = false, Highlight = false, Box = false,
        Name = false, Distance = false, HealthBar = false, Tracers = false,
        Skeleton = false, ShowTeammates = false, MaxDistance = 2000,
        Color = Color3.fromRGB(255, 50, 50),
        TeamColor = Color3.fromRGB(50, 255, 50),
        Rainbow = false, TextSize = 13,
        ChinaHat = false, ChinaHatRadius = 12, ChinaHatHeight = 8,
    },
    Aimbot = {
        Enabled = false, TeamCheck = false, VisibleCheck = false,
        FOV = 120, Smoothness = 5, AimPart = "Head",
        ShowFOV = false, FOVColor = Color3.fromRGB(255, 255, 255),
        Prediction = false, PredictionAmount = 12,
    },
    Triggerbot = {
        Enabled = false, Delay = 100, BurstMode = false, BurstCount = 3,
    },
    SilentAim = {
        Enabled = false, HitChance = 100, SmartTarget = false,
        TargetPart = "Auto", FOV = 150, ShowFOV = false,
        FOVColor = Color3.fromRGB(255, 100, 100),
    },
    Theme = {
        AccentColor = 1,
    }
}

local Connections, ESPObjects, OriginalHitboxData = {}, {}, {}
local Bypass = {WalkSpeed = 16, JumpPower = 50}
local OriginalLighting = {}
local FOVCircle = nil
local SilentFOVCircle = nil

-- ESP Optimizasyon değişkenleri
local ESPUpdateInterval = 0
local ESPUpdateRate = 1/60 -- 60 FPS ESP güncelleme
local ESPCache = {} -- Önbellek sistemi
local LastESPUpdate = 0

local function CleanupESP(player)
    if ESPObjects[player] then
        pcall(function() ESPObjects[player].Highlight:Destroy() end)
        pcall(function() for i = 1, 4 do if ESPObjects[player].Box[i] then ESPObjects[player].Box[i]:Remove() end end end)
        pcall(function() if ESPObjects[player].Name then ESPObjects[player].Name:Remove() end end)
        pcall(function() if ESPObjects[player].Distance then ESPObjects[player].Distance:Remove() end end)
        pcall(function() if ESPObjects[player].HealthBar.Bg then ESPObjects[player].HealthBar.Bg:Remove() end end)
        pcall(function() if ESPObjects[player].HealthBar.Fill then ESPObjects[player].HealthBar.Fill:Remove() end end)
        pcall(function() if ESPObjects[player].Tracer then ESPObjects[player].Tracer:Remove() end end)
        pcall(function() for i = 1, 15 do if ESPObjects[player].Skeleton[i] then ESPObjects[player].Skeleton[i]:Remove() end end end)
        pcall(function() for i = 1, 24 do if ESPObjects[player].ChinaHat and ESPObjects[player].ChinaHat.Lines[i] then ESPObjects[player].ChinaHat.Lines[i]:Remove() end end end)
        ESPObjects[player] = nil
    end
end

local function CleanupAllESP()
    for player, _ in pairs(ESPObjects) do
        CleanupESP(player)
    end
    ESPObjects = {}
end

local function ResetLighting()
    pcall(function()
        if OriginalLighting.Ambient then Lighting.Ambient = OriginalLighting.Ambient end
        if OriginalLighting.Brightness then Lighting.Brightness = OriginalLighting.Brightness end
        if OriginalLighting.ClockTime then Lighting.ClockTime = OriginalLighting.ClockTime end
        if OriginalLighting.FogEnd then Lighting.FogEnd = OriginalLighting.FogEnd end
    end)
end

local function ResetAllHitboxes()
    for pl, d in pairs(OriginalHitboxData) do
        pcall(function()
            if pl and pl.Character then
                local r = pl.Character:FindFirstChild("HumanoidRootPart")
                if r then r.Size = d.Size; r.Transparency = d.Trans; r.Material = d.Mat; r.BrickColor = d.Col end
            end
        end)
    end
    OriginalHitboxData = {}
end

local function GetChar() return LocalPlayer.Character end
local function GetHum() local c = GetChar() return c and c:FindFirstChildOfClass("Humanoid") end
local function GetRoot() local c = GetChar() return c and c:FindFirstChild("HumanoidRootPart") end
local function IsTeammate(p) return p.Team and LocalPlayer.Team and p.Team == LocalPlayer.Team end
local function GetDist(pos) local r = GetRoot() return r and (r.Position - pos).Magnitude or 9999 end
local function WorldToScreen(pos) local s, o = Camera:WorldToViewportPoint(pos) return Vector2.new(s.X, s.Y), o, s.Z end

local rainbowHue = 0
local rainbowConn = RunService.RenderStepped:Connect(function(dt) rainbowHue = (rainbowHue + dt * 0.2) % 1 end)
table.insert(Connections, rainbowConn)
local function GetRainbow() return Color3.fromHSV(rainbowHue, 1, 1) end

function Bypass:Init()
    pcall(function()
        local h = GetHum()
        if h then self.WalkSpeed, self.JumpPower = h.WalkSpeed, h.JumpPower end
    end)
end

LocalPlayer.CharacterAdded:Connect(function(c)
    task.wait(0.5)
    local h = c:FindFirstChildOfClass("Humanoid")
    if h then Bypass.WalkSpeed, Bypass.JumpPower = h.WalkSpeed, h.JumpPower end
end)

local FlyBV, FlyBG, FlyConn
local function StopFly()
    if FlyConn then FlyConn:Disconnect(); FlyConn = nil end
    if FlyBG then FlyBG:Destroy(); FlyBG = nil end
    if FlyBV then FlyBV:Destroy(); FlyBV = nil end
    local h = GetHum() if h then h.PlatformStand = false end
end

local function FullCleanup()
    for _, c in pairs(Connections) do pcall(function() c:Disconnect() end) end
    Connections = {}
    StopFly()
    CleanupAllESP()
    ResetAllHitboxes()
    ResetLighting()
    pcall(function() if FOVCircle then FOVCircle:Remove() end end)
    pcall(function() if SilentFOVCircle then SilentFOVCircle:Remove() end end)
    local h = GetHum()
    if h then
        pcall(function() h.WalkSpeed = Bypass.WalkSpeed end)
        pcall(function() h.JumpPower = Bypass.JumpPower end)
    end
end

local function StartFly()
    local r, h = GetRoot(), GetHum() if not r or not h then return end
    StopFly(); h.PlatformStand = true
    FlyBG = Instance.new("BodyGyro"); FlyBG.P = 9e4; FlyBG.MaxTorque = Vector3.new(9e9,9e9,9e9); FlyBG.CFrame = r.CFrame; FlyBG.Parent = r
    FlyBV = Instance.new("BodyVelocity"); FlyBV.Velocity = Vector3.zero; FlyBV.MaxForce = Vector3.new(9e9,9e9,9e9); FlyBV.Parent = r
    FlyConn = RunService.RenderStepped:Connect(function()
        if not Config.Fly then StopFly() return end
        local rt, hm = GetRoot(), GetHum() if not rt or not hm then return end
        hm.PlatformStand = true
        local d, cf = Vector3.zero, Camera.CFrame
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then d = d + cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then d = d - cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then d = d - cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then d = d + cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then d = d + Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then d = d - Vector3.new(0,1,0) end
        FlyBV.Velocity = d.Magnitude > 0 and d.Unit * Config.FlySpeed or Vector3.zero
        FlyBG.CFrame = CFrame.new(rt.Position, rt.Position + cf.LookVector)
    end)
end

local lastSpd, lastJmp = false, false
table.insert(Connections, RunService.Stepped:Connect(function()
    pcall(function()
        local h = GetHum() if not h then return end
        if Config.Speed then h.WalkSpeed = Config.SpeedValue; lastSpd = true
        elseif lastSpd then h.WalkSpeed = Bypass.WalkSpeed; lastSpd = false end
        if Config.Jump then h.JumpPower = Config.JumpValue; lastJmp = true
        elseif lastJmp then h.JumpPower = Bypass.JumpPower; lastJmp = false end
    end)
end))

table.insert(Connections, RunService.Stepped:Connect(function()
    if Config.Noclip then
        pcall(function()
            local c = GetChar() if c then
                for _, p in pairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end
        end)
    end
end))

UserInputService.JumpRequest:Connect(function()
    if Config.InfiniteJump then
        local h = GetHum()
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

table.insert(Connections, RunService.RenderStepped:Connect(function()
    if Config.Hitbox then
        for _, pl in pairs(Players:GetPlayers()) do
            if pl ~= LocalPlayer then
                pcall(function()
                    local c = pl.Character if c then
                        local r, h = c:FindFirstChild("HumanoidRootPart"), c:FindFirstChildOfClass("Humanoid")
                        if r and h and h.Health > 0 then
                            if not OriginalHitboxData[pl] then
                                OriginalHitboxData[pl] = {Size = r.Size, Trans = r.Transparency, Mat = r.Material, Col = r.BrickColor}
                            end
                            r.Size = Vector3.new(Config.HitboxSize, Config.HitboxSize, Config.HitboxSize)
                            if Config.HitboxInvisible then
                                r.Transparency = 1
                            else
                                r.Transparency = 0.7; r.BrickColor = BrickColor.new("Really blue")
                                r.Material = Enum.Material.Neon
                            end
                            r.CanCollide = false
                        end
                    end
                end)
            end
        end
    else
        for pl, d in pairs(OriginalHitboxData) do
            pcall(function()
                if pl and pl.Character then
                    local r = pl.Character:FindFirstChild("HumanoidRootPart")
                    if r then r.Size = d.Size; r.Transparency = d.Trans; r.Material = d.Mat; r.BrickColor = d.Col end
                end
            end)
        end
        OriginalHitboxData = {}
    end
end))

local lastFullbright, lastNoFog = false, false
table.insert(Connections, RunService.RenderStepped:Connect(function()
    if Config.Fullbright then
        if not lastFullbright then
            OriginalLighting.Ambient = OriginalLighting.Ambient or Lighting.Ambient
            OriginalLighting.Brightness = OriginalLighting.Brightness or Lighting.Brightness
            OriginalLighting.ClockTime = OriginalLighting.ClockTime or Lighting.ClockTime
            lastFullbright = true
        end
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
    elseif lastFullbright then
        pcall(function()
            Lighting.Ambient = OriginalLighting.Ambient
            Lighting.Brightness = OriginalLighting.Brightness
            Lighting.ClockTime = OriginalLighting.ClockTime
        end)
        lastFullbright = false
    end
    if Config.NoFog then
        if not lastNoFog then
            OriginalLighting.FogEnd = OriginalLighting.FogEnd or Lighting.FogEnd
            lastNoFog = true
        end
        Lighting.FogEnd = 100000
    elseif lastNoFog then
        pcall(function() Lighting.FogEnd = OriginalLighting.FogEnd end)
        lastNoFog = false
    end
end))

local function CreateESP(player)
    if player == LocalPlayer or ESPObjects[player] then return end
    local esp = {
        Highlight = Instance.new("Highlight"),
        Box = {}, Name = nil, Distance = nil, HealthBar = {}, Tracer = nil, Skeleton = {},
        ChinaHat = {Lines = {}, Triangles = {}}
    }
    esp.Highlight.FillTransparency = 0.5
    esp.Highlight.OutlineTransparency = 0
    esp.Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    esp.Highlight.Enabled = false
    pcall(function()
        for i = 1, 4 do
            esp.Box[i] = Drawing.new("Line")
            esp.Box[i].Thickness = 1.5; esp.Box[i].Visible = false
        end
        esp.Name = Drawing.new("Text")
        esp.Name.Center = true; esp.Name.Outline = true; esp.Name.Visible = false
        esp.Name.Size = Config.ESP.TextSize; esp.Name.Font = Drawing.Fonts.Plex
        esp.Distance = Drawing.new("Text")
        esp.Distance.Center = true; esp.Distance.Outline = true; esp.Distance.Visible = false
        esp.Distance.Size = Config.ESP.TextSize - 1; esp.Distance.Font = Drawing.Fonts.Plex
        esp.HealthBar.Bg = Drawing.new("Line")
        esp.HealthBar.Bg.Thickness = 4; esp.HealthBar.Bg.Color = Color3.new(0,0,0); esp.HealthBar.Bg.Visible = false
        esp.HealthBar.Fill = Drawing.new("Line")
        esp.HealthBar.Fill.Thickness = 2; esp.HealthBar.Fill.Visible = false
        esp.Tracer = Drawing.new("Line")
        esp.Tracer.Thickness = 1.5; esp.Tracer.Visible = false
        for i = 1, 15 do
            esp.Skeleton[i] = Drawing.new("Line")
            esp.Skeleton[i].Thickness = 1.5; esp.Skeleton[i].Visible = false
        end
        for i = 1, 24 do
            esp.ChinaHat.Lines[i] = Drawing.new("Line")
            esp.ChinaHat.Lines[i].Thickness = 1.5; esp.ChinaHat.Lines[i].Visible = false
        end
    end)
    ESPObjects[player] = esp
end

local function UpdateESP()
    -- Frame rate limiter for performance
    local currentTime = tick()
    if currentTime - LastESPUpdate < ESPUpdateRate then return end
    LastESPUpdate = currentTime
    
    -- ESP kapalıysa hızlıca gizle
    if not Config.ESP.Enabled then
        for player, esp in pairs(ESPObjects) do
            if esp.Highlight then esp.Highlight.Enabled = false end
            for i = 1, 4 do if esp.Box[i] then esp.Box[i].Visible = false end end
            if esp.Name then esp.Name.Visible = false end
            if esp.Distance then esp.Distance.Visible = false end
            if esp.HealthBar.Bg then esp.HealthBar.Bg.Visible = false end
            if esp.HealthBar.Fill then esp.HealthBar.Fill.Visible = false end
            if esp.Tracer then esp.Tracer.Visible = false end
            for i = 1, 15 do if esp.Skeleton[i] then esp.Skeleton[i].Visible = false end end
            for i = 1, 24 do if esp.ChinaHat and esp.ChinaHat.Lines[i] then esp.ChinaHat.Lines[i].Visible = false end end
        end
        return
    end
    
    local camPos = Camera.CFrame.Position
    local camSize = Camera.ViewportSize
    
    for player, esp in pairs(ESPObjects) do
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local visible = char and hum and root and hum.Health > 0
        if visible and not Config.ESP.ShowTeammates and IsTeammate(player) then visible = false end
        if visible and GetDist(root.Position) > Config.ESP.MaxDistance then visible = false end
        local color = Config.ESP.Rainbow and GetRainbow() or (IsTeammate(player) and Config.ESP.TeamColor or Config.ESP.Color)
        if esp.Highlight then
            if visible and Config.ESP.Highlight then
                esp.Highlight.FillColor = color; esp.Highlight.OutlineColor = color
                esp.Highlight.Adornee = char; esp.Highlight.Parent = CoreGui; esp.Highlight.Enabled = true
            else esp.Highlight.Enabled = false end
        end
        local screenPos, onScreen, depth
        if visible and root then screenPos, onScreen, depth = WorldToScreen(root.Position) end
        pcall(function()
            if visible and onScreen and depth > 0 then
                local dist = GetDist(root.Position)
                local boxH, boxW
                local head = char:FindFirstChild("Head")
                if head then
                    local headScreenPos = WorldToScreen(head.Position + Vector3.new(0, 0.5, 0))
                    local footScreenPos = WorldToScreen(root.Position - Vector3.new(0, 3, 0))
                    boxH = math.clamp(math.abs(footScreenPos.Y - headScreenPos.Y), 20, 350)
                    boxW = boxH * 0.45
                else
                    local scale = 1 / (depth * 0.05)
                    boxH = math.clamp(120 * scale, 20, 300)
                    boxW = boxH * 0.45
                end
                if Config.ESP.Box then
                    local tl = Vector2.new(screenPos.X - boxW/2, screenPos.Y - boxH/2)
                    local tr = Vector2.new(screenPos.X + boxW/2, screenPos.Y - boxH/2)
                    local bl = Vector2.new(screenPos.X - boxW/2, screenPos.Y + boxH/2)
                    local br = Vector2.new(screenPos.X + boxW/2, screenPos.Y + boxH/2)
                    esp.Box[1].From = tl; esp.Box[1].To = tr; esp.Box[1].Color = color; esp.Box[1].Visible = true
                    esp.Box[2].From = bl; esp.Box[2].To = br; esp.Box[2].Color = color; esp.Box[2].Visible = true
                    esp.Box[3].From = tl; esp.Box[3].To = bl; esp.Box[3].Color = color; esp.Box[3].Visible = true
                    esp.Box[4].From = tr; esp.Box[4].To = br; esp.Box[4].Color = color; esp.Box[4].Visible = true
                else for i = 1, 4 do esp.Box[i].Visible = false end end
                if Config.ESP.Name and esp.Name then
                    esp.Name.Position = Vector2.new(screenPos.X, screenPos.Y - boxH/2 - 15)
                    esp.Name.Text = player.DisplayName; esp.Name.Color = color; esp.Name.Visible = true
                elseif esp.Name then esp.Name.Visible = false end
                if Config.ESP.Distance and esp.Distance then
                    esp.Distance.Position = Vector2.new(screenPos.X, screenPos.Y + boxH/2 + 2)
                    esp.Distance.Text = string.format("[%dm]", math.floor(dist))
                    esp.Distance.Color = Color3.new(1,1,1); esp.Distance.Visible = true
                elseif esp.Distance then esp.Distance.Visible = false end
                if Config.ESP.HealthBar and esp.HealthBar.Bg then
                    local hp = hum.Health / hum.MaxHealth
                    local barX = screenPos.X - boxW/2 - 6
                    esp.HealthBar.Bg.From = Vector2.new(barX, screenPos.Y - boxH/2)
                    esp.HealthBar.Bg.To = Vector2.new(barX, screenPos.Y + boxH/2)
                    esp.HealthBar.Bg.Visible = true
                    esp.HealthBar.Fill.From = Vector2.new(barX, screenPos.Y + boxH/2)
                    esp.HealthBar.Fill.To = Vector2.new(barX, screenPos.Y + boxH/2 - boxH * hp)
                    esp.HealthBar.Fill.Color = Color3.fromRGB(255 * (1 - hp), 255 * hp, 0)
                    esp.HealthBar.Fill.Visible = true
                elseif esp.HealthBar.Bg then esp.HealthBar.Bg.Visible = false; esp.HealthBar.Fill.Visible = false end
                if Config.ESP.Tracers and esp.Tracer then
                    local camSize = Camera.ViewportSize
                    esp.Tracer.From = Vector2.new(camSize.X / 2, camSize.Y)
                    esp.Tracer.To = screenPos; esp.Tracer.Color = color; esp.Tracer.Visible = true
                elseif esp.Tracer then esp.Tracer.Visible = false end
                if Config.ESP.Skeleton and esp.Skeleton and #esp.Skeleton > 0 then
                    local function getBonePos(partName)
                        local part = char:FindFirstChild(partName)
                        if part then
                            local pos, vis = WorldToScreen(part.Position)
                            return pos, vis
                        end
                        return nil, false
                    end
                    local bones = {
                        {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
                        {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
                        {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
                        {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
                        {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"}
                    }
                    local r15 = char:FindFirstChild("UpperTorso") ~= nil
                    if not r15 then
                        bones = {
                            {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
                            {"Torso", "Left Leg"}, {"Torso", "Right Leg"}
                        }
                    end
                    for i, bone in ipairs(bones) do
                        if esp.Skeleton[i] then
                            local p1, v1 = getBonePos(bone[1])
                            local p2, v2 = getBonePos(bone[2])
                            if p1 and p2 and v1 and v2 then
                                esp.Skeleton[i].From = p1; esp.Skeleton[i].To = p2
                                esp.Skeleton[i].Color = color; esp.Skeleton[i].Visible = true
                            else
                                esp.Skeleton[i].Visible = false
                            end
                        end
                    end
                    for i = #bones + 1, 15 do
                        if esp.Skeleton[i] then esp.Skeleton[i].Visible = false end
                    end
                else
                    for i = 1, 15 do if esp.Skeleton[i] then esp.Skeleton[i].Visible = false end end
                end
                if Config.ESP.ChinaHat and esp.ChinaHat and esp.ChinaHat.Lines then
                    local head = char:FindFirstChild("Head")
                    if head then
                        local headPos = head.Position + Vector3.new(0, 1.5, 0)
                        local tipPos = headPos + Vector3.new(0, Config.ESP.ChinaHatHeight / 10, 0)
                        local tipScreen, tipVisible = WorldToScreen(tipPos)
                        local radius = Config.ESP.ChinaHatRadius / 10
                        local segments = 24
                        local basePoints = {}
                        
                        if tipVisible then
                            for deg = 0, 360, 360/segments do
                                local rad = math.rad(deg)
                                local pointPos = headPos + Vector3.new(math.cos(rad) * radius, 0, math.sin(rad) * radius)
                                local pointScreen, pointVisible = WorldToScreen(pointPos)
                                if pointVisible then
                                    table.insert(basePoints, pointScreen)
                                end
                            end
                        end
                        
                        for i = 1, segments do
                            if esp.ChinaHat.Lines[i] and basePoints[i] and tipScreen and tipVisible then
                                local nextIdx = i + 1
                                if nextIdx > #basePoints then nextIdx = 1 end
                                
                                local lineColor = color
                                if Config.ESP.Rainbow then
                                    local h = (rainbowHue + i * 0.04) % 1
                                    lineColor = Color3.fromHSV(h, 1, 1)
                                end
                                
                                esp.ChinaHat.Lines[i].From = basePoints[i]
                                esp.ChinaHat.Lines[i].To = tipScreen
                                esp.ChinaHat.Lines[i].Color = lineColor
                                esp.ChinaHat.Lines[i].Visible = true
                            elseif esp.ChinaHat.Lines[i] then
                                esp.ChinaHat.Lines[i].Visible = false
                            end
                        end
                    else
                        for i = 1, 24 do if esp.ChinaHat.Lines[i] then esp.ChinaHat.Lines[i].Visible = false end end
                    end
                else
                    for i = 1, 24 do if esp.ChinaHat and esp.ChinaHat.Lines and esp.ChinaHat.Lines[i] then esp.ChinaHat.Lines[i].Visible = false end end
                end
            else
                for i = 1, 4 do if esp.Box[i] then esp.Box[i].Visible = false end end
                if esp.Name then esp.Name.Visible = false end
                if esp.Distance then esp.Distance.Visible = false end
                if esp.HealthBar.Bg then esp.HealthBar.Bg.Visible = false end
                if esp.HealthBar.Fill then esp.HealthBar.Fill.Visible = false end
                if esp.Tracer then esp.Tracer.Visible = false end
                for i = 1, 15 do if esp.Skeleton and esp.Skeleton[i] then esp.Skeleton[i].Visible = false end end
                for i = 1, 24 do if esp.ChinaHat and esp.ChinaHat.Lines and esp.ChinaHat.Lines[i] then esp.ChinaHat.Lines[i].Visible = false end end
            end
        end)
    end
end

for _, p in pairs(Players:GetPlayers()) do CreateESP(p) end
Players.PlayerAdded:Connect(CreateESP)
Players.PlayerRemoving:Connect(function(p)
    CleanupESP(p)
    OriginalHitboxData[p] = nil
end)
table.insert(Connections, RunService.RenderStepped:Connect(UpdateESP))

pcall(function()
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Thickness = 1
    FOVCircle.NumSides = 64
    FOVCircle.Filled = false
    FOVCircle.Visible = false
    FOVCircle.Transparency = 0.7
end)

pcall(function()
    SilentFOVCircle = Drawing.new("Circle")
    SilentFOVCircle.Thickness = 1
    SilentFOVCircle.NumSides = 64
    SilentFOVCircle.Filled = false
    SilentFOVCircle.Visible = false
    SilentFOVCircle.Transparency = 0.7
end)

local CurrentTarget = nil
local LastTriggerTime = 0
local LockedTarget = nil
local LastTargetTime = 0
local TargetLockDuration = 0.5 -- Hedef kilitleme süresi (saniye)
local LastAimPosition = nil
local AimLerpSpeed = 0.3 -- Yumuşak geçiş hızı (0.1-1.0 arası)

local function GetBestAimPart(char, hum)
    if Config.SilentAim.TargetPart ~= "Auto" then
        return char:FindFirstChild(Config.SilentAim.TargetPart)
    end
    local hp = hum.Health / hum.MaxHealth
    if hp > 0.7 then return char:FindFirstChild("Head")
    elseif hp > 0.3 then return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    else return char:FindFirstChild("HumanoidRootPart") end
end

local function IsVisible(origin, target)
    local ray = Ray.new(origin, (target - origin).Unit * 1000)
    local hit = workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character, Camera})
    return hit and hit:IsDescendantOf(target.Parent)
end

local function GetClosestPlayer()
    local closest, closestDist = nil, math.huge
    local camPos = Camera.CFrame.Position
    local mousePos = UserInputService:GetMouseLocation()
    
    -- Eğer kilitli hedef varsa ve hala geçerliyse, onu döndür
    if LockedTarget and tick() - LastTargetTime < TargetLockDuration then
        local char = LockedTarget.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local aimPart = char and char:FindFirstChild(Config.Aimbot.AimPart) or (char and char:FindFirstChild("Head"))
        if char and hum and aimPart and hum.Health > 0 then
            local screenPos, onScreen = WorldToScreen(aimPart.Position)
            if onScreen then
                local dist = (screenPos - mousePos).Magnitude
                if dist <= Config.Aimbot.FOV * 1.5 then -- Kilitli hedef için biraz daha geniş FOV
                    return LockedTarget
                end
            end
        end
    end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local aimPart = char and char:FindFirstChild(Config.Aimbot.AimPart) or (char and char:FindFirstChild("Head"))
            
            if char and hum and aimPart and hum.Health > 0 then
                if Config.Aimbot.TeamCheck and IsTeammate(player) then continue end
                
                local screenPos, onScreen = WorldToScreen(aimPart.Position)
                if onScreen then
                    local dist = (screenPos - mousePos).Magnitude
                    if dist <= Config.Aimbot.FOV then
                        if Config.Aimbot.VisibleCheck then
                            if not IsVisible(camPos, aimPart.Position) then continue end
                        end
                        if dist < closestDist then
                            closest = player
                            closestDist = dist
                        end
                    end
                end
            end
        end
    end
    
    -- Yeni hedef bulunduğunda kilitle
    if closest then
        LockedTarget = closest
        LastTargetTime = tick()
    end
    
    return closest
end

local function PredictPosition(player, part)
    if not Config.Aimbot.Prediction then return part.Position end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        local velocity = root.AssemblyLinearVelocity or root.Velocity
        return part.Position + (velocity * (Config.Aimbot.PredictionAmount / 100))
    end
    return part.Position
end

table.insert(Connections, RunService.RenderStepped:Connect(function()
    local mousePos = UserInputService:GetMouseLocation()
    
    if FOVCircle then
        FOVCircle.Position = mousePos
        FOVCircle.Radius = Config.Aimbot.FOV
        FOVCircle.Color = Config.Aimbot.FOVColor
        FOVCircle.Visible = Config.Aimbot.ShowFOV and Config.Aimbot.Enabled
    end
    
    if SilentFOVCircle then
        SilentFOVCircle.Position = mousePos
        SilentFOVCircle.Radius = Config.SilentAim.FOV
        SilentFOVCircle.Color = Config.SilentAim.FOVColor
        SilentFOVCircle.Visible = Config.SilentAim.ShowFOV and Config.SilentAim.Enabled
    end
    
    if Config.Aimbot.Enabled and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        local target = GetClosestPlayer()
        if target then
            local char = target.Character
            local aimPart = char:FindFirstChild(Config.Aimbot.AimPart) or char:FindFirstChild("Head")
            if aimPart then
                local predictedPos = PredictPosition(target, aimPart)
                local screenPos, onScreen = Camera:WorldToViewportPoint(predictedPos)
                if onScreen then
                    local mousePos = UserInputService:GetMouseLocation()
                    local targetPos = Vector2.new(screenPos.X, screenPos.Y)
                    
                    -- Yumuşak geçiş için interpolasyon (Lerp)
                    if LastAimPosition then
                        targetPos = LastAimPosition:Lerp(targetPos, AimLerpSpeed)
                    end
                    LastAimPosition = targetPos
                    
                    local diff = targetPos - mousePos
                    
                    -- Dead zone - çok küçük hareketleri filtrele (titreşimi önler)
                    local deadZone = 2
                    if math.abs(diff.X) < deadZone then diff = Vector2.new(0, diff.Y) end
                    if math.abs(diff.Y) < deadZone then diff = Vector2.new(diff.X, 0) end
                    
                    -- Mesafeye göre dinamik smoothness
                    local distance = diff.Magnitude
                    local dynamicSmooth = Config.Aimbot.Smoothness
                    if distance < 50 then
                        dynamicSmooth = dynamicSmooth * 1.5 -- Yakınken daha yavaş
                    elseif distance > 200 then
                        dynamicSmooth = dynamicSmooth * 0.7 -- Uzaktayken daha hızlı
                    end
                    
                    local smoothed = diff / dynamicSmooth
                    
                    -- Maksimum hareket sınırı (ani sıçramaları önler)
                    local maxMove = 25
                    smoothed = Vector2.new(
                        math.clamp(smoothed.X, -maxMove, maxMove),
                        math.clamp(smoothed.Y, -maxMove, maxMove)
                    )
                    
                    pcall(function() mousemoverel(smoothed.X, smoothed.Y) end)
                end
            end
        else
            -- Hedef yoksa son pozisyonu sıfırla
            LastAimPosition = nil
            LockedTarget = nil
        end
    else
        -- Mouse bırakıldığında sıfırla
        if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
            LastAimPosition = nil
        end
    end
    
    if Config.Triggerbot.Enabled then
        local mouse = LocalPlayer:GetMouse()
        local target = mouse.Target
        if target then
            local player = Players:GetPlayerFromCharacter(target.Parent) or Players:GetPlayerFromCharacter(target.Parent.Parent)
            if player and player ~= LocalPlayer then
                if not (Config.Aimbot.TeamCheck and IsTeammate(player)) then
                local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    if tick() - LastTriggerTime >= (Config.Triggerbot.Delay / 1000) then
                        if Config.Triggerbot.BurstMode then
                            for i = 1, Config.Triggerbot.BurstCount do
                                pcall(function() mouse1click() end)
                                task.wait(0.05)
                            end
                        else
                            pcall(function() mouse1click() end)
                        end
                        LastTriggerTime = tick()
                    end
                end
                end
            end
        end
    end
end))

local function GetSilentAimTarget()
    local closest, closestDist = nil, math.huge
    local mousePos = UserInputService:GetMouseLocation()
    local camPos = Camera.CFrame.Position
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local head = char and char:FindFirstChild("Head")
            
            if char and hum and head and hum.Health > 0 then
                if Config.Aimbot.TeamCheck and IsTeammate(player) then continue end
                
                local screenPos, onScreen = WorldToScreen(head.Position)
                if onScreen then
                    local dist = (screenPos - mousePos).Magnitude
                    if dist <= Config.SilentAim.FOV then
                        if Config.Aimbot.VisibleCheck then
                            local rayParams = RaycastParams.new()
                            rayParams.FilterType = Enum.RaycastFilterType.Exclude
                            rayParams.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
                            local result = workspace:Raycast(camPos, (head.Position - camPos).Unit * 1000, rayParams)
                            if result and not result.Instance:IsDescendantOf(char) then continue end
                        end
                        if dist < closestDist then
                            closest = player
                            closestDist = dist
                        end
                    end
                end
            end
        end
    end
    return closest
end

local SilentAimTarget = nil

local function UpdateSilentTarget()
    if Config.SilentAim.Enabled then
        SilentAimTarget = GetSilentAimTarget()
    else
        SilentAimTarget = nil
    end
end

table.insert(Connections, RunService.RenderStepped:Connect(UpdateSilentTarget))

local function GetSilentAimPart()
    if not SilentAimTarget then return nil end
    local char = SilentAimTarget.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return nil end
    if Config.SilentAim.SmartTarget then
        return GetBestAimPart(char, hum)
    else
        return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    end
end

local oldNamecall, oldIndex

local indexHookSuccess = pcall(function()
    if hookmetamethod then
        oldIndex = hookmetamethod(game, "__index", function(self, key)
            if Config.SilentAim.Enabled and math.random(1, 100) <= Config.SilentAim.HitChance then
                local aimPart = GetSilentAimPart()
                if aimPart then
                    if tostring(self) == "Mouse" then
                        if key == "Hit" then
                            return CFrame.new(aimPart.Position)
                        elseif key == "Target" then
                            return aimPart
                        elseif key == "X" then
                            local pos = Camera:WorldToViewportPoint(aimPart.Position)
                            return pos.X
                        elseif key == "Y" then
                            local pos = Camera:WorldToViewportPoint(aimPart.Position)
                            return pos.Y
                        elseif key == "UnitRay" then
                            local origin = Camera.CFrame.Position
                            return Ray.new(origin, (aimPart.Position - origin).Unit)
                        end
                    end
                end
            end
            return oldIndex(self, key)
        end)
    elseif getrawmetatable then
        local mt = getrawmetatable(game)
        if mt then
            local oldIdx = mt.__index
            if setreadonly then setreadonly(mt, false) end
            mt.__index = newcclosure and newcclosure(function(self, key)
                if Config.SilentAim.Enabled and math.random(1, 100) <= Config.SilentAim.HitChance then
                    local aimPart = GetSilentAimPart()
                    if aimPart then
                        if tostring(self) == "Mouse" or (typeof(self) == "Instance" and self.ClassName == "PlayerMouse") then
                                                        if key == "Hit" then
                                return CFrame.new(aimPart.Position)
                            elseif key == "Target" then
                                return aimPart
                            elseif key == "X" then
                                local pos = Camera:WorldToViewportPoint(aimPart.Position)
                                return pos.X
                            elseif key == "Y" then
                                local pos = Camera:WorldToViewportPoint(aimPart.Position)
                                return pos.Y
                            elseif key == "UnitRay" then
                                local origin = Camera.CFrame.Position
                                return Ray.new(origin, (aimPart.Position - origin).Unit)
                            end
                        end
                    end
                end
                return oldIdx(self, key)
            end) or function(self, key)
                if Config.SilentAim.Enabled and math.random(1, 100) <= Config.SilentAim.HitChance then
                    local aimPart = GetSilentAimPart()
                    if aimPart then
                        if tostring(self) == "Mouse" or (typeof(self) == "Instance" and self.ClassName == "PlayerMouse") then
                                                        if key == "Hit" then
                                return CFrame.new(aimPart.Position)
                            elseif key == "Target" then
                                return aimPart
                            elseif key == "X" then
                                local pos = Camera:WorldToViewportPoint(aimPart.Position)
                                return pos.X
                            elseif key == "Y" then
                                local pos = Camera:WorldToViewportPoint(aimPart.Position)
                                return pos.Y
                            elseif key == "UnitRay" then
                                local origin = Camera.CFrame.Position
                                return Ray.new(origin, (aimPart.Position - origin).Unit)
                            end
                        end
                    end
                end
                return oldIdx(self, key)
            end
            if setreadonly then setreadonly(mt, true) end
        end
    end
end)

local namecallHookSuccess = pcall(function()
    if hookmetamethod then
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local args = {...}
            local method = getnamecallmethod()
            
            if Config.SilentAim.Enabled and math.random(1, 100) <= Config.SilentAim.HitChance then
                local aimPart = GetSilentAimPart()
                if aimPart then
                                        if method == "Raycast" then
                        local origin = args[1]
                        if typeof(origin) == "Vector3" then
                            args[2] = (aimPart.Position - origin).Unit * 1000
                        end
                    elseif method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRay" or method == "FindPartOnRayWithWhitelist" then
                        local ray = args[1]
                        if typeof(ray) == "Ray" then
                            args[1] = Ray.new(ray.Origin, (aimPart.Position - ray.Origin).Unit * 1000)
                        end
                    elseif method == "ViewportPointToRay" or method == "ScreenPointToRay" then
                        local origin = Camera.CFrame.Position
                        return Ray.new(origin, (aimPart.Position - origin).Unit)
                    end
                end
            end
            
            return oldNamecall(self, unpack(args))
        end)
    end
end)

local raycastHookSuccess = pcall(function()
    if hookfunction then
        local oldRaycast
        oldRaycast = hookfunction(workspace.Raycast, function(self, origin, direction, params, ...)
            if Config.SilentAim.Enabled and self == workspace then
                if math.random(1, 100) <= Config.SilentAim.HitChance then
                    local aimPart = GetSilentAimPart()
                    if aimPart and typeof(origin) == "Vector3" then
                                                direction = (aimPart.Position - origin).Unit * 1000
                    end
                end
            end
            return oldRaycast(self, origin, direction, params, ...)
        end)
    end
end)

local findPartHookSuccess = pcall(function()
    if hookfunction then
        local oldFindPart
        oldFindPart = hookfunction(workspace.FindPartOnRayWithIgnoreList, function(self, ray, ignoreList, ...)
            if Config.SilentAim.Enabled and self == workspace then
                if math.random(1, 100) <= Config.SilentAim.HitChance then
                    local aimPart = GetSilentAimPart()
                    if aimPart and typeof(ray) == "Ray" then
                                                ray = Ray.new(ray.Origin, (aimPart.Position - ray.Origin).Unit * 1000)
                    end
                end
            end
            return oldFindPart(self, ray, ignoreList, ...)
        end)
    end
end)

local whitelistHookSuccess = pcall(function()
    if hookfunction then
        local oldFindPartWhitelist
        oldFindPartWhitelist = hookfunction(workspace.FindPartOnRayWithWhitelist, function(self, ray, whitelist, ...)
            if Config.SilentAim.Enabled and self == workspace then
                if math.random(1, 100) <= Config.SilentAim.HitChance then
                    local aimPart = GetSilentAimPart()
                    if aimPart and typeof(ray) == "Ray" then
                                                ray = Ray.new(ray.Origin, (aimPart.Position - ray.Origin).Unit * 1000)
                    end
                end
            end
            return oldFindPartWhitelist(self, ray, whitelist, ...)
        end)
    end
end)

local findPartOnRayHookSuccess = pcall(function()
    if hookfunction then
        local oldFindPartOnRay
        oldFindPartOnRay = hookfunction(workspace.FindPartOnRay, function(self, ray, ...)
            if Config.SilentAim.Enabled and self == workspace then
                if math.random(1, 100) <= Config.SilentAim.HitChance then
                    local aimPart = GetSilentAimPart()
                    if aimPart and typeof(ray) == "Ray" then
                                                ray = Ray.new(ray.Origin, (aimPart.Position - ray.Origin).Unit * 1000)
                    end
                end
            end
            return oldFindPartOnRay(self, ray, ...)
        end)
    end
end)

local viewportRayHookSuccess = pcall(function()
    if hookfunction then
        local oldViewportPointToRay
        oldViewportPointToRay = hookfunction(Camera.ViewportPointToRay, function(self, x, y, depth, ...)
            if Config.SilentAim.Enabled then
                local aimPart = GetSilentAimPart()
                if aimPart and math.random(1, 100) <= Config.SilentAim.HitChance then
                                        local origin = self.CFrame.Position
                    return Ray.new(origin, (aimPart.Position - origin).Unit)
                end
            end
            return oldViewportPointToRay(self, x, y, depth, ...)
        end)
    end
end)

local screenPointRayHookSuccess = pcall(function()
    if hookfunction then
        local oldScreenPointToRay
        oldScreenPointToRay = hookfunction(Camera.ScreenPointToRay, function(self, x, y, depth, ...)
            if Config.SilentAim.Enabled then
                local aimPart = GetSilentAimPart()
                if aimPart and math.random(1, 100) <= Config.SilentAim.HitChance then
                                        local origin = self.CFrame.Position
                    return Ray.new(origin, (aimPart.Position - origin).Unit)
                end
            end
            return oldScreenPointToRay(self, x, y, depth, ...)
        end)
    end
end)

local worldToViewportHookSuccess = pcall(function()
    if hookfunction then
        local oldWorldToViewportPoint
        oldWorldToViewportPoint = hookfunction(Camera.WorldToViewportPoint, function(self, worldPoint, ...)
            if Config.SilentAim.Enabled then
                local aimPart = GetSilentAimPart()
                if aimPart and math.random(1, 100) <= Config.SilentAim.HitChance then
                                        return oldWorldToViewportPoint(self, aimPart.Position, ...)
                end
            end
            return oldWorldToViewportPoint(self, worldPoint, ...)
        end)
    end
end)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GunShotRemote = nil
for _, v in pairs(ReplicatedStorage:GetDescendants()) do
    if v.Name == "GunShot" and v:IsA("RemoteEvent") then
        GunShotRemote = v
        break
    end
end

pcall(function()
    if getgc and debug.getupvalue and debug.setupvalue and GunShotRemote then
        for _, v in pairs(getgc(true)) do
            if typeof(v) == "function" then
                local i = 1
                while true do
                    local name, value = debug.getupvalue(v, i)
                    if not name then break end
                    
                    if typeof(value) == "Instance" and value == GunShotRemote then
                        local oldFunc = v
                        local newFunc = function(...)
                            local args = {...}
                            if Config.SilentAim.Enabled then
                                local aimPart = GetSilentAimPart()
                                if aimPart and math.random(1, 100) <= Config.SilentAim.HitChance then
                                    for j, arg in ipairs(args) do
                                        if typeof(arg) == "Vector3" then
                                            args[j] = aimPart.Position
                                        elseif typeof(arg) == "CFrame" then
                                            args[j] = CFrame.new(aimPart.Position)
                                        end
                                    end
                                end
                            end
                            return oldFunc(unpack(args))
                        end
                        
                        if hookfunction then
                            hookfunction(v, newFunc)
                        end
                    end
                    i = i + 1
                end
            end
        end
    end
end)

local GameCopier = {}
GameCopier.Status = "Ready"
function GameCopier:Notify(title, text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {Title = title, Text = text, Duration = 5})
    end)
end
function GameCopier:SaveGame(decompile)
    self.Status = "Loading..."
    self:Notify("Game Copier", "Starting save...")
    local success = pcall(function()
        local ssi = loadstring(game:HttpGet("https://raw.githubusercontent.com/luau/SynSaveInstance/main/saveinstance.luau"))()
        local name = "Game"
        pcall(function() name = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name:gsub("[^%w%s]", ""):sub(1,30) end)
        ssi({FileName = name.."_"..game.PlaceId, Decompile = decompile ~= false, DecompileTimeout = 60,
            SavePlayers = false, RemovePlayerCharacters = true, SaveNonCreatable = true, SaveNotArchivable = true,
            ReplicatedFirst = true, ReplicatedStorage = true, StarterGui = true, StarterPack = true,
            StarterPlayer = true, Lighting = true, Workspace = true, Terrain = true, ShowStatus = true, Binary = false})
        self.Status = "Complete!"
    end)
    if success then self:Notify("Game Copier", "SUCCESS!") else self.Status = "Error" end
end


local function CreateUI()
    local SG = Instance.new("ScreenGui"); SG.Name = "GH"..math.random(1000,9999); SG.ResetOnSpawn = false; SG.Parent = CoreGui
    
    local Main = Instance.new("Frame", SG)
    Main.Size = UDim2.new(0, 580, 0, 380)
    Main.Position = UDim2.new(0.5, -290, 0.5, -190)
    Main.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
    Main.BorderSizePixel = 0; Main.Active = true; Main.Draggable = true
    Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)
    
    local MainStroke = Instance.new("UIStroke", Main)
    MainStroke.Color = Color3.fromRGB(100, 150, 200); MainStroke.Thickness = 1
    
    local SnowContainer = Instance.new("Frame", Main)
    SnowContainer.Size = UDim2.new(1, 0, 1, 0)
    SnowContainer.BackgroundTransparency = 1
    SnowContainer.ClipsDescendants = true
    SnowContainer.ZIndex = 10
    Instance.new("UICorner", SnowContainer).CornerRadius = UDim.new(0, 10)
    
    local snowflakes = {}
    for i = 1, 30 do
        local snow = Instance.new("TextLabel", SnowContainer)
        snow.Size = UDim2.new(0, math.random(8, 14), 0, math.random(8, 14))
        snow.Position = UDim2.new(math.random() * 0.95, 0, -0.05, 0)
        snow.BackgroundTransparency = 1
        snow.Text = "❄"
        snow.TextColor3 = Color3.fromRGB(220, 240, 255)
        snow.TextTransparency = math.random() * 0.3
        snow.Font = Enum.Font.GothamBold
        snow.TextSize = math.random(10, 16)
        snow.ZIndex = 10
        table.insert(snowflakes, {
            obj = snow,
            speed = math.random(20, 50) / 100,
            sway = math.random(-20, 20) / 100,
            startX = math.random() * 0.95
        })
    end
    
    local snowConn = RunService.RenderStepped:Connect(function(dt)
        for _, flake in ipairs(snowflakes) do
            local currentY = flake.obj.Position.Y.Scale
            local newY = currentY + flake.speed * dt
            local swayX = flake.startX + math.sin(tick() * 2 + flake.sway * 10) * 0.03
            
            if newY > 1.05 then
                newY = -0.05
                flake.startX = math.random() * 0.95
            end
            
            flake.obj.Position = UDim2.new(swayX, 0, newY, 0)
        end
    end)
    table.insert(Connections, snowConn)
    
    local Shadow = Instance.new("ImageLabel", Main)
    Shadow.Size = UDim2.new(1, 50, 1, 50); Shadow.Position = UDim2.new(0, -25, 0, -25)
    Shadow.BackgroundTransparency = 1; Shadow.Image = "rbxassetid://5554236805"
    Shadow.ImageColor3 = Color3.new(0, 0, 0); Shadow.ImageTransparency = 0.5; Shadow.ZIndex = -1
    Shadow.ScaleType = Enum.ScaleType.Slice; Shadow.SliceCenter = Rect.new(23, 23, 277, 277)
    
    local Sidebar = Instance.new("Frame", Main)
    Sidebar.Size = UDim2.new(0, 140, 1, 0)
    Sidebar.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
    Sidebar.BorderSizePixel = 0
    local SideCorner = Instance.new("UICorner", Sidebar); SideCorner.CornerRadius = UDim.new(0, 10)
    
    local SideGradient = Instance.new("UIGradient", Sidebar)
    SideGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
        ColorSequenceKeypoint.new(1, Color3.new(0.7, 0.7, 0.7))
    })
    SideGradient.Rotation = 90
    
    local LogoHolder = Instance.new("Frame", Sidebar)
    LogoHolder.Size = UDim2.new(1, 0, 0, 55)
    LogoHolder.BackgroundTransparency = 1
    
    local Logo = Instance.new("TextLabel", LogoHolder)
    Logo.Size = UDim2.new(1, 0, 0, 30)
    Logo.Position = UDim2.new(0, 0, 0, 12)
    Logo.BackgroundTransparency = 1
    Logo.Text = "🎄 EZWIN 🎄"
    Logo.TextColor3 = Color3.fromRGB(255, 255, 255)
    Logo.Font = Enum.Font.GothamBlack; Logo.TextSize = 14
    
    local LogoVersion = Instance.new("TextLabel", LogoHolder)
    LogoVersion.Size = UDim2.new(1, 0, 0, 15)
    LogoVersion.Position = UDim2.new(0, 0, 0, 38)
    LogoVersion.BackgroundTransparency = 1
    LogoVersion.Text = "❄️"
    LogoVersion.TextColor3 = Color3.fromRGB(100, 180, 255)
    LogoVersion.Font = Enum.Font.Gotham; LogoVersion.TextSize = 10
    
    local ChristmasLights = Instance.new("Frame", Sidebar)
    ChristmasLights.Size = UDim2.new(1, 0, 0, 8)
    ChristmasLights.Position = UDim2.new(0, 0, 0, 55)
    ChristmasLights.BackgroundTransparency = 1
    
    local lightColors = {
        Color3.fromRGB(255, 50, 50),
        Color3.fromRGB(50, 255, 50),
        Color3.fromRGB(255, 200, 50),
        Color3.fromRGB(50, 150, 255),
        Color3.fromRGB(255, 100, 200)
    }
    local lights = {}
    for i = 1, 14 do
        local light = Instance.new("Frame", ChristmasLights)
        light.Size = UDim2.new(0, 6, 0, 6)
        light.Position = UDim2.new(0, 5 + (i-1) * 9, 0, 1)
        light.BackgroundColor3 = lightColors[(i % #lightColors) + 1]
        light.BorderSizePixel = 0
        Instance.new("UICorner", light).CornerRadius = UDim.new(1, 0)
        table.insert(lights, light)
    end
    
    local lightTick = 0
    local lightConn = RunService.RenderStepped:Connect(function(dt)
        lightTick = lightTick + dt
        if lightTick >= 0.3 then
            lightTick = 0
            for i, light in ipairs(lights) do
                local newIdx = ((i + math.floor(tick() * 3)) % #lightColors) + 1
                light.BackgroundColor3 = lightColors[newIdx]
            end
        end
    end)
    table.insert(Connections, lightConn)
    
    local LogoDivider = Instance.new("Frame", Sidebar)
    LogoDivider.Size = UDim2.new(0.8, 0, 0, 1)
    LogoDivider.Position = UDim2.new(0.1, 0, 0, 66)
    LogoDivider.BackgroundColor3 = Color3.fromRGB(100, 180, 255)
    LogoDivider.BorderSizePixel = 0
    
    local TabList = Instance.new("Frame", Sidebar)
    TabList.Size = UDim2.new(1, -16, 1, -130)
    TabList.Position = UDim2.new(0, 8, 0, 73)
    TabList.BackgroundTransparency = 1
    local TabLayout = Instance.new("UIListLayout", TabList)
    TabLayout.Padding = UDim.new(0, 3)
    
    local UserInfo = Instance.new("Frame", Sidebar)
    UserInfo.Size = UDim2.new(1, -16, 0, 50)
    UserInfo.Position = UDim2.new(0, 8, 1, -58)
    UserInfo.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    UserInfo.BorderSizePixel = 0
    Instance.new("UICorner", UserInfo).CornerRadius = UDim.new(0, 8)
    
    local UserIconHolder = Instance.new("Frame", UserInfo)
    UserIconHolder.Size = UDim2.new(0, 34, 0, 34)
    UserIconHolder.Position = UDim2.new(0, 8, 0.5, -17)
    UserIconHolder.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    UserIconHolder.BorderSizePixel = 0
    Instance.new("UICorner", UserIconHolder).CornerRadius = UDim.new(1, 0)
    
    local UserIcon = Instance.new("ImageLabel", UserIconHolder)
    UserIcon.Size = UDim2.new(1, -4, 1, -4)
    UserIcon.Position = UDim2.new(0, 2, 0, 2)
    UserIcon.BackgroundTransparency = 1
    UserIcon.Image = "rbxthumb://type=AvatarHeadShot&id="..LocalPlayer.UserId.."&w=150&h=150"
    Instance.new("UICorner", UserIcon).CornerRadius = UDim.new(1, 0)
    
    local OnlineIndicator = Instance.new("Frame", UserIconHolder)
    OnlineIndicator.Size = UDim2.new(0, 10, 0, 10)
    OnlineIndicator.Position = UDim2.new(1, -10, 1, -10)
    OnlineIndicator.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
    OnlineIndicator.BorderSizePixel = 0
    Instance.new("UICorner", OnlineIndicator).CornerRadius = UDim.new(1, 0)
    Instance.new("UIStroke", OnlineIndicator).Color = Color3.fromRGB(25, 25, 35)
    
    local UserName = Instance.new("TextLabel", UserInfo)
    UserName.Size = UDim2.new(1, -55, 0, 16)
    UserName.Position = UDim2.new(0, 48, 0, 10)
    UserName.BackgroundTransparency = 1
    UserName.Text = LocalPlayer.DisplayName
    UserName.TextColor3 = Color3.new(1, 1, 1)
    UserName.Font = Enum.Font.GothamBold; UserName.TextSize = 12
    UserName.TextXAlignment = Enum.TextXAlignment.Left
    UserName.TextTruncate = Enum.TextTruncate.AtEnd
    
    local UserStatus = Instance.new("TextLabel", UserInfo)
    UserStatus.Size = UDim2.new(1, -55, 0, 12)
    UserStatus.Position = UDim2.new(0, 48, 0, 28)
    UserStatus.BackgroundTransparency = 1
    UserStatus.Text = "Keyless User"
    UserStatus.TextColor3 = Color3.fromRGB(150, 150, 180)
    UserStatus.Font = Enum.Font.Gotham; UserStatus.TextSize = 10
    UserStatus.TextXAlignment = Enum.TextXAlignment.Left
    
    
    local ContentArea = Instance.new("Frame", Main)
    ContentArea.Size = UDim2.new(1, -155, 1, -15)
    ContentArea.Position = UDim2.new(0, 148, 0, 8)
    ContentArea.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    ContentArea.BorderSizePixel = 0
    Instance.new("UICorner", ContentArea).CornerRadius = UDim.new(0, 8)
    
    local ContentStroke = Instance.new("UIStroke", ContentArea)
    ContentStroke.Color = Color3.fromRGB(35, 35, 48); ContentStroke.Thickness = 1
    
    local SubTabHolder = Instance.new("Frame", ContentArea)
    SubTabHolder.Size = UDim2.new(1, -20, 0, 30)
    SubTabHolder.Position = UDim2.new(0, 10, 0, 5)
    SubTabHolder.BackgroundTransparency = 1
    local SubTabLayout = Instance.new("UIListLayout", SubTabHolder)
    SubTabLayout.FillDirection = Enum.FillDirection.Horizontal
    SubTabLayout.Padding = UDim.new(0, 12)
    SubTabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    
    local ContentHolder = Instance.new("Frame", ContentArea)
    ContentHolder.Size = UDim2.new(1, -10, 1, -40)
    ContentHolder.Position = UDim2.new(0, 5, 0, 35)
    ContentHolder.BackgroundTransparency = 1
    
    local Pages, SubPages, Tabs, SubTabs = {}, {}, {}, {}
    local CurrentTab, CurrentSubTab = nil, nil
    
    local function CreateTab(name, icon)
        local Tab = Instance.new("TextButton", TabList)
        Tab.Size = UDim2.new(1, 0, 0, 34)
        Tab.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
        Tab.BackgroundTransparency = 1
        Tab.Text = ""
        Tab.BorderSizePixel = 0
        Instance.new("UICorner", Tab).CornerRadius = UDim.new(0, 6)
        
        local TabIcon = Instance.new("TextLabel", Tab)
        TabIcon.Size = UDim2.new(0, 25, 1, 0)
        TabIcon.Position = UDim2.new(0, 10, 0, 0)
        TabIcon.BackgroundTransparency = 1
        TabIcon.Text = icon
        TabIcon.TextColor3 = Color3.fromRGB(140, 140, 160)
        TabIcon.Font = Enum.Font.GothamBold; TabIcon.TextSize = 14
        
        local TabLabel = Instance.new("TextLabel", Tab)
        TabLabel.Size = UDim2.new(1, -45, 1, 0)
        TabLabel.Position = UDim2.new(0, 38, 0, 0)
        TabLabel.BackgroundTransparency = 1
        TabLabel.Text = name
        TabLabel.TextColor3 = Color3.fromRGB(140, 140, 160)
        TabLabel.Font = Enum.Font.GothamSemibold; TabLabel.TextSize = 12
        TabLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        local Indicator = Instance.new("Frame", Tab)
        Indicator.Size = UDim2.new(0, 3, 0.5, 0)
        Indicator.Position = UDim2.new(0, 0, 0.25, 0)
        Indicator.BackgroundColor3 = Color3.fromRGB(100, 180, 255)
        Indicator.BorderSizePixel = 0; Indicator.Visible = false
        Instance.new("UICorner", Indicator).CornerRadius = UDim.new(0, 2)
        
        Tabs[name] = {Button = Tab, Indicator = Indicator, Icon = TabIcon, Label = TabLabel}
        Pages[name] = {}
        
        Tab.MouseEnter:Connect(function()
            if CurrentTab ~= name then
                TweenService:Create(Tab, TweenInfo.new(0.15), {BackgroundTransparency = 0.85}):Play()
                TweenService:Create(TabLabel, TweenInfo.new(0.15), {TextColor3 = Color3.fromRGB(200, 200, 210)}):Play()
            end
        end)
        
        Tab.MouseLeave:Connect(function()
            if CurrentTab ~= name then
                TweenService:Create(Tab, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
                TweenService:Create(TabLabel, TweenInfo.new(0.15), {TextColor3 = Color3.fromRGB(140, 140, 160)}):Play()
            end
        end)
        
        Tab.MouseButton1Click:Connect(function()
            for n, t in pairs(Tabs) do
                TweenService:Create(t.Button, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
                TweenService:Create(t.Label, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(140, 140, 160)}):Play()
                TweenService:Create(t.Icon, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(140, 140, 160)}):Play()
                t.Indicator.Visible = false
            end
            TweenService:Create(Tab, TweenInfo.new(0.2), {BackgroundTransparency = 0.7}):Play()
            TweenService:Create(TabLabel, TweenInfo.new(0.2), {TextColor3 = Color3.new(1, 1, 1)}):Play()
            TweenService:Create(TabIcon, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(100, 180, 255)}):Play()
            Indicator.Visible = true
            CurrentTab = name
            
            for _, c in pairs(SubTabHolder:GetChildren()) do
                if c:IsA("TextButton") then c:Destroy() end
            end
            for _, c in pairs(ContentHolder:GetChildren()) do c.Visible = false end
            
            local firstSub = nil
            for subName, _ in pairs(Pages[name]) do
                local SubTab = Instance.new("TextButton", SubTabHolder)
                SubTab.Size = UDim2.new(0, 85, 0, 25)
                SubTab.BackgroundTransparency = 1
                SubTab.Text = subName
                SubTab.TextColor3 = Color3.fromRGB(100, 100, 120)
                SubTab.Font = Enum.Font.GothamSemibold; SubTab.TextSize = 11
                
                local Underline = Instance.new("Frame", SubTab)
                Underline.Size = UDim2.new(0.8, 0, 0, 2)
                Underline.Position = UDim2.new(0.1, 0, 1, -2)
                Underline.BackgroundColor3 = Color3.fromRGB(100, 180, 255)
                Underline.BorderSizePixel = 0
                Underline.Visible = false
                
                SubTab.MouseEnter:Connect(function()
                    if SubTab.TextColor3 ~= Color3.new(1, 1, 1) then
                        TweenService:Create(SubTab, TweenInfo.new(0.1), {TextColor3 = Color3.fromRGB(180, 180, 200)}):Play()
                    end
                end)
                SubTab.MouseLeave:Connect(function()
                    if SubTab.TextColor3 ~= Color3.new(1, 1, 1) then
                        TweenService:Create(SubTab, TweenInfo.new(0.1), {TextColor3 = Color3.fromRGB(100, 100, 120)}):Play()
                    end
                end)
                
                SubTab.MouseButton1Click:Connect(function()
                    for _, st in pairs(SubTabHolder:GetChildren()) do
                        if st:IsA("TextButton") then 
                            st.TextColor3 = Color3.fromRGB(100, 100, 120)
                            local ul = st:FindFirstChild("Frame")
                            if ul then ul.Visible = false end
                        end
                    end
                    SubTab.TextColor3 = Color3.new(1, 1, 1)
                    Underline.Visible = true
                    for _, p in pairs(ContentHolder:GetChildren()) do p.Visible = false end
                    if Pages[name][subName] then Pages[name][subName].Visible = true end
                end)
                if not firstSub then 
                    firstSub = subName
                    SubTab.TextColor3 = Color3.new(1, 1, 1)
                    Underline.Visible = true
                end
            end
            if firstSub and Pages[name][firstSub] then Pages[name][firstSub].Visible = true end
        end)
        return Tab
    end
    
    local function CreateSubPage(tabName, subName)
        local Page = Instance.new("ScrollingFrame", ContentHolder)
        Page.Size = UDim2.new(1, 0, 1, 0)
        Page.BackgroundTransparency = 1
        Page.ScrollBarThickness = 2
        Page.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
        Page.Visible = false; Page.CanvasSize = UDim2.new(0, 0, 0, 0)
        local PLayout = Instance.new("UIListLayout", Page)
        PLayout.Padding = UDim.new(0, 3)
        PLayout.SortOrder = Enum.SortOrder.LayoutOrder
        PLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            Page.CanvasSize = UDim2.new(0, 0, 0, PLayout.AbsoluteContentSize.Y + 10)
        end)
        if not Pages[tabName] then Pages[tabName] = {} end
        Pages[tabName][subName] = Page
        return Page
    end
    
    local LayoutOrders = {}
    local function GetLayoutOrder(parent)
        if not parent then return 0 end
        if not LayoutOrders[parent] then LayoutOrders[parent] = 0 end
        LayoutOrders[parent] = LayoutOrders[parent] + 1
        return LayoutOrders[parent]
    end
    
    local function Checkbox(parent, name, key, subKey, color, colorConfigKey)
        local C = Instance.new("Frame", parent)
        C.Size = UDim2.new(1, 0, 0, 30)
        C.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
        C.BackgroundTransparency = 1
        C.BorderSizePixel = 0
        C.LayoutOrder = GetLayoutOrder(parent)
        Instance.new("UICorner", C).CornerRadius = UDim.new(0, 5)
        
        local Box = Instance.new("Frame", C)
        Box.Size = UDim2.new(0, 18, 0, 18)
        Box.Position = UDim2.new(0, 8, 0.5, -9)
        Box.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
        Box.BorderSizePixel = 0
        Instance.new("UICorner", Box).CornerRadius = UDim.new(0, 4)
        local BoxStroke = Instance.new("UIStroke", Box)
        BoxStroke.Color = Color3.fromRGB(55, 55, 70); BoxStroke.Thickness = 1
        
        local Check = Instance.new("Frame", Box)
        Check.Size = UDim2.new(0, 10, 0, 10)
        Check.Position = UDim2.new(0.5, -5, 0.5, -5)
        Check.BackgroundColor3 = color or Color3.fromRGB(200, 70, 70)
        Check.BorderSizePixel = 0
        Instance.new("UICorner", Check).CornerRadius = UDim.new(0, 2)
        
        local val
        if subKey then val = Config[key][subKey] else val = Config[key] end
        Check.Visible = val == true
        if val == true then BoxStroke.Color = color or Color3.fromRGB(200, 70, 70) end
        
        local Label = Instance.new("TextLabel", C)
        Label.Size = UDim2.new(1, -40, 1, 0)
        Label.Position = UDim2.new(0, 34, 0, 0)
        Label.BackgroundTransparency = 1
        Label.Text = name
        Label.TextColor3 = (val == true) and Color3.new(1, 1, 1) or Color3.fromRGB(150, 150, 170)
        Label.Font = Enum.Font.Gotham; Label.TextSize = 12
        Label.TextXAlignment = Enum.TextXAlignment.Left
        
        local Btn = Instance.new("TextButton", C)
        Btn.Size = UDim2.new(1, 0, 1, 0)
        Btn.BackgroundTransparency = 1; Btn.Text = ""
        
        Btn.MouseEnter:Connect(function()
            TweenService:Create(C, TweenInfo.new(0.15), {BackgroundTransparency = 0.7}):Play()
        end)
        
        Btn.MouseLeave:Connect(function()
            TweenService:Create(C, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
        end)
        
        Btn.MouseButton1Click:Connect(function()
            if subKey then Config[key][subKey] = not Config[key][subKey]; val = Config[key][subKey]
            else Config[key] = not Config[key]; val = Config[key] end
            Check.Visible = val
            TweenService:Create(Label, TweenInfo.new(0.15), {TextColor3 = val and Color3.new(1, 1, 1) or Color3.fromRGB(150, 150, 170)}):Play()
            TweenService:Create(BoxStroke, TweenInfo.new(0.15), {Color = val and (color or Color3.fromRGB(200, 70, 70)) or Color3.fromRGB(55, 55, 70)}):Play()
            if key == "Fly" then if Config.Fly then StartFly() else StopFly() end end
        end)
    end
    
    local function ColorPicker(parent, name, configKey, configSubKey)
        local C = Instance.new("Frame", parent)
        C.Size = UDim2.new(1, 0, 0, 30)
        C.BackgroundTransparency = 1
        C.LayoutOrder = GetLayoutOrder(parent)
        
        local Label = Instance.new("TextLabel", C)
        Label.Size = UDim2.new(1, -50, 1, 0)
        Label.Position = UDim2.new(0, 8, 0, 0)
        Label.BackgroundTransparency = 1
        Label.Text = name
        Label.TextColor3 = Color3.fromRGB(180, 180, 200)
        Label.Font = Enum.Font.Gotham; Label.TextSize = 12
        Label.TextXAlignment = Enum.TextXAlignment.Left
        
        local currentColor = configSubKey and Config[configKey][configSubKey] or Config[configKey]
        
        local ColorDot = Instance.new("Frame", C)
        ColorDot.Size = UDim2.new(0, 20, 0, 20)
        ColorDot.Position = UDim2.new(1, -28, 0.5, -10)
        ColorDot.BackgroundColor3 = currentColor
        ColorDot.BorderSizePixel = 0
        Instance.new("UICorner", ColorDot).CornerRadius = UDim.new(0, 4)
        Instance.new("UIStroke", ColorDot).Color = Color3.fromRGB(60, 60, 80)
        
        local ColorBtn = Instance.new("TextButton", ColorDot)
        ColorBtn.Size = UDim2.new(1, 0, 1, 0)
        ColorBtn.BackgroundTransparency = 1; ColorBtn.Text = ""
        
        local colorPickerOpen = false
        local colorPickerFrame = nil
        
        ColorBtn.MouseButton1Click:Connect(function()
            if colorPickerOpen and colorPickerFrame then
                colorPickerFrame:Destroy()
                colorPickerOpen = false
                return
            end
            
            colorPickerOpen = true
            colorPickerFrame = Instance.new("Frame", C)
            colorPickerFrame.Size = UDim2.new(0, 160, 0, 130)
            colorPickerFrame.Position = UDim2.new(1, -165, 0, -100)
            colorPickerFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
            colorPickerFrame.BorderSizePixel = 0
            colorPickerFrame.ZIndex = 100
            Instance.new("UICorner", colorPickerFrame).CornerRadius = UDim.new(0, 8)
            Instance.new("UIStroke", colorPickerFrame).Color = Color3.fromRGB(50, 50, 70)
            
            local hue, sat, val2 = Color3.toHSV(currentColor)
            
            local ColorCanvas = Instance.new("ImageLabel", colorPickerFrame)
            ColorCanvas.Size = UDim2.new(0, 100, 0, 100)
            ColorCanvas.Position = UDim2.new(0, 10, 0, 10)
            ColorCanvas.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
            ColorCanvas.BorderSizePixel = 0
            ColorCanvas.Image = "rbxassetid://4155801252"
            ColorCanvas.ZIndex = 101
            Instance.new("UICorner", ColorCanvas).CornerRadius = UDim.new(0, 4)
            
            local CanvasSelector = Instance.new("Frame", ColorCanvas)
            CanvasSelector.Size = UDim2.new(0, 8, 0, 8)
            CanvasSelector.Position = UDim2.new(sat, -4, 1 - val2, -4)
            CanvasSelector.BackgroundColor3 = Color3.new(1, 1, 1)
            CanvasSelector.BorderSizePixel = 0
            CanvasSelector.ZIndex = 103
            Instance.new("UICorner", CanvasSelector).CornerRadius = UDim.new(1, 0)
            Instance.new("UIStroke", CanvasSelector).Color = Color3.new(0, 0, 0)
            
            local CanvasBtn = Instance.new("TextButton", ColorCanvas)
            CanvasBtn.Size = UDim2.new(1, 0, 1, 0)
            CanvasBtn.BackgroundTransparency = 1; CanvasBtn.Text = ""; CanvasBtn.ZIndex = 102
            
            local HueBar = Instance.new("ImageLabel", colorPickerFrame)
            HueBar.Size = UDim2.new(0, 25, 0, 100)
            HueBar.Position = UDim2.new(0, 120, 0, 10)
            HueBar.BackgroundColor3 = Color3.new(1, 1, 1)
            HueBar.BorderSizePixel = 0
            HueBar.Image = "rbxassetid://3641079629"
            HueBar.ZIndex = 101
            Instance.new("UICorner", HueBar).CornerRadius = UDim.new(0, 4)
            
            local HueSelector = Instance.new("Frame", HueBar)
            HueSelector.Size = UDim2.new(1, 4, 0, 6)
            HueSelector.Position = UDim2.new(0, -2, hue, -3)
            HueSelector.BackgroundColor3 = Color3.new(1, 1, 1)
            HueSelector.BorderSizePixel = 0
            HueSelector.ZIndex = 103
            Instance.new("UICorner", HueSelector).CornerRadius = UDim.new(0, 3)
            Instance.new("UIStroke", HueSelector).Color = Color3.new(0, 0, 0)
            
            local HueBtn = Instance.new("TextButton", HueBar)
            HueBtn.Size = UDim2.new(1, 0, 1, 0)
            HueBtn.BackgroundTransparency = 1; HueBtn.Text = ""; HueBtn.ZIndex = 102
            
            local draggingCanvas, draggingHue = false, false
            
            local function updateColor()
                local newColor = Color3.fromHSV(hue, sat, val2)
                ColorDot.BackgroundColor3 = newColor
                ColorCanvas.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
                CanvasSelector.Position = UDim2.new(sat, -4, 1 - val2, -4)
                HueSelector.Position = UDim2.new(0, -2, hue, -3)
                currentColor = newColor
                if configSubKey then
                    Config[configKey][configSubKey] = newColor
                else
                    Config[configKey] = newColor
                end
            end
            
            CanvasBtn.MouseButton1Down:Connect(function() draggingCanvas = true end)
            HueBtn.MouseButton1Down:Connect(function() draggingHue = true end)
            
            local inputConn = UserInputService.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then
                    draggingCanvas = false
                    draggingHue = false
                end
            end)
            
            local renderConn = RunService.RenderStepped:Connect(function()
                if not colorPickerFrame or not colorPickerFrame.Parent then 
                    inputConn:Disconnect()
                    return 
                end
                local m = UserInputService:GetMouseLocation()
                if draggingCanvas then
                    sat = math.clamp((m.X - ColorCanvas.AbsolutePosition.X) / ColorCanvas.AbsoluteSize.X, 0, 1)
                    val2 = 1 - math.clamp((m.Y - ColorCanvas.AbsolutePosition.Y) / ColorCanvas.AbsoluteSize.Y, 0, 1)
                    updateColor()
                end
                if draggingHue then
                    hue = math.clamp((m.Y - HueBar.AbsolutePosition.Y) / HueBar.AbsoluteSize.Y, 0, 1)
                    updateColor()
                end
            end)
            
            table.insert(Connections, renderConn)
        end)
    end
    
    local function Slider(parent, name, key, subKey, min, max)
        if not parent then return end
        local S = Instance.new("Frame", parent)
        S.Size = UDim2.new(1, 0, 0, 45)
        S.BackgroundTransparency = 1
        S.LayoutOrder = GetLayoutOrder(parent)
        
        local Label = Instance.new("TextLabel", S)
        Label.Size = UDim2.new(0.5, 0, 0, 20)
        Label.Position = UDim2.new(0, 5, 0, 0)
        Label.BackgroundTransparency = 1
        Label.Text = name
        Label.TextColor3 = Color3.fromRGB(180, 180, 200)
        Label.Font = Enum.Font.Gotham; Label.TextSize = 12
        Label.TextXAlignment = Enum.TextXAlignment.Left
        
        local val = min
        if subKey and Config[key] and Config[key][subKey] then
            val = Config[key][subKey]
        elseif Config[key] and type(Config[key]) ~= "table" then
            val = Config[key]
        end
        val = val or min
        local ValLabel = Instance.new("TextLabel", S)
        ValLabel.Size = UDim2.new(0.5, -10, 0, 20)
        ValLabel.Position = UDim2.new(0.5, 0, 0, 0)
        ValLabel.BackgroundTransparency = 1
        ValLabel.Text = tostring(val)
        ValLabel.TextColor3 = Color3.fromRGB(100, 150, 255)
        ValLabel.Font = Enum.Font.GothamBold; ValLabel.TextSize = 12
        ValLabel.TextXAlignment = Enum.TextXAlignment.Right
        
        local SliderBg = Instance.new("Frame", S)
        SliderBg.Size = UDim2.new(1, -10, 0, 6)
        SliderBg.Position = UDim2.new(0, 5, 0, 28)
        SliderBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        SliderBg.BorderSizePixel = 0
        Instance.new("UICorner", SliderBg).CornerRadius = UDim.new(1, 0)
        
        local SliderFill = Instance.new("Frame", SliderBg)
        SliderFill.Size = UDim2.new((val - min) / (max - min), 0, 1, 0)
        SliderFill.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
        SliderFill.BorderSizePixel = 0
        Instance.new("UICorner", SliderFill).CornerRadius = UDim.new(1, 0)
        
        local SliderBtn = Instance.new("TextButton", SliderBg)
        SliderBtn.Size = UDim2.new(1, 0, 1, 0)
        SliderBtn.BackgroundTransparency = 1; SliderBtn.Text = ""
        
        local dragging = false
        SliderBtn.MouseButton1Down:Connect(function() dragging = true end)
        local inputConn = UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end)
        local renderConn = RunService.RenderStepped:Connect(function()
            if not SliderBg or not SliderBg.Parent then
                inputConn:Disconnect()
                return
            end
            if dragging then
                local m = UserInputService:GetMouseLocation()
                local pct = math.clamp((m.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1)
                local newVal = math.floor(min + pct * (max - min))
                if subKey then Config[key][subKey] = newVal else Config[key] = newVal end
                ValLabel.Text = tostring(newVal)
                SliderFill.Size = UDim2.new(pct, 0, 1, 0)
            end
        end)
        table.insert(Connections, inputConn)
        table.insert(Connections, renderConn)
    end
    
    local function SectionLabel(parent, name)
        local L = Instance.new("TextLabel", parent)
        L.Size = UDim2.new(1, 0, 0, 25)
        L.BackgroundTransparency = 1
        L.Text = name
        L.TextColor3 = Color3.fromRGB(80, 80, 100)
        L.Font = Enum.Font.GothamBold; L.TextSize = 11
        L.TextXAlignment = Enum.TextXAlignment.Left
        L.LayoutOrder = GetLayoutOrder(parent)
    end
    
    local function ActionButton(parent, name, color, callback)
        local B = Instance.new("TextButton", parent)
        B.Size = UDim2.new(1, -10, 0, 35)
        B.BackgroundColor3 = color or Color3.fromRGB(60, 60, 80)
        B.Text = name
        B.TextColor3 = Color3.new(1, 1, 1)
        B.Font = Enum.Font.GothamSemibold; B.TextSize = 12
        B.LayoutOrder = GetLayoutOrder(parent)
        Instance.new("UICorner", B).CornerRadius = UDim.new(0, 6)
        
        local originalColor = color or Color3.fromRGB(60, 60, 80)
        B.MouseEnter:Connect(function()
            TweenService:Create(B, TweenInfo.new(0.15), {BackgroundColor3 = Color3.new(
                math.min(originalColor.R + 0.1, 1),
                math.min(originalColor.G + 0.1, 1),
                math.min(originalColor.B + 0.1, 1)
            )}):Play()
        end)
        B.MouseLeave:Connect(function()
            TweenService:Create(B, TweenInfo.new(0.15), {BackgroundColor3 = originalColor}):Play()
        end)
        B.MouseButton1Click:Connect(callback or function() end)
    end
    
    CreateTab("Combat", "◎")
    CreateTab("Movement", "○")
    CreateTab("Visuals", "○")
    CreateTab("Players", "○")
    CreateTab("Other", "○")
    CreateTab("Settings", "○")
    
    local AimbotSettings = CreateSubPage("Combat", "Aimbot")
    local TriggerSettings = CreateSubPage("Combat", "Triggerbot")
    local SilentSettings = CreateSubPage("Combat", "Silent Aim")
    
    local MoveSettings = CreateSubPage("Movement", "Settings")
    local MoveValues = CreateSubPage("Movement", "Values")
    
    local VisSettings = CreateSubPage("Visuals", "ESP Settings")
    local VisColors = CreateSubPage("Visuals", "ESP Colors")
    
    local PlayerSettings = CreateSubPage("Players", "Settings")
    local OtherSettings = CreateSubPage("Other", "Settings")
    local SettingsMain = CreateSubPage("Settings", "Main")
    local SettingsHooks = CreateSubPage("Settings", "Hooks")
    local SettingsBypass = CreateSubPage("Settings", "Bypass")
    
    SectionLabel(AimbotSettings, "Aimbot Settings")
    Checkbox(AimbotSettings, "Enable Aimbot", "Aimbot", "Enabled", Color3.fromRGB(255, 80, 80))
    Checkbox(AimbotSettings, "Team Check", "Aimbot", "TeamCheck", Color3.fromRGB(100, 200, 255))
    Checkbox(AimbotSettings, "Visible Check", "Aimbot", "VisibleCheck", Color3.fromRGB(255, 200, 50))
    Checkbox(AimbotSettings, "Show FOV Circle", "Aimbot", "ShowFOV", Color3.fromRGB(255, 255, 255))
    Checkbox(AimbotSettings, "Prediction", "Aimbot", "Prediction", Color3.fromRGB(150, 100, 255))
    SectionLabel(AimbotSettings, "Aimbot Values")
    Slider(AimbotSettings, "FOV Size", "Aimbot", "FOV", 50, 500)
    Slider(AimbotSettings, "Smoothness", "Aimbot", "Smoothness", 1, 20)
    Slider(AimbotSettings, "Prediction (x100)", "Aimbot", "PredictionAmount", 5, 30)
    
    SectionLabel(TriggerSettings, "Triggerbot Settings")
    Checkbox(TriggerSettings, "Enable Triggerbot", "Triggerbot", "Enabled", Color3.fromRGB(255, 150, 50))
    Checkbox(TriggerSettings, "Burst Mode", "Triggerbot", "BurstMode", Color3.fromRGB(255, 100, 100))
    SectionLabel(TriggerSettings, "Triggerbot Values")
    Slider(TriggerSettings, "Trigger Delay (ms)", "Triggerbot", "Delay", 0, 500)
    Slider(TriggerSettings, "Burst Count", "Triggerbot", "BurstCount", 1, 10)
    
    SectionLabel(SilentSettings, "Silent Aim Settings")
    Checkbox(SilentSettings, "Enable Silent Aim", "SilentAim", "Enabled", Color3.fromRGB(200, 50, 255))
    Checkbox(SilentSettings, "Smart Target (AI)", "SilentAim", "SmartTarget", Color3.fromRGB(100, 255, 200))
    Checkbox(SilentSettings, "Show FOV Circle", "SilentAim", "ShowFOV", Color3.fromRGB(255, 100, 100))
    SectionLabel(SilentSettings, "Silent Aim Values")
    Slider(SilentSettings, "FOV Size", "SilentAim", "FOV", 50, 500)
    Slider(SilentSettings, "Hit Chance %", "SilentAim", "HitChance", 1, 100)
    
    SectionLabel(MoveSettings, "Movement Settings")
    Checkbox(MoveSettings, "Enable Fly", "Fly", nil, Color3.fromRGB(100, 200, 255))
    Checkbox(MoveSettings, "Enable Speed", "Speed", nil, Color3.fromRGB(255, 100, 100))
    Checkbox(MoveSettings, "Enable Jump", "Jump", nil, Color3.fromRGB(255, 200, 50))
    Checkbox(MoveSettings, "Enable Noclip", "Noclip", nil, Color3.fromRGB(150, 100, 255))
    Checkbox(MoveSettings, "Infinite Jump", "InfiniteJump", nil, Color3.fromRGB(100, 255, 150))
    
    SectionLabel(MoveValues, "Movement Values")
    Slider(MoveValues, "Fly Speed", "FlySpeed", nil, 10, 300)
    Slider(MoveValues, "Speed Value", "SpeedValue", nil, 16, 300)
    Slider(MoveValues, "Jump Power", "JumpValue", nil, 50, 300)
    
    SectionLabel(VisSettings, "ESP Settings")
    Checkbox(VisSettings, "Enable ESP", "ESP", "Enabled", Color3.fromRGB(100, 200, 255))
    Checkbox(VisSettings, "Highlight ESP", "ESP", "Highlight", Color3.fromRGB(255, 100, 100))
    Checkbox(VisSettings, "Box ESP", "ESP", "Box", Color3.fromRGB(255, 200, 50))
    Checkbox(VisSettings, "Skeleton ESP", "ESP", "Skeleton", Color3.fromRGB(255, 255, 100))
    Checkbox(VisSettings, "Name Tags", "ESP", "Name", Color3.fromRGB(150, 100, 255))
    Checkbox(VisSettings, "Distance", "ESP", "Distance", Color3.fromRGB(100, 255, 150))
    Checkbox(VisSettings, "Health Bar", "ESP", "HealthBar", Color3.fromRGB(50, 255, 100))
    Checkbox(VisSettings, "Tracers", "ESP", "Tracers", Color3.fromRGB(255, 150, 50))
    Checkbox(VisSettings, "Rainbow Mode", "ESP", "Rainbow", Color3.fromRGB(255, 100, 200))
    Checkbox(VisSettings, "Show Teammates", "ESP", "ShowTeammates", Color3.fromRGB(100, 100, 255))
    Checkbox(VisSettings, "China Hat", "ESP", "ChinaHat", Color3.fromRGB(255, 200, 100))
    
    SectionLabel(VisColors, "ESP Values")
    Slider(VisColors, "Max Distance", "ESP", "MaxDistance", 100, 5000)
    Slider(VisColors, "Text Size", "ESP", "TextSize", 10, 20)
    
    SectionLabel(VisColors, "China Hat")
    Slider(VisColors, "Hat Width", "ESP", "ChinaHatRadius", 5, 25)
    Slider(VisColors, "Hat Height", "ESP", "ChinaHatHeight", 3, 20)
    
    SectionLabel(VisColors, "ESP Colors")
    ColorPicker(VisColors, "Enemy Color", "ESP", "Color")
    ColorPicker(VisColors, "Team Color", "ESP", "TeamColor")
    
    SectionLabel(PlayerSettings, "Hitbox Settings")
    Checkbox(PlayerSettings, "Hitbox Expand", "Hitbox", nil, Color3.fromRGB(100, 100, 255))
    Checkbox(PlayerSettings, "Invisible Hitbox", "HitboxInvisible", nil, Color3.fromRGB(150, 100, 200))
    Slider(PlayerSettings, "Hitbox Size", "HitboxSize", nil, 5, 50)
    
    SectionLabel(OtherSettings, "Visual Settings")
    Checkbox(OtherSettings, "Fullbright", "Fullbright", nil, Color3.fromRGB(255, 255, 100))
    Checkbox(OtherSettings, "No Fog", "NoFog", nil, Color3.fromRGB(200, 200, 255))
    
    SectionLabel(OtherSettings, "Game Copier")
    ActionButton(OtherSettings, "Save Full Game", Color3.fromRGB(43, 130, 226), function()
        task.spawn(function() GameCopier:SaveGame(true) end)
    end)
    ActionButton(OtherSettings, "Save Map Only", Color3.fromRGB(50, 60, 80), function()
        task.spawn(function() GameCopier:SaveGame(false) end)
    end)
    
    SectionLabel(SettingsMain, "Menu Settings")
    
    local function CreateStatusIndicator(parent, name, status, statusColor)
        local S = Instance.new("Frame", parent)
        S.Size = UDim2.new(1, -10, 0, 35)
        S.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
        S.BorderSizePixel = 0
        S.LayoutOrder = GetLayoutOrder(parent)
        Instance.new("UICorner", S).CornerRadius = UDim.new(0, 6)
        
        local Label = Instance.new("TextLabel", S)
        Label.Size = UDim2.new(0.6, -10, 1, 0)
        Label.Position = UDim2.new(0, 12, 0, 0)
        Label.BackgroundTransparency = 1
        Label.Text = name
        Label.TextColor3 = Color3.fromRGB(180, 180, 200)
        Label.Font = Enum.Font.Gotham; Label.TextSize = 12
        Label.TextXAlignment = Enum.TextXAlignment.Left
        
        local StatusHolder = Instance.new("Frame", S)
        StatusHolder.Size = UDim2.new(0, 80, 0, 22)
        StatusHolder.Position = UDim2.new(1, -90, 0.5, -11)
        StatusHolder.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
        StatusHolder.BorderSizePixel = 0
        Instance.new("UICorner", StatusHolder).CornerRadius = UDim.new(0, 4)
        
        local StatusDot = Instance.new("Frame", StatusHolder)
        StatusDot.Size = UDim2.new(0, 8, 0, 8)
        StatusDot.Position = UDim2.new(0, 8, 0.5, -4)
        StatusDot.BackgroundColor3 = statusColor
        StatusDot.BorderSizePixel = 0
        Instance.new("UICorner", StatusDot).CornerRadius = UDim.new(1, 0)
        
        local StatusText = Instance.new("TextLabel", StatusHolder)
        StatusText.Size = UDim2.new(1, -24, 1, 0)
        StatusText.Position = UDim2.new(0, 20, 0, 0)
        StatusText.BackgroundTransparency = 1
        StatusText.Text = status
        StatusText.TextColor3 = statusColor
        StatusText.Font = Enum.Font.GothamBold; StatusText.TextSize = 10
        StatusText.TextXAlignment = Enum.TextXAlignment.Left
        
        return S, StatusDot, StatusText
    end
    
    SectionLabel(SettingsHooks, "Hook Status")
    
    local bypassHookfunc = hookfunction ~= nil
    local bypassGetgc = getgc ~= nil
    
    CreateStatusIndicator(SettingsHooks, "Hook Function", bypassHookfunc and "Active" or "Blocked", bypassHookfunc and Color3.fromRGB(80, 200, 80) or Color3.fromRGB(200, 80, 80))
    CreateStatusIndicator(SettingsHooks, "GetGC", bypassGetgc and "Active" or "Blocked", bypassGetgc and Color3.fromRGB(80, 200, 80) or Color3.fromRGB(200, 80, 80))
    
    SectionLabel(SettingsHooks, "Silent Aim Status")
    CreateStatusIndicator(SettingsHooks, "Silent Aim", "Maintenance", Color3.fromRGB(255, 180, 50))
    
    SectionLabel(SettingsHooks, "Executor Info")
    local executorName = (identifyexecutor and identifyexecutor()) or (getexecutorname and getexecutorname()) or "Unknown"
    CreateStatusIndicator(SettingsHooks, "Executor", tostring(executorName), Color3.fromRGB(100, 150, 255))
    
    SectionLabel(SettingsBypass, "Anti-Cheat Bypass")
    
    local AntiCheatBypass = {
        Enabled = true,
        AntiAFK = false,
        AntiDetection = true
    }
    
    local function BypassCheckbox(parent, name, key, color)
        local C = Instance.new("Frame", parent)
        C.Size = UDim2.new(1, 0, 0, 30)
        C.BackgroundTransparency = 1
        C.BorderSizePixel = 0
        C.LayoutOrder = GetLayoutOrder(parent)
        
        local Box = Instance.new("Frame", C)
        Box.Size = UDim2.new(0, 18, 0, 18)
        Box.Position = UDim2.new(0, 5, 0.5, -9)
        Box.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
        Box.BorderSizePixel = 0
        Instance.new("UICorner", Box).CornerRadius = UDim.new(0, 4)
        Instance.new("UIStroke", Box).Color = Color3.fromRGB(60, 60, 80)
        
        local Check = Instance.new("Frame", Box)
        Check.Size = UDim2.new(0, 10, 0, 10)
        Check.Position = UDim2.new(0.5, -5, 0.5, -5)
        Check.BackgroundColor3 = color or Color3.fromRGB(80, 200, 80)
        Check.BackgroundTransparency = AntiCheatBypass[key] and 0 or 1
        Check.BorderSizePixel = 0
        Instance.new("UICorner", Check).CornerRadius = UDim.new(0, 2)
        
        local Label = Instance.new("TextLabel", C)
        Label.Size = UDim2.new(1, -35, 1, 0)
        Label.Position = UDim2.new(0, 30, 0, 0)
        Label.BackgroundTransparency = 1
        Label.Text = name
        Label.TextColor3 = Color3.fromRGB(200, 200, 220)
        Label.Font = Enum.Font.Gotham; Label.TextSize = 12
        Label.TextXAlignment = Enum.TextXAlignment.Left
        
        local Btn = Instance.new("TextButton", C)
        Btn.Size = UDim2.new(1, 0, 1, 0)
        Btn.BackgroundTransparency = 1; Btn.Text = ""
        
        Btn.MouseButton1Click:Connect(function()
            AntiCheatBypass[key] = not AntiCheatBypass[key]
            TweenService:Create(Check, TweenInfo.new(0.15), {
                BackgroundTransparency = AntiCheatBypass[key] and 0 or 1
            }):Play()
        end)
    end
    
    local BypassStatusFrame = Instance.new("Frame", SettingsBypass)
    BypassStatusFrame.Size = UDim2.new(1, -10, 0, 45)
    BypassStatusFrame.BackgroundColor3 = Color3.fromRGB(25, 45, 30)
    BypassStatusFrame.BorderSizePixel = 0
    BypassStatusFrame.LayoutOrder = GetLayoutOrder(SettingsBypass)
    Instance.new("UICorner", BypassStatusFrame).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", BypassStatusFrame).Color = Color3.fromRGB(60, 150, 80)
    
    local BypassDot = Instance.new("Frame", BypassStatusFrame)
    BypassDot.Size = UDim2.new(0, 12, 0, 12)
    BypassDot.Position = UDim2.new(0, 15, 0.5, -6)
    BypassDot.BackgroundColor3 = Color3.fromRGB(80, 220, 100)
    BypassDot.BorderSizePixel = 0
    Instance.new("UICorner", BypassDot).CornerRadius = UDim.new(1, 0)
    
    local BypassLabel = Instance.new("TextLabel", BypassStatusFrame)
    BypassLabel.Size = UDim2.new(1, -50, 1, 0)
    BypassLabel.Position = UDim2.new(0, 35, 0, 0)
    BypassLabel.BackgroundTransparency = 1
    BypassLabel.Text = "Bypass: Active"
    BypassLabel.TextColor3 = Color3.fromRGB(80, 220, 100)
    BypassLabel.Font = Enum.Font.GothamBold
    BypassLabel.TextSize = 14
    BypassLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    SectionLabel(SettingsBypass, "Bypass Options")
    
    local DetectionFrame = Instance.new("Frame", SettingsBypass)
    DetectionFrame.Size = UDim2.new(1, 0, 0, 30)
    DetectionFrame.BackgroundTransparency = 1
    DetectionFrame.BorderSizePixel = 0
    DetectionFrame.LayoutOrder = GetLayoutOrder(SettingsBypass)
    
    local DetectionBox = Instance.new("Frame", DetectionFrame)
    DetectionBox.Size = UDim2.new(0, 18, 0, 18)
    DetectionBox.Position = UDim2.new(0, 5, 0.5, -9)
    DetectionBox.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    DetectionBox.BorderSizePixel = 0
    Instance.new("UICorner", DetectionBox).CornerRadius = UDim.new(0, 4)
    Instance.new("UIStroke", DetectionBox).Color = Color3.fromRGB(60, 60, 80)
    
    local DetectionCheck = Instance.new("Frame", DetectionBox)
    DetectionCheck.Size = UDim2.new(0, 10, 0, 10)
    DetectionCheck.Position = UDim2.new(0.5, -5, 0.5, -5)
    DetectionCheck.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
    DetectionCheck.BackgroundTransparency = 0
    DetectionCheck.BorderSizePixel = 0
    Instance.new("UICorner", DetectionCheck).CornerRadius = UDim.new(0, 2)
    
    local DetectionLabel = Instance.new("TextLabel", DetectionFrame)
    DetectionLabel.Size = UDim2.new(1, -35, 1, 0)
    DetectionLabel.Position = UDim2.new(0, 30, 0, 0)
    DetectionLabel.BackgroundTransparency = 1
    DetectionLabel.Text = "Anti-Detection (Always On)"
    DetectionLabel.TextColor3 = Color3.fromRGB(80, 200, 80)
    DetectionLabel.Font = Enum.Font.GothamBold; DetectionLabel.TextSize = 12
    DetectionLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    BypassCheckbox(SettingsBypass, "Anti-AFK", "AntiAFK", Color3.fromRGB(255, 150, 50))
    
    local bypassTick = 0
    table.insert(Connections, RunService.Heartbeat:Connect(function()
        if AntiCheatBypass.Enabled then
            bypassTick = bypassTick + 1
            
            if AntiCheatBypass.AntiAFK and bypassTick % 60 == 0 then
                pcall(function()
                    local h = GetHum()
                    if h then h:ChangeState(Enum.HumanoidStateType.Landed) end
                end)
                pcall(function()
                    local VirtualUser = game:GetService("VirtualUser")
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
            end
            
            if AntiCheatBypass.AntiDetection then
                pcall(function()
                    if sethiddenproperty then
                        sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
                    end
                end)
            end
        end
    end))
    
    
    SectionLabel(SettingsMain, "Script Actions")
    ActionButton(SettingsMain, "Unload Script", Color3.fromRGB(200, 60, 60), function()
        FullCleanup()
        pcall(function()
            for _, gui in pairs(CoreGui:GetChildren()) do
                if gui.Name == SG.Name then
                    gui:Destroy()
                end
            end
        end)
        pcall(function() SG:Destroy() end)
        pcall(function() Main:Destroy() end)
    end)
    
    SectionLabel(SettingsMain, "Menu Color")
    
    local AccentColor = Color3.fromRGB(200, 70, 70)
    
    local function UpdateMenuColor(color)
        AccentColor = color
        local darkColor = Color3.fromRGB(
            math.floor(color.R * 255 * 0.15),
            math.floor(color.G * 255 * 0.15),
            math.floor(color.B * 255 * 0.15)
        )
        local medColor = Color3.fromRGB(
            math.floor(color.R * 255 * 0.25),
            math.floor(color.G * 255 * 0.25),
            math.floor(color.B * 255 * 0.25)
        )
        local lightColor = Color3.fromRGB(
            math.floor(color.R * 255 * 0.35),
            math.floor(color.G * 255 * 0.35),
            math.floor(color.B * 255 * 0.35)
        )
        
        Main.BackgroundColor3 = darkColor
        
        local sidebarColor = Color3.fromRGB(
            math.floor(color.R * 255 * 0.12),
            math.floor(color.G * 255 * 0.12),
            math.floor(color.B * 255 * 0.12)
        )
        Sidebar.BackgroundColor3 = sidebarColor
        
        ContentArea.BackgroundColor3 = medColor
        MainStroke.Color = lightColor
        ContentStroke.Color = lightColor
        
        for _, t in pairs(Tabs) do
            t.Indicator.BackgroundColor3 = color
            if CurrentTab and Tabs[CurrentTab] == t then
                t.Icon.TextColor3 = color
            end
        end
        LogoVersion.TextColor3 = color
        
        for _, holder in pairs(SubTabHolder:GetChildren()) do
            if holder:IsA("TextButton") then
                local ul = holder:FindFirstChild("Frame")
                if ul then ul.BackgroundColor3 = color end
            end
        end
        
        UserInfo.BackgroundColor3 = medColor
        
        local sidebarColor = Color3.fromRGB(
            math.floor(color.R * 255 * 0.20),
            math.floor(color.G * 255 * 0.20),
            math.floor(color.B * 255 * 0.20)
        )
        Sidebar.BackgroundColor3 = sidebarColor
    end
    
    local ColorPickerHolder = Instance.new("Frame", SettingsMain)
    ColorPickerHolder.Size = UDim2.new(1, -10, 0, 120)
    ColorPickerHolder.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    ColorPickerHolder.BorderSizePixel = 0
    ColorPickerHolder.LayoutOrder = GetLayoutOrder(SettingsMain)
    Instance.new("UICorner", ColorPickerHolder).CornerRadius = UDim.new(0, 8)
    
    local ColorCanvas = Instance.new("ImageLabel", ColorPickerHolder)
    ColorCanvas.Size = UDim2.new(0, 100, 0, 100)
    ColorCanvas.Position = UDim2.new(0, 10, 0, 10)
    ColorCanvas.BackgroundColor3 = Color3.new(1, 0, 0)
    ColorCanvas.BorderSizePixel = 0
    ColorCanvas.Image = "rbxassetid://4155801252"
    Instance.new("UICorner", ColorCanvas).CornerRadius = UDim.new(0, 6)
    
    local ColorSelector = Instance.new("Frame", ColorCanvas)
    ColorSelector.Size = UDim2.new(0, 10, 0, 10)
    ColorSelector.Position = UDim2.new(1, -10, 0, 0)
    ColorSelector.BackgroundColor3 = Color3.new(1, 1, 1)
    ColorSelector.BorderSizePixel = 0
    Instance.new("UICorner", ColorSelector).CornerRadius = UDim.new(1, 0)
    Instance.new("UIStroke", ColorSelector).Color = Color3.new(0, 0, 0)
    
    local HueBar = Instance.new("ImageLabel", ColorPickerHolder)
    HueBar.Size = UDim2.new(0, 20, 0, 100)
    HueBar.Position = UDim2.new(0, 120, 0, 10)
    HueBar.BackgroundColor3 = Color3.new(1, 1, 1)
    HueBar.BorderSizePixel = 0
    HueBar.Image = "rbxassetid://3641079629"
    Instance.new("UICorner", HueBar).CornerRadius = UDim.new(0, 4)
    
    local HueSelector = Instance.new("Frame", HueBar)
    HueSelector.Size = UDim2.new(1, 4, 0, 6)
    HueSelector.Position = UDim2.new(0, -2, 0, 0)
    HueSelector.BackgroundColor3 = Color3.new(1, 1, 1)
    HueSelector.BorderSizePixel = 0
    Instance.new("UICorner", HueSelector).CornerRadius = UDim.new(0, 3)
    Instance.new("UIStroke", HueSelector).Color = Color3.new(0, 0, 0)
    
    local PreviewBox = Instance.new("Frame", ColorPickerHolder)
    PreviewBox.Size = UDim2.new(0, 80, 0, 40)
    PreviewBox.Position = UDim2.new(0, 150, 0, 10)
    PreviewBox.BackgroundColor3 = AccentColor
    PreviewBox.BorderSizePixel = 0
    Instance.new("UICorner", PreviewBox).CornerRadius = UDim.new(0, 6)
    
    local PreviewLabel = Instance.new("TextLabel", ColorPickerHolder)
    PreviewLabel.Size = UDim2.new(0, 80, 0, 20)
    PreviewLabel.Position = UDim2.new(0, 150, 0, 55)
    PreviewLabel.BackgroundTransparency = 1
    PreviewLabel.Text = "Preview"
    PreviewLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
    PreviewLabel.Font = Enum.Font.Gotham
    PreviewLabel.TextSize = 11
    
    local ApplyBtn = Instance.new("TextButton", ColorPickerHolder)
    ApplyBtn.Size = UDim2.new(0, 80, 0, 30)
    ApplyBtn.Position = UDim2.new(0, 150, 0, 80)
    ApplyBtn.BackgroundColor3 = Color3.fromRGB(70, 150, 70)
    ApplyBtn.Text = "Apply"
    ApplyBtn.TextColor3 = Color3.new(1, 1, 1)
    ApplyBtn.Font = Enum.Font.GothamBold
    ApplyBtn.TextSize = 12
    Instance.new("UICorner", ApplyBtn).CornerRadius = UDim.new(0, 6)
    
    local currentHue, currentSat, currentVal = 0, 1, 1
    
    local function UpdateColorFromHSV()
        local color = Color3.fromHSV(currentHue, currentSat, currentVal)
        PreviewBox.BackgroundColor3 = color
        ColorCanvas.BackgroundColor3 = Color3.fromHSV(currentHue, 1, 1)
    end
    
    local draggingCanvas, draggingHue = false, false
    
    ColorCanvas.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingCanvas = true end
    end)
    HueBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingHue = true end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingCanvas = false
            draggingHue = false
        end
    end)
    
    local guiInset = game:GetService("GuiService"):GetGuiInset()
    
    RunService.RenderStepped:Connect(function()
        if draggingCanvas then
            local mouse = UserInputService:GetMouseLocation()
            local adjustedY = mouse.Y - guiInset.Y
            local relX = math.clamp((mouse.X - ColorCanvas.AbsolutePosition.X) / ColorCanvas.AbsoluteSize.X, 0, 1)
            local relY = math.clamp((adjustedY - ColorCanvas.AbsolutePosition.Y) / ColorCanvas.AbsoluteSize.Y, 0, 1)
            currentSat = relX
            currentVal = 1 - relY
            ColorSelector.Position = UDim2.new(relX, -5, relY, -5)
            UpdateColorFromHSV()
        end
        if draggingHue then
            local mouse = UserInputService:GetMouseLocation()
            local adjustedY = mouse.Y - guiInset.Y
            local relY = math.clamp((adjustedY - HueBar.AbsolutePosition.Y) / HueBar.AbsoluteSize.Y, 0, 1)
            currentHue = relY
            HueSelector.Position = UDim2.new(0, -2, relY, -3)
            UpdateColorFromHSV()
        end
    end)
    
    ApplyBtn.MouseButton1Click:Connect(function()
        local color = Color3.fromHSV(currentHue, currentSat, currentVal)
        UpdateMenuColor(color)
    end)
    
    SectionLabel(SettingsMain, "Controls")
    ActionButton(SettingsMain, "Reset Character", Color3.fromRGB(180, 120, 50), function()
        pcall(function() LocalPlayer.Character:BreakJoints() end)
    end)
    
    Tabs["Combat"].Button.BackgroundTransparency = 0.7
    Tabs["Combat"].Label.TextColor3 = Color3.new(1, 1, 1)
    Tabs["Combat"].Icon.TextColor3 = Color3.fromRGB(100, 180, 255)
    Tabs["Combat"].Indicator.Visible = true
    CurrentTab = "Combat"
    
    for _, c in pairs(SubTabHolder:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
    local firstSub = nil
    for subName, _ in pairs(Pages["Combat"]) do
        local SubTab = Instance.new("TextButton", SubTabHolder)
        SubTab.Size = UDim2.new(0, 85, 0, 25)
        SubTab.BackgroundTransparency = 1
        SubTab.Text = subName
        SubTab.TextColor3 = Color3.fromRGB(100, 100, 120)
        SubTab.Font = Enum.Font.GothamSemibold; SubTab.TextSize = 11
        
        local Underline = Instance.new("Frame", SubTab)
        Underline.Size = UDim2.new(0.8, 0, 0, 2)
        Underline.Position = UDim2.new(0.1, 0, 1, -2)
        Underline.BackgroundColor3 = Color3.fromRGB(200, 70, 70)
        Underline.BorderSizePixel = 0
        Underline.Visible = false
        
        SubTab.MouseEnter:Connect(function()
            if SubTab.TextColor3 ~= Color3.new(1, 1, 1) then
                TweenService:Create(SubTab, TweenInfo.new(0.1), {TextColor3 = Color3.fromRGB(180, 180, 200)}):Play()
            end
        end)
        SubTab.MouseLeave:Connect(function()
            if SubTab.TextColor3 ~= Color3.new(1, 1, 1) then
                TweenService:Create(SubTab, TweenInfo.new(0.1), {TextColor3 = Color3.fromRGB(100, 100, 120)}):Play()
            end
        end)
        
        SubTab.MouseButton1Click:Connect(function()
            for _, st in pairs(SubTabHolder:GetChildren()) do
                if st:IsA("TextButton") then 
                    st.TextColor3 = Color3.fromRGB(100, 100, 120)
                    local ul = st:FindFirstChild("Frame")
                    if ul then ul.Visible = false end
                end
            end
            SubTab.TextColor3 = Color3.new(1, 1, 1)
            Underline.Visible = true
            for _, p in pairs(ContentHolder:GetChildren()) do p.Visible = false end
            if Pages["Combat"][subName] then Pages["Combat"][subName].Visible = true end
        end)
        if not firstSub then 
            firstSub = subName
            SubTab.TextColor3 = Color3.new(1, 1, 1)
            Underline.Visible = true
        end
    end
    if firstSub and Pages["Combat"][firstSub] then Pages["Combat"][firstSub].Visible = true end
    
    local isHidden = false
    local isAnimating = false
    local originalPos = Main.Position
    
    local function ToggleMenu()
        if isAnimating then return end
        isAnimating = true
        if isHidden then
            Main.Visible = true
            Main.Position = UDim2.new(0.5, -290, 1.2, 0)
            TweenService:Create(Main, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Position = originalPos
            }):Play()
            TweenService:Create(Shadow, TweenInfo.new(0.3), {ImageTransparency = 0.5}):Play()
            task.wait(0.5)
            isHidden = false
        else
            TweenService:Create(Main, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, -290, 1.2, 0)
            }):Play()
            TweenService:Create(Shadow, TweenInfo.new(0.2), {ImageTransparency = 1}):Play()
            task.wait(0.4)
            Main.Visible = false
            isHidden = true
        end
        isAnimating = false
    end
    
    UserInputService.InputBegan:Connect(function(i, g)
        if not g then
            if i.KeyCode == Enum.KeyCode.Insert then ToggleMenu()
            elseif i.KeyCode == Enum.KeyCode.RightShift then Main.Visible = not Main.Visible end
        end
    end)
    
    return SG
end

Bypass:Init()
CreateUI()
print("╔═══════════════════════════════════════════════════════════╗")
print("║              EZWIN v3.0 - SUCCESSFULLY LOADED             ║")
print("║━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━║")
print("║  Insert = Animated Toggle | RightShift = Quick Toggle     ║")
print("╚═══════════════════════════════════════════════════════════╝")
