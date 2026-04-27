local CONFIG = {
    SOURCE_URL = "https://raw.githubusercontent.com/fbi2005z1000-cmyk/racket-script/refs/heads/main/main.lua",
    BALL_FOLDER_NAME = "DienTenFolderChuaCau",
    QUEST_NPC_NAME = "DienTenNPCNhiemVu",
    MATCH_BUTTON_NAME = "DienTenNutVaoTran",
    SKILL_KEYS = {"Q", "E", "R"},
    CHARGE_KEY = "F",
    SWING_KEY = "MouseButton1",

    LOOP_DELAY = 0.01,
    SKILL_INTERVAL = 0.5,
    FAST_HIT_DELAY = 0.016,
    BALL_SCAN_DELAY = 0.01,
    TELEPORT_DELAY = 0.016,
    JUMP_DELAY = 0.07,
    CHARGE_DELAY = 0.24,

    BALL_OFFSET = Vector3.new(0, 2, -2),
    BALL_FOLLOW_DISTANCE = 4,
    BALL_HEIGHT_OFFSET = 2,
    FORWARD_HIT_DIRECTION = Vector3.new(0, 0, -1),
    MAX_TELEPORT_STEP = 35,
    STICK_TO_LAST_BALL = true,
    LAST_BALL_TIMEOUT = 1.5,

    MY_COURT_CENTER = Vector3.new(0, 0, 0),
    MY_COURT_RADIUS = 85,
    ONLY_MY_COURT = true,
    DEBUG_IGNORE_COURT_CHECK = true,
    AUTO_TRACK_COURT_CENTER = true,
    COURT_CENTER_UPDATE_DELAY = 0.3,
    ENEMY_BALL_LOG_DELAY = 1.0,
    FALLBACK_BALL_DISTANCE = 70,

    MY_COURT_MIN = Vector3.new(-50, 0, -80),
    MY_COURT_MAX = Vector3.new(50, 0, 20),
    SAFE_Y_OFFSET = 3,
    FOLLOW_BACK_DISTANCE = 3,
    ONLY_TELEPORT_INSIDE_COURT = true,

    AUTO_RELOAD = true,
    SELECTED_MODE = "2v2",
    MODES = {"Rank 2v2", "Rank 1v1", "3v3", "2v2", "1v1"},

    JOIN_DELAY = 1.2,
    MODE_DELAY = 1.0,
    FIND_DELAY = 1.0,
    QUEST_DELAY = 4.0,

    LOG_LIMIT = 11,
    MAX_BALL_DISTANCE = 350
}

local MODE_TEXT_MAP = {
    ["Rank 2v2"] = {"Xep hang 2v2", "XepHang2v2", "Rank 2v2", "rank 2v2"},
    ["Rank 1v1"] = {"Xep hang 1v1", "XepHang1v1", "Rank 1v1", "rank 1v1"},
    ["3v3"] = {"3 v 3", "3v3"},
    ["2v2"] = {"2 v 2", "2v2"},
    ["1v1"] = {"1 v 1", "1v1"}
}

local PLAY_TEXTS = {"PLAY", "Play"}
local FIND_MATCH_TEXTS = {"Tim tran dau", "Find Match", "Find"}
local BALL_NAME_HINTS = {"ball", "shuttle", "projectile", "orb", "cau", "tennis"}
local CONFIG_FILE = "racket_helper_config.json"

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    return
end

local UI_NAME = "SafeRacketHelperUI"
local SHOW_NAME = "SafeRacketHelperShow"
local IN_MATCH_ATTR = "InMatch"

local state = {
    running = true,
    ui = {},
    logs = {},
    logTick = {},
    skillIndex = 1,
    lastBall = 0,
    lastJump = 0,
    lastCharge = 0,
    lastSkill = 0,
    lastQuest = 0,
    lastJoin = 0,
    lastMode = 0,
    lastFind = 0,
    lastTeleport = 0,
    lastFastHit = 0,
    lastTest = 0,
    lastBallSeen = 0,
    lastBallLockAt = 0,
    lastBallRef = nil,
    lastCourtSync = 0,
    toggles = {
        AutoBall = true,
        AutoJumpHit = true,
        AutoCharge = false,
        AutoSkill = true,
        AutoQuest = false,
        AutoJoin = false,
        AutoReload = CONFIG.AUTO_RELOAD,
        TestMode = false,
        AutoSelectMode = true,
        AutoFindMatch = true,
        FastHit = true,
        TeleportToBall = true
    }
}

if getgenv then
    local g = getgenv()
    if g.__SAFE_RACKET_HELPER_STOP then
        pcall(g.__SAFE_RACKET_HELPER_STOP)
    end
    g.__SAFE_RACKET_HELPER_STOP = function()
        state.running = false
        local oldGui = CoreGui:FindFirstChild(UI_NAME)
        if oldGui then
            oldGui:Destroy()
        end
    end
