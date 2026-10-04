-- ui.lua — الواجهة والميزات
local BASE = "https://raw.githubusercontent.com/2laxbeko-bljp/steal-an-egg/main/"
local core = loadstring(game:HttpGet(BASE .. "core.lua"))()

local HttpService = core.HttpService
local TeleportService = core.TeleportService
local Players = core.Players
local UserInputService = core.UserInputService
local LocalPlayer = core.LocalPlayer
local CONFIG = core.CONFIG
local STATE = core.STATE
local THEMES = core.THEMES
local T = core.T
local guiParent = core.guiParent
local vibrateOnce = core.vibrateOnce
local fetchAllServers = core.fetchAllServers
local REGIONS = core.REGIONS
local regionOfPing = core.regionOfPing
local bestRegion = core.bestRegion
local mergeEmpty = core.mergeEmpty
local persistSaved = core.persistSaved
local persistSettings = core.persistSettings

-- ═══ عناصر مساعدة ═══
local mainGui, mainFrame, floatGui, floatBtn
local renderCurrentTab

local function newBtn(txt,parent,size,pos,bg,ts)
    local b = Instance.new("TextButton")
    b.Size=size; b.Position=pos or UDim2.new(0,0,0,0)
    b.BackgroundColor3=bg or T().card; b.Text=txt; b.TextColor3=T().text
    b.TextSize=ts or 12; b.Font=Enum.Font.GothamMedium
    b.AutoButtonColor=false; b.Parent=parent
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,8)
    return b
end
local function newLabel(txt,parent,size,pos,col,ts,ft)
    local l = Instance.new("TextLabel")
    l.Size=size; l.Position=pos; l.BackgroundTransparency=1
    l.Text=txt; l.TextColor3=col or T().text; l.TextSize=ts or 12
    l.Font=ft or Enum.Font.Gotham; l.TextXAlignment=Enum.TextXAlignment.Left
    l.Parent=parent
    return l
end
local function makeScroll(parent,size,pos)
    local sc = Instance.new("ScrollingFrame")
    sc.Size=size; sc.Position=pos; sc.BackgroundTransparency=1
    sc.ScrollBarThickness=4; sc.ScrollBarImageColor3=T().accent2
    sc.CanvasSize=UDim2.new(0,0,0,0); sc.Parent=parent
    Instance.new("UIListLayout",sc).Padding=UDim.new(0,6)
    return sc
end
local function fitCanvas(sc)
    local l = sc:FindFirstChildOfClass("UIListLayout")
    if l then sc.CanvasSize = UDim2.new(0,0,0,l.AbsoluteContentSize.Y + 10) end
end
local function joinServer(s)
    pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer) end)
end
local function saveServer(s)
    for _, sv in ipairs(STATE.savedServers) do if sv.id == s.id then return false end end
    table.insert(STATE.savedServers, {id=s.id, playing=s.playing, maxPlayers=s.maxPlayers, ping=s.ping, savedAt=tick()})
    persistSaved(); return true
end
local function serverCard(parent, s, i, extraText)
    local c = Instance.new("TextButton")
    c.Size=UDim2.new(1,0,0,46); c.BackgroundColor3=T().card
    c.Text=extraText or ("#"..i.."  👤 "..s.playing.."/7  📶 "..(s.ping or "?").."ms")
    c.TextColor3=T().text; c.TextSize=12; c.Font=Enum.Font.GothamBold
    c.AutoButtonColor=false; c.Parent=parent
    Instance.new("UICorner",c).CornerRadius=UDim.new(0,8)
    local st = Instance.new("UIStroke",c)
    st.Color = (s.playing == 0) and Color3.fromRGB(80,180,100) or T().stroke
    st.Transparency=0.5
    c.MouseButton1Click:Connect(function() joinServer(s) end)
    local sv = newBtn("💾", c, UDim2.new(0,30,0,30), UDim2.new(1,-38,0,8), T().accent, 13)
    sv.MouseButton1Click:Connect(function() if saveServer(s) then sv.Text="✅" end end)
    return c
