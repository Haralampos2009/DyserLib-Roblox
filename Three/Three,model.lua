-- ===================== DYSER THIRD MODULE =====================
-- The base for the modules on top of it: the player window, the Screen tab (colors and FPS boosters), the config link
-- (Settings > Config Link) and the factory reset. This file loads the SECOND module (which loads the first one, the library,
-- and adds Info / Settings / History / Cursor / Trash, the search, the language and all the extras) and builds its parts on
-- top of it. The left / top tabs and the radar are in the FOURTH module, which loads THIS file and gives it a build function
-- (Third.start), so a factory reset rebuilds them too.
-- This file is hosted on GitHub (like the first and the second); run the FOURTH module.
-- The F9 console stays quiet. To see the messages of the menu: switch Settings > Console Output (F9) on, or run
-- getgenv().DyserVerbose = true before the script.

-- Nothing is written to the F9 console unless getgenv().DyserVerbose (or _G.DyserVerbose) is true.
local rawPrint, rawWarn = print, warn
local function verbose()
    if rawget(_G, "DyserVerbose") then return true end
    local ok, env = pcall(function() return getgenv and getgenv() end)
    return (ok and env and env.DyserVerbose) == true
end
local function print(...) if verbose() then rawPrint(...) end end
local function warn(...) if verbose() then rawWarn(...) end end

-- The link of the second module. The file name in the link is URL-encoded: "%D0%92%D1%82%D0%BE%D1%80%D0%BE%D0%B9.txt" is "Второй.txt".
local SECOND_URL = "https://raw.githubusercontent.com/Haralampos2009/DyserLib-Roblox/refs/heads/main/%D0%92%D1%82%D0%BE%D1%80%D0%BE%D0%B9.txt"

