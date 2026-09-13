--// ============================================================
--//  Abysall Remote Bridge  (webhook + discord transport)
--// ============================================================

local CONFIG = {
    WEBHOOK_URL = "https://discord.com/api/webhooks/1548636153874354307/5wWX4oqSA0l5lOt75K6h2KMTxtcGoM39A6IwX0zeXXdXcc-rEgF5cGaHnxRtWJ70uB4j",
    BOT_TOKEN   = "MTU0ODYzNDExNjQ4MjY2MjQ4Mg.GsHG-_.jYYqX2DSBdL2hhS3SBm31uoAKhpLtaV8ACJdKk",
    CHANNEL_ID  = "1548633706309091360",

    POLL_RATE   = 4,
    FETCH_LIMIT = 30,

    SELF_URL = "https://raw.githubusercontent.com/fungrumyisnowpresents/FGHub/refs/heads/main/Scripts/Bridge.luau", -- заполним в шаге 3.4
}

--// ---- services
local HttpService       = game:GetService("HttpService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local TextChatService   = game:GetService("TextChatService")
local CoreGui           = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local USER_ID = tostring(LocalPlayer.UserId)

--// ---- survive teleport
if CONFIG.SELF_URL ~= "" and queue_on_teleport then
    pcall(function()
        queue_on_teleport(([[loadstring(game:HttpGet(%q))()]]):format(CONFIG.SELF_URL))
    end)
end

--// ---- wait for hub
local startWait = tick()
while not (getgenv().Abysall and getgenv().Abysall.Interface) do
    if tick() - startWait > 120 then break end
    task.wait(0.5)
end

local Abysall = getgenv().Abysall
local Library = Abysall and Abysall.Interface and Abysall.Interface.Library
local Toggles = Library and Library.Toggles
local Options = Library and Library.Options

local RemotesFolder = ReplicatedStorage:FindFirstChild("RemotesFolder")
    or ReplicatedStorage:WaitForChild("RemotesFolder", 15)

--// ============================================================
--//  Notify
--// ============================================================

local NotifyContainer
local function GetHiddenContainer()
    if Abysall and Abysall.Environment and Abysall.Environment.gethui then
        local ok, res = pcall(Abysall.Environment.gethui)
        if ok and res then return res end
    end
    return CoreGui
end

local function EnsureContainer()
    if NotifyContainer and NotifyContainer.Parent then return NotifyContainer end
    local gui = Instance.new("ScreenGui")
    gui.Name = "BridgeNotify_" .. tostring(math.random(100000, 999999))
    gui.DisplayOrder = 32767
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.ResetOnSpawn = false
    gui.Parent = GetHiddenContainer()
    NotifyContainer = gui
    return gui
end

local NotifyIndex = 0
local function BridgeNotify(title, body, time)
    time = time or 5
    NotifyIndex += 1
    local slot = NotifyIndex % 6
    task.spawn(function()
        local container = EnsureContainer()
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 360, 0, 62)
        frame.Position = UDim2.new(1, 12, 0, 60 + slot * 70)
        frame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
        frame.BackgroundTransparency = 0.05
        frame.BorderSizePixel = 0
        frame.Parent = container

        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)
        local accent = Instance.new("Frame", frame)
        accent.Size = UDim2.new(0, 4, 1, 0)
        accent.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
        accent.BorderSizePixel = 0
        Instance.new("UICorner", accent).CornerRadius = UDim.new(0, 6)

        local stroke = Instance.new("UIStroke", frame)
        stroke.Color = Color3.fromRGB(60, 60, 70)
        stroke.Thickness = 1
        stroke.Transparency = 0.4

        local t = Instance.new("TextLabel", frame)
        t.Position = UDim2.new(0, 14, 0, 8); t.Size = UDim2.new(1, -22, 0, 20)
        t.BackgroundTransparency = 1; t.Font = Enum.Font.GothamBold
        t.TextSize = 14; t.TextColor3 = Color3.fromRGB(255,255,255)
        t.TextXAlignment = Enum.TextXAlignment.Left; t.Text = title or "Notification"

        local b = Instance.new("TextLabel", frame)
        b.Position = UDim2.new(0, 14, 0, 28); b.Size = UDim2.new(1, -22, 0, 28)
        b.BackgroundTransparency = 1; b.Font = Enum.Font.Gotham
        b.TextSize = 12; b.TextColor3 = Color3.fromRGB(200,200,210)
        b.TextXAlignment = Enum.TextXAlignment.Left; b.TextYAlignment = Enum.TextYAlignment.Top
        b.TextWrapped = true; b.Text = body or ""

        TweenService:Create(frame, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(1, -380, 0, 60 + slot * 70)
        }):Play()
        task.wait(time)
        TweenService:Create(frame, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(1, 12, 0, 60 + slot * 70)
        }):Play()
        task.wait(0.4)
        frame:Destroy()
    end)
