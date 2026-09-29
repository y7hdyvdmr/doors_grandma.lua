--[[
    ╔══════════════════════════════════════════════════════════╗
    ║   DOORS HELPER v4.0 — Полный помощник с подсказками     ║
    ║   Все монстры (Hotel / Mines / Backdoor / Rooms)        ║
    ╚══════════════════════════════════════════════════════════╝
--]]

local GENV = rawget(_G, "getgenv") and getgenv() or _G
if GENV._DoorsHelper and GENV._DoorsHelper.unload then pcall(GENV._DoorsHelper.unload) end

local DH = {}
GENV._DoorsHelper = DH

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local Workspace    = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local LocalPlayer  = Players.LocalPlayer
local PlayerGui    = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
--                    НАСТРОЙКИ
-- ============================================================
local CONFIG = {
    ShowBigWarnings   = true,
    ShowChatHints     = true,
    ShowLog           = true,
    ShowHealthBar     = true,
    ShowSessionTimer  = true,
    ShowRoomNumber    = true,
    AutoHints         = true,
    AutoHintInterval  = 25,
    PlaySoundOnThreat = true,
    SoundVolume       = 0.5,

    HighlightDoors     = true,
    HighlightKeys      = true,
    HighlightHideSpots = true,
    HighlightNearestHide = true,

    WarnAll = true,
    ChatPrefix = "[🧭 Помощник]",
}

-- ============================================================
--                    ТАБЛИЦА ВСЕХ СУЩНОСТЕЙ
-- ============================================================
local ENTITIES = {
    -- The Hotel / The Mines
    ["rush"]     = {name="Rush",     text="🏃 RUSH! СВЕТ МИГАЕТ! БЕГИ В ШКАФ И ЖДИ!", color=Color3.fromRGB(255,50,50)},
    ["ambush"]   = {name="Ambush",   text="👥 AMBUSH! НЕ ВЫХОДИ ИЗ ШКАФА! ОН ВЕРНЁТСЯ!", color=Color3.fromRGB(255,30,30)},
    ["screech"]  = {name="Screech",  text="👂 SCREECH! ТЫ СЛЫШИШЬ 'PSST'? ОБЕРНИСЬ И ПОСМОТРИ НА НЕГО!", color=Color3.fromRGB(180,100,255)},
    ["eyes"]     = {name="Eyes",     text="👁 EYES! НЕ СМОТРИ НА ГЛАЗА! ОПУСТИ ВЗГЛЯД!", color=Color3.fromRGB(150,200,255)},
    ["dupe"]     = {name="Dupe",     text="🌀 DUPE! ПРОВЕРЬ НОМЕР ДВЕРИ! НЕ ОТКРЫВАЙ ФАЛЬШИВУЮ!", color=Color3.fromRGB(255,200,60)},
    ["hide"]     = {name="Hide",     text="🙈 HIDE! ТЫ СЛИШКОМ ДОЛГО В ШКАФУ! ВЫХОДИ!", color=Color3.fromRGB(120,60,60)},
    ["glitch"]   = {name="Glitch",   text="📺 GLITCH! ТЫ ОТСТАЛ! ДОГОНЯЙ ГРУППУ!", color=Color3.fromRGB(255,60,180)},
    ["figure"]   = {name="Figure",   text="👺 FIGURE! НЕ БЕГИ! ПРИСЯДЬ И ИДИ ТИХО!", color=Color3.fromRGB(150,0,0)},
    ["seek"]     = {name="Seek",     text="🕷 SEEK! БЕГИ ПО СИНЕЙ ДОРОЖКЕ! НЕ ОСТАНАВЛИВАЙСЯ!", color=Color3.fromRGB(255,100,50)},
    ["halt"]     = {name="Halt",     text="👻 HALT! РАЗВЕРНИСЬ И БЕГИ В ОБРАТНУЮ СТОРОНУ!", color=Color3.fromRGB(100,200,255)},
    ["timothy"]  = {name="Timothy",  text="🕷 TIMOTHY! ОСТОРОЖНО С ЯЩИКАМИ! ОН ВЫПРЫГИВАЕТ!", color=Color3.fromRGB(200,100,100)},
    ["jack"]     = {name="Jack",     text="😈 JACK! ОН БЕЗВРЕДЕН, ПРОСТО ПУГАЕТ!", color=Color3.fromRGB(255,100,100)},
    ["snare"]    = {name="Snare",    text="🪤 SNARE! СМОТРИ ПОД НОГИ! НЕ НАСТУПАЙ!", color=Color3.fromRGB(180,120,60)},
    ["giggle"]   = {name="Giggle",   text="😂 GIGGLE! ОН НА ПОТОЛКЕ! НЕ ПРОХОДИ ПОД НИМ!", color=Color3.fromRGB(255,180,80)},
    ["grumble"]  = {name="Grumble",  text="😤 GRUMBLE! АКТИВИРУЙ ВСЕ ИСТОЧНИКИ ПИТАНИЯ! ОН ОПАСЕН!", color=Color3.fromRGB(200,80,80)},
    ["gloombats"]= {name="Gloombats",text="🦇 GLOOMBATS! НЕ ИСПОЛЬЗУЙ СВЕТ! ОНИ АТАКУЮТ!", color=Color3.fromRGB(80,80,120)},
    ["dread"]    = {name="Dread",    text="🕷 DREAD! ПРОДОЛЖАЙ ДВИЖЕНИЕ! НЕ ОСТАНАВЛИВАЙСЯ!", color=Color3.fromRGB(100,50,80)},
    ["seek chase"]={name="Seek Chase",text="🕷 SEEK CHASE! БЕГИ ПО СИНЕЙ ДОРОЖКЕ!", color=Color3.fromRGB(255,100,50)},
    ["lookman"]  = {name="Lookman",  text="👀 LOOKMAN! ОПУСТИ ВЗГЛЯД В ПОЛ! НЕ СМОТРИ НА НЕГО!", color=Color3.fromRGB(200,150,150)},
    ["window"]   = {name="Window",   text="🪟 WINDOW! НЕ СМОТРИ В ОКНО!", color=Color3.fromRGB(150,150,200)},
    ["shadow"]   = {name="Shadow",   text="🌑 SHADOW! ОН ПРОХОДИТ МИМО, НЕ МЕШАЙ!", color=Color3.fromRGB(80,80,120)},
    ["blitz"]    = {name="Blitz",    text="⚡ BLITZ! СВЕТ МИГАЕТ! БЫСТРО В ШКАФ!", color=Color3.fromRGB(100,255,100)},
    ["haste"]    = {name="Haste",    text="⏰ HASTE! ИЩИ РЫЧАГ! ВРЕМЯ ИСТЕКАЕТ!", color=Color3.fromRGB(255,60,60)},
    ["a-60"]     = {name="A-60",     text="🅰️ A-60! ИДИ В ШКАФ! СЛУШАЙ КРИК!", color=Color3.fromRGB(255,80,80)},
    ["a-90"]     = {name="A-90",     text="🅰️ A-90! ЗАМРИ! НЕ ДВИГАЙСЯ!", color=Color3.fromRGB(255,120,80)},
    ["a-120"]    = {name="A-120",    text="🅰️ A-120! ПРЯЧЬСЯ! ОН ПОЯВИТСЯ СПЕРЕДИ!", color=Color3.fromRGB(255,40,40)},
    ["void"]     = {name="Void",     text="🕳️ VOID! НЕ СТОЙ НА МЕСТЕ! УХОДИ!", color=Color3.fromRGB(50,50,50)},
    ["seek eyes"]={name="Seek Eyes", text="👁 EYES НА СТЕНЕ! ЭТО НАЧАЛО ПОГОНИ!", color=Color3.fromRGB(150,200,255)},
}

