--[[
    ╔══════════════════════════════════════════════════════════╗
    ║   DOORS HELPER v2.0 — Расширенный помощник в Doors       ║
    ║   Подсказки / Предупреждения / Подсветка / Статистика    ║
    ╚══════════════════════════════════════════════════════════╝
--]]

local GENV = rawget(_G, "getgenv") and getgenv() or _G
if GENV._DoorsHelper and GENV._DoorsHelper.unload then pcall(GENV._DoorsHelper.unload) end

local DH = {}
GENV._DoorsHelper = DH
shared.DOORS_HELPER = DH

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local Workspace    = game:GetService("Workspace")
local Lighting     = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local UserInput    = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local LocalPlayer  = Players.LocalPlayer
local PlayerGui    = LocalPlayer:WaitForChild("PlayerGui")
local Camera       = Workspace.CurrentCamera

-- ============================================================
--                    НАСТРОЙКИ
-- ============================================================
local CONFIG = {
    ShowBigWarnings    = true,
    ShowChatHints      = true,
    ShowRoomNumber     = true,
    ShowHealthBar      = true,
    ShowSessionTimer   = true,
    ShowSurviveCount   = true,
    ShowLog            = true,
    AutoHints          = true,
    AutoHintInterval   = 30,     -- сек
    PlaySoundOnThreat  = true,
    SoundVolume        = 0.6,

    HighlightDoors     = true,
    HighlightKeys      = true,
    HighlightCoins     = true,
    HighlightHideSpots = true,
    HighlightNearestHide = true,

    WarnRush           = true,
    WarnAmbush         = true,
    WarnScreech        = true,
    WarnEyes           = true,
    WarnDupe           = true,
    WarnHide           = true,
    WarnGlitch         = true,
    WarnFigure         = true,
    WarnSeek           = true,

    ChatPrefix         = "[🧭 Помощник]",
    WarningDuration    = 3,
    CheckInterval      = 0.15,
}

-- ============================================================
--                    СОСТОЯНИЕ
-- ============================================================
local State = {
    CurrentRoom       = 1,
    HighestRoom       = 1,
    LastRoom          = 0,
    LastWarnedEntity  = nil,
    LastWarnTime      = 0,
    LastAutoHintTime  = tick(),
    SessionStart      = tick(),
    DetectedEntities  = {},
    HighlightedObjs   = {},
    SurviveCounts     = {Rush = 0, Ambush = 0, Screech = 0, Hide = 0, Eyes = 0, Figure = 0, Seek = 0, Dupe = 0, Glitch = 0},
    LastSeenEntity    = {},
    CustomHints       = {
        [1]   = "🔑 Найди зажигалку/ключ, если темно. Иди к двери!",
        [2]   = "🚪 Тёмная комната. Ищи источник света. Осторожно — Скрич!",
        [5]   = "🖼️ Здесь может быть картина. Зажми взгляд на 3 сек.",
        [25]  = "🚪 Большой зал. Ищи монеты, ключ где-то в ящиках.",
        [50]  = "👹 FIGURE! Не беги, иди шагом. Прячься в шкафах!",
        [75]  = "⚡ Активируй электрические щиты если они есть.",
        [100] = "🏁 FIGURE снова! Иди шагом между шкафами. Финал игры!",
    },
    DefaultHint = "🔍 Осмотрись. Ищи ключ, свечи, монеты. Осторожно с сущностями!",
}

-- ============================================================
--                    ХЕЛПЕРЫ
-- ============================================================
local function getSafeParent()
    if rawget(GENV, "gethui") then
        local ok, hui = pcall(GENV.gethui)
        if ok and hui then return hui end
    end
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then return cg end
    return PlayerGui
end

local function protectGui(gui)
    if syn and syn.protect_gui then pcall(syn.protect_gui, gui)
    elseif rawget(GENV, "protect_gui") then pcall(GENV.protect_gui, gui) end
end

local function getChar() return LocalPlayer.Character end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function getHRP()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function detectRoomNumber()
    local highest = 0
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") or obj:IsA("Folder") then
            local n = obj.Name:match("^Room%s*(%d+)")
            if n then
                local num = tonumber(n)
                if num and num > highest then highest = num end
            end
        end
    end
    return highest > 0 and highest or State.CurrentRoom
end

local function formatTime(seconds)
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    return string.format("%d:%02d", m, s)
end

-- ============================================================
--         ЗВУКОВОЙ СИГНАЛ ПРИ УГРОЗЕ
-- ============================================================
local threatSound
local function playThreatSound()
    if not CONFIG.PlaySoundOnThreat then return end
    if not threatSound or not threatSound.Parent then
        threatSound = Instance.new("Sound")
        threatSound.SoundId = "rbxassetid://131961136"  -- короткий писк
        threatSound.Volume = CONFIG.SoundVolume
        threatSound.Parent = SoundService
    end
    pcall(function() threatSound:Play() end)