end

--// ============================================================
--//  Actions
--// ============================================================

local Actions = {}

Actions.kill = function()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if Abysall and Abysall.Environment and Abysall.Environment.replicatesignal then
        if pcall(function() Abysall.Environment.replicatesignal(LocalPlayer.Kill) end) then return end
    end
    hum.Health = 0
end

Actions.notify = function(a)
    BridgeNotify(a.title or "Notification", a.body or "", a.time or 5)
end

Actions.chat = function(a)
    if not a.text then return end
    local folder = ReplicatedStorage:FindFirstChild("DefaultChatSystemEvents")
    if folder then
        local ev = folder:FindFirstChild("SayMessageRequest")
        if ev then pcall(function() ev:FireServer(a.text, "All") end) end
    end
    local channels = TextChatService:FindFirstChild("TextChannels")
    if channels then
        local general = channels:FindFirstChild("RBXGeneral")
        if general then pcall(function() general:SendAsync(a.text) end) end
    end
end

Actions.playagain = function()
    if RemotesFolder and RemotesFolder:FindFirstChild("PlayAgain") then
        RemotesFolder.PlayAgain:FireServer()
    end
end

Actions.lobby = function()
    if RemotesFolder and RemotesFolder:FindFirstChild("Lobby") then
        RemotesFolder.Lobby:FireServer()
    end
end

Actions.revive = function()
    if RemotesFolder and RemotesFolder:FindFirstChild("Revive") then
        RemotesFolder.Revive:FireServer()
    end
end

Actions.toggle = function(a)
    if not Toggles then return end
    local t = Toggles[a.name]
    if t then pcall(function() t:SetValue(a.value and true or false) end) end
end

Actions.option = function(a)
    if not Options then return end
    local o = Options[a.name]
    if o then pcall(function() o:SetValue(a.value) end) end
end

Actions.crouch = function(a)
    if RemotesFolder and RemotesFolder:FindFirstChild("Crouch") then
        pcall(function() RemotesFolder.Crouch:FireServer(a.value and true or false, true) end)
    end
end

Actions.teleport = function(a)
    local char = LocalPlayer.Character
    if char then
        pcall(function() char:PivotTo(CFrame.new(a.x or 0, a.y or 50, a.z or 0)) end)
    end
end

Actions.ping = function()
    BridgeNotify("Pong", "Bridge alive.", 3)
end

--// ============================================================
--//  Inject webhook
--// ============================================================

local function SendInjectWebhook()
    local ok, info = pcall(function()
        return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
    end)
    local gameName = ok and info and info.Name or game.Name
    local gameUrl  = "https://www.roblox.com/games/" .. game.PlaceId
    local payload = {
        embeds = {{
            title = "Script Injected",
            description = string.format(
                "**%s** (`%s`)\nInjected the Script in:\n**%s** ([GameID](%s))",
                LocalPlayer.DisplayName, LocalPlayer.Name, gameName, gameUrl
            ),
            color = 0x00FF00,
            timestamp = DateTime.now():ToIsoDate()
        }}
    }
    pcall(function()
        HttpService:PostAsync(CONFIG.WEBHOOK_URL, HttpService:JSONEncode(payload),
            Enum.HttpContentType.ApplicationJson)
    end)