-- Приоритет вывода (сначала самые опасные)
local PRIORITY = {"ambush","rush","seek","figure","a-120","a-90","a-60","halt","eyes","screech","dupe","hide","glitch","lookman","blitz","haste","grumble","dread","giggle","gloombats","timothy","snare","jack","window","shadow","void"}

-- ============================================================
--                    ЛОГИКА ОБНАРУЖЕНИЯ
-- ============================================================
local State = {
    CurrentRoom = 1,
    HighestRoom = 1,
    LastWarnedEntity = nil,
    LastWarnTime = 0,
    SessionStart = tick(),
    DetectedEntities = {},
    LastSeenEntity = {},
    HighlightedObjs = {},
    SurviveCounts = {},
    CustomHints = {
        [1]="🔑 Ищи ключ и зажигалку. Открывай двери.",
        [2]="🚪 Тёмная комната. Зажги свет. Осторожно — Screech.",
        [5]="🖼️ Картина. Зажми взгляд на 3 секунды.",
        [33]="🕷 SEEK! Готовься бежать! Появится синяя дорожка.",
        [50]="👺 FIGURE! В библиотеке. Присядь и иди тихо. Собирай книги.",
        [51]="🛒 Магазин Джеффа. Купи Crucifix, Vitamins, Lockpick.",
        [75]="⚡ Электрощит. Активируй все рубильники.",
        [100]="👺 FIGURE СНОВА! Финальная битва. Иди тихо, не шуми!",
        [150]="😤 GRUMBLE! В шахтах. Активируй питание!",
    },
    DefaultHint = "🔍 Осмотрись. Ищи ключ, свечи, монеты. Слушай звуки!",
}