end

local function getCharacter()
    local c = LocalPlayer.Character
    if c and c.Parent then
        return c
    end
    return nil
end

local function getHumanoid()
    local c = getCharacter()
    if not c then
        return nil
    end
    return c:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
    local c = getCharacter()
    if not c then
        return nil
    end
    return c:FindFirstChild("HumanoidRootPart")
end

local function safeLower(v)
    if typeof(v) ~= "string" then
        return ""
    end
    return string.lower(v)
end

local function normalizeText(v)
    local s = safeLower(v)
    s = s:gsub("%s+", "")
    s = s:gsub("[%p%c]", "")
    return s
end

local function now()
    return os.clock()
end

local function shouldIgnoreCourtCheck()
    return CONFIG.DEBUG_IGNORE_COURT_CHECK == true
end

local function updateCourtCenterFromCharacter()
    if not CONFIG.AUTO_TRACK_COURT_CENTER then
        return
    end
    local t = now()
    if t - state.lastCourtSync < CONFIG.COURT_CENTER_UPDATE_DELAY then
        return
    end
    state.lastCourtSync = t

    local root = getRoot()
    if not root then
        return
    end

    -- Chi dong bo theo mat phang san (XZ), giu nguyen Y tu config.
    CONFIG.MY_COURT_CENTER = Vector3.new(root.Position.X, CONFIG.MY_COURT_CENTER.Y, root.Position.Z)
end

local function getForwardUnit()
    local v = CONFIG.FORWARD_HIT_DIRECTION
    local flat = Vector3.new(v.X, 0, v.Z)
    if flat.Magnitude < 0.001 then
        return Vector3.new(0, 0, -1)
    end
    return flat.Unit
end

local function tapKey(keyName, holdTime)
    local keyCode = Enum.KeyCode[keyName]
    if not keyCode then
        return false
    end
    holdTime = holdTime or 0.08
    local ok = pcall(function()
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        task.wait(holdTime)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)
    return ok
end

local function clickMouseLeft()
    local cam = workspace.CurrentCamera
    if not cam then
        return false
    end
    local vp = cam.ViewportSize
    local x = math.floor(vp.X * 0.5)
    local y = math.floor(vp.Y * 0.5)
    local ok = pcall(function()
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.008)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
    return ok
end

function log(msg)
    local ts = os.date("%H:%M:%S")
    local line = "[" .. ts .. "] " .. tostring(msg)
    print("[Helper] " .. tostring(msg))
    table.insert(state.logs, 1, line)
    while #state.logs > CONFIG.LOG_LIMIT do
        table.remove(state.logs)
    end
    if state.ui.status then
        state.ui.status.Text = table.concat(state.logs, "\n")
    end
end

local function throttledLog(key, msg, delay)
    local t = now()
    local last = state.logTick[key] or 0
    if t - last >= delay then
        state.logTick[key] = t
        log(msg)
    end
end

function saveConfig()
    local payload = {
        SELECTED_MODE = CONFIG.SELECTED_MODE,
        toggles = state.toggles
    }
    if getgenv then
        pcall(function()
            getgenv().__RACKET_HELPER_SAVED = payload
        end)
    end
    if writefile and HttpService then
        pcall(function()
            writefile(CONFIG_FILE, HttpService:JSONEncode(payload))
        end)
    end
end

function loadConfig()
    if getgenv then
        local ok, cached = pcall(function()
            return getgenv().__RACKET_HELPER_SAVED
        end)
        if ok and type(cached) == "table" then
            if type(cached.SELECTED_MODE) == "string" then
                CONFIG.SELECTED_MODE = cached.SELECTED_MODE
            end
            if type(cached.toggles) == "table" then
                for k, v in pairs(cached.toggles) do
                    if state.toggles[k] ~= nil and type(v) == "boolean" then
                        state.toggles[k] = v
                    end
                end
            end
        end
    end
    if readfile and isfile then
        pcall(function()
            if isfile(CONFIG_FILE) then
                local raw = readfile(CONFIG_FILE)
                local decoded = HttpService:JSONDecode(raw)
                if type(decoded) == "table" then
                    if type(decoded.SELECTED_MODE) == "string" then
                        CONFIG.SELECTED_MODE = decoded.SELECTED_MODE
                    end
                    if type(decoded.toggles) == "table" then
                        for k, v in pairs(decoded.toggles) do
                            if state.toggles[k] ~= nil and type(v) == "boolean" then
                                state.toggles[k] = v
                            end
                        end
                    end
                end
            end
        end)
    end
end

local function setToggleButtonStyle(btn, enabled)
    btn.Text = enabled and "ON" or "OFF"
    btn.BackgroundColor3 = enabled and Color3.fromRGB(45, 160, 85) or Color3.fromRGB(165, 70, 70)