end

-- ============================================================
--                    ОВЕРЛЕЙ-ЛОГ
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "_DoorsHelper_" .. tostring(math.random(100000, 999999))
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 999
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
protectGui(screenGui)
local okp = pcall(function() screenGui.Parent = getSafeParent() end)
if not okp or not screenGui.Parent then screenGui.Parent = PlayerGui end

local logContainer = Instance.new("Frame")
logContainer.Size = UDim2.new(0, 340, 0, 220)
logContainer.Position = UDim2.new(0, 10, 1, -240)
logContainer.BackgroundTransparency = 1
logContainer.Parent = screenGui

local logLayout = Instance.new("UIListLayout")
logLayout.SortOrder = Enum.SortOrder.LayoutOrder
logLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
logLayout.Padding = UDim.new(0, 4)
logLayout.Parent = logContainer

local activeLogs = {}

local function pushLog(text, color)
    if not CONFIG.ShowLog then return end
    color = color or Color3.fromRGB(150, 220, 255)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 24)
    lbl.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    lbl.BackgroundTransparency = 0.2
    lbl.BorderSizePixel = 0
    lbl.Text = " " .. text
    lbl.TextColor3 = color
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextWrapped = true
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.Parent = logContainer
    Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", lbl)
    stroke.Color = color
    stroke.Thickness = 1
    stroke.Transparency = 0.6
    table.insert(activeLogs, lbl)
    if #activeLogs > 5 then
        local old = table.remove(activeLogs, 1)
        pcall(function() old:Destroy() end)
    end
    task.spawn(function()
        task.wait(6)
        pcall(function()
            TweenService:Create(lbl, TweenInfo.new(0.5), {
                BackgroundTransparency = 1, TextTransparency = 1,
            }):Play()
        end)
        task.wait(0.6)
        for i, l in ipairs(activeLogs) do
            if l == lbl then table.remove(activeLogs, i); break end
        end
        pcall(function() lbl:Destroy() end)
    end)
end

-- ============================================================
--                    КНОПКА
-- ============================================================
local mainBtn = Instance.new("TextButton")
mainBtn.Size = UDim2.new(0, 52, 0, 52)
mainBtn.Position = UDim2.new(0, 20, 0, 240)
mainBtn.BackgroundColor3 = Color3.fromRGB(40, 25, 25)
mainBtn.TextColor3 = Color3.fromRGB(255, 220, 200)
mainBtn.Font = Enum.Font.GothamBold
mainBtn.TextSize = 22
mainBtn.Text = "🚪"
mainBtn.AutoButtonColor = false
mainBtn.Parent = screenGui
Instance.new("UICorner", mainBtn).CornerRadius = UDim.new(0, 14)
local mStroke = Instance.new("UIStroke", mainBtn)
mStroke.Color = Color3.fromRGB(255, 140, 80); mStroke.Thickness = 1.5

-- ============================================================
--                    ПАНЕЛЬ
-- ============================================================
local panel = Instance.new("ScrollingFrame")
panel.Size = UDim2.new(0, 300, 0, 640)
panel.Position = UDim2.new(0, 82, 0, 10)
panel.BackgroundColor3 = Color3.fromRGB(25, 18, 18)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Visible = false
panel.CanvasSize = UDim2.new(0, 0, 0, 0)
panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
panel.ScrollBarThickness = 3
panel.ScrollBarImageColor3 = Color3.fromRGB(255, 150, 80)
panel.Parent = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
local pStroke = Instance.new("UIStroke", panel)
pStroke.Color = Color3.fromRGB(200, 100, 60); pStroke.Thickness = 1

local y = 6
local function makeSection(text, color)
    local s = Instance.new("TextLabel")
    s.Size = UDim2.new(1, -20, 0, 26)
    s.Position = UDim2.new(0, 10, 0, y)
    s.BackgroundColor3 = color or Color3.fromRGB(70, 45, 45)
    s.BackgroundTransparency = 0.4
    s.BorderSizePixel = 0
    s.Text = "▸ " .. text
    s.TextColor3 = Color3.fromRGB(255, 220, 200)
    s.Font = Enum.Font.GothamBold
    s.TextSize = 12
    s.TextXAlignment = Enum.TextXAlignment.Left
    s.Parent = panel
    Instance.new("UICorner", s).CornerRadius = UDim.new(0, 6)
    y = y + 30
end

local function makeBtn(text, bg, fg, h)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -20, 0, h or 32)
    b.Position = UDim2.new(0, 10, 0, y)
    b.BackgroundColor3 = bg or Color3.fromRGB(50, 35, 35)
    b.TextColor3 = fg or Color3.fromRGB(240, 220, 220)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Text = text
    b.Parent = panel
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    y = y + (h or 32) + 4
    return b
