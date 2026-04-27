local CONFIG = {
    SOURCE_URL = "https://raw.githubusercontent.com/username/repo/main/main.lua",
    BALL_FOLDER_NAME = "DienTenFolderChuaCau",
    QUEST_NPC_NAME = "DienTenNPCNhiemVu",
    MATCH_BUTTON_NAME = "DienTenNutVaoTran",
    SKILL_KEYS = {"Q", "E", "R"},
    CHARGE_KEY = "F",
    LOOP_DELAY = 0.15,
    SKILL_INTERVAL = 2.5,
    AUTO_RELOAD = true
}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")

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
    skillIndex = 1,
    lastBall = 0,
    lastJump = 0,
    lastCharge = 0,
    lastSkill = 0,
    lastQuest = 0,
    lastJoin = 0,
    lastTest = 0,
    toggles = {
        AutoBall = false,
        AutoJumpHit = false,
        AutoCharge = false,
        AutoSkill = false,
        AutoQuest = false,
        AutoJoin = false,
        AutoReload = CONFIG.AUTO_RELOAD,
        TestMode = false
    }
}

if getgenv then
    local g = getgenv()
    if g.__SAFE_RACKET_HELPER_STOP then
        pcall(g.__SAFE_RACKET_HELPER_STOP)
    end
    g.__SAFE_RACKET_HELPER_STOP = function()
        state.running = false
        local old1 = CoreGui:FindFirstChild(UI_NAME)
        if old1 then
            old1:Destroy()
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

function log(msg)
    local ts = os.date("%H:%M:%S")
    local line = "[" .. ts .. "] " .. tostring(msg)
    print("[Helper] " .. tostring(msg))
    table.insert(state.logs, 1, line)
    while #state.logs > 10 do
        table.remove(state.logs)
    end
    if state.ui.status then
        state.ui.status.Text = table.concat(state.logs, "\n")
    end
end

local function setToggleButtonStyle(btn, enabled)
    btn.Text = enabled and "ON" or "OFF"
    btn.BackgroundColor3 = enabled and Color3.fromRGB(45, 160, 85) or Color3.fromRGB(165, 70, 70)
end

local function addToggleRow(parent, y, labelText, keyName)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -14, 0, 26)
    row.Position = UDim2.new(0, 7, 0, y)
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
        log(labelText .. " = " .. (state.toggles[keyName] and "ON" or "OFF"))
    end)
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
    panel.Size = UDim2.new(0, 330, 0, 390)
    panel.Position = UDim2.new(0, 20, 0.5, -195)
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
    status.Size = UDim2.new(1, -14, 0, 105)
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

    local startY = 155
    addToggleRow(panel, startY + 0, "Auto Ball", "AutoBall")
    addToggleRow(panel, startY + 28, "Auto Jump Hit", "AutoJumpHit")
    addToggleRow(panel, startY + 56, "Auto Charge", "AutoCharge")
    addToggleRow(panel, startY + 84, "Auto Skill", "AutoSkill")
    addToggleRow(panel, startY + 112, "Auto Quest", "AutoQuest")
    addToggleRow(panel, startY + 140, "Auto Join", "AutoJoin")
    addToggleRow(panel, startY + 168, "Auto Reload", "AutoReload")
    addToggleRow(panel, startY + 196, "Test Mode", "TestMode")

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
    log("UI san sang")
end

function findBall()
    local root = getRoot()
    if not root then
        return nil
    end
    local folder = workspace:FindFirstChild(CONFIG.BALL_FOLDER_NAME)
    if not folder then
        return nil
    end

    local nearestPart = nil
    local nearestDist = math.huge
    for _, obj in ipairs(folder:GetDescendants()) do
        if obj:IsA("BasePart") then
            local dist = (obj.Position - root.Position).Magnitude
            if dist < nearestDist then
                nearestDist = dist
                nearestPart = obj
            end
        end
    end
    return nearestPart
end