end

local function addToggleRow(parent, y, labelText, keyName)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -10, 0, 26)
    row.Position = UDim2.new(0, 5, 0, y)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextColor3 = Color3.fromRGB(240, 240, 240)
    label.Text = labelText
    label.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 72, 0, 22)
    btn.Position = UDim2.new(1, -74, 0.5, -11)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.AutoButtonColor = false
    btn.Parent = row
    setToggleButtonStyle(btn, state.toggles[keyName])

    btn.MouseButton1Click:Connect(function()
        state.toggles[keyName] = not state.toggles[keyName]
        setToggleButtonStyle(btn, state.toggles[keyName])
        saveConfig()
        log(labelText .. " = " .. (state.toggles[keyName] and "ON" or "OFF"))
    end)
end

function findGuiButtonByText(textList)
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui or type(textList) ~= "table" then
        return nil
    end

    local normalizedTargets = {}
    for _, t in ipairs(textList) do
        local nt = normalizeText(t)
        if nt ~= "" then
            table.insert(normalizedTargets, nt)
        end
    end

    local function scoreText(candidate)
        local n = normalizeText(candidate)
        if n == "" then
            return -1
        end
        local best = -1
        for _, target in ipairs(normalizedTargets) do
            if n == target then
                best = math.max(best, 1000)
            elseif string.find(n, target, 1, true) then
                best = math.max(best, 700)
            elseif string.find(target, n, 1, true) then
                best = math.max(best, 500)
            end
        end
        return best
    end

    local bestButton = nil
    local bestScore = -1

    for _, obj in ipairs(playerGui:GetDescendants()) do
        local candidateButton = nil
        local candidateScore = -1

        if obj:IsA("TextButton") then
            candidateButton = obj
            candidateScore = scoreText(obj.Text)
        elseif obj:IsA("ImageButton") then
            candidateButton = obj
            for _, d in ipairs(obj:GetDescendants()) do
                if d:IsA("TextLabel") or d:IsA("TextButton") then
                    candidateScore = math.max(candidateScore, scoreText(d.Text))
                end
            end
        elseif obj:IsA("TextLabel") and obj.Parent and obj.Parent:IsA("GuiButton") then
            candidateButton = obj.Parent
            candidateScore = scoreText(obj.Text)
        end

        if candidateButton and candidateButton.Visible and candidateScore > bestScore then
            bestScore = candidateScore
            bestButton = candidateButton
        end
    end

    return bestButton
end

function clickGuiButton(button)
    if not button then
        return false
    end
    local okActivate = pcall(function()
        if button:IsA("GuiButton") then
            button:Activate()
        end
    end)
    if okActivate then
        return true
    end
    local okClick = pcall(function()
        local pos = button.AbsolutePosition
        local size = button.AbsoluteSize
        local x = math.floor(pos.X + size.X * 0.5)
        local y = math.floor(pos.Y + size.Y * 0.5)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.02)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
    return okClick
end

function clickPlayButton()
    local btn = findGuiButtonByText(PLAY_TEXTS)
    if not btn then
        throttledLog("play_not_found", "Khong tim thay nut PLAY", 1.0)
        return false
    end
    local ok = clickGuiButton(btn)
    if ok then
        log("Da bam PLAY")
    else
        throttledLog("play_click_fail", "Khong bam duoc nut PLAY", 1.0)
    end
    return ok
end

function selectGameMode(modeName)
    local targets = MODE_TEXT_MAP[modeName] or {modeName}
    local btn = findGuiButtonByText(targets)
    if not btn then
        throttledLog("mode_not_found_" .. tostring(modeName), "Khong tim thay mode: " .. tostring(modeName), 1.0)
        return false
    end
    local ok = clickGuiButton(btn)
    if ok then
        log("Da chon mode: " .. tostring(modeName))
    else
        throttledLog("mode_click_fail_" .. tostring(modeName), "Khong bam duoc mode: " .. tostring(modeName), 1.0)
    end
    return ok
end

function clickFindMatch()
    local btn = findGuiButtonByText(FIND_MATCH_TEXTS)
    if not btn then
        throttledLog("find_not_found", "Khong tim thay nut Tim tran dau", 1.0)
        return false
    end
    local ok = clickGuiButton(btn)
    if ok then
        log("Da bam Tim tran dau")
    else
        throttledLog("find_click_fail", "Khong bam duoc Tim tran dau", 1.0)
    end
    return ok
end

function isInsideMyCourt(pos)
    return pos.X >= CONFIG.MY_COURT_MIN.X
        and pos.X <= CONFIG.MY_COURT_MAX.X
        and pos.Z >= CONFIG.MY_COURT_MIN.Z
        and pos.Z <= CONFIG.MY_COURT_MAX.Z
end