-- ── 1. Load the second module ──────────────────────────────────────────
-- Every step is checked on its own (the messages appear in the console when Console Output is on).
-- The text of the second module is kept, so the factory reset can start it again without downloading it.
local secondBody
local function startSecond()
    if type(loadstring) ~= "function" then
        warn("[Dyser] loadstring is not available here. Run this script in an executor, or enable LoadStringEnabled.")
        return nil
    end
    if not secondBody then
        local okGet, body = pcall(function() return game:HttpGet(SECOND_URL) end)
        if not okGet then
            warn("[Dyser] Download of the second module failed (link or connection): " .. tostring(body)); return nil
        end
        if type(body) ~= "string" or #body < 2000 then
            warn("[Dyser] The link of the second module did not return it. It returned: " .. tostring(body):sub(1, 150)); return nil
        end
        secondBody = body
    end
    local chunk, compileError = loadstring(secondBody)
    if not chunk then
        warn("[Dyser] The second module has an error and cannot start: " .. tostring(compileError)); return nil
    end
    local okRun, Second = pcall(chunk)
    if not okRun or type(Second) ~= "table" or not Second.Dyser or not Second.Window then
        warn("[Dyser] The second module did not start correctly: " .. tostring(Second)); return nil
    end
    print("[Dyser] Second module loaded (" .. #secondBody .. " bytes).")
    return Second
end

-- ── Factory reset: starts everything again (the button is in Settings > Factory Reset, built below) ──
local build            -- the function that builds all the tabs and windows (below)
local builders = {}    -- the build functions of the modules on top of this one (the fourth module): they run after every start of the menu
local currentContext   -- what those modules get: the library, the window, helper functions
local currentSecond
local activeCleanups = {}
local resetting = false
local function factoryReset()
    if resetting then return end
    resetting = true
    task.spawn(function()
        -- 1. everything that was changed in the game is undone (colors, light, FPS booster, radar, ...)
        for _, undo in ipairs(activeCleanups) do pcall(undo) end
        -- 2. the menu and every window of it are removed
        local UI = currentSecond and currentSecond.UI
        local roots = { game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui") }
        if UI and UI.screenGui then roots[#roots + 1] = UI.screenGui.Parent end
        for _, root in ipairs(roots) do
            for _, name in ipairs({ "DyserMenu", "DyserDock", "DyserStats", "DyserRadar", "DyserScreenTint", "DyserPlayerInfo" }) do
                local found = root:FindFirstChild(name)
                if found then pcall(function() found:Destroy() end) end
            end
        end
        if UI and UI.screenGui then pcall(function() UI.screenGui:Destroy() end) end
        local sounds = game:GetService("SoundService"):FindFirstChild("DyserMenuSounds")
        if sounds then pcall(function() sounds:Destroy() end) end
        _G.DyserVerbose = false   -- factory setting: the console stays quiet
        pcall(function() getgenv().DyserVerbose = false end)
        -- 3. start again: the second module (it loads the first one) and then the tabs
        local fresh = startSecond()
        if fresh then
            currentSecond = fresh
            build(fresh)
        end
        resetting = false
    end)
end

build = function(Second)
    -- listeners on the game's services disconnect themselves when the menu was started again (see the second module)
    local generation = rawget(_G, "DyserGeneration")
    local function gconnect(signal, fn)
        local connection
        connection = signal:Connect(function(...)
            if rawget(_G, "DyserGeneration") ~= generation then connection:Disconnect(); return end
            return fn(...)
        end)
        return connection
    end
    local cleanups = {}   -- what the factory reset has to undo
    activeCleanups = cleanups

    local Dyser, Window, Nav = Second.Dyser, Second.Window, Second.Nav

    -- ── Hints and button texts of the tabs below ───────────────────────────
    -- Hints appear when the mouse rests on a tab or function (they can be switched off in Settings > Hints). The key is the
    -- name shown in the menu. The text left of a button says what the button does.
    local HINTS = {}
    HINTS["Player Window"] = "Shows the player lookup window in the bottom-left corner. It is shown only while the menu is open and closes with it."
    HINTS["Screen Overlay"] = "Puts a colored film over your whole screen (not over the game itself). Pick the color below."
    HINTS["Overlay Color"] = "The color of the film over the screen. Use the palette: pick the color and make it lighter or darker."
    HINTS["Overlay Strength"] = "How strong the film is: 0 = invisible, 100 = almost solid."
    HINTS["Overlay Lighten"] = "Mixes white into the film color: 0 = the color you picked, 100 = white."
    HINTS["Color Correction"] = "Changes the colors of the game itself with the tint, brightness, contrast and saturation below."
    HINTS["Game Tint"] = "The color the whole game is tinted with. White = no tint. Use the palette to make it lighter or darker."
    HINTS["Game Brightness"] = "50 = normal. Higher makes the game lighter, lower makes it darker."
    HINTS["Game Contrast"] = "50 = normal. Higher = stronger difference between light and dark."
    HINTS["Game Saturation"] = "50 = normal. Higher = more vivid colors, 0 = black and white."
    HINTS["Fullbright"] = "Lights up the whole game, also dark places, and removes shadows and fog. Turn it off to get the old light back."
    HINTS["Ambient Color"] = "Replaces the color of the game's ambient light with the color below. Turn it off to get the old light back."
    HINTS["Ambient"] = "The color of the ambient light. Use the palette to make it lighter or darker."
    HINTS["FPS Booster (Light)"] = "A gentle boost: lowest graphics quality, no shadows, no blur / bloom / sun rays, no grass. Everything comes back when you turn it off."
    HINTS["FPS Booster (Hard)"] = "A strong boost: everything from the light one plus plain materials, no textures or decals, no particles, trails or beams, flat water. Everything comes back when you turn it off, but the game looks very plain."
    HINTS["FPS Cap"] = "The highest number of frames per second the game may draw (needs an executor that can change it)."
    HINTS["Reset Calibration"] = "Turns off the screen overlay and every color change of the game, and puts the sliders back to normal."
    HINTS["Reset to Factory Settings"] = "Puts every setting back to what it was when you first started the menu and every function back where it was. Press twice to confirm."
    HINTS["Copy Preset Link"] = "Makes one link with everything set in the menu (toggles, sliders, colors, choices, texts, keys and the place of every function) and copies it. Send it to a friend."
    HINTS["Paste Link"] = "Paste a preset link here (or the web address of a text file that contains one), then press Load From Link."
    HINTS["Load From Link"] = "Applies the preset link from the box above, or from your clipboard if the box is empty: the whole menu takes the setup of the link."
    HINTS["Player Window Key"] = "Click, then press the key that switches the player lookup window on or off (works while the menu is open)."
    local BUTTON_INFO = {
        ["Reset Calibration"] = "Turns every color change off",
        ["Reset to Factory Settings"] = "Restores every setting and puts every function back",
        ["Copy Preset Link"] = "Copies one link with the whole menu setup",
        ["Load From Link"] = "Applies the link from the box above (or from the clipboard)",
    }
    if Nav then
        if Nav.setHint then for name, text in pairs(HINTS) do Nav.setHint(name, text) end end
        if Nav.buttonInfo then for name, text in pairs(BUTTON_INFO) do Nav.buttonInfo[name] = text end end
    end

    -- Russian words for everything in the tabs below (Settings > Language > Русский shows them)
    if Nav and Nav.addTranslations then
        Nav.addTranslations({
            ["Jump Key"] = "Клавиша прыжка",
            ["Player Window"] = "Окно игрока",
            ["Player Window Key"] = "Клавиша окна игрока",
            ["Player Lookup"] = "Поиск игрока",
            ["Enter a nickname..."] = "Введите ник...",
            ["Type a nickname to see information about the player."] = "Введите ник, чтобы увидеть информацию об игроке.",
            ["Shows the player lookup window in the bottom-left corner. It is shown only while the menu is open and closes with it."] = "Показывает окно поиска игрока в левом нижнем углу. Оно видно только при открытом меню и закрывается вместе с ним.",
            ["Click, then press the key that switches the player lookup window on or off (works while the menu is open)."] = "Нажмите, затем на клавишу, которая включает и выключает окно поиска игрока (работает при открытом меню).",
            ["Game stats (leaderboard)"] = "Статистика игры (таблица лидеров)",
            ["Status"] = "Статус",
            ["Friend"] = "Друг",
            ["Friends"] = "Друзья",
            ["Followers"] = "Подписчики",
            ["Following"] = "Подписки",
            ["Banned"] = "Забанен",
            ["Verified"] = "Верифицирован",
            ["Past Names"] = "Прошлые ники",
            ["Groups"] = "Группы",
            ["Avatar"] = "Аватар",
            ["About"] = "Обо мне",
            ["Equipped"] = "В руке",
            ["Backpack"] = "Рюкзак",
            ["Accessories"] = "Аксессуары",
            ["State"] = "Состояние",
            ["Speed"] = "Скорость",
            ["Floor"] = "Пол",
            ["Sitting"] = "Сидит",
            ["Distance"] = "Расстояние",
            ["in this server"] = "на этом сервере",
            ["not in this server"] = "не на этом сервере",
            ["that is you"] = "это вы",
            ["nothing"] = "ничего",
            ["empty"] = "пусто",
            ["Screen"] = "Экран",
            ["Screen Overlay"] = "Экранная плёнка",
            ["Overlay Color"] = "Цвет плёнки",
            ["Overlay Strength"] = "Сила плёнки",
            ["Overlay Lighten"] = "Осветление плёнки",
            ["Screen overlay (over the screen)"] = "Плёнка на экране (поверх экрана)",
            ["Color Correction"] = "Цветокоррекция",
            ["Game Tint"] = "Оттенок игры",
            ["Game Brightness"] = "Яркость игры",
            ["Game Contrast"] = "Контраст игры",
            ["Game Saturation"] = "Насыщенность игры",
            ["Game colors (in the game)"] = "Цвета игры (внутри игры)",
            ["Fullbright"] = "Полная яркость",
            ["Ambient Color"] = "Цвет окружающего света",
            ["Ambient"] = "Окружающий свет",
            ["Reset Calibration"] = "Сбросить калибровку",
            ["FPS Booster (Light)"] = "Ускоритель FPS (лёгкий)",
            ["FPS Booster (Hard)"] = "Ускоритель FPS (жёсткий)",
            ["FPS Booster (can be detected)"] = "Ускоритель FPS (может быть обнаружен)",
            ["FPS Cap"] = "Лимит FPS",
            ["60 (normal)"] = "60 (обычный)",
            ["Unlimited"] = "Без лимита",
            ["Turns every color change off"] = "Выключает все изменения цвета",
            ["Puts a colored film over your whole screen (not over the game itself). Pick the color below."] = "Накладывает цветную плёнку на весь экран (не на саму игру). Выберите цвет ниже.",
            ["The color of the film over the screen. Use the palette: pick the color and make it lighter or darker."] = "Цвет плёнки на экране. Используйте палитру: выберите цвет и сделайте его светлее или темнее.",
            ["How strong the film is: 0 = invisible, 100 = almost solid."] = "Насколько сильна плёнка: 0 = невидима, 100 = почти сплошная.",
            ["Mixes white into the film color: 0 = the color you picked, 100 = white."] = "Подмешивает белый к цвету плёнки: 0 = выбранный цвет, 100 = белый.",
            ["Changes the colors of the game itself with the tint, brightness, contrast and saturation below."] = "Меняет цвета самой игры: оттенок, яркость, контраст и насыщенность ниже.",
            ["The color the whole game is tinted with. White = no tint. Use the palette to make it lighter or darker."] = "Цвет, которым окрашена вся игра. Белый = без оттенка. Используйте палитру, чтобы сделать его светлее или темнее.",
            ["50 = normal. Higher makes the game lighter, lower makes it darker."] = "50 = как обычно. Больше = светлее, меньше = темнее.",
            ["50 = normal. Higher = stronger difference between light and dark."] = "50 = как обычно. Больше = сильнее разница между светлым и тёмным.",
            ["50 = normal. Higher = more vivid colors, 0 = black and white."] = "50 = как обычно. Больше = ярче цвета, 0 = чёрно-белое.",
            ["Lights up the whole game, also dark places, and removes shadows and fog. Turn it off to get the old light back."] = "Освещает всю игру, в том числе тёмные места, и убирает тени и туман. Выключите, чтобы вернуть прежний свет.",
            ["Replaces the color of the game's ambient light with the color below. Turn it off to get the old light back."] = "Заменяет цвет окружающего света игры на цвет ниже. Выключите, чтобы вернуть прежний свет.",
            ["The color of the ambient light. Use the palette to make it lighter or darker."] = "Цвет окружающего света. Используйте палитру, чтобы сделать его светлее или темнее.",
            ["A gentle boost: lowest graphics quality, no shadows, no blur / bloom / sun rays, no grass. Everything comes back when you turn it off."] = "Лёгкое ускорение: самое низкое качество графики, без теней, размытия, свечения, лучей солнца и травы. Всё возвращается при выключении.",
            ["A strong boost: everything from the light one plus plain materials, no textures or decals, no particles, trails or beams, flat water. Everything comes back when you turn it off, but the game looks very plain."] = "Сильное ускорение: всё из лёгкого плюс простые материалы, без текстур и наклеек, частиц, следов и лучей, плоская вода. Всё возвращается при выключении, но игра выглядит очень просто.",
            ["The highest number of frames per second the game may draw (needs an executor that can change it)."] = "Наибольшее число кадров в секунду, которое может рисовать игра (нужен экзекьютор, который это умеет).",
            ["Turns off the screen overlay and every color change of the game, and puts the sliders back to normal."] = "Выключает экранную плёнку и все изменения цвета игры и возвращает слайдеры в норму.",
            ["Factory Reset"] = "Заводские настройки",
            ["Reset to Factory Settings"] = "Сбросить до заводских",
            ["Puts every setting back to what it was when you first started the menu and every function back where it was. Press twice to confirm."] = "Возвращает все настройки к тем, что были при первом запуске меню, а каждую функцию на её место. Для подтверждения нажмите дважды.",
            ["Restores every setting and puts every function back"] = "Возвращает все настройки и ставит каждую функцию на место",
            ["Press Reset to Factory Settings once more within 5 seconds to confirm."] = "Нажмите «Сбросить до заводских» ещё раз в течение 5 секунд для подтверждения.",
            ["Config Link"] = "Ссылка с конфигом",
            ["Copy Preset Link"] = "Скопировать ссылку на пресет",
            ["Paste Link"] = "Вставить ссылку",
            ["Load From Link"] = "Загрузить по ссылке",
            ["Applies the link from the box above (or from the clipboard)"] = "Применяет ссылку из поля выше (или из буфера обмена)",
            ["Paste a preset link here (or the web address of a text file that contains one), then press Load From Link."] = "Вставьте сюда ссылку на пресет (или веб-адрес текстового файла с ней), затем нажмите «Загрузить по ссылке».",
            ["Copies one link with the whole menu setup"] = "Копирует одну ссылку со всеми настройками меню",
            ["Makes one link with everything set in the menu (toggles, sliders, colors, choices, texts, keys and the place of every function) and copies it. Send it to a friend."] = "Создаёт одну ссылку со всем, что настроено в меню (переключатели, слайдеры, цвета, выбор, тексты, клавиши и место каждой функции) и копирует её. Отправьте её другу.",
            ["Applies the preset link from the box above, or from your clipboard if the box is empty: the whole menu takes the setup of the link."] = "Применяет ссылку на пресет из поля выше или из буфера обмена, если поле пустое: всё меню примет настройки из ссылки.",
            ["Account"] = "Аккаунт",
            ["In this server"] = "На этом сервере",
            ["Character (live)"] = "Персонаж (вживую)",
        })
    end

    -- ── Keys for functions ─────────────────────────────────────────────────
    -- addActionKey(tab, "Jump Key", Enum.KeyCode.F, jump) adds a row with a key button under the function. The function runs
    -- EVERY time that key is pressed: click the key button, then press the key you want (Escape or Backspace clears it).
    -- (The game's own typing is respected: nothing runs while you type in a text box.)
    local UserInputService = game:GetService("UserInputService")
    local function addActionKey(tab, text, defaultKey, action)
        local state = { key = defaultKey }
        tab:AddRebind({ Text = text, Default = defaultKey, Callback = function(keyCode) state.key = keyCode end })
        pcall(function()   -- the key button gets the same "keycap" look as the other key buttons
            local rows = {}
            for _, c in ipairs(tab:GetPage():GetChildren()) do if c:IsA("Frame") then rows[#rows + 1] = c end end
            local keyButton = rows[#rows] and rows[#rows]:FindFirstChildWhichIsA("TextButton")
            if keyButton and Nav and Nav.styleKeyButton then Nav.styleKeyButton(keyButton) end
        end)
        gconnect(UserInputService.InputBegan, function(input, processed)
            if processed or not state.key or input.KeyCode ~= state.key then return end
            local ok, err = pcall(action)
            if not ok then warn("[Dyser] " .. text .. " failed: " .. tostring(err)) end
        end)
        return state
    end

    -- ── Player window (bottom-left corner of the screen) ───────────────────
    -- A small window where you type a nickname and see information about that player. It is part of the menu: it is OFF until
    -- you switch it on in Settings > Player Window, and it closes together with the menu (and comes back when the menu opens
    -- again, if it is switched on).
    --   * type a name (or a part of it, a display name or a user ID): a player of this server is shown at once, with live
    --     health, speed, state, tools, distance, position and the values of the game's leaderboard (leaderstats)
    --   * press Enter to look up a player who is NOT in this server (names, ID and the Roblox profile)
    --   * the Roblox profile (created date, friends, followers, groups, past names, avatar, about text, banned, verified) is
    --     loaded in the background for everybody; it needs game:HttpGet from your executor
    --   * the list scrolls when it is long; drag the window by its title; click a value to copy it
    local PlayerWindow = {}
    local okPlayerWindow, errPlayerWindow = pcall(function()
        local UI = Second.UI
        local COLORS, FONTS, Track = UI.COLORS, UI.FONTS, UI.Track
        local corner, stroke, label = UI.corner, UI.stroke, UI.label
        local bindCursorHover, playsfx = UI.bindCursorHover, UI.playsfx
        local Players = game:GetService("Players")
        local HttpService = game:GetService("HttpService")
        local lp = Players.LocalPlayer
        local MAX_HEIGHT = 340   -- the information list never gets taller than this (it scrolls)

        -- the window lives in the menu's own screen gui: it disappears when the menu is closed
        local old = UI.screenGui:FindFirstChild("DyserPlayerInfo")
        if old then old:Destroy() end
        local frame = Instance.new("Frame")
        frame.Name = "DyserPlayerInfo"; frame.AnchorPoint = Vector2.new(0, 1); frame.Position = UDim2.new(0, 12, 1, -12)
        frame.Size = UDim2.fromOffset(270, 0); frame.AutomaticSize = Enum.AutomaticSize.Y
        frame.BorderSizePixel = 0; Track.WindowBG(frame); frame.BackgroundTransparency = 0.04
        frame.ZIndex = 200; frame.Visible = false   -- off until it is switched on in Settings
        corner(frame, 8); Track.Stroke(stroke(frame, COLORS.accent, 1.5, 0.25))
        local layout = Instance.new("UIListLayout", frame); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Padding = UDim.new(0, 4)
        local pad = Instance.new("UIPadding", frame)
        pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8); pad.PaddingTop = UDim.new(0, 6); pad.PaddingBottom = UDim.new(0, 8)
        frame.Parent = UI.screenGui

        -- title (drag the window by it)
        local title = Instance.new("Frame", frame)
        title.LayoutOrder = 1; title.Size = UDim2.new(1, 0, 0, 18); title.BackgroundTransparency = 1; title.Active = true
        Track.TextElement(label(title, "TextLabel", { Size = UDim2.new(1, 0, 1, 0), Text = "Player Lookup", TextSize = 12,
            Font = FONTS.bold, TextColor3 = COLORS.accent, TextXAlignment = Enum.TextXAlignment.Left, Category = "Labels" }))
        local dragging, dragStart, startPos
        title.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging, dragStart, startPos = true, input.Position, frame.Position
            end
        end)
        gconnect(UserInputService.InputChanged, function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local d = input.Position - dragStart
                frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end)
        gconnect(UserInputService.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
        end)

        -- the box for the nickname
        local inputRow = Instance.new("Frame", frame)
        inputRow.LayoutOrder = 2; inputRow.Size = UDim2.new(1, 0, 0, 24); inputRow.BorderSizePixel = 0
        inputRow.BackgroundColor3 = Color3.fromRGB(8, 8, 10); inputRow.BackgroundTransparency = 0.1
        corner(inputRow, 4); stroke(inputRow, COLORS.lineLight, 1, 0.15)
        local box = label(inputRow, "TextBox", { Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -16, 1, 0), Text = "",
            TextSize = 12, Font = Enum.Font.Code, TextColor3 = COLORS.text, TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false, Category = "Inputs" })
        box.PlaceholderText = "Enter a nickname..."; box.PlaceholderColor3 = COLORS.muted
        bindCursorHover(box)

        -- what is shown: a message, or the information
        local message = Instance.new("TextLabel", frame)
        message.LayoutOrder = 3; message.Size = UDim2.new(1, 0, 0, 30); message.BackgroundTransparency = 1
        message.Font = Enum.Font.Code; message.TextSize = 11; message.TextColor3 = COLORS.muted; message.TextWrapped = true
        message.Text = "Type a nickname to see information about the player."

        local content = Instance.new("ScrollingFrame", frame)
        content.LayoutOrder = 4; content.Size = UDim2.new(1, 0, 0, 0); content.BackgroundTransparency = 1; content.BorderSizePixel = 0
        content.ScrollBarThickness = 3; content.ScrollBarImageColor3 = COLORS.accent; content.ScrollingDirection = Enum.ScrollingDirection.Y
        content.CanvasSize = UDim2.new(); content.Visible = false
        local contentLayout = Instance.new("UIListLayout", content)
        contentLayout.SortOrder = Enum.SortOrder.LayoutOrder; contentLayout.Padding = UDim.new(0, 2)
        contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()   -- as tall as the list, up to the maximum
            local h = contentLayout.AbsoluteContentSize.Y
            content.CanvasSize = UDim2.fromOffset(0, h)
            content.Size = UDim2.new(1, 0, 0, math.min(h, MAX_HEIGHT, math.max(120, UI.screenGui.AbsoluteSize.Y - 170)))
        end)

        -- the card: avatar, display name, username
        local card = Instance.new("Frame", content)
        card.LayoutOrder = 1; card.Size = UDim2.new(1, 0, 0, 52); card.BorderSizePixel = 0
        card.BackgroundColor3 = Color3.fromRGB(8, 8, 10); card.BackgroundTransparency = 0.1; corner(card, 4)
        local avatar = Instance.new("ImageLabel", card)
        avatar.AnchorPoint = Vector2.new(0, 0.5); avatar.Position = UDim2.new(0, 6, 0.5, 0); avatar.Size = UDim2.fromOffset(40, 40)
        avatar.BackgroundColor3 = Color3.fromRGB(16, 16, 18); avatar.BorderSizePixel = 0; avatar.ScaleType = Enum.ScaleType.Crop
        corner(avatar, 6); stroke(avatar, COLORS.lineLight, 1, 0.2)
        local displayName = label(card, "TextLabel", { Position = UDim2.fromOffset(54, 8), Size = UDim2.new(1, -60, 0, 18), Text = "",
            TextSize = 13, Font = FONTS.bold, TextColor3 = COLORS.text, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, Category = "Labels" })
        local userName = label(card, "TextLabel", { Position = UDim2.fromOffset(54, 27), Size = UDim2.new(1, -60, 0, 16), Text = "",
            TextSize = 11, Font = Enum.Font.Code, TextColor3 = COLORS.muted, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, Category = "Labels" })

        -- "key value" rows (a click on a value copies it) and small headers
        local function makeRow(key, order)
            local f = Instance.new("Frame", content)
            f.LayoutOrder = order; f.Size = UDim2.new(1, 0, 0, 22); f.BorderSizePixel = 0
            f.BackgroundColor3 = Color3.fromRGB(8, 8, 10); f.BackgroundTransparency = 0.1; corner(f, 3)
            label(f, "TextLabel", { Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0.34, 0, 1, 0), Text = key, TextSize = 11,
                Font = FONTS.default, TextColor3 = COLORS.text, TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd, Category = "Labels" })
            local v = label(f, "TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0), Size = UDim2.new(0.64, -8, 1, 0),
                Text = "-", TextSize = 11, Font = Enum.Font.Code, TextColor3 = COLORS.accent, TextXAlignment = Enum.TextXAlignment.Right,
                TextTruncate = Enum.TextTruncate.AtEnd, AutoButtonColor = false, Category = "Labels" })
            Track.TextElement(v)
            bindCursorHover(v)
            v.MouseButton1Click:Connect(function()
                local copy = (typeof(setclipboard) == "function" and setclipboard) or (typeof(toclipboard) == "function" and toclipboard)
                local text = v:GetAttribute("Copy") or v.Text   -- long values keep their full text in the "Copy" attribute
                if copy and text ~= "-" and text ~= "..." then pcall(copy, text); playsfx("click") end
            end)
            return f, v
        end
        local function makeHeader(text, order)
            local f = Instance.new("Frame", content)
            f.LayoutOrder = order; f.Size = UDim2.new(1, 0, 0, 18); f.BackgroundTransparency = 1
            Track.TextElement(label(f, "TextLabel", { Position = UDim2.fromOffset(4, 0), Size = UDim2.new(1, -8, 1, 0), Text = text,
                TextSize = 11, Font = FONTS.bold, TextColor3 = COLORS.accent, TextXAlignment = Enum.TextXAlignment.Left, Category = "Labels" }))
            return f
        end

        -- the list: headers start with "#"; server = only for a player who is in this server
        local SPEC = {
            { "#Account" },
            { "Status" }, { "User ID" }, { "Created" }, { "Account Age" }, { "Friend" }, { "Friends" }, { "Followers" }, { "Following" },
            { "Banned" }, { "Verified" }, { "Past Names" }, { "Groups" }, { "Avatar" }, { "About" },
            { "#In this server", server = true },
            { "Membership", server = true }, { "Language", server = true }, { "Team", server = true }, { "Equipped", server = true },
            { "Backpack", server = true }, { "Accessories", server = true },
            { "#Character (live)", server = true },
            { "Health", server = true }, { "Walk Speed", server = true }, { "Jump", server = true }, { "Rig Type", server = true },
            { "State", server = true }, { "Speed", server = true }, { "Floor", server = true }, { "Sitting", server = true },
            { "Distance", server = true }, { "Position", server = true },
        }
        local values, rowFrames, serverKeys = {}, {}, {}
        for i, entry in ipairs(SPEC) do
            local key = entry[1]
            if key:sub(1, 1) == "#" then rowFrames[key] = makeHeader(key:sub(2), i + 1)
            else rowFrames[key], values[key] = makeRow(key, i + 1) end
            if entry.server then serverKeys[#serverKeys + 1] = key end
        end
        local statsHeader = makeHeader("Game stats (leaderboard)", 500)
        local statRows = {}   -- the values of the player's leaderstats, one row per stat

        -- ---------- asking Roblox ----------
        local function getJson(url)
            local ok, body = pcall(function() return game:HttpGet(url) end)
            if not ok then return nil end
            local okJson, data = pcall(function() return HttpService:JSONDecode(body) end)
            return okJson and data or nil
        end

        -- user id from a username: Roblox's own function first, then the web API (needs request / http_request)
        local function userIdFromName(name)
            local ok, id = pcall(function() return Players:GetUserIdFromNameAsync(name) end)
            if ok and id then return id end
            local reason = tostring(id)
            local req = (typeof(request) == "function" and request) or (typeof(http_request) == "function" and http_request)
                or (typeof(syn) == "table" and syn.request) or nil
            if req then
                local ok2, res = pcall(req, { Url = "https://users.roblox.com/v1/usernames/users", Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = HttpService:JSONEncode({ usernames = { name }, excludeBannedUsers = false }) })
                if ok2 and type(res) == "table" and res.Body then
                    local okJson, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
                    local u = okJson and data and data.data and data.data[1]
                    if u and u.id then return u.id, nil, u.name, u.displayName end
                    reason = "no such user"
                end
            end
            return nil, reason
        end

        -- ---------- the shown player ----------
        local target   -- { player = Player } for someone in this server, or { userId, name, display } for someone who is not
        local refresh

        local function showMessage(text)
            target = nil
            content.Visible = false
            message.Text = text; message.Visible = true
        end

        -- the Roblox profile of a player, loaded step by step in the background; every step updates the window
        local function loadProfile(t, id)
            local prof = { loaded = {} }
            t.profile = prof
            task.spawn(function()
                local function step(key, url, handler)
                    if target ~= t then return false end   -- another player was chosen: stop asking
                    local data = getJson(url)
                    pcall(handler, data)
                    prof.loaded[key] = true
                    if target == t then refresh() end
                    return true
                end
                local base = "https://users.roblox.com/v1/users/" .. id
                step("user", base, function(d)
                    if not d then return end
                    prof.created, prof.banned, prof.verified, prof.about = d.created, d.isBanned, d.hasVerifiedBadge, d.description
                    if not t.player then   -- the names of a player who is not in the server
                        t.name, t.display = d.name or t.name, d.displayName or t.display
                        if target == t then displayName.Text = t.display; userName.Text = "@" .. t.name end
                    end
                end)
                step("friends", "https://friends.roblox.com/v1/users/" .. id .. "/friends/count", function(d) prof.friends = d and d.count end)
                step("followers", "https://friends.roblox.com/v1/users/" .. id .. "/followers/count", function(d) prof.followers = d and d.count end)
                step("following", "https://friends.roblox.com/v1/users/" .. id .. "/followings/count", function(d) prof.following = d and d.count end)
                step("names", base .. "/username-history?limit=10&sortOrder=Desc", function(d)
                    if not (d and d.data) then return end
                    local names = {}
                    for _, n in ipairs(d.data) do names[#names + 1] = n.name end
                    prof.pastNames = #names > 0 and table.concat(names, ", ") or "none"
                end)
                step("groups", "https://groups.roblox.com/v2/users/" .. id .. "/groups/roles", function(d)
                    if not (d and d.data) then return end
                    local names = {}
                    for _, g in ipairs(d.data) do names[#names + 1] = g.group and g.group.name or "?" end
                    prof.groupCount = #d.data
                    prof.groupNames = table.concat(names, ", ")
                    prof.firstGroup = names[1]
                end)
                step("avatar", "https://avatar.roblox.com/v1/users/" .. id .. "/avatar", function(d)
                    if not d then return end
                    prof.avatar = (d.playerAvatarType or "?") .. " · " .. tostring(d.assets and #d.assets or 0) .. " items"
                end)
            end)
        end

        local function fill(t)
            target = t
            message.Visible = false; content.Visible = true
            local id = t.player and t.player.UserId or t.userId
            avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(id) .. "&w=150&h=150"
            displayName.Text = t.player and t.player.DisplayName or t.display
            userName.Text = "@" .. (t.player and t.player.Name or t.name)
            values["User ID"].Text = tostring(id)
            values["Friend"].Text = "..."
            task.spawn(function()
                if id == lp.UserId then values["Friend"].Text = "that is you"; return end
                local ok, isFriend = pcall(function() return lp:IsFriendsWith(id) end)
                if target == t then values["Friend"].Text = ok and (isFriend and "Yes" or "No") or "-" end
            end)
            loadProfile(t, id)
        end

        -- the date "2015-03-04T12:34:56Z" as a number of days ago
        local function daysSince(iso)
            local y, m, d = tostring(iso):match("(%d+)-(%d+)-(%d+)")
            if not y then return nil end
            local ok, stamp = pcall(os.time, { year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
            return ok and stamp and math.max(0, math.floor((os.time() - stamp) / 86400)) or nil
        end

        local function setLong(valueLabel, full, maxLen)   -- a long text is cut for the window; a click copies all of it
            full = tostring(full):gsub("%s+", " ")
            valueLabel.Text = #full > maxLen and (full:sub(1, maxLen - 3) .. "...") or full
            valueLabel:SetAttribute("Copy", full)
        end

        local function updateStats(p)   -- one row for every value in the player's "leaderstats" folder
            local seen, count = {}, 0
            local folder = p and p:FindFirstChild("leaderstats")
            for _, v in ipairs(folder and folder:GetChildren() or {}) do
                if v:IsA("ValueBase") then
                    seen[v.Name] = true; count = count + 1
                    local row = statRows[v.Name]
                    if not row then
                        local f, val = makeRow(v.Name, 500 + count)
                        row = { frame = f, value = val }; statRows[v.Name] = row
                    end
                    row.frame.Visible = true
                    row.value.Text = tostring(v.Value)
                end
            end
            for name, row in pairs(statRows) do if not seen[name] then row.frame.Visible = false end end
            statsHeader.Visible = count > 0
        end

        refresh = function()
            local t = target
            if not t then return end
            local p = t.player
            if p and not p.Parent then   -- the player left: keep what is known about them
                t.userId, t.name, t.display, t.player = p.UserId, p.Name, p.DisplayName, nil
                p = nil
            end
            values["Status"].Text = p and "in this server" or "not in this server"
            for _, key in ipairs(serverKeys) do rowFrames[key].Visible = p ~= nil end
            if not p then statsHeader.Visible = false; for _, row in pairs(statRows) do row.frame.Visible = false end end

            -- from the Roblox profile (everybody): "..." while it loads, "-" when Roblox has nothing
            local prof = t.profile
            local function loaded(step) return prof and prof.loaded[step] end
            local function shown(step, value, format)
                if not loaded(step) then return "..." end
                if value == nil then return "-" end
                return format and format(value) or tostring(value)
            end
            local yesNo = function(v) return v and "Yes" or "No" end
            values["Created"].Text = shown("user", prof and prof.created, function(v) return tostring(v):sub(1, 10) end)
            local createdDays = prof and prof.created and daysSince(prof.created)
            if p then
                values["Account Age"].Text = string.format("%d days (%.1f years)", p.AccountAge, p.AccountAge / 365.25)
            elseif createdDays then
                values["Account Age"].Text = string.format("%d days (%.1f years)", createdDays, createdDays / 365.25)
            else
                values["Account Age"].Text = loaded("user") and "-" or "..."
            end
            values["Friends"].Text = shown("friends", prof and prof.friends)
            values["Followers"].Text = shown("followers", prof and prof.followers)
            values["Following"].Text = shown("following", prof and prof.following)
            values["Banned"].Text = shown("user", prof and prof.banned, yesNo)
            values["Verified"].Text = shown("user", prof and prof.verified, yesNo)
            values["Avatar"].Text = shown("avatar", prof and prof.avatar)
            if loaded("names") then setLong(values["Past Names"], prof.pastNames or "-", 34) else values["Past Names"].Text = "..." end
            if loaded("groups") then
                if prof.groupCount then
                    setLong(values["Groups"], prof.groupCount .. (prof.firstGroup and (" · " .. prof.firstGroup) or ""), 34)
                    values["Groups"]:SetAttribute("Copy", prof.groupNames ~= "" and prof.groupNames or "none")
                else values["Groups"].Text = "-" end
            else values["Groups"].Text = "..." end
            if loaded("user") then
                local about = prof.about
                if about and about:gsub("%s", "") ~= "" then setLong(values["About"], about, 34) else values["About"].Text = "empty" end
            else values["About"].Text = "..." end

            -- live values (only for a player in this server)
            if p then
                values["Membership"].Text = p.MembershipType == Enum.MembershipType.Premium and "Premium" or "None"
                local okLocale, locale = pcall(function() return p.LocaleId end)
                values["Language"].Text = okLocale and tostring(locale) or "-"
                values["Team"].Text = (p.Team and p.Team.Name) or "none"
                local backpack = p:FindFirstChildOfClass("Backpack")
                values["Backpack"].Text = backpack and (#backpack:GetChildren() .. " tools") or "-"
                local character = p.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                local root = character and character:FindFirstChild("HumanoidRootPart")
                local tool = character and character:FindFirstChildOfClass("Tool")
                values["Equipped"].Text = tool and tool.Name or "nothing"
                values["Accessories"].Text = humanoid and tostring(#humanoid:GetAccessories()) or "-"
                values["Health"].Text = humanoid and string.format("%d / %d", math.floor(humanoid.Health + 0.5), math.floor(humanoid.MaxHealth + 0.5)) or "-"
                values["Walk Speed"].Text = humanoid and string.format("%.1f", humanoid.WalkSpeed) or "-"
                values["Jump"].Text = humanoid and (humanoid.UseJumpPower and string.format("%.1f (power)", humanoid.JumpPower)
                    or string.format("%.1f (height)", humanoid.JumpHeight)) or "-"
                values["Rig Type"].Text = humanoid and humanoid.RigType.Name or "-"
                local okState, state = pcall(function() return humanoid:GetState().Name end)
                values["State"].Text = (humanoid and okState) and state or "-"
                values["Speed"].Text = root and string.format("%.1f studs/s", root.AssemblyLinearVelocity.Magnitude) or "-"
                values["Floor"].Text = humanoid and humanoid.FloorMaterial.Name or "-"
                values["Sitting"].Text = humanoid and (humanoid.Sit and ("Yes" .. (humanoid.SeatPart and (" (" .. humanoid.SeatPart.Name .. ")") or "")) or "No") or "-"
                values["Position"].Text = root and string.format("%.0f, %.0f, %.0f", root.Position.X, root.Position.Y, root.Position.Z) or "-"
                local mine = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
                values["Distance"].Text = (root and mine) and string.format("%.0f studs", (root.Position - mine.Position).Magnitude) or "-"
                updateStats(p)
            end
        end
        task.spawn(function()
            while frame.Parent do
                if frame.Visible and UI.screenGui.Enabled and target then pcall(refresh) end   -- nothing is updated while the window is hidden
                task.wait(0.3)
            end
        end)

        -- ---------- finding the player ----------
        local function findInServer(query)
            local q = query:lower()
            local byId = tonumber(q) and Players:GetPlayerByUserId(tonumber(q))
            if byId then return byId end
            local prefix, part
            for _, p in ipairs(Players:GetPlayers()) do
                local n, d = p.Name:lower(), p.DisplayName:lower()
                if n == q or d == q then return p end
                if not prefix and (n:sub(1, #q) == q or d:sub(1, #q) == q) then prefix = p end
                if not part and (n:find(q, 1, true) or d:find(q, 1, true)) then part = p end
            end
            return prefix or part
        end

        local function lookupOffline(name)   -- a player who is not in this server (asks Roblox, so it takes a moment)
            showMessage('Searching for "' .. name .. '"...')
            task.spawn(function()
                local id, reason, foundName, foundDisplay
                if tonumber(name) then id = tonumber(name) else id, reason, foundName, foundDisplay = userIdFromName(name) end
                if box.Text:match("^%s*(.-)%s*$") ~= name then return end   -- the box was changed meanwhile
                if not id then
                    showMessage('"' .. name .. '" was not found on Roblox' .. (reason and (" (" .. tostring(reason) .. ")") or "") .. ". Type the exact username.")
                    return
                end
                local okInfo, infos = pcall(function() return Players:GetUserInfosByUserIdsAsync({ id }) end)
                local info = okInfo and infos and infos[1]
                fill({ userId = id, name = (info and info.Username) or foundName or name, display = (info and info.DisplayName) or foundDisplay or name })
                refresh()
            end)
        end

        box:GetPropertyChangedSignal("Text"):Connect(function()
            local q = box.Text:match("^%s*(.-)%s*$")
            if q == "" then showMessage("Type a nickname to see information about the player."); return end
            local p = findInServer(q)
            if p then
                if not (target and target.player == p) then fill({ player = p }) end
                refresh()
            else
                showMessage('Nobody in this server matches "' .. q .. '". Press Enter to look the name up on Roblox.')
            end
        end)
        box.FocusLost:Connect(function(enter)
            if not enter then return end
            local q = box.Text:match("^%s*(.-)%s*$")
            if q ~= "" and not findInServer(q) then lookupOffline(q) end
        end)

        PlayerWindow.setVisible = function(on) frame.Visible = on and true or false end
        PlayerWindow.frame = frame
    end)
    if not okPlayerWindow then warn("[Dyser] The player window could not be built: " .. tostring(errPlayerWindow)) end

    -- Settings > Player Window: an on / off switch, and a key that does the same (a "keybutton": click it, then press the key)
    do
        local Settings = Nav and Nav.settingsTab
        if Settings and PlayerWindow.setVisible then
            Settings:AddSection("Player Window")
            -- off until you switch it on; it is shown only while the menu is open
            Settings:AddToggle({ Text = "Player Window", Default = false, Callback = function(on) PlayerWindow.setVisible(on) end })
            PlayerWindow.key = Enum.KeyCode.RightControl
            Settings:AddRebind({ Text = "Player Window Key", Default = PlayerWindow.key, Callback = function(keyCode) PlayerWindow.key = keyCode end })
            -- the key button gets the same "keycap" look as the other key buttons
            pcall(function()
                local rows = {}
                for _, c in ipairs(Settings:GetPage():GetChildren()) do if c:IsA("Frame") then rows[#rows + 1] = c end end
                local keyButton = rows[#rows] and rows[#rows]:FindFirstChildWhichIsA("TextButton")
                if keyButton and Nav.styleKeyButton then Nav.styleKeyButton(keyButton) end
            end)
            gconnect(UserInputService.InputBegan, function(input, processed)
                if processed or not PlayerWindow.key or input.KeyCode ~= PlayerWindow.key then return end
                if not Second.UI.screenGui.Enabled then return end   -- the window belongs to the menu: nothing happens while it is closed
                Dyser:SetToggle("Player Window", not Dyser:GetToggleState("Player Window"))   -- flips the switch in Settings too
            end)
        end
    end

    -- ── Screen tab: calibration and FPS boosters ───────────────────────────
    -- A right-hand tab (before Trash). WARNING (also written at the top of the tab): changing colors, lighting or graphics from the
    -- client can be noticed by a game's anti-cheat, and an account can be banned for it. Use it at your own risk.
    --   * Screen overlay  : a colored film over the whole screen (not over the game): pick the color with the palette, make it
    --                       stronger or lighter
    --   * Game colors     : a color correction of the game itself (tint from the palette, brightness, contrast, saturation),
    --                       Fullbright (lights up everything) and a replacement for the ambient light color
    --   * FPS Booster     : two levels - Light (gentle) and Hard (strong) - and an FPS cap. Both are undone when switched off
    local okScreen, errScreen = pcall(function()
        local UI = Second.UI
        local COLORS = UI.COLORS
        local Lighting = game:GetService("Lighting")
        local Tab = Window:AddRightTab("Screen", { Order = 90 })   -- 90 = before Trash (100)
        local page = Tab:GetPage()
        local WHITE = Color3.new(1, 1, 1)

        -- the warning, at the top of the tab (a plain label)
        local warning = Instance.new("TextLabel", page)
        warning.Name = "ScreenWarning"; warning.Size = UDim2.new(1, 0, 0, 0); warning.AutomaticSize = Enum.AutomaticSize.Y
        warning.BackgroundTransparency = 1; warning.TextWrapped = true; warning.TextXAlignment = Enum.TextXAlignment.Left
        warning.TextYAlignment = Enum.TextYAlignment.Top; warning.Font = UI.FONTS.bold; warning.TextSize = 12
        warning.TextColor3 = Color3.fromRGB(255, 190, 80)
        warning.Text = "WARNING: changing colors, lighting or graphics of a game from your side can be noticed by the game's anti-cheat "
            .. "and can get your account banned. Everything in this tab is used at your own risk."
        local warnPad = Instance.new("UIPadding", warning)
        warnPad.PaddingLeft = UDim.new(0, 4); warnPad.PaddingRight = UDim.new(0, 4); warnPad.PaddingTop = UDim.new(0, 2); warnPad.PaddingBottom = UDim.new(0, 6)

        -- ---------- screen overlay ----------
        local overlay = { on = false, color = Color3.fromRGB(255, 180, 90), strength = 0.2, lighten = 0 }
        local overlayGui = Instance.new("ScreenGui")
        overlayGui.Name = "DyserScreenTint"; overlayGui.ResetOnSpawn = false; overlayGui.IgnoreGuiInset = true
        overlayGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; overlayGui.DisplayOrder = 2147470000; overlayGui.Enabled = false
        local film = Instance.new("Frame", overlayGui)
        film.Size = UDim2.fromScale(1, 1); film.BorderSizePixel = 0; film.Active = false   -- never blocks the mouse
        overlayGui.Parent = UI.screenGui.Parent
        local function applyOverlay()
            film.BackgroundColor3 = overlay.color:Lerp(WHITE, overlay.lighten)
            film.BackgroundTransparency = 1 - overlay.strength * 0.85
            overlayGui.Enabled = overlay.on
        end
        applyOverlay()

        Tab:AddSection("Screen overlay (over the screen)")
        Tab:AddToggle({ Text = "Screen Overlay", Default = false, Callback = function(on) overlay.on = on; applyOverlay() end })
        Tab:AddColorPicker({ Text = "Overlay Color", Default = overlay.color, Callback = function(c) overlay.color = c; applyOverlay() end })
        Tab:AddSlider({ Text = "Overlay Strength", Min = 0, Max = 100, Default = 20, Callback = function(a) overlay.strength = a; applyOverlay() end })
        Tab:AddSlider({ Text = "Overlay Lighten", Min = 0, Max = 100, Default = 1, Callback = function(a) overlay.lighten = a; applyOverlay() end })

        -- ---------- game colors ----------
        local look = { on = false, tint = WHITE, brightness = 0, contrast = 0, saturation = 0 }
        local effect = Instance.new("ColorCorrectionEffect")
        effect.Name = "DyserColor"; effect.Enabled = false; effect.Parent = Lighting
        local function applyLook()
            effect.TintColor = look.tint; effect.Brightness = look.brightness
            effect.Contrast = look.contrast; effect.Saturation = look.saturation
            effect.Enabled = look.on
        end

        Tab:AddSection("Game colors (in the game)")
        Tab:AddToggle({ Text = "Color Correction", Default = false, Callback = function(on) look.on = on; applyLook() end })
        Tab:AddColorPicker({ Text = "Game Tint", Default = WHITE, Callback = function(c) look.tint = c; applyLook() end })
        -- the sliders show 0..100, 50 is "normal"
        Tab:AddSlider({ Text = "Game Brightness", Min = 0, Max = 100, Default = 50, Callback = function(a) look.brightness = (a - 0.5) * 1.2; applyLook() end })
        Tab:AddSlider({ Text = "Game Contrast", Min = 0, Max = 100, Default = 50, Callback = function(a) look.contrast = (a - 0.5) * 1.6; applyLook() end })
        Tab:AddSlider({ Text = "Game Saturation", Min = 0, Max = 100, Default = 50, Callback = function(a) look.saturation = (a - 0.5) * 2; applyLook() end })

        -- Fullbright and the ambient color change the game's lighting; the old values are kept and put back when switched off
        local lightingSaved = {}
        local function saveLighting(prop)
            if lightingSaved[prop] == nil then lightingSaved[prop] = { Lighting[prop] } end
        end
        local function restoreLighting(prop)
            local box = lightingSaved[prop]
            if box then pcall(function() Lighting[prop] = box[1] end); lightingSaved[prop] = nil end
        end
        local fullbrightOn, ambientOn, ambientColor = false, false, Color3.fromRGB(150, 150, 170)
        local function applyLighting()
            if fullbrightOn then
                for _, prop in ipairs({ "Brightness", "Ambient", "OutdoorAmbient", "GlobalShadows", "FogEnd" }) do saveLighting(prop) end
                Lighting.Brightness = 3; Lighting.GlobalShadows = false; Lighting.FogEnd = 1e6
                Lighting.Ambient = Color3.fromRGB(190, 190, 190); Lighting.OutdoorAmbient = Color3.fromRGB(190, 190, 190)
            elseif ambientOn then
                saveLighting("Ambient"); saveLighting("OutdoorAmbient")
                Lighting.Ambient = ambientColor; Lighting.OutdoorAmbient = ambientColor
                for _, prop in ipairs({ "Brightness", "GlobalShadows", "FogEnd" }) do restoreLighting(prop) end
            else
                for _, prop in ipairs({ "Brightness", "Ambient", "OutdoorAmbient", "GlobalShadows", "FogEnd" }) do restoreLighting(prop) end
            end
        end
        task.spawn(function()   -- a game may set its light again: keep ours while it is switched on
            while rawget(_G, "DyserGeneration") == generation do   -- (stops when the menu is started again)
                task.wait(0.5)
                if fullbrightOn or ambientOn then pcall(applyLighting) end
            end
        end)
        Tab:AddToggle({ Text = "Fullbright", Default = false, Callback = function(on) fullbrightOn = on; applyLighting() end })
        Tab:AddToggle({ Text = "Ambient Color", Default = false, Callback = function(on) ambientOn = on; applyLighting() end })
        Tab:AddColorPicker({ Text = "Ambient", Default = ambientColor, Callback = function(c) ambientColor = c; if ambientOn then applyLighting() end end })

        Tab:AddButton({ Text = "Reset Calibration", Callback = function()
            for _, name in ipairs({ "Screen Overlay", "Color Correction", "Fullbright", "Ambient Color" }) do Dyser:SetToggle(name, false) end
            Dyser:SetSlider("Overlay Strength", 0.2); Dyser:SetSlider("Overlay Lighten", 0.01)
            for _, name in ipairs({ "Game Brightness", "Game Contrast", "Game Saturation" }) do Dyser:SetSlider(name, 0.5) end
        end })

        -- ---------- FPS booster ----------
        local booster = { light = false, hard = false, lightApplied = false, session = 0 }
        local capChanged = false
        local lightStore = setmetatable({}, { __mode = "k" })   -- thing -> { property -> { old value } }
        local hardStore = setmetatable({}, { __mode = "k" })
        local function put(store, thing, prop, value)   -- sets a property and remembers the old value
            pcall(function()
                local saved = store[thing]
                if not saved then saved = {}; store[thing] = saved end
                if saved[prop] == nil then saved[prop] = { thing[prop] } end
                thing[prop] = value
            end)
        end
        local function restore(store)
            for thing, props in pairs(store) do
                for prop, box in pairs(props) do pcall(function() thing[prop] = box[1] end) end
            end
            for thing in pairs(store) do store[thing] = nil end
        end

        -- Light: lowest quality, no shadows, no post effects, no grass
        local function applyLight()
            booster.lightApplied = true
            pcall(function()
                local rendering = settings().Rendering
                booster.oldQuality = rendering.QualityLevel
                rendering.QualityLevel = Enum.QualityLevel.Level01
            end)
            put(lightStore, Lighting, "GlobalShadows", false)
            local function effects(container)
                for _, e in ipairs(container:GetChildren()) do
                    if e.Name ~= "DyserColor" and (e:IsA("BloomEffect") or e:IsA("BlurEffect") or e:IsA("SunRaysEffect") or e:IsA("DepthOfFieldEffect")) then
                        put(lightStore, e, "Enabled", false)
                    end
                end
            end
            effects(Lighting)
            if workspace.CurrentCamera then effects(workspace.CurrentCamera) end
            put(lightStore, workspace.Terrain, "Decoration", false)
        end
        local function restoreLight()
            booster.lightApplied = false
            restore(lightStore)
            pcall(function() if booster.oldQuality then settings().Rendering.QualityLevel = booster.oldQuality end end)
        end
        local function updateLight()   -- the light level is on when either of the two switches is on
            local want = booster.light or booster.hard
            if want and not booster.lightApplied then applyLight() elseif not want and booster.lightApplied then restoreLight() end
        end

        -- Hard: plain materials, no textures, no particles, flat water, simple meshes (also for things that appear later)
        local function hardThing(inst)
            if inst:IsA("BasePart") then
                if not inst:IsA("Terrain") then
                    put(hardStore, inst, "Material", Enum.Material.SmoothPlastic)
                    put(hardStore, inst, "Reflectance", 0)
                    put(hardStore, inst, "CastShadow", false)
                end
            elseif inst:IsA("Decal") or inst:IsA("Texture") then
                put(hardStore, inst, "Transparency", 1)
            elseif inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam") or inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles") then
                put(hardStore, inst, "Enabled", false)
            end
        end
        local function applyHard()
            booster.session = booster.session + 1
            local mine = booster.session
            pcall(function()
                local rendering = settings().Rendering
                booster.oldMesh = rendering.MeshPartDetailLevel
                rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04
            end)
            local terrain = workspace.Terrain
            put(hardStore, terrain, "WaterWaveSize", 0); put(hardStore, terrain, "WaterWaveSpeed", 0)
            put(hardStore, terrain, "WaterReflectance", 0); put(hardStore, terrain, "WaterTransparency", 0)
            booster.hardConn = workspace.DescendantAdded:Connect(function(inst) if booster.hard then hardThing(inst) end end)
            task.spawn(function()   -- the big job runs in small pieces so the game does not freeze
                local count = 0
                for _, inst in ipairs(workspace:GetDescendants()) do
                    if booster.session ~= mine or not booster.hard then return end
                    hardThing(inst)
                    count = count + 1
                    if count % 400 == 0 then task.wait() end
                end
                Dyser:AddLog("FPS Booster (Hard) is on: " .. count .. " things simplified", COLORS.accent)
            end)
        end
        local function restoreHard()
            booster.session = booster.session + 1   -- stops a job that is still running
            if booster.hardConn then booster.hardConn:Disconnect(); booster.hardConn = nil end
            restore(hardStore)
            pcall(function() if booster.oldMesh then settings().Rendering.MeshPartDetailLevel = booster.oldMesh end end)
        end

        Tab:AddSection("FPS Booster (can be detected)")
        Tab:AddToggle({ Text = "FPS Booster (Light)", Default = false, Callback = function(on)
            booster.light = on; updateLight()
            if on then Dyser:AddLog("FPS Booster (Light) is on", COLORS.accent) end
        end })
        Tab:AddToggle({ Text = "FPS Booster (Hard)", Default = false, Callback = function(on)
            booster.hard = on
            if on then applyHard() else restoreHard() end
            updateLight()
        end })
        if typeof(setfpscap) == "function" then
            local caps = { 60, 120, 240, 9999 }
            local armed = false   -- the list may report its starting choice while it is being built: that must not change your cap
            Tab:AddDropdown({ Text = "FPS Cap", Default = 1, Options = { "60 (normal)", "120", "240", "Unlimited" },
                Callback = function(i) if armed then capChanged = true; pcall(setfpscap, caps[i] or 60) end end })
            armed = true
        end

        -- the factory reset undoes everything this tab changed in the game
        table.insert(cleanups, function()
            booster.hard = false; booster.light = false
            restoreHard(); updateLight()
            fullbrightOn = false; ambientOn = false
            pcall(applyLighting)
            pcall(function() effect:Destroy() end)
            pcall(function() overlayGui:Destroy() end)
            if capChanged and typeof(setfpscap) == "function" then pcall(setfpscap, 60) end
        end)
    end)
    if not okScreen then warn("[Dyser] The Screen tab could not be built: " .. tostring(errScreen)) end

    -- ── Config link (Settings > Config Link) ───────────────────────────────
    -- Share your whole setup in one piece of text:
    --   * Copy Preset Link : reads EVERYTHING that is set in the menu and copies it as one link
    --   * Paste Link + Load From Link : applies a link (yours or from a friend): the whole menu takes the setup at once.
    --                        Without a pasted link the clipboard is used.
    -- What is in a link: EVERYTHING the menu has: every toggle (function on / off), every slider, every color (the color
    -- scheme, the styling, the colors of the Screen tab, the cursor, ...), every dropdown choice (language, menu size, radar
    -- range, ...), every text box, every key (the keys of the rebinds, also the menu hotkey, and the keys of the "key + switch"
    -- rows), the place of every function and the order of the tabs, the tabs that are in the Trash, which sections are folded,
    -- the two folded panels, which tabs are open, and where the menu window and the player window stand on the screen.
    -- A link looks like  dyserlib://preset/...  and contains the settings themselves, so it needs no server. It can also be
    -- shared as a web address: put the link into any text file on the web (Pastebin, a GitHub raw file) and paste that
    -- address; Load From Link downloads the text and applies it.
    -- A link only holds names and values (true / false, numbers, colors, texts, key names). Nothing in it is ever run as code,
    -- and a name the menu does not have is ignored. Applying a link really does switch the functions in it on or off (also
    -- Fullbright, the FPS boosters, ... if they were on for the sender).
    -- Two things depend on your executor: the key of a "key + switch" row can only be put on a row with firesignal (the library
    -- gives no other way), and a color is typed into the picker's own box, which needs the box to take the keyboard focus.
    -- The log tells how many of each were put on the menu.
    do
        local Settings = Nav and Nav.settingsTab
        if Settings then
            local HttpService = game:GetService("HttpService")
            local window = Second.UI.screenGui:FindFirstChild("MenuWindow")
            local ACCENT, PINK = Second.UI.COLORS.accent, Second.UI.COLORS.pink
            local FONT_BOLD = Second.UI.FONTS.bold
            local PREFIX = "dyserlib://preset/"
            local SKIP = { ["Paste Link"] = true }   -- the box the link is pasted in is not part of the setup

            -- base64: the link is the settings as text (JSON) written in letters and digits
            local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
            local function b64encode(data)
                return ((data:gsub(".", function(x)
                    local r, b = "", x:byte()
                    for i = 8, 1, -1 do r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and "1" or "0") end
                    return r
                end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(x)
                    if #x < 6 then return "" end
                    local c = 0
                    for i = 1, 6 do c = c + (x:sub(i, i) == "1" and 2 ^ (6 - i) or 0) end
                    return B64:sub(c + 1, c + 1)
                end) .. ({ "", "==", "=" })[#data % 3 + 1])
            end
            local function b64decode(data)
                data = data:gsub("[^" .. B64 .. "=]", "")
                return ((data:gsub(".", function(x)
                    if x == "=" then return "" end
                    local r, f = "", (B64:find(x, 1, true) - 1)
                    for i = 6, 1, -1 do r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0") end
                    return r
                end)):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
                    if #x ~= 8 then return "" end
                    local c = 0
                    for i = 1, 8 do c = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0) end
                    return string.char(c)
                end))
            end

            -- ---------- reading the menu ----------
            local function rowName(row)   -- the English name of a row, header or note
                local label = row:FindFirstChild("Label")
                if label and label:IsA("TextLabel") and label.Text ~= "" then return Nav.textOf(label) end
                for _, d in ipairs(row:GetDescendants()) do
                    if d:IsA("TextLabel") and d.Text ~= "" then return Nav.textOf(d) end
                end
            end
            local function pageKey(page)   -- "L|Main|Visuals" for a page of a left tab, "R|Settings" for a right-hand one
                local pane = page.Parent
                if pane and pane.Name:sub(-9) == "_LeftPane" then return "L|" .. pane.Name:sub(1, -10) .. "|" .. page.Name:sub(1, -5) end
                if pane and pane.Name == "RightPane" then return "R|" .. page.Name:sub(1, -5) end
            end
            local function menuPages()
                local list = {}
                for _, page in ipairs(window:GetDescendants()) do
                    if page:IsA("ScrollingFrame") and page.Name:sub(-4) == "Page" and page.Name ~= "InfoPage" and page.Name ~= "HistoryPage" then
                        local key = pageKey(page)
                        if key then list[#list + 1] = { page = page, key = key } end
                    end
                end
                return list
            end
            local function sortedItems(page)   -- the things on a page in the order they are shown
                local list = {}
                for i, c in ipairs(page:GetChildren()) do
                    if c:IsA("GuiObject") then list[#list + 1] = { obj = c, idx = i } end
                end
                table.sort(list, function(x, y)
                    if x.obj.LayoutOrder ~= y.obj.LayoutOrder then return x.obj.LayoutOrder < y.obj.LayoutOrder end
                    return x.idx < y.idx
                end)
                local out = {}
                for _, e in ipairs(list) do out[#out + 1] = e.obj end
                return out
            end
            local function menuRows()   -- every function row (a row with a "Label"): its English name and the row
                local list = {}
                for _, p in ipairs(menuPages()) do
                    for _, row in ipairs(p.page:GetChildren()) do
                        local label = row:IsA("Frame") and row:FindFirstChild("Label")
                        if label and label:IsA("TextLabel") then list[#list + 1] = { row = row, name = Nav.textOf(label) } end
                    end
                end
                return list
            end
            local function hexBoxOf(row)   -- the "#RRGGBB" box of a color picker
                for _, d in ipairs(row:GetDescendants()) do
                    if d:IsA("TextBox") and d.Text:match("^#%x%x%x%x%x%x$") then return d end
                end
            end
            local function sliderFillOf(row)   -- the bar of a slider (it has a number on its right)
                local fill, hasNumber
                for _, c in ipairs(row:GetChildren()) do
                    if c:IsA("Frame") and c:FindFirstChildOfClass("UIGradient") then fill = c end
                    if c:IsA("TextLabel") and c.Name ~= "Label" and c.AnchorPoint.X == 1 and tonumber(c.Text) then hasNumber = true end
                end
                return hasNumber and fill or nil
            end
            local function buttonsOf(row)
                local list = {}
                for _, c in ipairs(row:GetChildren()) do if c:IsA("TextButton") then list[#list + 1] = c end end
                return list
            end
            local function rowByName(name)
                for _, e in ipairs(menuRows()) do if e.name == name then return e.row end end
            end

            -- the state of the whole menu
            local function collect()
                local config = { v = 3, t = {}, s = {}, c = {}, d = {}, i = {}, k = {}, b = {}, p = {}, o = {}, x = {}, f = {} }
                for _, e in ipairs(menuRows()) do   -- switches, sliders, colors
                    if not SKIP[e.name] then
                        local hexBox = hexBoxOf(e.row)
                        if hexBox then
                            config.c[e.name] = hexBox.Text
                        else
                            local state = Dyser:GetToggleState(e.name)
                            if state ~= nil then
                                config.t[e.name] = state and 1 or 0
                            else
                                local fill = sliderFillOf(e.row)
                                if fill then config.s[e.name] = math.floor(fill.Size.X.Scale * 1000 + 0.5) / 1000 end
                            end
                        end
                    end
                end
                for _, control in ipairs(Nav.controls or {}) do   -- dropdown choices, texts, keys
                    local row = control.name and not SKIP[control.name] and rowByName(control.name)
                    if row then
                        if control.kind == "AddDropdown" and control.options then
                            local header = buttonsOf(row)[1]
                            local shown = header and header:FindFirstChildWhichIsA("TextLabel")
                            for index, option in ipairs(control.options) do
                                if shown and Nav.textOf(shown) == option then config.d[control.name] = index end
                            end
                        elseif control.kind == "AddInput" then
                            for _, d in ipairs(row:GetDescendants()) do
                                if d:IsA("TextBox") then config.i[control.name] = d.Text; break end
                            end
                        elseif control.kind == "AddRebind" then
                            local keyButton = buttonsOf(row)[1]
                            if keyButton and pcall(function() return Enum.KeyCode[keyButton.Text] end) and Enum.KeyCode[keyButton.Text] then
                                config.k[control.name] = keyButton.Text
                            end
                        end
                    end
                end
                -- the pages as they would be with NOTHING in the Trash as a tab: the functions of a tab that was put away are written
                -- under their own pages (in their old order), and the tab itself is written in "x"
                local packed, extra = {}, {}
                for _, package in ipairs(Nav.trashPackages or {}) do
                    packed[package.banner] = true
                    local perPage = {}
                    for _, it in ipairs(package.items) do
                        packed[it.obj] = true
                        perPage[it.page] = perPage[it.page] or {}
                        table.insert(perPage[it.page], it)
                    end
                    for pg, list in pairs(perPage) do
                        table.sort(list, function(x, y) return x.order < y.order end)
                        local key = pageKey(pg)
                        if key then
                            extra[key] = extra[key] or {}
                            for _, it in ipairs(list) do
                                local name = rowName(it.obj)
                                if name then table.insert(extra[key], name) end
                            end
                        end
                    end
                    config.x[#config.x + 1] = { package.kind, package.name, package.top }
                end
                for _, p in ipairs(menuPages()) do   -- where every function is, in the order shown
                    local names = {}
                    for _, name in ipairs(extra[p.key] or {}) do names[#names + 1] = name end
                    for _, item in ipairs(sortedItems(p.page)) do
                        if not packed[item] then
                            local name = rowName(item)
                            if name then names[#names + 1] = name end
                        end
                    end
                    config.p[p.key] = names
                end
                for _, d in ipairs(window:GetDescendants()) do   -- the order of the side tabs
                    if d:IsA("ScrollingFrame") and d.Name:sub(-10) == "_SidePanel" then
                        local names = {}
                        for _, item in ipairs(sortedItems(d)) do
                            local label = item:IsA("TextButton") and item:FindFirstChildWhichIsA("TextLabel")
                            if label then names[#names + 1] = Nav.textOf(label) end
                        end
                        config.o["S|" .. d.Name:sub(1, -11)] = names
                    end
                end
                local top = {}   -- the order of the top tabs
                for _, e in ipairs(Nav.topTabBtns) do top[#top + 1] = e end
                table.sort(top, function(x, y) return x.button.LayoutOrder < y.button.LayoutOrder end)
                local topNames = {}
                for _, e in ipairs(top) do topNames[#topNames + 1] = e.name end
                config.o["T"] = topNames

                -- the keys of the "key + switch" rows (a key button and the small x / check box)
                for _, e in ipairs(menuRows()) do
                    local list = buttonsOf(e.row)
                    if #list == 2 and not SKIP[e.name] then
                        local keyButton, hasBox
                        for _, b in ipairs(list) do
                            if b.Text == "x" or b.Text == "✓" then hasBox = true else keyButton = b end
                        end
                        if hasBox and keyButton and keyButton.Text ~= "None" and keyButton.Text ~= "..." then config.b[e.name] = keyButton.Text end
                    end
                end
                -- sections that are folded: "page|section" = 1
                for _, p in ipairs(menuPages()) do
                    for _, item in ipairs(p.page:GetChildren()) do
                        if item:IsA("Frame") and item:GetAttribute("DyserSection") and Nav.sectionCollapsed and Nav.sectionCollapsed(item) then
                            local name = rowName(item)
                            if name then config.f[p.key .. "|" .. name] = 1 end
                        end
                    end
                end
                -- the two big panels (folded with the arrows next to General and Preview)
                if Nav.panelsFolded then
                    local st = Nav.panelsFolded()
                    config.u = { st.left and 1 or 0, st.right and 1 or 0 }
                end
                -- which tabs are open
                local sel = {}
                for _, e in ipairs(Nav.topTabBtns) do if e.button == Nav.selectedTop then sel.top = e.name end end
                if sel.top then
                    local pane = window:FindFirstChild(sel.top .. "_LeftPane", true)
                    for _, c in ipairs(pane and pane:GetChildren() or {}) do
                        if c:IsA("ScrollingFrame") and c.Name:sub(-4) == "Page" and c.Visible then sel.side = c.Name:sub(1, -5) end
                    end
                end
                for _, e in ipairs(Nav.rightTabBtns) do if e.button == Nav.selectedRight then sel.right = e.name end end
                config.sel = sel
                -- where the windows stand
                local pos = window.Position
                config.w = { pos.X.Scale, pos.X.Offset, pos.Y.Scale, pos.Y.Offset }
                local playerWindow = Second.UI.screenGui:FindFirstChild("DyserPlayerInfo")
                if playerWindow then
                    local q = playerWindow.Position
                    config.pw = { q.X.Scale, q.X.Offset, q.Y.Scale, q.Y.Offset }
                end
                return config
            end
            local function makeLink(config) return PREFIX .. b64encode(HttpService:JSONEncode(config)) end

            -- text -> settings (nil and a reason when it is not a link)
            local function readLink(text)
                text = tostring(text or ""):match("^%s*(.-)%s*$")
                if text:sub(1, 4):lower() == "http" then   -- a web address: the text of that page is the link
                    local ok, page = pcall(function() return game:HttpGet(text) end)
                    if not ok then return nil, "the web address could not be downloaded" end
                    text = tostring(page):match("^%s*(.-)%s*$")
                end
                if text:sub(1, #PREFIX) == PREFIX then text = text:sub(#PREFIX + 1) end
                local okText, json = pcall(b64decode, text)
                if not okText or json == "" then return nil, "this is not a preset link" end
                local okJson, data = pcall(function() return HttpService:JSONDecode(json) end)
                if not okJson or type(data) ~= "table" or type(data.v) ~= "number" or data.v < 1 or data.v > 3 then return nil, "this is not a preset link" end
                return data
            end

            -- ---------- putting a setup on the menu ----------
            -- a color picker has no function to set it, so its own "#RRGGBB" box is typed into: the box gets the focus for
            -- two frames (it has to be shown for that), and the picker reads the text exactly as if you had typed it
            local function setPickerColor(name, hex)
                local row = rowByName(name)
                local box = row and hexBoxOf(row)
                if not box then return false end
                local revealed, o = {}, box
                while o and o ~= window do
                    if o:IsA("GuiObject") and not o.Visible then o.Visible = true; revealed[#revealed + 1] = o end
                    o = o.Parent
                end
                pcall(function() box:CaptureFocus() end)
                local focused = box:IsFocused()
                if focused then box.Text = hex end
                task.wait(); task.wait()
                pcall(function() box:ReleaseFocus() end)
                for _, g in ipairs(revealed) do g.Visible = false end
                if focused then return true end
                -- the box could not be focused: the two main colors have a function of their own
                local r, g, b = tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
                if name == "Accent Color (Buttons, etc.)" then Dyser:SetAccent(Color3.fromRGB(r, g, b)); return true end
                if name == "Window Background" then Dyser:SetWindowBG(Color3.fromRGB(r, g, b)); return true end
                return false
            end

            -- the key of a "key + switch" row: the library takes a new key from the next key press after a click on the key
            -- button, so the click and the key press are both sent to its own handlers (this needs firesignal)
            local function setKeybindKey(name, keyName)
                local row = rowByName(name)
                if not row or typeof(firesignal) ~= "function" then return false end
                local keyButton
                for _, b in ipairs(buttonsOf(row)) do
                    if b.Text ~= "x" and b.Text ~= "✓" then keyButton = b end
                end
                if not keyButton then return false end
                if keyButton.Text == keyName then return true end
                local okKey, keyCode = pcall(function() return Enum.KeyCode[keyName] end)
                if not okKey or not keyCode then return false end
                local fake = { KeyCode = keyCode, UserInputType = Enum.UserInputType.Keyboard, UserInputState = Enum.UserInputState.Begin }
                pcall(firesignal, keyButton.MouseButton1Click)
                task.wait()
                pcall(firesignal, UserInputService.InputBegan, fake, false)
                task.wait()
                return keyButton.Text == keyName
            end

            local function placeFrame(frame, values)   -- puts a window at a saved place, but keeps it on the screen
                if not frame or type(values) ~= "table" or #values < 4 then return end
                local screen = Second.UI.screenGui.AbsoluteSize
                local x = math.clamp((values[1] or 0) * screen.X + (values[2] or 0), 0, screen.X)
                local y = math.clamp((values[3] or 0) * screen.Y + (values[4] or 0), 0, screen.Y)
                frame.Position = UDim2.fromOffset(x, y)
            end

            local function showDropdownChoice(row, options, index)   -- the row shows the new choice (the library cannot be told)
                local buttons = buttonsOf(row)
                local shown = buttons[1] and buttons[1]:FindFirstChildWhichIsA("TextLabel")
                if shown then shown.Text = options[index] end
                for k = 2, #buttons do
                    local n = k - 1
                    if options[n] then
                        buttons[k].Text = (n == index and "✓ " or "   ") .. options[n]
                        buttons[k].BackgroundColor3 = n == index and Color3.fromRGB(28, 28, 34) or Color3.fromRGB(12, 12, 14)
                        buttons[k].Font = n == index and FONT_BOLD or Enum.Font.Code
                    end
                end
            end

            local function applyLayout(data)   -- where the functions are, and in which order the things on a page and the tabs are
                local pages, functions = {}, {}
                for _, p in ipairs(menuPages()) do
                    pages[p.key] = p.page
                    for _, row in ipairs(p.page:GetChildren()) do
                        if row:IsA("Frame") and row.Active then
                            local name = rowName(row)
                            if name then functions[name] = functions[name] == nil and row or false end   -- a name used twice is left alone
                        end
                    end
                end
                local moved = 0
                for key, names in pairs(type(data.p) == "table" and data.p or {}) do   -- 1. the functions go to their pages
                    local page = pages[key]
                    if page and type(names) == "table" then
                        for _, name in ipairs(names) do
                            local row = functions[name]
                            if row and row.Parent ~= page then
                                row.Parent = page; moved = moved + 1
                                if Nav.setRowPage then Nav.setRowPage(row, page) end
                            end
                        end
                    end
                end
                for key, names in pairs(type(data.p) == "table" and data.p or {}) do   -- 2. every page gets the recorded order
                    local page = pages[key]
                    if page and type(names) == "table" then
                        local taken, order = {}, 0
                        for _, name in ipairs(names) do
                            for _, item in ipairs(page:GetChildren()) do
                                if item:IsA("GuiObject") and not taken[item] and rowName(item) == name then
                                    taken[item] = true; order = order + 1; item.LayoutOrder = order
                                    break
                                end
                            end
                        end
                        for _, item in ipairs(page:GetChildren()) do   -- what the link does not know goes to the end
                            if item:IsA("GuiObject") and not taken[item] then order = order + 1; item.LayoutOrder = order end
                        end
                    end
                end
                local function reorderTabs(buttons, names)   -- buttons: { name, button }
                    local order, taken = 0, {}
                    for _, name in ipairs(names) do
                        for _, e in ipairs(buttons) do
                            if e.name == name and not taken[e] then taken[e] = true; order = order + 1; e.button.LayoutOrder = order; break end
                        end
                    end
                    for _, e in ipairs(buttons) do if not taken[e] then order = order + 1; e.button.LayoutOrder = order end end
                end
                for key, names in pairs(type(data.o) == "table" and data.o or {}) do   -- 3. the tabs
                    if type(names) == "table" then
                        if key == "T" then
                            reorderTabs(Nav.topTabBtns, names)
                        elseif key:sub(1, 2) == "S|" then
                            local panel = window:FindFirstChild(key:sub(3) .. "_SidePanel", true)
                            local buttons = {}
                            for _, b in ipairs(panel and panel:GetChildren() or {}) do
                                local label = b:IsA("TextButton") and b:FindFirstChildWhichIsA("TextLabel")
                                if label then buttons[#buttons + 1] = { name = Nav.textOf(label), button = b } end
                            end
                            reorderTabs(buttons, names)
                        end
                    end
                end
                return moved
            end

            local function applyConfig(data)
                task.spawn(function()
                    local known = {}
                    for _, e in ipairs(menuRows()) do known[e.name] = true end
                    local n = { t = 0, s = 0, c = 0, d = 0, i = 0, k = 0, b = 0, bFailed = 0 }
                    -- first the places: everything after it finds its row where it belongs. Tabs that are in the Trash come
                    -- back, every function goes to its page, then the tabs of the link that were in the Trash go there again
                    if Nav.restoreAllTrash then pcall(Nav.restoreAllTrash) end
                    local moved = applyLayout(data)
                    for _, entry in ipairs(type(data.x) == "table" and data.x or {}) do
                        local kind, tabName, topName = entry[1], entry[2], entry[3]
                        local button
                        if kind == "top" then
                            for _, e in ipairs(Nav.topTabBtns) do if e.name == tabName then button = e.button end end
                        elseif kind == "side" then
                            local panel = window:FindFirstChild(tostring(topName) .. "_SidePanel", true)
                            for _, b in ipairs(panel and panel:GetChildren() or {}) do
                                local l = b:IsA("TextButton") and b:FindFirstChildWhichIsA("TextLabel")
                                if l and Nav.textOf(l) == tabName then button = b end
                            end
                        end
                        if button and Nav.putTabInTrash then pcall(Nav.putTabInTrash, button, kind) end
                    end
                    if type(data.f) == "table" and Nav.collapseSection and Nav.expandSection then   -- folded sections
                        for _, p in ipairs(menuPages()) do
                            for _, item in ipairs(p.page:GetChildren()) do
                                if item:IsA("Frame") and item:GetAttribute("DyserSection") then
                                    local name = rowName(item)
                                    if name and data.f[p.key .. "|" .. name] == 1 then Nav.collapseSection(item, true)
                                    else Nav.expandSection(item, true) end
                                end
                            end
                        end
                    end

                    local byName = {}   -- the registry of dropdowns, text boxes and key rebinds, by kind and name
                    for _, control in ipairs(Nav.controls or {}) do
                        if control.name then byName[control.kind .. "|" .. control.name] = control end
                    end
                    for name, index in pairs(type(data.d) == "table" and data.d or {}) do   -- dropdown choices
                        local control, row = byName["AddDropdown|" .. tostring(name)], rowByName(tostring(name))
                        if control and row and control.options and control.options[index] and not SKIP[name] then
                            pcall(control.apply, index, control.options[index])
                            showDropdownChoice(row, control.options, index); n.d = n.d + 1
                        end
                    end
                    for name, text in pairs(type(data.i) == "table" and data.i or {}) do   -- text boxes
                        local control, row = byName["AddInput|" .. tostring(name)], rowByName(tostring(name))
                        if control and row and type(text) == "string" and not SKIP[name] then
                            for _, d in ipairs(row:GetDescendants()) do
                                if d:IsA("TextBox") then d.Text = text; break end
                            end
                            pcall(control.apply, text); n.i = n.i + 1
                        end
                    end
                    for name, keyName in pairs(type(data.k) == "table" and data.k or {}) do   -- keys of the key rebinds
                        local control, row = byName["AddRebind|" .. tostring(name)], rowByName(tostring(name))
                        local okKey, keyCode = pcall(function() return Enum.KeyCode[tostring(keyName)] end)
                        if control and row and okKey and keyCode and not SKIP[name] then
                            local keyButton = buttonsOf(row)[1]
                            if keyButton then keyButton.Text = keyName end
                            pcall(control.apply, keyCode); n.k = n.k + 1
                        end
                    end
                    -- colors, then sliders, then the switches (a switch like Rainbow may override a color)
                    for name, hex in pairs(type(data.c) == "table" and data.c or {}) do
                        if known[name] and not SKIP[name] and type(hex) == "string" and hex:match("^#%x%x%x%x%x%x$") then
                            if setPickerColor(name, hex) then n.c = n.c + 1 end
                        end
                    end
                    for name, a in pairs(type(data.s) == "table" and data.s or {}) do
                        if known[name] and not SKIP[name] and type(a) == "number" then
                            Dyser:SetSlider(name, math.clamp(a, 0, 1)); n.s = n.s + 1
                        end
                    end
                    for name, v in pairs(type(data.t) == "table" and data.t or {}) do
                        if known[name] and not SKIP[name] then
                            Dyser:SetToggle(name, v == 1 or v == true); n.t = n.t + 1
                        end
                    end
                    for name, keyName in pairs(type(data.b) == "table" and data.b or {}) do   -- keys of "key + switch" rows
                        if known[name] and not SKIP[name] and type(keyName) == "string" then
                            if setKeybindKey(name, keyName) then n.b = n.b + 1 else n.bFailed = n.bFailed + 1 end
                        end
                    end
                    if type(data.u) == "table" and Nav.foldPanel then   -- the two big panels
                        pcall(Nav.foldPanel, "left", data.u[1] == 1)
                        pcall(Nav.foldPanel, "right", data.u[2] == 1)
                    end
                    local sel = type(data.sel) == "table" and data.sel   -- which tabs are open
                    if sel then
                        if sel.top and Nav.selectTopTab then pcall(Nav.selectTopTab, sel.top) end
                        if sel.top and sel.side and Nav.selectSideTab then pcall(Nav.selectSideTab, sel.top, sel.side) end
                        if sel.right and Nav.selectRightTab then pcall(Nav.selectRightTab, sel.right) end
                    end
                    placeFrame(window, data.w)   -- where the windows stand
                    placeFrame(Second.UI.screenGui:FindFirstChild("DyserPlayerInfo"), data.pw)
                    local keysText = tostring(n.k + n.b) .. " keys"
                    if n.bFailed > 0 then keysText = keysText .. " (" .. n.bFailed .. " could not be set)" end
                    Dyser:AddLog(string.format("Preset applied: %d switches, %d sliders, %d colors, %d choices, %d texts, %s, %d functions moved.",
                        n.t, n.s, n.c, n.d, n.i, keysText, moved), ACCENT)
                end)
            end

            local function pasteBox()   -- the text box of the "Paste Link" row
                local row = rowByName("Paste Link")
                for _, d in ipairs(row and row:GetDescendants() or {}) do if d:IsA("TextBox") then return d end end
            end

            Settings:AddSection("Config Link")
            local pasted = ""
            Settings:AddInput({ Text = "Paste Link", Default = "", Callback = function(text) pasted = text or "" end })
            Settings:AddButton({ Text = "Copy Preset Link", Callback = function()
                local link = makeLink(collect())
                local copy = (typeof(setclipboard) == "function" and setclipboard) or (typeof(toclipboard) == "function" and toclipboard)
                if copy and pcall(copy, link) then
                    Dyser:AddLog("Preset link copied (" .. #link .. " characters). Send it to a friend.", ACCENT)
                else
                    local box = pasteBox()
                    if box then box.Text = link end
                    Dyser:AddLog("No clipboard here: the link is in the Paste Link box, copy it from there.", ACCENT)
                end
            end })
            Settings:AddButton({ Text = "Load From Link", Callback = function()
                local box = pasteBox()
                local text = (box and box.Text ~= "") and box.Text or pasted
                if text == "" and typeof(getclipboard) == "function" then
                    local ok, clip = pcall(getclipboard)
                    if ok then text = clip end
                end
                local data, reason = readLink(text)
                if not data then
                    Dyser:AddLog("Load failed: " .. tostring(reason) .. ".", PINK)
                    return
                end
                applyConfig(data)
            end })
        end
    end

    -- ── Factory reset (Settings > Factory Reset) ───────────────────────────
    -- The button starts the whole menu again from nothing: the menu and all its windows are removed, everything that was changed
    -- in the game (colors, light, FPS booster, radar) is undone, then the library, the second module, this one and the fourth
    -- module (tabs, radar) are built
    -- again. So every setting, the size and place of the window, the hotkeys, the moved functions and tabs (also those in the
    -- Trash), the language and the console switch are back as they were at the very first start. Press it twice (within 5
    -- seconds) to confirm.
    do
        local Settings = Nav and Nav.settingsTab
        if Settings then
            Settings:AddSection("Factory Reset")
            local armedAt = 0
            Settings:AddButton({ Text = "Reset to Factory Settings", Callback = function()
                if os.clock() - armedAt < 5 then
                    armedAt = 0
                    factoryReset()
                else
                    armedAt = os.clock()
                    Dyser:AddLog("Press Reset to Factory Settings once more within 5 seconds to confirm.", Second.UI.COLORS.accent)
                end
            end })
        end
    end

    -- ── 3. Finish ──────────────────────────────────────────────────────────
    -- What the modules on top of this one need. The fourth module builds the left / top tabs and the radar with it: it gives its
    -- build function to Third.start (see the end of this file), and after a factory reset that function runs again.
    local context = {
        Second = Second, Dyser = Dyser, Window = Window, Nav = Nav, UI = Second.UI,
        gconnect = gconnect,                  -- listener on a game service that stops by itself after a restart of the menu
        addActionKey = addActionKey,          -- a row with a key for a function (see "Keys for functions")
        UserInputService = UserInputService,
        addCleanup = function(undo) table.insert(cleanups, undo) end,   -- something the factory reset has to undo
        refresh = Second.refresh,             -- call it after creating tabs: they become draggable / movable and get hints
    }
    currentContext = context
    for _, builder in ipairs(builders) do   -- after a factory reset the modules on top build themselves again
        local ok, err = pcall(builder, context)
        if not ok then warn("[Dyser] A module on top of this one failed: " .. tostring(err)) end
    end
    -- the tabs created after the second module had started are made draggable / movable and get hints
    if Second.refresh then Second.refresh() end
end

local firstSecond = startSecond()
if not firstSecond then return end
currentSecond = firstSecond
build(firstSecond)

-- What the fourth module uses: Third.start(function(context) ... end) runs the function now (with the library, the window and
-- the helpers in "context") and again after every factory reset.
local Third = {}
function Third.start(builder)
    builders[#builders + 1] = builder
    if currentContext then
        local ok, err = pcall(builder, currentContext)
        if not ok then warn("[Dyser] The fourth module failed: " .. tostring(err)) end
        if currentContext.refresh then currentContext.refresh() end
    else
        warn("[Dyser] The menu is not built: the fourth module cannot start.")
    end
end
return Third