end

-- ═══ الميزات ═══
local autoRefreshRunning = false
local function startAutoRefresh()
    if autoRefreshRunning then return end
    autoRefreshRunning = true
    task.spawn(function()
        while autoRefreshRunning and STATE.settings.autoRefresh do
            local all = fetchAllServers()
            STATE.totalChecked = STATE.totalChecked + #all
            mergeEmpty(all)
            pcall(function()
                if mainGui and mainGui.Enabled and STATE.currentTab == "empty" then
                    renderCurrentTab("empty")
                end
            end)
            print(string.format("[SE] فارغة=%d فحص=%d", #STATE.emptyServers, STATE.totalChecked))
            for _ = 1, CONFIG.REFRESH_SEC do
                if not autoRefreshRunning or not STATE.settings.autoRefresh then return end
                task.wait(1)
            end
        end
    end)
end
local function stopAutoRefresh() autoRefreshRunning = false end

local antiAfkConn
local function startAntiAfk()
    if antiAfkConn then return end
    antiAfkConn = LocalPlayer.Idled:Connect(function()
        pcall(function()
            game:GetService("VirtualUser"):CaptureController()
            game:GetService("VirtualUser"):ClickButton2(Vector2.new())
        end)
    end)
end
local function stopAntiAfk() if antiAfkConn then antiAfkConn:Disconnect(); antiAfkConn=nil end end

local bestSwitchRunning = false
local function startBestSwitch()
    if bestSwitchRunning then return end
    bestSwitchRunning = true
    task.spawn(function()
        while bestSwitchRunning and STATE.settings.bestSwitch do
            if #Players:GetPlayers() > 3 then
                local best = nil
                for _, s in ipairs(STATE.emptyServers) do
                    if s.playing <= 1 and (s.ping or 9999) < 200 then best=s; break end
                end
                if best then joinServer(best); return end
            end
            task.wait(8)
        end
    end)
end
local function stopBestSwitch() bestSwitchRunning = false end

-- ═══ بناء الواجهة ═══
local function buildMain()
    if mainGui then mainGui:Destroy() end
    mainGui = Instance.new("ScreenGui")
    mainGui.Name="SE_Main"; mainGui.ResetOnSpawn=false
    mainGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    mainGui.DisplayOrder=5
    mainGui.Parent=guiParent

    mainFrame = Instance.new("Frame")
    mainFrame.Size=UDim2.new(0,400,0,560); mainFrame.Position=UDim2.new(0.5,-200,0.5,-280)
    mainFrame.BackgroundColor3=T().bg; mainFrame.BorderSizePixel=0
    mainFrame.ClipsDescendants=true; mainFrame.Parent=mainGui
    Instance.new("UICorner",mainFrame).CornerRadius=UDim.new(0,14)
    local bst = Instance.new("UIStroke",mainFrame)
    bst.Color=T().stroke; bst.Thickness=1; bst.Transparency=0.25

    -- هيدر
    local header = Instance.new("Frame")
    header.Size=UDim2.new(1,0,0,100); header.BackgroundColor3=T().panel
    header.BorderSizePixel=0; header.Parent=mainFrame
    Instance.new("UICorner",header).CornerRadius=UDim.new(0,14)
    local hcov = Instance.new("Frame")
    hcov.Size=UDim2.new(1,0,0,14); hcov.Position=UDim2.new(0,0,1,-14)
    hcov.BackgroundColor3=T().panel; hcov.BorderSizePixel=0; hcov.Parent=header

    local logoFrame = Instance.new("Frame")
    logoFrame.Size=UDim2.new(0,66,0,66); logoFrame.Position=UDim2.new(0,14,0,16)
    logoFrame.BackgroundColor3=T().card; logoFrame.BorderSizePixel=0; logoFrame.Parent=header
    Instance.new("UICorner",logoFrame).CornerRadius=UDim.new(1,0)
    local lgs = Instance.new("UIStroke",logoFrame)
    lgs.Color=T().accent2; lgs.Thickness=1.5; lgs.Transparency=0.2
    do
        local img = Instance.new("ImageLabel")
        img.Size=UDim2.new(1,-4,1,-4); img.Position=UDim2.new(0,2,0,2)
        img.BackgroundTransparency=1; img.Image=T().img; img.Parent=logoFrame
        Instance.new("UICorner",img).CornerRadius=UDim.new(1,0)
        local fb = Instance.new("TextLabel")
        fb.Size=UDim2.new(1,0,1,0); fb.BackgroundTransparency=1
        fb.Text="⚔️"; fb.TextSize=30; fb.Font=Enum.Font.GothamBold
        fb.TextColor3=T().gold; fb.Visible=false; fb.Parent=logoFrame
        img.ImageFailed:Connect(function() img.Visible=false; fb.Visible=true end)
        task.delay(3, function() if not img.IsLoaded then img.Visible=false; fb.Visible=true end end)
    end
    newLabel("Steal an Egg",header,UDim2.new(1,-110,0,26),UDim2.new(0,92,0,10),T().text,19,Enum.Font.GothamBold)
    newLabel(T().name,header,UDim2.new(1,-110,0,18),UDim2.new(0,92,0,36),T().gold,10,Enum.Font.GothamMedium)
    local v = Instance.new("TextLabel")
    v.Size=UDim2.new(0,52,0,16); v.Position=UDim2.new(0,92,0,56)
    v.BackgroundColor3=T().accent; v.Text="v3.4"
    v.TextColor3=T().text; v.TextSize=9; v.Font=Enum.Font.GothamBold; v.Parent=header
    Instance.new("UICorner",v).CornerRadius=UDim.new(0,5)

    local themeBtn = newBtn("🎨",header,UDim2.new(0,30,0,30),UDim2.new(1,-78,0,12),T().card,14)
    themeBtn.MouseButton1Click:Connect(function()
        local keys = {}
        for k in pairs(THEMES) do table.insert(keys,k) end
        table.sort(keys)
        for i, k in ipairs(keys) do
            if k == STATE.theme then STATE.theme = keys[(i % #keys)+1]; break end
        end
        persistSettings(); buildMain(); renderCurrentTab(STATE.currentTab)
        if rebuildFloat then rebuildFloat() end
    end)
    local closeBtn = newBtn("X",header,UDim2.new(0,30,0,30),UDim2.new(1,-40,0,12),Color3.fromRGB(180,55,55),13)
    closeBtn.MouseButton1Click:Connect(function() mainGui.Enabled=false end)

    -- إحصائيات
    local sb = Instance.new("Frame")
    sb.Size=UDim2.new(1,-20,0,42); sb.Position=UDim2.new(0,10,0,108)
    sb.BackgroundColor3=T().panel; sb.BorderSizePixel=0; sb.Parent=mainFrame
    Instance.new("UICorner",sb).CornerRadius=UDim.new(0,8)
    local eL = newLabel("🥚 0",sb,UDim2.new(0,80,1,0),UDim2.new(0,8,0,0),T().text,13,Enum.Font.GothamBold)
    local rL = newLabel("0/0",sb,UDim2.new(0,90,1,0),UDim2.new(0,92,0,0),T().dim,11)
    local sL = newLabel("منذ —",sb,UDim2.new(0,90,1,0),UDim2.new(0,182,0,0),T().dim,11)
    local nL = newLabel("—",sb,UDim2.new(0,70,1,0),UDim2.new(1,-80,0,0),T().dim,11,Enum.Font.GothamBold)
    nL.TextXAlignment=Enum.TextXAlignment.Right

    -- التبويبات
    local tabs = {
        {id="empty",label="🥚 الفارغة"},
        {id="hunter",label="🎯 صياد"},
        {id="region",label="🌍 مناطق"},
        {id="saved",label="💾 محفوظة"},
        {id="set",label="⚙️ إعدادات"},
        {id="chilli",label="🌶️ Chilli"}
    }
    local tabScroll = Instance.new("ScrollingFrame")
    tabScroll.Size=UDim2.new(1,-20,0,34); tabScroll.Position=UDim2.new(0,10,0,154)
    tabScroll.BackgroundTransparency=1; tabScroll.ScrollBarThickness=3
    tabScroll.ScrollBarImageColor3=T().accent2; tabScroll.CanvasSize=UDim2.new(0,420,0,0)
    tabScroll.ScrollingDirection=Enum.ScrollingDirection.X
    tabScroll.Parent=mainFrame
    local tl = Instance.new("UIListLayout",tabScroll)
    tl.FillDirection=Enum.FillDirection.Horizontal; tl.Padding=UDim.new(0,4)
    tl.SortOrder=Enum.SortOrder.LayoutOrder

    local tabContent = Instance.new("Frame")
    tabContent.Size=UDim2.new(1,-20,1,-250); tabContent.Position=UDim2.new(0,10,0,194)
    tabContent.BackgroundTransparency=1; tabContent.Parent=mainFrame

    local tabBtns = {}
    for i, t in ipairs(tabs) do
        local b = newBtn(t.label,tabScroll,UDim2.new(0,90,0,30),nil,T().card,11)
        b.LayoutOrder=i
        b.MouseButton1Click:Connect(function()
            STATE.currentTab=t.id
            for j, bb in ipairs(tabBtns) do
                bb.BackgroundColor3 = (j==i) and T().accent or T().card
            end
            renderCurrentTab(t.id)
        end)
        tabBtns[i]=b
    end

    renderCurrentTab = function(tabId)
        STATE.currentTab=tabId
        for _, ch in ipairs(tabContent:GetChildren()) do ch:Destroy() end

        if tabId=="empty" then
            local top = Instance.new("Frame")
            top.Size=UDim2.new(1,0,0,34); top.BackgroundTransparency=1; top.Parent=tabContent
            local rb = newBtn("🔄 تحديث الآن",top,UDim2.new(0.48,0,1,0),nil,T().accent,11)
            local jb = newBtn("⚡ أفضل سيرفر",top,UDim2.new(0.48,0,1,0),UDim2.new(0.52,0,0,0),T().accent2,11)
            jb.MouseButton1Click:Connect(function()
                if #STATE.emptyServers > 0 then joinServer(STATE.emptyServers[1]) end
            end)
            local sc = makeScroll(tabContent,UDim2.new(1,0,1,-44),UDim2.new(0,0,0,44))
            local function draw()
                for _, ch in ipairs(sc:GetChildren()) do if ch:IsA("GuiObject") then ch:Destroy() end end
                if #STATE.emptyServers == 0 then
                    local l = newLabel("لا سيرفرات 0/7 أو 1/7 حالياً... التحديث كل 15ث",sc,
                        UDim2.new(1,0,0,50),nil,T().dim,12,Enum.Font.GothamMedium)
                    l.TextXAlignment=Enum.TextXAlignment.Center
                else
                    local now=tick()
                    for i, s in ipairs(STATE.emptyServers) do
                        if i > CONFIG.MAX_SHOW then break end
                        local age = math.floor(now - (s.firstSeen or now))
                        serverCard(sc, s, i,
                            "#"..i.."  👤 "..s.playing.."/7  📶 "..(s.ping or "?").."ms  🕐"..age.."ث")
                    end
                end
                fitCanvas(sc)
            end
            rb.MouseButton1Click:Connect(function()
                rb.Text="⏳..."
                task.spawn(function()
                    local all = fetchAllServers()
                    STATE.totalChecked = STATE.totalChecked + #all
                    mergeEmpty(all); rb.Text="🔄 تحديث الآن"; draw()
                end)
            end)
            draw()

        elseif tabId=="hunter" then
            newLabel("🎯 الصياد",tabContent,UDim2.new(1,0,0,22),nil,T().text,13,Enum.Font.GothamBold)
            newLabel("فلتر عدد اللاعبين والبنق:",tabContent,UDim2.new(1,0,0,18),UDim2.new(0,0,0,26),T().dim,10)
            local mn = Instance.new("TextBox")
            mn.Size=UDim2.new(0.3,0,0,28); mn.Position=UDim2.new(0,0,0,46)
            mn.BackgroundColor3=T().card; mn.Text="0"
            mn.TextColor3=T().text; mn.TextSize=12; mn.Font=Enum.Font.Gotham; mn.Parent=tabContent
            Instance.new("UICorner",mn).CornerRadius=UDim.new(0,8)
            local mx = Instance.new("TextBox")
            mx.Size=UDim2.new(0.3,0,0,28); mx.Position=UDim2.new(0.35,0,0,46)
            mx.BackgroundColor3=T().card; mx.Text="1"
            mx.TextColor3=T().text; mx.TextSize=12; mx.Font=Enum.Font.Gotham; mx.Parent=tabContent
            Instance.new("UICorner",mx).CornerRadius=UDim.new(0,8)
            local pb = Instance.new("TextBox")
            pb.Size=UDim2.new(0.3,0,0,28); pb.Position=UDim2.new(0.7,0,0,46)
            pb.BackgroundColor3=T().card; pb.Text=tostring(STATE.settings.hunterMaxPing)
            pb.TextColor3=T().text; pb.TextSize=12; pb.Font=Enum.Font.Gotham
            pb.ClearTextOnFocus=false; pb.Parent=tabContent
            Instance.new("UICorner",pb).CornerRadius=UDim.new(0,8)
            local apply = newBtn("🔍 بحث",tabContent,UDim2.new(1,0,0,30),UDim2.new(0,0,0,82),T().accent,12)
            local sc = makeScroll(tabContent,UDim2.new(1,0,1,-120),UDim2.new(0,0,0,120))
            apply.MouseButton1Click:Connect(function()
                local a=tonumber(mn.Text) or 0
                local b=tonumber(mx.Text) or 1
                local p=tonumber(pb.Text) or 150
                STATE.settings.hunterMaxPing=p; persistSettings()
                for _, ch in ipairs(sc:GetChildren()) do if ch:IsA("GuiObject") then ch:Destroy() end end
                local matches = {}
                for _, s in ipairs(STATE.emptyServers) do
                    if s.playing>=a and s.playing<=b and (s.ping or 9999)<=p then table.insert(matches,s) end
                end
                table.sort(matches,function(x,y) return (x.ping or 9999)<(y.ping or 9999) end)
                if #matches==0 then
                    local l = newLabel("لا نتائج",sc,UDim2.new(1,0,0,40),nil,T().dim,12)
                    l.TextXAlignment=Enum.TextXAlignment.Center
                else
                    for i, s in ipairs(matches) do if i>30 then break end serverCard(sc,s,i) end
                end
                fitCanvas(sc)
            end)

        elseif tabId=="region" then
            newLabel("🌍 المناطق (حسب البنق)",tabContent,UDim2.new(1,0,0,22),nil,T().text,12,Enum.Font.GothamBold)
            local sc = makeScroll(tabContent,UDim2.new(1,0,1,-30),UDim2.new(0,0,0,30))
            local bstName = bestRegion()
            for _, r in ipairs(REGIONS) do
                local sum,cnt=0,0
                for _, s in ipairs(STATE.emptyServers) do
                    if regionOfPing(s.ping or 9999)==r.name then sum=sum+(s.ping or 0); cnt=cnt+1 end
                end
                local avg = cnt>0 and math.floor(sum/cnt) or 0
                local isBest = (r.name==bstName)
                local c = Instance.new("TextButton")
                c.Size=UDim2.new(1,0,0,54); c.BackgroundColor3 = isBest and T().accent or T().card
                c.Text=""; c.AutoButtonColor=false; c.Parent=sc
                Instance.new("UICorner",c).CornerRadius=UDim.new(0,8)
                local st = Instance.new("UIStroke",c)
                st.Color = isBest and T().gold or T().stroke; st.Transparency=0.4
                local title = isBest and (r.name.." ⭐ الأفضل") or r.name
                newLabel(title,c,UDim2.new(0.65,0,0,24),UDim2.new(0,12,0,5),T().text,13,Enum.Font.GothamBold)
                newLabel("📶 متوسط: "..avg.."ms",c,UDim2.new(0.65,0,0,18),UDim2.new(0,12,0,29),T().dim,11)
                local cl = newLabel("🥚 "..cnt,c,UDim2.new(0.35,-12,1,0),UDim2.new(0.65,0,0,0),T().accent2,15,Enum.Font.GothamBold)
                cl.TextXAlignment=Enum.TextXAlignment.Right
                c.MouseButton1Click:Connect(function()
                    for _, ch in ipairs(tabContent:GetChildren()) do ch:Destroy() end
                    local back = newBtn("← عودة",tabContent,UDim2.new(0,70,0,28),nil,T().card,11)
                    newLabel(r.name,tabContent,UDim2.new(1,-80,0,28),UDim2.new(0,80,0,0),T().text,13,Enum.Font.GothamBold)
                    local s2 = makeScroll(tabContent,UDim2.new(1,0,1,-38),UDim2.new(0,0,0,38))
                    local list = {}
                    for _, s in ipairs(STATE.emptyServers) do
                        if regionOfPing(s.ping or 9999)==r.name then table.insert(list,s) end
                    end
                    table.sort(list,function(x,y) return (x.ping or 9999)<(y.ping or 9999) end)
                    for i, s in ipairs(list) do serverCard(s2,s,i) end
                    fitCanvas(s2)
                    back.MouseButton1Click:Connect(function() renderCurrentTab("region") end)
                end)
            end
            fitCanvas(sc)

        elseif tabId=="saved" then
            newLabel("💾 المحفوظة ("..#STATE.savedServers..")",tabContent,
                UDim2.new(1,-180,0,22),nil,T().text,12,Enum.Font.GothamBold)
            local ckb = newBtn("✔️ تحقق",tabContent,UDim2.new(0,84,0,22),UDim2.new(1,-180,0,0),T().accent,10)
            local clb = newBtn("🗑 مسح",tabContent,UDim2.new(0,84,0,22),UDim2.new(1,-88,0,0),Color3.fromRGB(150,50,50),10)
            clb.MouseButton1Click:Connect(function()
                STATE.savedServers={}; persistSaved(); renderCurrentTab("saved")
            end)
            local sc = makeScroll(tabContent,UDim2.new(1,0,1,-30),UDim2.new(0,0,0,30))
            local function drawSaved()
                for _, ch in ipairs(sc:GetChildren()) do if ch:IsA("GuiObject") then ch:Destroy() end end
                if #STATE.savedServers==0 then
                    local l = newLabel("لا محفوظات — اضغط 💾 على أي سيرفر",sc,
                        UDim2.new(1,0,0,40),nil,T().dim,12,Enum.Font.GothamMedium)
                    l.TextXAlignment=Enum.TextXAlignment.Center
                else
                    for i, s in ipairs(STATE.savedServers) do
                        local c = serverCard(sc,s,i,"#"..i.."  🆔 "..s.id:sub(1,14).."…  📶 "..(s.ping or "?").."ms")
                        local del = newBtn("✖",c,UDim2.new(0,28,0,28),UDim2.new(1,-70,0,9),Color3.fromRGB(150,50,50),11)
                        del.MouseButton1Click:Connect(function()
                            table.remove(STATE.savedServers,i); persistSaved(); drawSaved()
                        end)
                    end
                end
                fitCanvas(sc)
            end
            ckb.MouseButton1Click:Connect(function()
                ckb.Text="⏳..."
                task.spawn(function()
                    local all = fetchAllServers()
                    local alive = {}
                    for _, srv in ipairs(all) do alive[srv.id]=srv end
                    local kept={}
                    for _, sv in ipairs(STATE.savedServers) do
                        local cur = alive[sv.id]
                        if cur and cur.playing<=1 and (cur.ping or 9999)<=300 then
                            sv.playing=cur.playing; sv.ping=cur.ping; table.insert(kept,sv)
                        end
                    end
                    STATE.savedServers=kept; persistSaved(); ckb.Text="✔️ تحقق"; drawSaved()
                end)
            end)
            drawSaved()

        elseif tabId=="set" then
            newLabel("⚙️ الإعدادات",tabContent,UDim2.new(1,0,0,22),nil,T().text,13,Enum.Font.GothamBold)
            local sc = makeScroll(tabContent,UDim2.new(1,0,1,-30),UDim2.new(0,0,0,30))
            local function makeToggle(label,key,onChange)
                local row = Instance.new("Frame")
                row.Size=UDim2.new(1,0,0,42); row.BackgroundColor3=T().card; row.Parent=sc
                Instance.new("UICorner",row).CornerRadius=UDim.new(0,8)
                newLabel(label,row,UDim2.new(1,-90,1,0),UDim2.new(0,10,0,0),T().text,12)
                local b = newBtn(STATE.settings[key] and "✅ يعمل" or "⭕ متوقف",
                    row,UDim2.new(0,76,0,30),UDim2.new(1,-84,0,6),
                    STATE.settings[key] and T().accent or T().panel,11)
                b.MouseButton1Click:Connect(function()
                    STATE.settings[key] = not STATE.settings[key]
                    b.Text = STATE.settings[key] and "✅ يعمل" or "⭕ متوقف"
                    b.BackgroundColor3 = STATE.settings[key] and T().accent or T().panel
                    persistSettings()
                    if onChange then onChange(STATE.settings[key]) end
                end)
            end
            makeToggle("🔄 تحديث كل "..CONFIG.REFRESH_SEC.."ث","autoRefresh",
                function(on) if on then startAutoRefresh() else stopAutoRefresh() end end)
            makeToggle("📳 اهتزاز عند اكتشاف","vibrateOnEmpty")
            makeToggle("💤 Anti-AFK","antiAfk",
                function(on) if on then startAntiAfk() else stopAntiAfk() end end)
            makeToggle("⚡ الانتقال للأفضل","bestSwitch",
                function(on) if on then startBestSwitch() else stopBestSwitch() end end)
            makeToggle("👥 ضم سيرفرات 1 لاعب","includeOnePlayer",
                function(on) STATE.settings.includeOnePlayer = on end)

            newLabel("🎨 الثيم: "..T().name.." ("..STATE.theme..")",sc,
                UDim2.new(1,0,0,26),nil,T().gold,11,Enum.Font.GothamBold)
            newLabel("📊 فحص:"..STATE.totalChecked.." | فارغة:"..#STATE.emptyServers..
                " | محفوظة:"..#STATE.savedServers,sc,UDim2.new(1,0,0,20),nil,T().dim,11)
            newLabel("⏱ تشغيل:"..math.floor(tick()-STATE.sessionStart).."ث",sc,
                UDim2.new(1,0,0,20),nil,T().dim,11)
            fitCanvas(sc)

        elseif tabId=="chilli" then
            newLabel("🌶️ Chilli Hub",tabContent,UDim2.new(1,0,0,26),nil,T().text,15,Enum.Font.GothamBold)
            newLabel("تشغيل Chilli Hub داخل السكربت",tabContent,UDim2.new(1,0,0,20),UDim2.new(0,0,0,30),T().dim,11)
            local launch = newBtn("🚀 تشغيل Chilli Hub",tabContent,UDim2.new(1,0,0,44),UDim2.new(0,0,0,66),T().accent,13)
            local status = newLabel("الحالة: غير مشغل",tabContent,UDim2.new(1,0,0,24),UDim2.new(0,0,0,118),T().dim,11)
            launch.MouseButton1Click:Connect(function()
                launch.Text="⏳ تحميل..."; status.Text="تحميل..."
                task.spawn(function()
                    local ok, err = pcall(function()
                        loadstring(game:HttpGet(CONFIG.CHILLI_URL))()
                    end)
                    if ok then
                        launch.Text="✅ يعمل"; launch.BackgroundColor3=Color3.fromRGB(60,150,90)
                        status.Text="يعمل (بواجهته الخاصة)"
                    else
                        launch.Text="❌ فشل"; launch.BackgroundColor3=Color3.fromRGB(160,50,50)
                        status.Text="خطأ: "..tostring(err):sub(1,40)
                    end
                end)
            end)
        end
    end

    -- سحب
    local dragging, dragStart, startPos = false, nil, nil
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging=true; dragStart=input.Position; startPos=mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging=false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y)
        end
    end)

    -- إحصائيات كل ثانية
    task.spawn(function()
        while mainGui and mainGui.Parent do
            task.wait(1)
            pcall(function()
                eL.Text = "🥚 "..#STATE.emptyServers
                rL.Text = STATE.totalChecked.."/"..#STATE.emptyServers
                if STATE.lastEmptyAt > 0 then
                    sL.Text = "منذ "..math.floor(tick()-STATE.lastEmptyAt).."ث"
                else sL.Text = "منذ —" end
                local ping = 0
                pcall(function() ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() end)
                if ping > 0 then
                    if ping < 80 then nL.Text="ممتاز"; nL.TextColor3=Color3.fromRGB(80,190,110)
                    elseif ping < 150 then nL.Text="جيد"; nL.TextColor3=Color3.fromRGB(200,190,80)
                    else nL.Text="ضعيف"; nL.TextColor3=Color3.fromRGB(200,80,80) end
                else nL.Text="—" end
            end)
        end
    end)

    renderCurrentTab(STATE.currentTab)
end

-- الزر العائم
function rebuildFloat()
    if floatGui then floatGui:Destroy() end
    floatGui = Instance.new("ScreenGui")
    floatGui.Name="SE_Float"; floatGui.ResetOnSpawn=false
    floatGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    floatGui.DisplayOrder=100
    floatGui.IgnoreGuiInset=true
    floatGui.Parent=guiParent

    floatBtn = Instance.new("TextButton")
    floatBtn.Size=UDim2.new(0,54,0,54)
    floatBtn.Position=UDim2.new(0,16,0.5,-27)
    floatBtn.BackgroundColor3=T().panel
    floatBtn.Text="⚔️"; floatBtn.TextSize=24
    floatBtn.Font=Enum.Font.GothamBold
    floatBtn.TextColor3=T().gold
    floatBtn.AutoButtonColor=false
    floatBtn.Parent=floatGui
    Instance.new("UICorner",floatBtn).CornerRadius=UDim.new(1,0)
    local fs = Instance.new("UIStroke",floatBtn)
    fs.Color=T().accent2; fs.Thickness=1.5; fs.Transparency=0.2

    local moved, dragging, dragStart, startPos = false, false, nil, nil
    floatBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            moved=false; dragging=true; dragStart=input.Position; startPos=floatBtn.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging=false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            if math.abs(d.X)+math.abs(d.Y) > 8 then moved=true end
            floatBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y)
        end
    end)
    floatBtn.MouseButton1Click:Connect(function()
        if moved then return end
        mainGui.Enabled = not mainGui.Enabled
    end)
end

buildMain()
rebuildFloat()
if STATE.settings.autoRefresh then startAutoRefresh() end
if STATE.settings.antiAfk then startAntiAfk() end
if STATE.settings.bestSwitch then startBestSwitch() end
print("[SE] ✅ v3.4 جاهز | ثيم="..T().name)
