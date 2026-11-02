--[[
  VANTA public loader — upload THIS file to GitHub (public repo).
  Buyers only run:
    getgenv().VantaKey = "THEIR_KEY"
    loadstring(game:HttpGet("RAW_GITHUB_URL"))()
]]

local KEY = (getgenv and getgenv().VantaKey) or nil
local API = (getgenv and getgenv().VantaAPI) or "http://localhost:3000"

if type(KEY) ~= "string" or #KEY < 10 then
    return warn("[VANTA] Set getgenv().VantaKey = \"YOUR-KEY\" before running")
end

API = tostring(API):gsub("/+$", "")
local HS = game:GetService("HttpService")

local function hw()
    local p = {
        tostring((game.Players.LocalPlayer and game.Players.LocalPlayer.UserId) or 0),
        tostring(game.PlaceId or 0),
    }
    pcall(function()
        if identifyexecutor then
            p[#p + 1] = tostring(identifyexecutor())
        elseif getexecutorname then
            p[#p + 1] = tostring(getexecutorname())
        end
    end)
    local r = table.concat(p, "|")
    local h = 0
    for i = 1, #r do
        h = (h * 31 + string.byte(r, i)) % 2147483647
    end
    return string.format("VNTA-%08X-GHL", h)
end

local function http(url, body)
    local payload = {
        Url = url,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = body,
    }
    if syn and syn.request then
        local r = syn.request(payload)
        return r.StatusCode and r.StatusCode >= 200 and r.StatusCode < 300, r.Body, r.StatusCode
    end
    if http_request then
        local r = http_request(payload)
        return r.StatusCode and r.StatusCode >= 200 and r.StatusCode < 300, r.Body, r.StatusCode
    end
    if request then
        local r = request(payload)
        return r.StatusCode and r.StatusCode >= 200 and r.StatusCode < 300, r.Body, r.StatusCode
    end
    local ok, r = pcall(function()
        return HS:RequestAsync(payload)
    end)
    if not ok then
        return false, tostring(r), 0
    end
    return r.Success, r.Body, r.StatusCode
end

local function b64decode(data)
    local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    data = data:gsub("[^" .. b .. "=]", "")
    return (
        data:gsub(".", function(x)
            if x == "=" then
                return ""
            end
            local r, f = "", (b:find(x) - 1)
            for i = 6, 1, -1 do
                r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0")
            end
            return r
        end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
            if #x ~= 8 then
                return ""
            end
            local c = 0
            for i = 1, 8 do
                c = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0)
            end
            return string.char(c)
        end)
    )
end

print("[VANTA] Auth...")
local body = HS:JSONEncode({ key = KEY, hwid = hw() })
local ok, respBody, code = http(API .. "/auth/script", body)
if not ok then
    local err = "HTTP " .. tostring(code)
    pcall(function()
        local d = HS:JSONDecode(respBody)
        if d and d.error then
            err = d.error
        end
    end)
    return warn("[VANTA] Failed: " .. tostring(err) .. " (is the API running?)")
end

local data
local decOk = pcall(function()
    data = HS:JSONDecode(respBody)
end)
if not decOk or type(data) ~= "table" then
    return warn("[VANTA] Bad response from API")
end
if not data.success or type(data.script) ~= "string" then
    return warn("[VANTA] " .. tostring(data.error or "No script"))
end

print("[VANTA] Loading hub...")
local src = data.script
if data.encoding == "base64" then
    local dok, decoded = pcall(b64decode, src)
    if not dok or not decoded or #decoded < 100 then
        return warn("[VANTA] Decode failed")
    end
    src = decoded
end

local fn, err = loadstring(src)
if not fn then
    return warn("[VANTA] loadstring: " .. tostring(err))
end
local ran, runErr = pcall(fn)
if not ran then
    warn("[VANTA] Script error: " .. tostring(runErr))
end
print("[VANTA] Done.")