end

--// ============================================================
--//  Discord transport
--// ============================================================

local AUTH_HEADER = { ["Authorization"] = "Bot " .. CONFIG.BOT_TOKEN }
local LAST_SEEN_ID = "0"

local function ParseCommand(content)
    local parts = {}
    for piece in string.gmatch(content, "([^|]+)") do
        table.insert(parts, piece)
    end
    if #parts < 3 then return nil end
    if parts[1] ~= "CMD" then return nil end
    if parts[2] ~= USER_ID then return nil end
    local cmd = parts[3]
    local argsJson = parts[4] or "{}"
    local ok, args = pcall(HttpService.JSONDecode, HttpService, argsJson)
    if not ok then args = {} end
    return cmd, args
end

local function PollLoop()
    while task.wait(CONFIG.POLL_RATE) do
        pcall(function()
            local url = string.format(
                "https://discord.com/api/v10/channels/%s/messages?limit=%d",
                CONFIG.CHANNEL_ID, CONFIG.FETCH_LIMIT
            )
            local res = HttpService:RequestAsync({
                Url = url,
                Method = "GET",
                Headers = AUTH_HEADER,
            })
            if not res.Success then return end
            local messages = HttpService:JSONDecode(res.Body)
            if type(messages) ~= "table" then return end

            local sorted = {}
            for _, m in ipairs(messages) do table.insert(sorted, m) end
            table.sort(sorted, function(a, b)
                return tonumber(a.id) < tonumber(b.id)
            end)

            for _, msg in ipairs(sorted) do
                if tonumber(msg.id) > tonumber(LAST_SEEN_ID) then
                    LAST_SEEN_ID = msg.id
                    if msg.content and msg.content:sub(1, 4) == "CMD|" then
                        local cmd, args = ParseCommand(msg.content)
                        if cmd then
                            local fn = Actions[cmd]
                            if fn then
                                local ok2, err = pcall(fn, args)
                                if not ok2 then
                                    warn("[Bridge] action failed:", cmd, err)
                                end
                            end
                        end
                    end
                end
            end
        end)
    end
end

--// ============================================================
--//  GO
--// ============================================================

SendInjectWebhook()
task.spawn(PollLoop)

--// ============ DEBUG ============
task.spawn(function()
    print("[Bridge DEBUG] === START ===")
    print("[Bridge DEBUG] USER_ID =", USER_ID)
    print("[Bridge DEBUG] CHANNEL_ID =", CONFIG.CHANNEL_ID)
    print("[Bridge DEBUG] BOT_TOKEN first 10 =", CONFIG.BOT_TOKEN:sub(1, 10))
    print("[Bridge DEBUG] WEBHOOK first 40 =", CONFIG.WEBHOOK_URL:sub(1, 40))

    local url = string.format(
        "https://discord.com/api/v10/channels/%s/messages?limit=5",
        CONFIG.CHANNEL_ID
    )
    print("[Bridge DEBUG] URL =", url)

    local ok, res = pcall(function()
        return HttpService:RequestAsync({
            Url = url,
            Method = "GET",
            Headers = { ["Authorization"] = "Bot " .. CONFIG.BOT_TOKEN },
        })
    end)

    if not ok then
        print("[Bridge DEBUG] RequestAsync FAILED:", res)
        return
    end

    print("[Bridge DEBUG] Success =", res.Success)
    print("[Bridge DEBUG] StatusCode =", res.StatusCode)
    print("[Bridge DEBUG] StatusMessage =", res.StatusMessage)
    print("[Bridge DEBUG] Body (first 800):")
    print(res.Body:sub(1, 800))
    print("[Bridge DEBUG] === END ===")
end)

task.wait(1)
BridgeNotify("Bridge Connected", "Канал слушается. Ждём команды.", 4)
