-- core.lua — الدوال الأساسية
-- يُحمّل تلقائياً من loader.lua

local BASE = "https://raw.githubusercontent.com/2laxbeko-bljp/steal-an-egg/main/"

-- ═══ الخدمات ═══
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HapticService = game:GetService("HapticService")
local LocalPlayer = Players.LocalPlayer

-- ═══ الإعدادات ═══
local CONFIG = {
    PAGES = 3,
    MAX_SHOW = 60,
    REFRESH_SEC = 15,
    MAX_PLAYERS_IN_SERVER = 7, -- سعة Steal an Egg = 7 لاعبين
    CHILLI_URL = "https://raw.githubusercontent.com/tienkhanh1/spicy/main/Chilli.lua",
    SAVE_FILE = "SE_saved.json",
    SETTINGS_FILE = "SE_settings.json",
    DEBUG = true
}

-- ═══ الحالة ═══
local STATE = {
    theme = "guts_dark",
    currentTab = "empty",
    settings = {
        autoRefresh = true,
        vibrateOnEmpty = true,
        antiAfk = true,
        bestSwitch = false,
        hunterMaxPing = 300,
        includeOnePlayer = true
    },
    emptyServers = {},
    savedServers = {},
    lastEmptyAt = 0,
    totalChecked = 0,
    sessionStart = tick()
}

-- ═══ الثيمات ═══
local THEMES = {
    guts_dark = {name="قاتس - العاصفة", bg=Color3.fromRGB(8,8,12), panel=Color3.fromRGB(18,20,30),
        card=Color3.fromRGB(26,30,44), accent=Color3.fromRGB(70,90,140), accent2=Color3.fromRGB(110,140,190),
        stroke=Color3.fromRGB(50,60,90), text=Color3.fromRGB(225,228,240), dim=Color3.fromRGB(140,150,175),
        gold=Color3.fromRGB(180,150,90), img="rbxassetid://11657474206"},
    guts_red = {name="قاتس - كسوف", bg=Color3.fromRGB(13,6,9), panel=Color3.fromRGB(32,14,20),
        card=Color3.fromRGB(46,20,28), accent=Color3.fromRGB(150,35,42), accent2=Color3.fromRGB(200,65,70),
        stroke=Color3.fromRGB(95,30,38), text=Color3.fromRGB(248,228,226), dim=Color3.fromRGB(185,140,142),
        gold=Color3.fromRGB(215,155,75), img="rbxassetid://11657474206"},
    guts_blue = {name="قاتس - ليل", bg=Color3.fromRGB(6,9,18), panel=Color3.fromRGB(14,23,46),
        card=Color3.fromRGB(22,35,62), accent=Color3.fromRGB(40,82,165), accent2=Color3.fromRGB(72,132,225),
        stroke=Color3.fromRGB(42,62,115), text=Color3.fromRGB(222,232,252), dim=Color3.fromRGB(142,158,192),
        gold=Color3.fromRGB(172,152,102), img="rbxassetid://11657474206"},
    indigo = {name="نيلي", bg=Color3.fromRGB(10,10,18), panel=Color3.fromRGB(18,22,38),
        card=Color3.fromRGB(26,32,52), accent=Color3.fromRGB(45,70,150), accent2=Color3.fromRGB(80,120,210),
        stroke=Color3.fromRGB(55,70,110), text=Color3.fromRGB(230,235,250), dim=Color3.fromRGB(145,155,185),
        gold=Color3.fromRGB(190,165,95), img="rbxassetid://11657474206"},
    obsidian = {name="أوبسيديان", bg=Color3.fromRGB(6,6,8), panel=Color3.fromRGB(14,14,18),
        card=Color3.fromRGB(22,22,28), accent=Color3.fromRGB(80,80,95), accent2=Color3.fromRGB(130,130,150),
        stroke=Color3.fromRGB(45,45,55), text=Color3.fromRGB(230,230,235), dim=Color3.fromRGB(150,150,160),
        gold=Color3.fromRGB(200,180,110), img="rbxassetid://11657474206"}
}

local function T() return THEMES[STATE.theme] or THEMES.guts_dark end

-- ═══ guiParent ═══
local guiParent = LocalPlayer:WaitForChild("PlayerGui")
for _, n in ipairs({"SE_Main","SE_Float"}) do
    local g = guiParent:FindFirstChild(n); if g then g:Destroy() end
end

-- ═══ حفظ/تحميل ═══
local function safeRead(p) local ok,d = pcall(function() return readfile(p) end); return ok and d or nil end
local function safeWrite(p,d) pcall(function() writefile(p,d) end) end
local function loadSaved()
    local d = safeRead(CONFIG.SAVE_FILE); if not d then return {} end
    local ok,a = pcall(function() return HttpService:JSONDecode(d) end)
    return (ok and type(a)=="table") and a or {}
end
local function persistSaved() safeWrite(CONFIG.SAVE_FILE, HttpService:JSONEncode(STATE.savedServers)) end
local function loadSettings()
    local d = safeRead(CONFIG.SETTINGS_FILE); if not d then return end
    local ok,o = pcall(function() return HttpService:JSONDecode(d) end)
    if ok and type(o)=="table" then
        if o.settings then for k,v in pairs(o.settings) do STATE.settings[k]=v end end
        if o.theme then STATE.theme=o.theme end
    end