-- ИСПРАВЛЕНО: Расширенный поиск — вся Workspace + ReplicatedStorage, частичное совпадение
local function scanForEntities()
    local found = {}
    local function check(obj)
        if not obj or not obj.Name then return end
        local lname = obj.Name:lower()
        for key, data in pairs(ENTITIES) do
            if lname == key or lname:find(key, 1, true) then
                -- Исключаем ложные срабатывания
                if not (lname:find("script") or lname:find("sound") or lname:find("gui") or lname:find("light")) then
                    found[data.name] = true
                end
                return
            end
        end
    end

    for _, obj in ipairs(Workspace:GetDescendants()) do
        pcall(check, obj)
    end
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        pcall(check, obj)
    end

    State.DetectedEntities = found
    return found
end

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

local function getRoomNumber()
    local ok, val = pcall(function() return ReplicatedStorage.GameData.LatestRoom.Value end)
    if ok and type(val) == "number" then return val end
    return State.CurrentRoom
end

local function getHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function formatTime(s)
    return string.format("%d:%02d", math.floor(s/60), math.floor(s%60))
end

-- ============================================================
--                    UI
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

-- Лог
local logContainer = Instance.new("Frame")
logContainer.Size = UDim2.new(0, 340, 0, 240)
logContainer.Position = UDim2.new(0, 10, 1, -260)
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
    lbl.Size = UDim2.new(1, 0, 0, 22)
    lbl.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    lbl.BackgroundTransparency = 0.15
    lbl.BorderSizePixel = 0
    lbl.Text = " " .. text
    lbl.TextColor3 = color
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
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
        task.wait(8)
        pcall(function()
            TweenService:Create(lbl, TweenInfo.new(0.5), {BackgroundTransparency = 1, TextTransparency = 1}):Play()
        end)
        task.wait(0.6)
        for i, l in ipairs(activeLogs) do if l == lbl then table.remove(activeLogs, i); break end end
        pcall(function() lbl:Destroy() end)
    end)
end

-- Кнопка
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

-- Панель
local panel = Instance.new("ScrollingFrame")
panel.Size = UDim2.new(0, 300, 0, 600)
panel.Position = UDim2.new(0, 82, 0, 20)
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
local function makeSection(t)
    local s = Instance.new("TextLabel")
    s.Size = UDim2.new(1, -20, 0, 24)
    s.Position = UDim2.new(0, 10, 0, y)
    s.BackgroundColor3 = Color3.fromRGB(70, 45, 45)
    s.BackgroundTransparency = 0.4
    s.BorderSizePixel = 0
    s.Text = "▸ " .. t
    s.TextColor3 = Color3.fromRGB(255, 220, 200)
    s.Font = Enum.Font.GothamBold
    s.TextSize = 11
    s.TextXAlignment = Enum.TextXAlignment.Left
    s.Parent = panel
    Instance.new("UICorner", s).CornerRadius = UDim.new(0, 6)
    y = y + 28
end

local function makeBtn(t, bg, fg)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -20, 0, 30)
    b.Position = UDim2.new(0, 10, 0, y)
    b.BackgroundColor3 = bg or Color3.fromRGB(50, 35, 35)
    b.TextColor3 = fg or Color3.fromRGB(240, 220, 220)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.Text = t
    b.Parent = panel
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    y = y + 34
    return b
end

local function makeToggle(t, getter, setter)
    local b = makeBtn(t)
    local function upd()
        local v = getter()
        b.Text = t .. ": " .. (v and "ВКЛ" or "ВЫКЛ")
        if v then b.BackgroundColor3 = Color3.fromRGB(35, 60, 45)
        else b.BackgroundColor3 = Color3.fromRGB(50, 40, 45) end
    end
    upd()
    b.Activated:Connect(function() setter(not getter()); upd() end)
    return b
end

-- Заголовок
local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1, 0, 0, 24)
titleLbl.Position = UDim2.new(0, 0, 0, y)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "🚪 DOORS HELPER v4.0"
titleLbl.TextColor3 = Color3.fromRGB(255, 200, 150)
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 13
titleLbl.Parent = panel
y = y + 30

-- HUD
local hudFrame = Instance.new("Frame")
hudFrame.Size = UDim2.new(0, 230, 0, 110)
hudFrame.Position = UDim2.new(1, -240, 0, 10)
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
timeLbl.Text = "⏱️ 0:00"
timeLbl.TextColor3 = Color3.fromRGB(180, 220, 255)
timeLbl.Font = Enum.Font.GothamBold
timeLbl.TextSize = 12
timeLbl.TextXAlignment = Enum.TextXAlignment.Left
timeLbl.Parent = hudFrame