function clampToMyCourt(pos)
    local root = getRoot()
    local y = pos.Y
    if root then
        y = root.Position.Y + CONFIG.SAFE_Y_OFFSET
    else
        y = y + CONFIG.SAFE_Y_OFFSET
    end

    local clampedX = math.clamp(pos.X, CONFIG.MY_COURT_MIN.X, CONFIG.MY_COURT_MAX.X)
    local clampedZ = math.clamp(pos.Z, CONFIG.MY_COURT_MIN.Z, CONFIG.MY_COURT_MAX.Z)
    return Vector3.new(clampedX, y, clampedZ)
end

function isBallOnMyCourt(ball)
    if not ball or not ball:IsA("BasePart") then
        return false
    end
    local bxz = Vector3.new(ball.Position.X, 0, ball.Position.Z)
    local cxz = Vector3.new(CONFIG.MY_COURT_CENTER.X, 0, CONFIG.MY_COURT_CENTER.Z)
    local d = (bxz - cxz).Magnitude
    return d <= CONFIG.MY_COURT_RADIUS
end

function getSafeCourtPositionNearBall(ball)
    if not ball or not ball:IsA("BasePart") then
        return nil
    end

    local bp = ball.Position
    if (not shouldIgnoreCourtCheck()) and CONFIG.ONLY_TELEPORT_INSIDE_COURT and (not isInsideMyCourt(bp)) then
        return nil
    end

    local forward = getForwardUnit()
    local target = bp - (forward * CONFIG.FOLLOW_BACK_DISTANCE) + Vector3.new(0, CONFIG.SAFE_Y_OFFSET, 0)
    target = clampToMyCourt(target)
    return target
end

function getBallTargetCFrame(ball)
    if not ball or not ball:IsA("BasePart") then
        return nil
    end
    local forward = getForwardUnit()
    local target = ball.Position - (forward * CONFIG.BALL_FOLLOW_DISTANCE) + Vector3.new(0, CONFIG.BALL_HEIGHT_OFFSET, 0)
    if (not shouldIgnoreCourtCheck()) and CONFIG.ONLY_TELEPORT_INSIDE_COURT then
        target = clampToMyCourt(target)
    end
    local lookPos = ball.Position + (forward * 8)
    return CFrame.new(target, lookPos)
end

function smartFindBall()
    local root = getRoot()
    if not root then
        return nil, math.huge
    end

    local bestPart = nil
    local bestDist = math.huge
    local bestScore = -math.huge

    local function tryPart(part, ownerName, extraScore)
        if not part or not part:IsA("BasePart") then
            return
        end

        local combinedName = safeLower(ownerName .. " " .. part.Name)
        local nameMatched = false
        for _, hint in ipairs(BALL_NAME_HINTS) do
            if string.find(combinedName, hint, 1, true) then
                nameMatched = true
                break
            end
        end
        if not nameMatched then
            return
        end

        local dist = (part.Position - root.Position).Magnitude
        if dist > CONFIG.MAX_BALL_DISTANCE then
            return
        end

        local vel = part.AssemblyLinearVelocity.Magnitude
        local sizeMag = part.Size.Magnitude
        if sizeMag > 30 then
            return
        end

        if (not shouldIgnoreCourtCheck()) and CONFIG.ONLY_TELEPORT_INSIDE_COURT and (not isInsideMyCourt(part.Position)) and (not isBallOnMyCourt(part)) then
            return
        end

        extraScore = extraScore or 0
        local score = 0
        score = score + math.min(vel * 3, 300)
        score = score + (220 - math.min(dist, 220))
        score = score + (40 - math.min(sizeMag, 40))
        if vel > 3 then
            score = score + 100
        end
        score = score + extraScore

        if score > bestScore then
            bestScore = score
            bestPart = part
            bestDist = dist
        end
    end

    if CONFIG.STICK_TO_LAST_BALL and state.lastBallRef and state.lastBallRef.Parent and state.lastBallRef:IsA("BasePart") then
        local held = state.lastBallRef
        local heldDist = (held.Position - root.Position).Magnitude
        if heldDist <= CONFIG.MAX_BALL_DISTANCE then
            local bonus = 500
            if now() - state.lastBallLockAt <= CONFIG.LAST_BALL_TIMEOUT then
                bonus = bonus + 300
            end
            tryPart(held, held.Name, bonus)
        end
    end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            tryPart(obj, obj.Name)
        elseif obj:IsA("Model") then
            local p = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if p then
                tryPart(p, obj.Name)
            end
        end
    end

    if not bestPart then
        -- Fallback: neu ten khong giong "ball", uu tien vat the nho + bay nhanh + gan nhan vat.
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                local dist = (obj.Position - root.Position).Magnitude
                if dist <= CONFIG.FALLBACK_BALL_DISTANCE then
                    local vel = obj.AssemblyLinearVelocity.Magnitude
                    local sizeMag = obj.Size.Magnitude
                    if vel >= 35 and sizeMag <= 10 then
                        if (not shouldIgnoreCourtCheck()) and CONFIG.ONLY_TELEPORT_INSIDE_COURT and (not isInsideMyCourt(obj.Position)) and (not isBallOnMyCourt(obj)) then
                            continue
                        end
                        local score = vel * 2 + (CONFIG.FALLBACK_BALL_DISTANCE - dist)
                        if score > bestScore then
                            bestScore = score
                            bestPart = obj
                            bestDist = dist
                        end
                    end
                end
            end
        end
    end

    if not bestPart then
        local folder = workspace:FindFirstChild(CONFIG.BALL_FOLDER_NAME)
        if folder then
            for _, obj in ipairs(folder:GetDescendants()) do
                if obj:IsA("BasePart") then
                    tryPart(obj, obj.Name)
                end
            end
        end
    end

    if bestPart then
        state.lastBallRef = bestPart
        state.lastBallLockAt = now()
    elseif state.lastBallRef and (now() - state.lastBallLockAt > CONFIG.LAST_BALL_TIMEOUT) then
        state.lastBallRef = nil
    end

    return bestPart, bestDist