end
local function persistSettings()
    safeWrite(CONFIG.SETTINGS_FILE, HttpService:JSONEncode({settings=STATE.settings, theme=STATE.theme}))
end
STATE.savedServers = loadSaved(); loadSettings()

-- ═══ اهتزاز ═══
local function vibrateOnce()
    if not STATE.settings.vibrateOnEmpty then return end
    pcall(function()
        if HapticService:IsVibrationSupported(Enum.UserInputType.Gamepad1) then
            HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0.6)
            task.wait(0.15)
            HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0)
        end
    end)
end

-- ═══ HTTP ═══
local PROXIES = {"https://games.roblox.com","https://games.roproxy.com"}
local CHOSEN_BASE = nil
local function fetchPage(base, cursor)
    local url = base.."/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
    if cursor and cursor ~= "" then url = url.."&cursor="..cursor end
    local ok, body = pcall(function() return game:HttpGet(url, true) end)
    if not ok or not body or #body < 20 then return nil end
    local ok2, data = pcall(function() return HttpService:JSONDecode(body) end)
    if not ok2 then return nil end
    return data
end
local function pickProxy()
    if CHOSEN_BASE then return CHOSEN_BASE end
    for _, base in ipairs(PROXIES) do
        local d = fetchPage(base, nil)
        if d and d.data then CHOSEN_BASE=base; print("[SE] proxy="..base); return base end
        task.wait(0.3)
    end
    return nil
end
local function fetchAllServers()
    local base = pickProxy(); if not base then return {} end
    local all, seen, cursor = {}, {}, nil
    for page = 1, CONFIG.PAGES do
        local data = fetchPage(base, cursor)
        if not data or not data.data then break end
        for _, s in ipairs(data.data) do
            if not seen[s.id] then
                seen[s.id]=true
                table.insert(all, {id=s.id, playing=s.playing, maxPlayers=s.maxPlayers, ping=s.ping or 9999})
            end
        end
        cursor = data.nextPageCursor
        if not cursor or cursor=="" then break end
        task.wait(0.15)
    end
    return all
end

-- ═══ المناطق ═══
local REGIONS = {
    {name="قريب جداً", min=0, max=60}, {name="قريب", min=60, max=120},
    {name="متوسط", min=120, max=200}, {name="بعيد", min=200, max=350},
    {name="بعيد جداً", min=350, max=10000}
}
local function regionOfPing(p)
    for _, r in ipairs(REGIONS) do if p >= r.min and p < r.max then return r.name end end
    return "غير معروف"
end
local function bestRegion()
    local best, bestAvg = nil, math.huge
    for _, r in ipairs(REGIONS) do
        local sum, cnt = 0, 0
        for _, s in ipairs(STATE.emptyServers) do
            if regionOfPing(s.ping or 9999) == r.name then sum = sum + (s.ping or 0); cnt = cnt + 1 end
        end
        if cnt > 0 then local avg = sum/cnt; if avg < bestAvg then bestAvg=avg; best=r.name end end
    end
    return best, bestAvg
end

-- ═══ دمج السيرفرات الفارغة ═══
local function mergeEmpty(newList)
    local merged, byId = {}, {}
    for _, s in ipairs(STATE.emptyServers) do byId[s.id]=s; byId[s.id]._stale=true end
    for _, s in ipairs(newList) do
        local maxAllowed = STATE.settings.includeOnePlayer and 1 or 0
        if s.playing <= maxAllowed then
            if byId[s.id] then
                byId[s.id]._stale=false; byId[s.id].playing=s.playing
                byId[s.id].ping=s.ping; byId[s.id].lastSeen=tick()
            else
                byId[s.id]={id=s.id, playing=s.playing, maxPlayers=s.maxPlayers, ping=s.ping,
                    firstSeen=tick(), lastSeen=tick(), _stale=false}
            end
        end
    end
    local now = tick()
    for _, s in pairs(byId) do
        if not s._stale or (now - (s.lastSeen or now) < 300) then
            s._stale=nil; table.insert(merged, s)
        end
    end
    table.sort(merged, function(a,b)
        if a.playing ~= b.playing then return a.playing < b.playing end
        return (a.ping or 9999) < (b.ping or 9999)
    end)
    local before = #STATE.emptyServers
    STATE.emptyServers = merged
    if #merged > 0 then STATE.lastEmptyAt = now end
    if #merged > before and before > 0 then vibrateOnce() end
end

-- ═══ تصدير للجزء 3 ═══
return {
    HttpService=HttpService, TeleportService=TeleportService, Players=Players,
    UserInputService=UserInputService, HapticService=HapticService, LocalPlayer=LocalPlayer,
    CONFIG=CONFIG, STATE=STATE, THEMES=THEMES, T=T, guiParent=guiParent,
    vibrateOnce=vibrateOnce, fetchAllServers=fetchAllServers, pickProxy=pickProxy,
    REGIONS=REGIONS, regionOfPing=regionOfPing, bestRegion=bestRegion,
    mergeEmpty=mergeEmpty, persistSaved=persistSaved, persistSettings=persistSettings,
    loadSaved=loadSaved, loadSettings=loadSettings
}