end

local function makeToggle(text, getter, setter)
    local b = makeBtn(text)
    local function upd()
        local v = getter()
        b.Text = text .. ": " .. (v and "ВКЛ" or "ВЫКЛ")
        if v then b.BackgroundColor3 = Color3.fromRGB(35, 60, 45)
        else b.BackgroundColor3 = Color3.fromRGB(50, 40, 45) end
    end
    upd()
    b.Activated:Connect(function() setter(not getter()); upd() end)
    return b
end

-- Заголовок
local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1, 0, 0, 26)
titleLbl.Position = UDim2.new(0, 0, 0, y)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "🚪 DOORS HELPER v2.0"
titleLbl.TextColor3 = Color3.fromRGB(255, 200, 150)
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 14
titleLbl.Parent = panel
y = y + 32

-- ============================================================
--                    UI СЕКЦИИ
-- ============================================================
makeSection("📊  СТАТИСТИКА", Color3.fromRGB(60, 60, 100))
local statsLbl = Instance.new("TextLabel")
statsLbl.Size = UDim2.new(1, -20, 0, 70)
statsLbl.Position = UDim2.new(0, 10, 0, y)
statsLbl.BackgroundColor3 = Color3.fromRGB(30, 25, 40)
statsLbl.BackgroundTransparency = 0.2
statsLbl.BorderSizePixel = 0
statsLbl.Text = "Загрузка..."
statsLbl.TextColor3 = Color3.fromRGB(220, 220, 255)
statsLbl.Font = Enum.Font.GothamBold
statsLbl.TextSize = 11
statsLbl.TextXAlignment = Enum.TextXAlignment.Left
statsLbl.TextYAlignment = Enum.TextYAlignment.Top
statsLbl.Parent = panel
Instance.new("UICorner", statsLbl).CornerRadius = UDim.new(0, 6)
y = y + 74

makeSection("📢  ПОДСКАЗКИ", Color3.fromRGB(80, 60, 100))
local sayHintBtn = makeBtn("💬 Сказать подсказку сейчас", Color3.fromRGB(55, 40, 80), Color3.fromRGB(200, 180, 255))
local showRoomBtn = makeBtn("📍 Показать номер комнаты", Color3.fromRGB(45, 60, 80), Color3.fromRGB(180, 220, 255))
local sosBtn = makeBtn("🆘 SOS — БЫСТРАЯ ПОМОЩЬ", Color3.fromRGB(120, 40, 40), Color3.fromRGB(255, 200, 200))

local hintInput = Instance.new("TextBox")
hintInput.Size = UDim2.new(1, -20, 0, 30)
hintInput.Position = UDim2.new(0, 10, 0, y)
hintInput.BackgroundColor3 = Color3.fromRGB(40, 30, 30)
hintInput.TextColor3 = Color3.fromRGB(240, 220, 220)
hintInput.Font = Enum.Font.Gotham
hintInput.TextSize = 11
hintInput.PlaceholderText = "Своя подсказка для комнаты " .. State.CurrentRoom
hintInput.PlaceholderColor3 = Color3.fromRGB(150, 120, 120)
hintInput.ClearTextOnFocus = false
hintInput.Parent = panel
Instance.new("UICorner", hintInput).CornerRadius = UDim.new(0, 8)
y = y + 34
local setHintBtn = makeBtn("✅ Сохранить подсказку", Color3.fromRGB(35, 60, 45), Color3.fromRGB(160, 255, 180))

makeSection("⚠️  ПРЕДУПРЕЖДЕНИЯ", Color3.fromRGB(120, 40, 40))
makeToggle("👹 Rush", function() return CONFIG.WarnRush end, function(v) CONFIG.WarnRush = v end)
makeToggle("👥 Ambush", function() return CONFIG.WarnAmbush end, function(v) CONFIG.WarnAmbush = v end)
makeToggle("👂 Screech", function() return CONFIG.WarnScreech end, function(v) CONFIG.WarnScreech = v end)
makeToggle("👁 Eyes", function() return CONFIG.WarnEyes end, function(v) CONFIG.WarnEyes = v end)
makeToggle("🌀 Dupe", function() return CONFIG.WarnDupe end, function(v) CONFIG.WarnDupe = v end)
makeToggle("🙈 Hide", function() return CONFIG.WarnHide end, function(v) CONFIG.WarnHide = v end)
makeToggle("📺 Glitch", function() return CONFIG.WarnGlitch end, function(v) CONFIG.WarnGlitch = v end)
makeToggle("👺 Figure", function() return CONFIG.WarnFigure end, function(v) CONFIG.WarnFigure = v end)
makeToggle("🕷 Seek", function() return CONFIG.WarnSeek end, function(v) CONFIG.WarnSeek = v end)

