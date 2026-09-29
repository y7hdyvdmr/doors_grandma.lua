--[[
    ╔══════════════════════════════════════════════════════════╗
    ║   DOORS HELPER v3.0 — Исправленный помощник              ║
    ║   Работает с актуальной структурой Doors                 ║
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
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local LocalPlayer  = Players.LocalPlayer
local PlayerGui    = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
--                    НАСТРОЙКИ
-- ============================================================
local CONFIG = {
    ShowBigWarnings    = true,
    ShowChatHints      = true,
    ShowLog            = true,
    ShowHealthBar      = true,
    ShowSessionTimer   = true,
    AutoHints          = true,
    AutoHintInterval   = 30,
    PlaySoundOnThreat  = true,
    SoundVolume        = 0.6,

    HighlightDoors     = true,
    HighlightKeys      = true,
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
    WarnHalt           = true,
    WarnTimothy        = true,

    ChatPrefix         = "[🧭 Помощник]",
    WarningDuration    = 3,
}

-- ============================================================
--                    СОСТОЯНИЕ
-- ============================================================
local State = {
    CurrentRoom       = 1,
    HighestRoom       = 1,
    LastWarnedEntity  = nil,
    LastAutoHintTime  = tick(),
    SessionStart      = tick(),
    DetectedEntities  = {},
    HighlightedObjs   = {},
    SurviveCounts     = {Rush = 0, Ambush = 0, Screech = 0, Figure = 0, Seek = 0, Halt = 0, Eyes = 0, Hide = 0, Dupe = 0, Glitch = 0},
    LastSeenEntity    = {},
    CustomHints       = {
        [1]   = "🔑 Найди зажигалку/ключ, если темно. Иди к двери!",
        [2]   = "🚪 Тёмная комната. Ищи источник света. Осторожно — Скрич!",
        [5]   = "🖼️ Здесь может быть картина. Зажми взгляд на 3 сек.",
        [25]  = "🚪 Большой зал. Ищи монеты, ключ где-то в ящиках.",
        [33]  = "🌊 SEEK! БЕГИ ПО КОРИДОРУ!",
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

-- ИСПРАВЛЕНО: Получаем номер комнаты через ReplicatedStorage.GameData.LatestRoom[reference:2][reference:3]
local function getRoomNumber()
    local ok, val = pcall(function()
        return game:GetService("ReplicatedStorage").GameData.LatestRoom.Value
    end)
    if ok and type(val) == "number" then
        return val
    end
    return State.CurrentRoom
end

local function formatTime(seconds)
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    return string.format("%d:%02d", m, s)
end

-- ============================================================
--         ЗВУКОВОЙ СИГНАЛ
-- ============================================================
local threatSound
local function playThreatSound()
    if not CONFIG.PlaySoundOnThreat then return end
    if not threatSound or not threatSound.Parent then
        threatSound = Instance.new("Sound")
        threatSound.SoundId = "rbxassetid://131961136"
        threatSound.Volume = CONFIG.SoundVolume
        threatSound.Parent = SoundService
    end
    pcall(function() threatSound:Play() end)
end

-- ============================================================
--                    UI (логика лог-оверлея и кнопок)
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
    stroke.Color = color; stroke.Thickness = 1; stroke.Transparency = 0.6
    table.insert(activeLogs, lbl)
    if #activeLogs > 5 then
        local old = table.remove(activeLogs, 1)
        pcall(function() old:Destroy() end)
    end
    task.spawn(function()
        task.wait(6)
        pcall(function()
            TweenService:Create(lbl, TweenInfo.new(0.5), {BackgroundTransparency = 1, TextTransparency = 1}):Play()
        end)
        task.wait(0.6)
        for i, l in ipairs(activeLogs) do if l == lbl then table.remove(activeLogs, i); break end end
        pcall(function() lbl:Destroy() end)
    end)
end

-- Кнопка и панель (сокращённо, логика та же)
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

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1, 0, 0, 26)
titleLbl.Position = UDim2.new(0, 0, 0, y)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "🚪 DOORS HELPER v3.0"
titleLbl.TextColor3 = Color3.fromRGB(255, 200, 150)
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 14
titleLbl.Parent = panel
y = y + 32

-- ============================================================
--                    HUD (правый верх)
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
--            ГЛАВНАЯ ЛОГИКА: ПОДСКАЗКИ + ОБНАРУЖЕНИЕ
-- ============================================================
local function say(text)
    if not CONFIG.ShowChatHints then return end
    pcall(function()
        game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
            Text = CONFIG.ChatPrefix .. " " .. text,
            Color = Color3.fromRGB(150, 220, 255),
            Font = Enum.Font.GothamBold,
        })
    end)
    pcall(pushLog, text, Color3.fromRGB(150, 220, 255))
end

local function getHintForRoom(room)
    return State.CustomHints[room] or State.DefaultHint
end

local function sayCurrentHint()
    local hint = getHintForRoom(State.CurrentRoom)
    say(hint)
    hintLbl.Text = hint:sub(1, 40)
end

-- Таблица сущностей с подсказками
local ENTITY_DATA = {
    ["Rush"]     = {text = "🏃 RUSH! БЕГИ В ШКАФ!",       color = Color3.fromRGB(255, 50, 50)},
    ["Ambush"]   = {text = "👥 AMBUSH! НЕ ВЫХОДИ!",       color = Color3.fromRGB(255, 30, 30)},
    ["Screech"]  = {text = "👂 SCREECH! СМОТРИ!",        color = Color3.fromRGB(180, 100, 255)},
    ["Eyes"]     = {text = "👁 EYES! НЕ СМОТРИ!",        color = Color3.fromRGB(150, 200, 255)},
    ["Dupe"]     = {text = "🌀 DUPE! НЕ ОТКРЫВАЙ!",      color = Color3.fromRGB(255, 200, 60)},
    ["Hide"]     = {text = "🙈 HIDE! НЕ ВЫХОДИ РАНО!",   color = Color3.fromRGB(120, 60, 60)},
    ["Glitch"]   = {text = "📺 GLITCH! ОСТОРОЖНО!",      color = Color3.fromRGB(255, 60, 180)},
    ["Figure"]   = {text = "👺 FIGURE! ИДИ ШАГОМ!",      color = Color3.fromRGB(150, 0, 0)},
    ["Seek"]     = {text = "🕷 SEEK! БЕГИ!",             color = Color3.fromRGB(255, 100, 50)},
    ["Halt"]     = {text = "👻 HALT! ИДИ НАЗАД!",        color = Color3.fromRGB(100, 200, 255)},
    ["Timothy"]  = {text = "🕷 TIMOTHY! ОТКРОЙ ЯЩИК!",   color = Color3.fromRGB(200, 100, 100)},
}

-- ИСПРАВЛЕНО: Ищем сущности в workspace.CurrentRooms, а не в корне Workspace[reference:4][reference:5]
local function scanForEntities()
    local found = {}
    local currentRooms = Workspace:FindFirstChild("CurrentRooms")
    if not currentRooms then return found end

    for _, obj in ipairs(currentRooms:GetDescendants()) do
        if ENTITY_DATA[obj.Name] then
            found[obj.Name] = true
        end
    end
    State.DetectedEntities = found
    return found
end

local function checkSurvive(entityName)
    if not State.LastSeenEntity[entityName] then return end
    if not State.DetectedEntities[entityName] then
        local hum = getHum()
        if hum and hum.Health > 0 then
            State.SurviveCounts[entityName] = (State.SurviveCounts[entityName] or 0) + 1
        end
        State.LastSeenEntity[entityName] = false
    end
end

-- ============================================================
--            ГЛАВНЫЙ ЦИКЛ
-- ============================================================
local lastRoomCheck = 0
local function tickHelper()
    local now = tick()

    -- 1. Определение комнаты (через GameData.LatestRoom)
    if now - lastRoomCheck > 0.5 then
        lastRoomCheck = now
        local roomNum = getRoomNumber()
        if roomNum ~= State.CurrentRoom then
            State.CurrentRoom = roomNum
            if roomNum > State.HighestRoom then State.HighestRoom = roomNum end
            if roomLbl then roomLbl.Text = "🚪 Комната: " .. State.CurrentRoom end
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
    local priority = {"Ambush", "Rush", "Seek", "Figure", "Halt", "Eyes", "Screech", "Hide", "Dupe", "Glitch", "Timothy"}
    local activeWarn = nil
    for _, name in ipairs(priority) do
        if ents[name] and ENTITY_DATA[name] then
            local enabled = true
            -- Проверка настроек
            if name == "Rush" then enabled = CONFIG.WarnRush
            elseif name == "Ambush" then enabled = CONFIG.WarnAmbush
            elseif name == "Screech" then enabled = CONFIG.WarnScreech
            elseif name == "Eyes" then enabled = CONFIG.WarnEyes
            elseif name == "Dupe" then enabled = CONFIG.WarnDupe
            elseif name == "Hide" then enabled = CONFIG.WarnHide
            elseif name == "Glitch" then enabled = CONFIG.WarnGlitch
            elseif name == "Figure" then enabled = CONFIG.WarnFigure
            elseif name == "Seek" then enabled = CONFIG.WarnSeek
            elseif name == "Halt" then enabled = CONFIG.WarnHalt
            elseif name == "Timothy" then enabled = CONFIG.WarnTimothy
            end
            if enabled then
                activeWarn = {name = name, text = ENTITY_DATA[name].text, color = ENTITY_DATA[name].color}
                break
            end
        end
    end

    if activeWarn and activeWarn.name ~= State.LastWarnedEntity then
        State.LastWarnedEntity = activeWarn.name
        -- Показываем большое предупреждение
        warningLbl.Text = activeWarn.text
        warningLbl.TextColor3 = activeWarn.color
        warningLbl.TextTransparency = 0
        TweenService:Create(warningLbl, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
        task.spawn(function()
            task.wait(3)
            TweenService:Create(warningLbl, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
        end)
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
        local hum = getHum()
        if hum and hpFill then
            local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            hpFill.Size = UDim2.new(pct, 0, 1, 0)
            hpText.Text = string.format("%d/%d", math.floor(hum.Health), math.floor(hum.MaxHealth))
            if pct > 0.5 then hpFill.BackgroundColor3 = Color3.fromRGB(60, 200, 80)
            elseif pct > 0.25 then hpFill.BackgroundColor3 = Color3.fromRGB(230, 180, 60)
            else hpFill.BackgroundColor3 = Color3.fromRGB(220, 50, 50) end
        end
    end
end

-- Оверлей для предупреждений
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

-- Запуск
mainBtn.Activated:Connect(function() panel.Visible = not panel.Visible end)
local helperConn = RunService.Heartbeat:Connect(function(dt) pcall(tickHelper) end)

task.wait(0.5)
say("✅ Doors Helper v3.0 загружен!")
task.wait(2)
sayCurrentHint()

function DH.unload()
    if helperConn then pcall(function() helperConn:Disconnect() end) end
    if screenGui then pcall(function() screenGui:Destroy() end) end
    GENV._DoorsHelper = nil
    shared.DOORS_HELPER = nil
end

print("[Doors Helper v3.0] Загружено.")
