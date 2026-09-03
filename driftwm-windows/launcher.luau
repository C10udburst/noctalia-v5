--!nonstrict
-- DriftWM Windows launcher provider: switch between open DriftWM windows.
-- Supports searching open windows by title and customizable settings.

local inFlight: boolean = false
local pendingQuery: string? = nil

local function trim(s: string): string
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Resolve application icon name directly from app_id.
-- Noctalia launcher resolves icon theme names natively via QIcon at render time.
local function resolveAppIcon(appId: any): string?
    if type(appId) ~= "string" or appId == "" then
        return nil
    end
    return appId
end

local function makeSubtitle(win: { [string]: any }): string
    local parts = {}

    if type(win.app_id) == "string" and win.app_id ~= "" then
        table.insert(parts, win.app_id)
    end

    local pos = type(win.position) == "table" and win.position or nil
    local size = type(win.size) == "table" and win.size or nil
    local px = pos and tonumber(pos[1])
    local py = pos and tonumber(pos[2])
    local sw = size and tonumber(size[1])
    local sh = size and tonumber(size[2])

    if px and py and sw and sh then
        table.insert(
            parts,
            string.format(
                "(%d, %d) · %dx%d",
                math.floor(px),
                math.floor(py),
                math.floor(sw),
                math.floor(sh)
            )
        )
    end

    if win.is_focused == true then
        table.insert(parts, "Focused")
    end

    if win.suspended == true then
        table.insert(parts, "Suspended")
    end

    return table.concat(parts, " · ")
end

local function parseWindows(stdout: string)
    local data, err = noctalia.json.decode(stdout)
    if not data or type(data) ~= "table" then
        return nil, err or "Invalid JSON"
    end

    local state = data.Ok and data.Ok.State
    if not state or type(state) ~= "table" then
        return nil, "Missing Ok.State in response"
    end

    local rawWindows = state.windows or state.window
    if type(rawWindows) ~= "table" then
        return {}
    end

    local list = {}
    for _, win in ipairs(rawWindows) do
        -- Skip widget windows as requested
        if win.is_widget == true then
            continue
        end

        local winId = win.id
        if winId == nil then
            continue
        end

        table.insert(list, win)
    end

    return list
end

local function executeQuery(query: string)
    local text = trim(query)

    inFlight = true
    noctalia.runAsync({"driftwm", "msg", "state", "--json"}, function(result)
        inFlight = false

        -- If a newer query arrived while this was in flight, process that instead
        if pendingQuery ~= nil then
            local nextQuery = pendingQuery
            pendingQuery = nil
            executeQuery(nextQuery)
            return
        end

        local ok, renderErr = pcall(function()
            if result.exitCode ~= 0 or not result.stdout or result.stdout == "" then
                launcher.setResults(query, {
                    {
                        id = "",
                        title = "DriftWM Offline",
                        subtitle = "Could not connect to DriftWM IPC socket",
                        glyph = "alert-triangle",
                    },
                })
                return
            end

            local windows, err = parseWindows(result.stdout)
            if not windows then
                launcher.setResults(query, {
                    {
                        id = "",
                        title = "DriftWM State Error",
                        subtitle = tostring(err),
                        glyph = "alert-triangle",
                    },
                })
                return
            end

            local results = {}
            for _, win in ipairs(windows) do
                local winId = win.id
                local title = type(win.title) == "string" and win.title or ""
                if title == "" then
                    title = type(win.app_id) == "string" and win.app_id or ("Window " .. tostring(winId))
                end

                local score = nil
                if text == "" then
                    score = 0
                else
                    score = noctalia.fuzzyScore(text, title)
                    -- Fallback to app_id match if title did not match
                    if score == nil and type(win.app_id) == "string" and win.app_id ~= "" then
                        local appScore = noctalia.fuzzyScore(text, win.app_id)
                        if appScore ~= nil then
                            score = appScore - 50
                        end
                    end
                end

                if score ~= nil then
                    local icon = resolveAppIcon(win.app_id)
                    local subtitle = makeSubtitle(win)

                    table.insert(results, {
                        id = tostring(winId),
                        title = title,
                        subtitle = subtitle,
                        icon = icon,
                        glyph = "app-window",
                        score = score,
                        is_focused = win.is_focused == true,
                    })
                end
            end

            if #results == 0 then
                if text ~= "" then
                    launcher.setResults(query, {
                        {
                            id = "",
                            title = "No matching windows",
                            subtitle = "No windows matched '" .. text .. "'",
                            glyph = "search-off",
                        },
                    })
                else
                    launcher.setResults(query, {
                        {
                            id = "",
                            title = "No open windows",
                            subtitle = "No active windows found in DriftWM",
                            glyph = "app-window",
                        },
                    })
                end
                return
            end

            if text == "" then
                -- When query is empty: focused window first, then by ID
                table.sort(results, function(a, b)
                    if a.is_focused ~= b.is_focused then
                        return a.is_focused == true
                    end
                    return (tonumber(a.id) or 0) < (tonumber(b.id) or 0)
                end)
            else
                table.sort(results, function(a, b)
                    return (a.score or 0) > (b.score or 0)
                end)
            end

            launcher.setResults(query, results)
        end)

        if not ok then
            noctalia.log("driftwm-windows: callback error: " .. tostring(renderErr))
        end
    end, 2000)
end

function onQuery(query: string)
    if inFlight then
        pendingQuery = query
        return
    end

    executeQuery(query)
end

function onActivate(id: string)
    if not id or id == "" then
        return
    end

    local numId = tonumber(id)
    if not numId then
        noctalia.log("driftwm-windows: invalid window id: " .. tostring(id))
        return
    end

    noctalia.runAsync({"driftwm", "msg", "focus", "--id", tostring(numId)})
end