makeSection("🎯  ПОДСВЕТКА", Color3.fromRGB(60, 100, 60))
makeToggle("🚪 Двери", function() return CONFIG.HighlightDoors end, function(v) CONFIG.HighlightDoors = v end)
makeToggle("🔑 Ключи", function() return CONFIG.HighlightKeys end, function(v) CONFIG.HighlightKeys = v end)
makeToggle("💰 Монеты", function() return CONFIG.HighlightCoins end, function(v) CONFIG.HighlightCoins = v end)
makeToggle("🚪 Укрытия", function() return CONFIG.HighlightHideSpots end, function(v) CONFIG.HighlightHideSpots = v end)
makeToggle("🎯 Ближайшее укрытие", function() return CONFIG.HighlightNearestHide end, function(v) CONFIG.HighlightNearestHide = v end)

makeSection("🎨  ОВЕРЛЕИ НА ЭКРАНЕ", Color3.fromRGB(80, 80, 120))
makeToggle("📜 Лог подсказок", function() return CONFIG.ShowLog end, function(v) CONFIG.ShowLog = v end)
makeToggle("❤️ Полоса здоровья", function() return CONFIG.ShowHealthBar end, function(v) CONFIG.ShowHealthBar = v end)
makeToggle("⏱️ Таймер сессии", function() return CONFIG.ShowSessionTimer end, function(v) CONFIG.ShowSessionTimer = v end)
makeToggle("🏆 Счётчик выживаний", function() return CONFIG.ShowSurviveCount end, function(v) CONFIG.ShowSurviveCount = v end)
makeToggle("📍 Номер комнаты", function() return CONFIG.ShowRoomNumber end, function(v) CONFIG.ShowRoomNumber = v end)
makeToggle("💬 Чат-подсказки", function() return CONFIG.ShowChatHints end, function(v) CONFIG.ShowChatHints = v end)
makeToggle("📢 Большие предупреждения", function() return CONFIG.ShowBigWarnings end, function(v) CONFIG.ShowBigWarnings = v end)

makeSection("🔊  ЗВУК И АВТО", Color3.fromRGB(100, 80, 60))
makeToggle("🔊 Звук при угрозе", function() return CONFIG.PlaySoundOnThreat end, function(v) CONFIG.PlaySoundOnThreat = v end)
makeToggle("⏰ Авто-подсказки", function() return CONFIG.AutoHints end, function(v) CONFIG.AutoHints = v end)