function moveToBall(ball)
    if not ball or not ball:IsA("BasePart") then
        return
    end
    local humanoid = getHumanoid()
    if not humanoid then
        return
    end
    humanoid:MoveTo(ball.Position)
end

function jumpHitBall()
    local humanoid = getHumanoid()
    if not humanoid then
        return
    end
    humanoid.Jump = true
end

function chargePower()
    local ok = tapKey(CONFIG.CHARGE_KEY, 0.12)
    if not ok then
        log("Charge key khong hop le")
    end
end

function useSkill()
    if #CONFIG.SKILL_KEYS == 0 then
        return
    end
    local key = CONFIG.SKILL_KEYS[state.skillIndex]
    local ok = tapKey(key, 0.07)
    if ok then
        log("Dang dung skill: " .. tostring(key))
    else
        log("Skill key khong hop le: " .. tostring(key))
    end
    state.skillIndex = state.skillIndex + 1
    if state.skillIndex > #CONFIG.SKILL_KEYS then
        state.skillIndex = 1
    end
end

function acceptQuest()
    local npc = workspace:FindFirstChild(CONFIG.QUEST_NPC_NAME)
    if npc then
        log("Tim thay NPC nhiem vu: " .. npc.Name)
    else
        log("Chua tim thay NPC nhiem vu")
    end
end

function collectReward()
    log("collectReward placeholder dang chay")
end

function joinMatch()
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        log("Khong co PlayerGui")
        return
    end
    local button = playerGui:FindFirstChild(CONFIG.MATCH_BUTTON_NAME, true)
    if button and (button:IsA("TextButton") or button:IsA("ImageButton")) then
        local ok = pcall(function()
            button:Activate()
        end)
        if ok then
            log("Dang vao tran...")
        else
            log("Khong the Activate nut vao tran")
        end
    else
        log("Chua tim thay nut vao tran")
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
    if workspace:FindFirstChild(CONFIG.BALL_FOLDER_NAME) then
        return true
    end
    return false
end

function waitForMatch(timeoutSec)
    timeoutSec = timeoutSec or 20
    local t0 = os.clock()
    while os.clock() - t0 < timeoutSec do
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
        local queueFn = queue_on_teleport or (syn and syn.queue_on_teleport)
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

function mainLoop()
    task.spawn(function()
        log("Main loop dang chay")
        while state.running do
            pcall(function()
                local now = os.clock()
                if state.toggles.AutoBall and now - state.lastBall >= 0.3 then
                    state.lastBall = now
                    local ball = findBall()
                    if ball then
                        log("Dang tim cau: " .. ball.Name)
                        moveToBall(ball)
                    else
                        log("chua tim thay cau")
                    end
                end

                if state.toggles.AutoJumpHit and now - state.lastJump >= 0.6 then
                    state.lastJump = now
                    log("Dang jump hit")
                    jumpHitBall()
                end

                if state.toggles.AutoCharge and now - state.lastCharge >= 1.2 then
                    state.lastCharge = now
                    log("Dang charge")
                    chargePower()
                end

                if state.toggles.AutoSkill and now - state.lastSkill >= CONFIG.SKILL_INTERVAL then
                    state.lastSkill = now
                    useSkill()
                end

                if state.toggles.AutoQuest and now - state.lastQuest >= 4 then
                    state.lastQuest = now
                    acceptQuest()
                    collectReward()
                end

                if state.toggles.AutoJoin and now - state.lastJoin >= 2 then
                    state.lastJoin = now
                    if not isInMatch() then
                        joinMatch()
                    end
                end

                if state.toggles.TestMode and now - state.lastTest >= 2 then
                    state.lastTest = now
                    log("Test Mode: loop OK | inMatch=" .. tostring(isInMatch()))
                end
            end)
            task.wait(CONFIG.LOOP_DELAY)
        end
    end)
end

createUI()
autoReloadOnTeleport()
mainLoop()
log("Script da khoi dong")
