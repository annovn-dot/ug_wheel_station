local function discordEnabled()
    return Config
        and Config.DiscordLogs
        and Config.DiscordLogs.Enabled
        and Config.DiscordLogs.Webhook
        and Config.DiscordLogs.Webhook ~= ""
end

local function safeStr(v)
    if v == nil then return "nil" end
    return tostring(v)
end

local function isFinite(n)
    return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function fmtNum(n, decimals)
    if not isFinite(n) then return "n/a" end
    return string.format("%." .. (decimals or 2) .. "f", n)
end

local function postToDiscord(payload)
    if not discordEnabled() then return end

    PerformHttpRequest(Config.DiscordLogs.Webhook, function() end, "POST",
        json.encode(payload),
        { ["Content-Type"] = "application/json" }
    )
end

local function buildEmbed(title, description, color, fields)
    return {
        username = Config.DiscordLogs.Username or "ug_wheel_tuning",
        avatar_url = (Config.DiscordLogs.Avatar ~= "" and Config.DiscordLogs.Avatar) or nil,
        embeds = {
            {
                title = title,
                description = description,
                color = color or 3447003,
                fields = fields or {},
                footer = { text = "ug_wheel_tuning" },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
        }
    }
end

local function getPlayerMeta(src)
    local name = GetPlayerName(src) or ("ID " .. tostring(src))

    local ids = GetPlayerIdentifiers(src) or {}
    local license, discord, steam, fivem = "n/a", "n/a", "n/a", "n/a"

    for _, id in ipairs(ids) do
        if id:find("license:") == 1 then license = id end
        if id:find("discord:") == 1 then discord = id:gsub("discord:", "") end
        if id:find("steam:") == 1 then steam = id end
        if id:find("fivem:") == 1 then fivem = id end
    end

    return name, license, discord, steam, fivem
end

local function summarizeWheelData(data)
    data = data or {}
    local st = data.stance or {}
    local cb = data.camber or {}

    local lines = {}

    if isFinite(data.width) then table.insert(lines, ("Width: **%s**"):format(fmtNum(data.width, 2))) end
    if isFinite(data.size) then table.insert(lines, ("Size: **%s**"):format(fmtNum(data.size, 2))) end
    if isFinite(data.height) then table.insert(lines, ("Susp: **%s**"):format(fmtNum(data.height, 2))) end

    local function addOffsets()
        if isFinite(st.fl) or isFinite(st.fr) or isFinite(st.rl) or isFinite(st.rr) then
            table.insert(lines, ("Offsets FL/FR/RL/RR: **%s / %s / %s / %s**"):format(
                fmtNum(st.fl, 3), fmtNum(st.fr, 3), fmtNum(st.rl, 3), fmtNum(st.rr, 3)
            ))
        end
    end

    local function addCamber()
        if isFinite(cb.fl) or isFinite(cb.fr) or isFinite(cb.rl) or isFinite(cb.rr) then
            table.insert(lines, ("Camber FL/FR/RL/RR: **%s / %s / %s / %s**"):format(
                fmtNum(cb.fl, 3), fmtNum(cb.fr, 3), fmtNum(cb.rl, 3), fmtNum(cb.rr, 3)
            ))
        end
    end

    addOffsets()
    addCamber()

    if #lines == 0 then
        return "No values found in payload."
    end

    return table.concat(lines, "\n")
end

function UG_WHEEL_LogSave(src, plate, data)
    if not discordEnabled() then return end

    local name, license, discord, steam, fivem = getPlayerMeta(src)

    local summary = summarizeWheelData(data)
    local desc = ("**Player:** %s (src %s)\n**Plate:** %s\n\n%s"):format(
        safeStr(name), safeStr(src), safeStr(plate), summary
    )

    local fields = {
        { name = "License", value = safeStr(license), inline = false },
        { name = "Discord", value = safeStr(discord), inline = true },
        { name = "Steam",   value = safeStr(steam),   inline = true },
        { name = "FiveM",   value = safeStr(fivem),   inline = false },
    }

    if Config.DiscordLogs.IncludeRawJson then
        local raw = json.encode(data or {})
        if #raw > 900 then raw = raw:sub(1, 900) .. "..." end
        table.insert(fields, { name = "Raw JSON (trimmed)", value = "```json\n" .. raw .. "\n```", inline = false })
    end

    postToDiscord(buildEmbed(
        "Wheel Tuning Saved",
        desc,
        Config.DiscordLogs.ColorSave or 3447003,
        fields
    ))
end