local autoHintIntBtn = makeBtn("⏰ Интервал авто: " .. CONFIG.AutoHintInterval .. " сек", Color3.fromRGB(60, 55, 35), Color3.fromRGB(255, 220, 150))
autoHintIntBtn.Activated:Connect(function()
    local steps = {15, 30, 45, 60, 90, 120}
    local idx = 1
    for i, v in ipairs(steps) do if v == CONFIG.AutoHintInterval then idx = i; break end end
    CONFIG.AutoHintInterval = steps[(idx % #steps) + 1]
    autoHintIntBtn.Text = "⏰ Интервал авто: " .. CONFIG.AutoHintInterval .. " сек"
end)

makeSection("🧪  ТЕСТ", Color3.fromRGB(80, 80, 40))
local testRushBtn = makeBtn("🧪 Тест: Rush", Color3.fromRGB(80, 40, 40), Color3.fromRGB(255, 180, 180))
local testAmbushBtn = makeBtn("🧪 Тест: Ambush", Color3.fromRGB(80, 40, 40), Color3.fromRGB(255, 180, 180))
local testScreechBtn = makeBtn("🧪 Тест: Screech", Color3.fromRGB(80, 40, 40), Color3.fromRGB(255, 180, 180))

makeSection("🛠️  СИСТЕМА", Color3.fromRGB(60, 60, 80))
local resetStatsBtn = makeBtn("🗑 Сбросить статистику", Color3.fromRGB(60, 40, 40), Color3.fromRGB(255, 180, 180))
local closeBtn = makeBtn("❌ Закрыть панель", Color3.fromRGB(60, 30, 30), Color3.fromRGB(255, 150, 150))

-- ============================================================
--            ОВЕРЛЕЙ: большие предупреждения
-- ============================================================
local warningLbl = Instance.new("TextLabel")
warningLbl.Size = UDim2.new(1, 0, 0, 100)
warningLbl.Position = UDim2.new(0, 0, 0.15, 0)
warningLbl.BackgroundTransparency = 1
warningLbl.Text = ""
warningLbl.TextColor3 = Color3.fromRGB(255, 60, 60)
warningLbl.Font = Enum.Font.GothamBold
warningLbl.TextSize = 48
warningLbl.TextStrokeTransparency = 0
warningLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
warningLbl.TextTransparency = 1
warningLbl.Parent = screenGui

-- ============================================================
--            ОВЕРЛЕЙ: мини-статистика (правый верх)
-- ============================================================
local hudFrame = Instance.new("Frame")
hudFrame.Size = UDim2.new(0, 220, 0, 110)
hudFrame.Position = UDim2.new(1, -230, 0, 10)
hudFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
hudFrame.BackgroundTransparency = 0.15
hudFrame.BorderSizePixel = 0
hudFrame.Parent = screenGui
Instance.new("UICorner", hudFrame).CornerRadius = UDim.new(0, 10)
local hudStroke = Instance.new("UIStroke", hudFrame)
hudStroke.Color = Color3.fromRGB(255, 150, 80); hudStroke.Thickness = 1.5

local roomLbl = Instance.new("TextLabel")
roomLbl.Size = UDim2.new(1, -12, 0, 22)
roomLbl.Position = UDim2.new(0, 6, 0, 4)
roomLbl.BackgroundTransparency = 1
roomLbl.Text = "🚪 Комната: ?"
roomLbl.TextColor3 = Color3.fromRGB(255, 220, 150)
roomLbl.Font = Enum.Font.GothamBold
roomLbl.TextSize = 13
roomLbl.TextXAlignment = Enum.TextXAlignment.Left
roomLbl.Parent = hudFrame

local timeLbl = Instance.new("TextLabel")
timeLbl.Size = UDim2.new(1, -12, 0, 18)
timeLbl.Position = UDim2.new(0, 6, 0, 26)
timeLbl.BackgroundTransparency = 1
timeLbl.Text = "⏱️ Время: 0:00"
timeLbl.TextColor3 = Color3.fromRGB(180, 220, 255)
timeLbl.Font = Enum.Font.GothamBold
timeLbl.TextSize = 12
timeLbl.TextXAlignment = Enum.TextXAlignment.Left
timeLbl.Parent = hudFrame

local surviveLbl = Instance.new("TextLabel")
surviveLbl.Size = UDim2.new(1, -12, 0, 18)
surviveLbl.Position = UDim2.new(0, 6, 0, 44)
surviveLbl.BackgroundTransparency = 1
surviveLbl.Text = "🏆 Выжил: R:0 A:0"
surviveLbl.TextColor3 = Color3.fromRGB(180, 255, 200)
surviveLbl.Font = Enum.Font.GothamBold
surviveLbl.TextSize = 12
surviveLbl.TextXAlignment = Enum.TextXAlignment.Left
surviveLbl.Parent = hudFrame

-- Полоса здоровья
local hpBg = Instance.new("Frame")
hpBg.Size = UDim2.new(1, -12, 0, 14)
hpBg.Position = UDim2.new(0, 6, 0, 66)
hpBg.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
hpBg.BorderSizePixel = 0
hpBg.Parent = hudFrame
Instance.new("UICorner", hpBg).CornerRadius = UDim.new(0, 4)

local hpFill = Instance.new("Frame")
hpFill.Size = UDim2.new(1, 0, 1, 0)
hpFill.BackgroundColor3 = Color3.fromRGB(60, 200, 80)
hpFill.BorderSizePixel = 0
hpFill.Parent = hpBg
Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 4)

local hpText = Instance.new("TextLabel")
hpText.Size = UDim2.new(1, 0, 1, 0)
hpText.BackgroundTransparency = 1
hpText.Text = "100/100"
hpText.TextColor3 = Color3.fromRGB(255, 255, 255)
hpText.Font = Enum.Font.GothamBold
hpText.TextSize = 10
hpText.Parent = hpBg

local hintLbl = Instance.new("TextLabel")
hintLbl.Size = UDim2.new(1, -12, 0, 18)
hintLbl.Position = UDim2.new(0, 6, 0, 84)
hintLbl.BackgroundTransparency = 1
hintLbl.Text = ""
hintLbl.TextColor3 = Color3.fromRGB(255, 200, 150)
hintLbl.Font = Enum.Font.GothamBold
hintLbl.TextSize = 11
hintLbl.TextXAlignment = Enum.TextXAlignment.Left
hintLbl.Parent = hudFrame

-- ============================================================
--            ФУНКЦИЯ ЧАТА + ЛОГ
-- ============================================================
local function say(text)
    if not CONFIG.ShowChatHints then return end
    local prefix = CONFIG.ChatPrefix .. " "
    pcall(function()
        game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
            Text = prefix .. text,
            Color = Color3.fromRGB(150, 220, 255),
            Font = Enum.Font.GothamBold,
        })
    end)
    pcall(pushLog, text, Color3.fromRGB(150, 220, 255))
end

