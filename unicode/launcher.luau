--!nonstrict
-- Unicode search launcher provider: search and copy Unicode characters using Python.

local inFlight: boolean = false
local pendingQuery: string? = nil

local function trim(s: string): string
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function getPythonScript(): string
    local dir = noctalia.pluginDir() or "."
    return dir .. "/search.py"
end

local function executeQuery(query: string)
    local text = trim(query)
    local script = getPythonScript()

    inFlight = true
    noctalia.runAsync({"python3", script, text}, function(result)
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
                        title = "Unicode Search Error",
                        subtitle = (result.stderr and result.stderr ~= "") and result.stderr or "Search script failed",
                        glyph = "alert-triangle",
                    },
                })
                return
            end

            local items, err = noctalia.json.decode(result.stdout)
            if not items or type(items) ~= "table" then
                launcher.setResults(query, {
                    {
                        id = "",
                        title = "Unicode Parse Error",
                        subtitle = tostring(err),
                        glyph = "alert-triangle",
                    },
                })
                return
            end

            if #items == 0 then
                launcher.setResults(query, {
                    {
                        id = "",
                        title = "No matching characters",
                        subtitle = "No Unicode characters matched '" .. text .. "'",
                        glyph = "search-off",
                    },
                })
                return
            end

            local results = {}
            for index, item in ipairs(items) do
                local char = item[1] or ""
                local name = item[2] or ""

                table.insert(results, {
                    id = char,
                    title = char .. "   " .. name,
                    subtitle = "Press Enter to copy",
                    badge = char,
                    glyph = "typography",
                    score = 1000 - index,
                })
            end

            launcher.setResults(query, results)
        end)

        if not ok then
            noctalia.log("unicode: render error: " .. tostring(renderErr))
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

    -- Copy character to clipboard using native API and wl-copy
    if noctalia.copyToClipboard then
        noctalia.copyToClipboard(id, "text/plain")
    end
    noctalia.runAsync({"wl-copy", id})

    -- Record character in recent history
    local script = getPythonScript()
    noctalia.runAsync({"python3", script, "--record", id})
end
