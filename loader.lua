-- loader.lua
local BASE = "https://raw.githubusercontent.com/2laxbeko-bljp/steal-an-egg/main/"
print("[SE] 🟢 تحميل السكريبت...")
local ok, err = pcall(function()
    loadstring(game:HttpGet(BASE .. "ui.lua"))()
end)
if not ok then
    warn("[SE] ❌ فشل التحميل: " .. tostring(err))
end