-- ============================================================
--            БОЛЬШОЕ ПРЕДУПРЕЖДЕНИЕ
-- ============================================================
local function showBigWarning(text, color, duration)
    if not CONFIG.ShowBigWarnings then return end
    color = color or Color3.fromRGB(255, 60, 60)
    warningLbl.Text = text
    warningLbl.TextColor3 = color
    warningLbl.TextTransparency = 0
    warningLbl.Position = UDim2.new(0, 0, 0.15, 0)
    TweenService:Create(warningLbl, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
    pcall(pushLog, text, color)
    task.spawn(function()
        task.wait(duration or CONFIG.WarningDuration)
        TweenService:Create(warningLbl, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
    end)
end

-- ============================================================
--            ЛОГИКА ПОДСКАЗОК
-- ============================================================
local function getHintForRoom(room)
    return State.CustomHints[room] or State.DefaultHint
end

local function sayCurrentHint()
    local hint = getHintForRoom(State.CurrentRoom)
    say(hint)
    hintLbl.Text = hint:sub(1, 40)
end

-- ============================================================
--            ОБНАРУЖЕНИЕ СУЩНОСТЕЙ
-- ============================================================
local ENTITY_NAMES = {
    ["Rush"]     = {text = "🏃 RUSH! БЕГИ В ШКАФ!",       color = Color3.fromRGB(255, 50, 50)},
    ["Ambush"]   = {text = "👥 AMBUSH! НЕ ВЫХОДИ!",       color = Color3.fromRGB(255, 30, 30)},
    ["Screech"]  = {text = "👂 SCREECH! СМОТРИ!",        color = Color3.fromRGB(180, 100, 255)},
    ["Eyes"]     = {text = "👁 EYES! НЕ СМОТРИ!",        color = Color3.fromRGB(150, 200, 255)},
    ["Dupe"]     = {text = "🌀 DUPE! НЕ ОТКРЫВАЙ!",      color = Color3.fromRGB(255, 200, 60)},
    ["Hide"]     = {text = "🙈 HIDE! НЕ ВЫХОДИ РАНО!",   color = Color3.fromRGB(120, 60, 60)},
    ["Glitch"]   = {text = "📺 GLITCH! ОСТОРОЖНО!",      color = Color3.fromRGB(255, 60, 180)},
    ["Figure"]   = {text = "👺 FIGURE! ИДИ ШАГОМ!",      color = Color3.fromRGB(150, 0, 0)},
    ["Seek"]     = {text = "🕷 SEEK! БЕГИ!",             color = Color3.fromRGB(255, 100, 50)},
}

local function scanForEntities()
    local found = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("Part") or obj:IsA("MeshPart") then
            if ENTITY_NAMES[obj.Name] then
                found[obj.Name] = true
            end
        end
    end
    State.DetectedEntities = found
    return found
end

local function checkSurvive(entityName)
    -- Считаем, что если игрок жив и сущность исчезла — он выжил
    if not State.LastSeenEntity[entityName] then return end
    if not State.DetectedEntities[entityName] then
        -- Сущность пропала, если игрок жив — выжил
        local hum = getHum()
        if hum and hum.Health > 0 then
            State.SurviveCounts[entityName] = (State.SurviveCounts[entityName] or 0) + 1
        end
        State.LastSeenEntity[entityName] = false
    end
end

-- ============================================================
--            ПОДСВЕТКА
-- ============================================================
local function clearHighlights()
    for obj, hl in pairs(State.HighlightedObjs) do
        pcall(function()
            if hl and hl.Parent then hl:Destroy() end
        end)
    end
    State.HighlightedObjs = {}
end

local function highlightObject(obj, color, label)
    if State.HighlightedObjs[obj] then return end
    local hl = Instance.new("Highlight")
    hl.FillColor = color
    hl.OutlineColor = color
    hl.FillTransparency = 0.7
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = obj
    State.HighlightedObjs[obj] = hl
end

-- Найти ближайшее укрытие
local function findNearestHide()
    local hrp = getHRP()
    if not hrp then return nil end
    local best, bestDist = nil, math.huge
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("Part") then
            local name = obj.Name:lower()
            if name:find("closet") or name:find("wardrobe") or name:find("bed") or name:find("hide") then
                local base = obj:FindFirstChildWhichIsA("BasePart") or obj.PrimaryPart
                if base then
                    local d = (base.Position - hrp.Position).Magnitude
                    if d < bestDist then best, bestDist = obj, d end
                end
            end
        end
    end
    return best, bestDist
end

local function rescanHighlights()
    if not (CONFIG.HighlightDoors or CONFIG.HighlightKeys or CONFIG.HighlightCoins or CONFIG.HighlightHideSpots) then
        clearHighlights()
        return
    end
    local seen = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("Part") or obj:IsA("MeshPart") then
            seen[obj] = false
            local name = obj.Name:lower()
            if CONFIG.HighlightDoors and (name:find("door") or name:find("дверь")) and not name:find("dupe") then
                highlightObject(obj, Color3.fromRGB(100, 200, 255), "🚪 Дверь")
                seen[obj] = true
            elseif CONFIG.HighlightKeys and (name:find("key") or name:find("ключ")) then
                highlightObject(obj, Color3.fromRGB(255, 220, 80), "🔑 Ключ")
                seen[obj] = true
            elseif CONFIG.HighlightCoins and (name:find("coin") or name:find("gold") or name:find("money")) then
                highlightObject(obj, Color3.fromRGB(255, 200, 60), "💰")
                seen[obj] = true
            elseif CONFIG.HighlightHideSpots and (name:find("closet") or name:find("wardrobe") or name:find("bed") or name:find("hide")) then
                highlightObject(obj, Color3.fromRGB(150, 255, 150), "🚪 Укрытие")
                seen[obj] = true
            end
        end
    end
    for obj, hl in pairs(State.HighlightedObjs) do
        if not obj.Parent or (seen[obj] == false) then
            pcall(function() hl:Destroy() end)
            State.HighlightedObjs[obj] = nil
        end
    end

    -- Ближайшее укрытие — особая подсветка
    if CONFIG.HighlightNearestHide then
        local nearest = findNearestHide()
        if nearest then
            highlightObject(nearest, Color3.fromRGB(80, 255, 80), "🎯 БЛИЖАЙШЕЕ УКРЫТИЕ")
        end
    end
end

-- ============================================================
--            ГЛАВНЫЙ ЦИКЛ
-- ============================================================
local lastRoomDetect = 0
local function tickHelper()
    local now = tick()

    -- 1. Определение комнаты
    if now - lastRoomDetect > 0.5 then
        lastRoomDetect = now
        local detected = detectRoomNumber()
        if detected > State.CurrentRoom then
            State.CurrentRoom = detected
            if detected > State.HighestRoom then State.HighestRoom = detected end
            if roomLbl then roomLbl.Text = "🚪 Комната: " .. State.CurrentRoom end
            hintInput.PlaceholderText = "Своя подсказка для комнаты " .. State.CurrentRoom
            if State.CustomHints[State.CurrentRoom] then
                say(getHintForRoom(State.CurrentRoom))
            end
        end
    end

    -- 2. Обнаружение сущностей
    local ents = scanForEntities()
    for entName in pairs(State.LastSeenEntity) do
        checkSurvive(entName)
    end
    for entName in pairs(ents) do
        State.LastSeenEntity[entName] = true
    end

    -- 3. Приоритетные предупреждения
    local priority = {"Ambush", "Rush", "Seek", "Figure", "Eyes", "Screech", "Hide", "Dupe", "Glitch"}
    local activeWarn = nil
    for _, name in ipairs(priority) do
        if ents[name] and ENTITY_NAMES[name] then
            local cfg = ENTITY_NAMES[name]
            local enabled = true
            if name == "Rush" then enabled = CONFIG.WarnRush
            elseif name == "Ambush" then enabled = CONFIG.WarnAmbush
            elseif name == "Screech" then enabled = CONFIG.WarnScreech
            elseif name == "Eyes" then enabled = CONFIG.WarnEyes
            elseif name == "Dupe" then enabled = CONFIG.WarnDupe
            elseif name == "Hide" then enabled = CONFIG.WarnHide
            elseif name == "Glitch" then enabled = CONFIG.WarnGlitch
            elseif name == "Figure" then enabled = CONFIG.WarnFigure
            elseif name == "Seek" then enabled = CONFIG.WarnSeek
            end
            if enabled then
                activeWarn = {name = name, text = cfg.text, color = cfg.color}
                break
            end
        end
    end

    if activeWarn and activeWarn.name ~= State.LastWarnedEntity then
        State.LastWarnedEntity = activeWarn.name
        showBigWarning(activeWarn.text, activeWarn.color, 3)
        say(activeWarn.text)
        playThreatSound()
    elseif not activeWarn then
        State.LastWarnedEntity = nil
    end

    -- 4. Автоподсказки
    if CONFIG.AutoHints and now - State.LastAutoHintTime > CONFIG.AutoHintInterval then
        State.LastAutoHintTime = now
        sayCurrentHint()
    end

    -- 5. Обновление HUD
    if now - (State.LastHudUpdate or 0) > 0.3 then
        State.LastHudUpdate = now

        if timeLbl then
            timeLbl.Text = "⏱️ Время: " .. formatTime(now - State.SessionStart)
        end
        if surviveLbl then
            surviveLbl.Text = string.format("🏆 R:%d A:%d S:%d",
                State.SurviveCounts.Rush or 0,
                State.SurviveCounts.Ambush or 0,
                State.SurviveCounts.Screech or 0)
        end

        -- HP-бар
        local hum = getHum()
        if hum and hpFill then
            local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            hpFill.Size = UDim2.new(pct, 0, 1, 0)
            hpText.Text = string.format("%d/%d", math.floor(hum.Health), math.floor(hum.MaxHealth))
            if pct > 0.5 then hpFill.BackgroundColor3 = Color3.fromRGB(60, 200, 80)
            elseif pct > 0.25 then hpFill.BackgroundColor3 = Color3.fromRGB(230, 180, 60)
            else hpFill.BackgroundColor3 = Color3.fromRGB(220, 50, 50) end
        end

        -- Стата в панели
        if statsLbl then
            statsLbl.Text = string.format(
                "🚪 Текущая комната: %d\n🎯 Рекорд: %d\n⏱️ Время: %s\n👹 Rush: %d | 👥 Ambush: %d\n👂 Screech: %d",
                State.CurrentRoom, State.HighestRoom,
                formatTime(now - State.SessionStart),
                State.SurviveCounts.Rush or 0,
                State.SurviveCounts.Ambush or 0,
                State.SurviveCounts.Screech or 0
            )
        end
    end
end

-- ============================================================
--            ОБРАБОТЧИКИ UI
-- ============================================================
mainBtn.Activated:Connect(function() panel.Visible = not panel.Visible end)
closeBtn.Activated:Connect(function() panel.Visible = false end)

sayHintBtn.Activated:Connect(function()
    sayCurrentHint()
    sayHintBtn.Text = "✅ Отправлено!"
    task.wait(1)
    sayHintBtn.Text = "💬 Сказать подсказку сейчас"
end)

showRoomBtn.Activated:Connect(function()
    say("📍 Мы в комнате " .. State.CurrentRoom .. " (рекорд: " .. State.HighestRoom .. ")")
end)

sosBtn.Activated:Connect(function()
    local msg = "🆘 SOS! Комната " .. State.CurrentRoom
    say(msg)
    showBigWarning("🆘 SOS! Комната " .. State.CurrentRoom, Color3.fromRGB(255, 200, 60), 2)
end)

setHintBtn.Activated:Connect(function()
    local txt = hintInput.Text
    if txt and txt ~= "" then
        State.CustomHints[State.CurrentRoom] = txt
        say("✏️ Подсказка для комнаты " .. State.CurrentRoom .. " сохранена")
        hintInput.Text = ""
    end
end)

testRushBtn.Activated:Connect(function()
    showBigWarning("🏃 RUSH! БЕГИ В ШКАФ!", Color3.fromRGB(255, 50, 50), 3)
    playThreatSound()
end)
testAmbushBtn.Activated:Connect(function()
    showBigWarning("👥 AMBUSH! НЕ ВЫХОДИ!", Color3.fromRGB(255, 30, 30), 3)
    playThreatSound()
end)
testScreechBtn.Activated:Connect(function()
    showBigWarning("👂 SCREECH! СМОТРИ!", Color3.fromRGB(180, 100, 255), 3)
    playThreatSound()
end)

resetStatsBtn.Activated:Connect(function()
    State.SurviveCounts = {Rush = 0, Ambush = 0, Screech = 0, Hide = 0, Eyes = 0, Figure = 0, Seek = 0, Dupe = 0, Glitch = 0}
    State.SessionStart = tick()
    State.HighestRoom = State.CurrentRoom
    say("🗑 Статистика сброшена")
end)

-- Перетаскивание кнопки
local dragging, dragStart, startPos = false, nil, nil
mainBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = input.Position; startPos = mainBtn.Position
    end
end)
mainBtn.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
        local d = input.Position - dragStart
        mainBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
mainBtn.InputEnded:Connect(function() dragging = false end)

-- ============================================================
--            ЗАПУСК
-- ============================================================
local helperConn = RunService.Heartbeat:Connect(function(dt)
    pcall(tickHelper)
end)

local highlightConn = RunService.Heartbeat:Connect(function(dt)
    pcall(rescanHighlights)
end)

-- Проверка респавна (сброс состояния)
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    say("🔄 Респавн! Комната " .. State.CurrentRoom)
end)

task.wait(0.5)
say("✅ Doors Helper v2.0 загружен!")
say("📍 Комната: " .. detectRoomNumber())

task.wait(2)
sayCurrentHint()

-- ============================================================
--            ВЫГРУЗКА
-- ============================================================
function DH.unload()
    if helperConn then pcall(function() helperConn:Disconnect() end) end
    if highlightConn then pcall(function() highlightConn:Disconnect() end) end
    clearHighlights()
    if screenGui then pcall(function() screenGui:Destroy() end) end
    GENV._DoorsHelper = nil
    shared.DOORS_HELPER = nil
end

print("[Doors Helper v2.0] Загружено.")