local surviveLbl = Instance.new("TextLabel")
surviveLbl.Size = UDim2.new(1, -12, 0, 18)
surviveLbl.Position = UDim2.new(0, 6, 0, 44)
surviveLbl.BackgroundTransparency = 1
surviveLbl.Text = "🏆 R:0 A:0"
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
hintLbl.TextSize = 10
hintLbl.TextXAlignment = Enum.TextXAlignment.Left
hintLbl.Parent = hudFrame

-- Оверлей предупреждений
local warningLbl = Instance.new("TextLabel")
warningLbl.Size = UDim2.new(1, 0, 0, 120)
warningLbl.Position = UDim2.new(0, 0, 0.15, 0)
warningLbl.BackgroundTransparency = 1
warningLbl.Text = ""
warningLbl.TextColor3 = Color3.fromRGB(255, 60, 60)
warningLbl.Font = Enum.Font.GothamBold
warningLbl.TextSize = 52
warningLbl.TextStrokeTransparency = 0
warningLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
warningLbl.TextTransparency = 1
warningLbl.TextWrapped = true
warningLbl.Parent = screenGui

-- Звук
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

-- Основные функции
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

local function sayCurrentHint()
    local hint = State.CustomHints[State.CurrentRoom] or State.DefaultHint
    say(hint)
    if hintLbl then hintLbl.Text = hint:sub(1, 40) end
end

local function showBigWarning(text, color, duration)
    if not CONFIG.ShowBigWarnings then return end
    color = color or Color3.fromRGB(255, 60, 60)
    warningLbl.Text = text
    warningLbl.TextColor3 = color
    warningLbl.TextTransparency = 0
    TweenService:Create(warningLbl, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
    pcall(pushLog, text, color)
    task.spawn(function()
        task.wait(duration or 3)
        TweenService:Create(warningLbl, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
    end)
end

-- ============================================================
--                    ГЛАВНЫЙ ЦИКЛ
-- ============================================================
local lastRoomCheck = 0
local function tickHelper()
    local now = tick()

    -- 1. Определение комнаты
    if now - lastRoomCheck > 0.5 then
        lastRoomCheck = now
        local roomNum = getRoomNumber()
        if roomNum ~= State.CurrentRoom then
            State.CurrentRoom = roomNum
            if roomNum > State.HighestRoom then State.HighestRoom = roomNum end
            if roomLbl then roomLbl.Text = "🚪 Комната: " .. State.CurrentRoom end
            if State.CustomHints[State.CurrentRoom] then
                say(State.CustomHints[State.CurrentRoom])
            end
        end
    end

    -- 2. Обнаружение сущностей
    local ents = scanForEntities()

    -- Считаем выживания
    for entName in pairs(State.LastSeenEntity) do
        if not ents[entName] then
            local hum = getHum()
            if hum and hum.Health > 0 then
                State.SurviveCounts[entName] = (State.SurviveCounts[entName] or 0) + 1
            end
            State.LastSeenEntity[entName] = nil
        end
    end
    for entName in pairs(ents) do
        State.LastSeenEntity[entName] = true
    end

    -- 3. Предупреждения по приоритету
    local activeWarn = nil
    for _, key in ipairs(PRIORITY) do
        local data = ENTITIES[key]
        if data and ents[data.name] then
            activeWarn = data
            break
        end
    end

    if activeWarn and activeWarn.name ~= State.LastWarnedEntity then
        State.LastWarnedEntity = activeWarn.name
        showBigWarning(activeWarn.text, activeWarn.color, 3.5)
        say(activeWarn.text)
        playThreatSound()
    elseif not activeWarn then
        State.LastWarnedEntity = nil
    end

    -- 4. Автоподсказки
    if CONFIG.AutoHints and now - (State.LastAutoHintTime or 0) > CONFIG.AutoHintInterval then
        State.LastAutoHintTime = now
        sayCurrentHint()
    end

    -- 5. HUD
    if now - (State.LastHudUpdate or 0) > 0.3 then
        State.LastHudUpdate = now
        if timeLbl then
            timeLbl.Text = "⏱️ " .. formatTime(now - State.SessionStart)
        end
        if surviveLbl then
            surviveLbl.Text = string.format("🏆 R:%d A:%d",
                State.SurviveCounts.Rush or 0,
                State.SurviveCounts.Ambush or 0)
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

-- Запуск
mainBtn.Activated:Connect(function() panel.Visible = not panel.Visible end)
local helperConn = RunService.Heartbeat:Connect(function() pcall(tickHelper) end)

task.wait(0.5)
say("✅ Doors Helper v4.0 загружен! Все сущности отслеживаются.")
task.wait(2)
sayCurrentHint()

function DH.unload()
    if helperConn then pcall(function() helperConn:Disconnect() end) end
    if screenGui then pcall(function() screenGui:Destroy() end) end
    GENV._DoorsHelper = nil
end

print("[Doors Helper v4.0] Загружено. Отслеживается " .. #PRIORITY .. " сущностей.")