end

function findBall()
    local part, _ = smartFindBall()
    return part
end

function moveToBall(ball)
    if not ball or not ball:IsA("BasePart") then
        return
    end
    if (not shouldIgnoreCourtCheck()) and CONFIG.ONLY_MY_COURT and (not isBallOnMyCourt(ball)) then
        return
    end
    local humanoid = getHumanoid()
    local root = getRoot()
    if not humanoid then
        return
    end

    if state.toggles.TeleportToBall then
        return
    end

    pcall(function()
        humanoid.WalkSpeed = math.max(humanoid.WalkSpeed, 70)
        local dist = root and (ball.Position - root.Position).Magnitude or 0
        local forward = getForwardUnit()
        if root and dist > 20 then
            local dashPos = ball.Position - (forward * 3) + Vector3.new(0, 2, 0)
            root.CFrame = CFrame.new(dashPos, ball.Position)
        else
            humanoid:MoveTo(ball.Position)
        end
    end)
end

function teleportToBall(ball)
    return safeTeleportToBall(ball)
end

function safeTeleportToBall(ball)
    if not ball or not ball:IsA("BasePart") then
        return false
    end

    if (not shouldIgnoreCourtCheck()) and CONFIG.ONLY_MY_COURT and not isBallOnMyCourt(ball) then
        throttledLog("ball_enemy_zone", "Cau dang o san doi thu - dung yen", CONFIG.ENEMY_BALL_LOG_DELAY)
        return false
    end

    local root = getRoot()
    if not root then
        return false
    end

    local safePos = getSafeCourtPositionNearBall(ball)
    if safePos == nil then
        throttledLog("ball_outside_court", "Cau ngoai san minh - khong teleport", CONFIG.ENEMY_BALL_LOG_DELAY)
        return false
    end

    local targetCf = getBallTargetCFrame(ball)
    if not targetCf then
        targetCf = CFrame.new(safePos, ball.Position)
    end

    pcall(function()
        local targetPos = targetCf.Position
        local delta = targetPos - root.Position
        if delta.Magnitude > CONFIG.MAX_TELEPORT_STEP then
            targetPos = root.Position + delta.Unit * CONFIG.MAX_TELEPORT_STEP
            targetCf = CFrame.new(targetPos, targetPos + getForwardUnit())
        end
        root.CFrame = targetCf
    end)
    return true
end

function jumpHitBall()
    local humanoid = getHumanoid()
    if not humanoid then
        return
    end
    pcall(function()
        humanoid.Jump = true
    end)
end

function chargePower()
    local ok = tapKey(CONFIG.CHARGE_KEY, 0.04)
    if not ok then
        throttledLog("charge_key_invalid", "Charge key khong hop le", 1.2)
    end
end

function useSkill()
    if #CONFIG.SKILL_KEYS == 0 then
        return
    end
    local key = CONFIG.SKILL_KEYS[state.skillIndex]
    local ok = tapKey(key, 0.03)
    if ok then
        throttledLog("skill_use_" .. tostring(key), "Dang dung skill: " .. tostring(key), 0.5)
    else
        throttledLog("skill_invalid_" .. tostring(key), "Skill key khong hop le: " .. tostring(key), 1.0)
    end
    state.skillIndex = state.skillIndex + 1
    if state.skillIndex > #CONFIG.SKILL_KEYS then
        state.skillIndex = 1
    end
end

function spamSwing()
    if CONFIG.SWING_KEY == "MouseButton1" then
        clickMouseLeft()
    else
        tapKey(CONFIG.SWING_KEY, 0.01)
    end
