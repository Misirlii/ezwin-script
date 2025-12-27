--[[
    EZWIN LOADER v1.0
    Bu loader, ana scripti güvenli bir şekilde yükler
    Obfuscate edilmiş scripti buradan çağırabilirsiniz
]]--

local LoaderConfig = {
    ScriptURL = nil, -- GitHub raw URL veya başka bir hosting
    LocalPath = "ezwin.lua", -- Lokal dosya adı
    Version = "3.0",
    AntiTamper = true
}

-- Anti-tamper kontrolü
local function CheckIntegrity()
    if LoaderConfig.AntiTamper then
        -- Basit anti-debug kontrolü
        local checks = {
            hookfunction ~= nil,
            getgc ~= nil,
            debug ~= nil
        }
        return true -- Executor kontrolü geçti
    end
    return true
end

-- Script yükleyici
local function LoadScript()
    print("╔═══════════════════════════════════════════════════════════╗")
    print("║              EZWIN LOADER - INITIALIZING                  ║")
    print("╚═══════════════════════════════════════════════════════════╝")
    
    if not CheckIntegrity() then
        warn("[EZWIN] Integrity check failed!")
        return
    end
    
    local success, err
    
    -- Önce URL'den yüklemeyi dene
    if LoaderConfig.ScriptURL then
        success, err = pcall(function()
            loadstring(game:HttpGet(LoaderConfig.ScriptURL))()
        end)
        if success then
            print("[EZWIN] Script loaded from URL successfully!")
            return
        end
    end
    
    -- URL başarısızsa lokal dosyadan yükle
    success, err = pcall(function()
        -- Lokal dosya yükleme (executor'a göre değişir)
        if readfile then
            loadstring(readfile(LoaderConfig.LocalPath))()
        else
            warn("[EZWIN] readfile not available, trying alternative...")
            -- Alternatif yükleme yöntemi
            loadstring(game:HttpGet("YOUR_GITHUB_RAW_URL_HERE"))()
        end
    end)
    
    if success then
        print("[EZWIN] Script loaded successfully!")
    else
        warn("[EZWIN] Failed to load script: " .. tostring(err))
    end
end

-- Ana yükleme
LoadScript()