end

function fastHitBall()
    local t = now()
    if t - state.lastFastHit < CONFIG.FAST_HIT_DELAY then
        return
    end
    state.lastFastHit = t

    pcall(function()
        spamSwing()
    end)

    if state.toggles.AutoSkill and t - state.lastSkill >= CONFIG.SKILL_INTERVAL then
        state.lastSkill = t
        pcall(function()
            useSkill()
        end)
    end
end

function acceptQuest()
    local npc = workspace:FindFirstChild(CONFIG.QUEST_NPC_NAME)
    if npc then
        throttledLog("quest_found", "Tim thay NPC nhiem vu: " .. npc.Name, 2.0)
    else
        throttledLog("quest_not_found", "Chua tim thay NPC nhiem vu", 2.0)
    end
end

function collectReward()
    throttledLog("collect_reward", "collectReward placeholder dang chay", 2.0)
end

function joinMatch()
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        throttledLog("join_no_gui", "Khong co PlayerGui", 1.0)
        return
    end
    local button = playerGui:FindFirstChild(CONFIG.MATCH_BUTTON_NAME, true)
    if button and (button:IsA("TextButton") or button:IsA("ImageButton")) then
        local ok = clickGuiButton(button)
        if ok then
            log("Dang vao tran...")
        else
            throttledLog("join_click_fail", "Khong bam duoc nut vao tran", 1.0)
        end
    else
        throttledLog("join_button_not_found", "Chua tim thay nut vao tran", 1.0)
    end
end

function isInMatch()
    local pAttr = LocalPlayer:GetAttribute(IN_MATCH_ATTR)
    if typeof(pAttr) == "boolean" then
        return pAttr
    end
    local wAttr = workspace:GetAttribute(IN_MATCH_ATTR)
    if typeof(wAttr) == "boolean" then
        return wAttr
    end
    if now() - state.lastBallSeen <= 1.8 then
        return true
    end
    return false
end

function waitForMatch(timeoutSec)
    timeoutSec = timeoutSec or 20
    local t0 = now()
    while now() - t0 < timeoutSec do
        if isInMatch() then
            return true
        end
        task.wait(0.25)
    end
    return false
end

function autoReloadOnTeleport()
    LocalPlayer.OnTeleport:Connect(function(teleportState)
        if teleportState ~= Enum.TeleportState.Started then
            return
        end
        if not state.toggles.AutoReload then
            return
        end

        saveConfig()

        local queueFn = queue_on_teleport
            or (syn and syn.queue_on_teleport)
            or (fluxus and fluxus.queue_on_teleport)
            or (krnl and krnl.queue_on_teleport)

        if queueFn then
            local code = 'loadstring(game:HttpGet("' .. tostring(CONFIG.SOURCE_URL) .. '"))()'
            local ok, err = pcall(function()
                queueFn(code)
            end)
            if ok then
                log("Da queue auto reload khi teleport")
            else
                log("Queue that bai: " .. tostring(err))
            end
        else
            log("moi truong khong ho tro queue_on_teleport")
        end
    end)
end

local function normalizeRuntimeToggles()
    -- Neu file save cu tat het, bat lai bo toi thieu de tranh dung im.
    if (not state.toggles.AutoBall) and (not state.toggles.TeleportToBall) and (not state.toggles.FastHit) then
        state.toggles.AutoBall = true
        state.toggles.TeleportToBall = true
        state.toggles.FastHit = true
        state.toggles.AutoJumpHit = true
        state.toggles.AutoSkill = true
    end
end

function createUI()
    local oldGui = CoreGui:FindFirstChild(UI_NAME)
    if oldGui then
        oldGui:Destroy()
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = UI_NAME
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = CoreGui

    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(0, 340, 0, 620)
    panel.Position = UDim2.new(0, 20, 0.5, -310)
    panel.BackgroundColor3 = Color3.fromRGB(28, 30, 36)
    panel.BorderSizePixel = 0
    panel.Parent = gui

    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 10)
    panelCorner.Parent = panel

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 34)
    header.BackgroundColor3 = Color3.fromRGB(40, 44, 53)
    header.BorderSizePixel = 0
    header.Parent = panel

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 10)
    headerCorner.Parent = header

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -70, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "Safe Helper Template"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextColor3 = Color3.fromRGB(245, 245, 245)
    title.Parent = header

    local hideBtn = Instance.new("TextButton")
    hideBtn.Size = UDim2.new(0, 50, 0, 22)
    hideBtn.Position = UDim2.new(1, -56, 0.5, -11)
    hideBtn.BackgroundColor3 = Color3.fromRGB(90, 97, 111)
    hideBtn.Font = Enum.Font.GothamBold
    hideBtn.TextSize = 12
    hideBtn.Text = "Hide"
    hideBtn.TextColor3 = Color3.new(1, 1, 1)
    hideBtn.Parent = header

    local hideCorner = Instance.new("UICorner")
    hideCorner.CornerRadius = UDim.new(0, 7)
    hideCorner.Parent = hideBtn

    local showBtn = Instance.new("TextButton")
    showBtn.Name = SHOW_NAME
    showBtn.Size = UDim2.new(0, 95, 0, 30)
    showBtn.Position = UDim2.new(0, 20, 1, -42)
    showBtn.BackgroundColor3 = Color3.fromRGB(40, 44, 53)
    showBtn.Font = Enum.Font.GothamBold
    showBtn.TextSize = 12
    showBtn.Text = "Show Helper"
    showBtn.TextColor3 = Color3.new(1, 1, 1)
    showBtn.Visible = false
    showBtn.Parent = gui

    local showCorner = Instance.new("UICorner")
    showCorner.CornerRadius = UDim.new(0, 8)
    showCorner.Parent = showBtn

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -14, 0, 90)
    status.Position = UDim2.new(0, 7, 0, 42)
    status.BackgroundColor3 = Color3.fromRGB(20, 23, 28)
    status.BorderSizePixel = 0
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.TextYAlignment = Enum.TextYAlignment.Top
    status.Font = Enum.Font.Code
    status.TextSize = 12
    status.TextColor3 = Color3.fromRGB(165, 225, 174)
    status.Text = "Dang khoi dong..."
    status.Parent = panel

    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 8)
    statusCorner.Parent = status

    local body = Instance.new("ScrollingFrame")
    body.Size = UDim2.new(1, -14, 1, -140)
    body.Position = UDim2.new(0, 7, 0, 136)
    body.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
    body.BorderSizePixel = 0
    body.ScrollBarThickness = 6
    body.CanvasSize = UDim2.new(0, 0, 0, 760)
    body.Parent = panel

    local bodyCorner = Instance.new("UICorner")
    bodyCorner.CornerRadius = UDim.new(0, 8)
    bodyCorner.Parent = body

    local modeTitle = Instance.new("TextLabel")
    modeTitle.Size = UDim2.new(1, -10, 0, 20)
    modeTitle.Position = UDim2.new(0, 5, 0, 6)
    modeTitle.BackgroundTransparency = 1
    modeTitle.TextXAlignment = Enum.TextXAlignment.Left
    modeTitle.Font = Enum.Font.GothamBold
    modeTitle.TextSize = 13
    modeTitle.TextColor3 = Color3.fromRGB(240, 240, 240)
    modeTitle.Text = "Mode:"
    modeTitle.Parent = body

    local modeButton = Instance.new("TextButton")
    modeButton.Size = UDim2.new(1, -10, 0, 26)
    modeButton.Position = UDim2.new(0, 5, 0, 28)
    modeButton.BackgroundColor3 = Color3.fromRGB(55, 63, 78)
    modeButton.Font = Enum.Font.GothamBold
    modeButton.TextSize = 12
    modeButton.TextColor3 = Color3.new(1, 1, 1)
    modeButton.Text = "Selected: " .. tostring(CONFIG.SELECTED_MODE)
    modeButton.Parent = body

    local modeButtonCorner = Instance.new("UICorner")
    modeButtonCorner.CornerRadius = UDim.new(0, 6)
    modeButtonCorner.Parent = modeButton

    local optionsFrame = Instance.new("Frame")
    optionsFrame.Size = UDim2.new(1, -10, 0, 130)
    optionsFrame.Position = UDim2.new(0, 5, 0, 58)
    optionsFrame.BackgroundColor3 = Color3.fromRGB(38, 43, 52)
    optionsFrame.Visible = false
    optionsFrame.Parent = body

    local optionsCorner = Instance.new("UICorner")
    optionsCorner.CornerRadius = UDim.new(0, 6)
    optionsCorner.Parent = optionsFrame

    for i, modeName in ipairs(CONFIG.MODES) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -8, 0, 22)
        b.Position = UDim2.new(0, 4, 0, 4 + (i - 1) * 25)
        b.BackgroundColor3 = Color3.fromRGB(70, 78, 95)
        b.Font = Enum.Font.Gotham
        b.TextSize = 12
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Text = modeName
        b.Parent = optionsFrame

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 5)
        c.Parent = b

        b.MouseButton1Click:Connect(function()
            CONFIG.SELECTED_MODE = modeName
            modeButton.Text = "Selected: " .. tostring(CONFIG.SELECTED_MODE)
            optionsFrame.Visible = false
            saveConfig()
            log("Da doi mode UI: " .. tostring(modeName))
        end)
    end

    modeButton.MouseButton1Click:Connect(function()
        optionsFrame.Visible = not optionsFrame.Visible
    end)

    local startY = 198
    addToggleRow(body, startY + 0, "Auto Ball", "AutoBall")
    addToggleRow(body, startY + 28, "Auto Jump Hit", "AutoJumpHit")
    addToggleRow(body, startY + 56, "Auto Charge", "AutoCharge")
    addToggleRow(body, startY + 84, "Auto Skill", "AutoSkill")
    addToggleRow(body, startY + 112, "Auto Quest", "AutoQuest")
    addToggleRow(body, startY + 140, "Auto Join", "AutoJoin")
    addToggleRow(body, startY + 168, "Auto Reload", "AutoReload")
    addToggleRow(body, startY + 196, "Test Mode", "TestMode")
    addToggleRow(body, startY + 224, "Auto Select Mode", "AutoSelectMode")
    addToggleRow(body, startY + 252, "Auto Find Match", "AutoFindMatch")
    addToggleRow(body, startY + 280, "Fast Hit", "FastHit")
    addToggleRow(body, startY + 308, "Teleport To Ball", "TeleportToBall")

    hideBtn.MouseButton1Click:Connect(function()
        panel.Visible = false
        showBtn.Visible = true
    end)

    showBtn.MouseButton1Click:Connect(function()
        panel.Visible = true
        showBtn.Visible = false
    end)

    local dragging = false
    local dragStart = nil
    local startPos = nil

    local function updateDrag(input)
        local delta = input.Position - dragStart
        panel.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end

    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = panel.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateDrag(input)
        end
    end)

    state.ui.gui = gui
    state.ui.panel = panel
    state.ui.status = status
    state.ui.modeButton = modeButton
    log("UI san sang")
end

function mainLoop()
    task.spawn(function()
        log("Main loop dang chay")
        while state.running do
            pcall(function()
                updateCourtCenterFromCharacter()
                local t = now()
                local inMatch = isInMatch()

                if state.toggles.AutoJoin and not inMatch and (t - state.lastJoin >= CONFIG.JOIN_DELAY) then
                    state.lastJoin = t
                    clickPlayButton()
                    joinMatch()
                end

                if state.toggles.AutoJoin and state.toggles.AutoSelectMode and not inMatch and (t - state.lastMode >= CONFIG.MODE_DELAY) then
                    state.lastMode = t
                    selectGameMode(CONFIG.SELECTED_MODE)
                end

                if state.toggles.AutoJoin and state.toggles.AutoFindMatch and not inMatch and (t - state.lastFind >= CONFIG.FIND_DELAY) then
                    state.lastFind = t
                    clickFindMatch()
                end

                if state.toggles.AutoQuest and (t - state.lastQuest >= CONFIG.QUEST_DELAY) then
                    state.lastQuest = t
                    acceptQuest()
                    collectReward()
                end

                if (state.toggles.AutoBall or state.toggles.TeleportToBall or state.toggles.FastHit) and (t - state.lastBall >= CONFIG.BALL_SCAN_DELAY) then
                    state.lastBall = t
                    local ball, dist = smartFindBall()

                    if ball then
                        state.lastBallSeen = t
                        throttledLog("ball_found", "Ball found: " .. ball.Name .. " dist=" .. tostring(math.floor(dist)), 0.2)

                        if state.toggles.TeleportToBall then
                            if t - state.lastTeleport >= CONFIG.TELEPORT_DELAY then
                                state.lastTeleport = t
                                local okTp = safeTeleportToBall(ball)
                                if okTp then
                                    throttledLog("ball_action_tp", "Dang TeleportToBall", 0.25)
                                end
                            end
                        elseif state.toggles.AutoBall then
                            moveToBall(ball)
                            throttledLog("ball_action_move", "Dang MoveToBall", 0.25)
                        end

                        if state.toggles.AutoJumpHit then
                            jumpHitBall()
                        end

                        if state.toggles.FastHit then
                            fastHitBall()
                        end
                    else
                        throttledLog("ball_missing", "Khong tim thay cau", 0.8)
                    end
                end

                if state.toggles.AutoCharge and (t - state.lastCharge >= CONFIG.CHARGE_DELAY) then
                    state.lastCharge = t
                    chargePower()
                end

                if state.toggles.AutoSkill and (not state.toggles.FastHit) and (t - state.lastSkill >= CONFIG.SKILL_INTERVAL) then
                    state.lastSkill = t
                    useSkill()
                end

                if state.toggles.TestMode and (t - state.lastTest >= 2.0) then
                    state.lastTest = t
                    log("Test Mode: loop OK | inMatch=" .. tostring(inMatch) .. " | mode=" .. tostring(CONFIG.SELECTED_MODE))
                end
            end)
            task.wait(CONFIG.LOOP_DELAY)
        end
    end)
end

loadConfig()
normalizeRuntimeToggles()
createUI()
autoReloadOnTeleport()
mainLoop()
log("Script da khoi dong")

