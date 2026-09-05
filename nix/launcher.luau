--!nonstrict
-- Nix package launcher provider for Noctalia.
-- Discovers packages with .desktop files via nix-locate, caches in /tmp,
-- searches via noctalia.fuzzyScore, and launches via launch.py.

local items: { any } = {}
local isLoaded: boolean = false
local isIndexing: boolean = false
local pendingQuery: string? = nil

local INDEX_FILE = "/tmp/nix-desktop-index.json"

local function trim(s: string): string
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function getIndexerScript(): string
    local dir = noctalia.pluginDir() or "."
    return dir .. "/indexer.py"
end

local function getLaunchScript(): string
    local dir = noctalia.pluginDir() or "."
    return dir .. "/launch.py"
end

local function tryLoadIndex(): boolean
    if noctalia.fileExists and noctalia.fileExists(INDEX_FILE) then
        local raw = noctalia.readFile(INDEX_FILE)
        if raw and raw ~= "" then
            local parsed, err = noctalia.json.decode(raw)
            if parsed and type(parsed) == "table" then
                items = parsed
                isLoaded = true
                return true
            else
                noctalia.log("nix-launcher: failed to decode index json: " .. tostring(err))
            end
        end
    end
    return false
end

local function runIndexer(callback: (() -> ())?)
    if isIndexing then
        return
    end

    isIndexing = true
    local script = getIndexerScript()

    noctalia.runAsync({"python3", script}, function(result)
        isIndexing = false
        if result.exitCode == 0 then
            tryLoadIndex()
        else
            noctalia.log("nix-launcher: indexer failed: " .. tostring(result.stderr))
        end

        if callback then
            callback()
        end
    end)
end

-- Attempt to load index immediately if present in /tmp
if not tryLoadIndex() then
    runIndexer()
end

local function performSearch(query: string)
    local text = trim(query)

    if not isLoaded then
        if isIndexing then
            launcher.setResults(query, {
                {
                    id = "",
                    title = "Indexing Nix Packages...",
                    subtitle = "Discovering desktop applications with nix-locate in background...",
                    glyph = "refresh",
                },
            })
        else
            runIndexer(function()
                performSearch(query)
            end)
            launcher.setResults(query, {
                {
                    id = "",
                    title = "Loading Nix Packages Index...",
                    subtitle = "Initializing cache from /tmp...",
                    glyph = "refresh",
                },
            })
        end
        return
    end

    if text == "" then
        launcher.setResults(query, {
            {
                id = "",
                title = "Search Nix Packages",
                subtitle = string.format("Indexed %d desktop packages. Type package or app name...", #items),
                glyph = "package",
            },
        })
        return
    end

    local matches = {}
    for _, item in ipairs(items) do
        local pkgName = item.pkg or ""
        local subtitle = item.subtitle or ""
        local score = noctalia.fuzzyScore(text, pkgName)

        -- If query did not match package name, check desktop filename subtitle
        if score == nil and subtitle ~= "" then
            local subScore = noctalia.fuzzyScore(text, subtitle)
            if subScore ~= nil then
                score = subScore - 50
            end
        end

        if score ~= nil then
            table.insert(matches, {
                id = pkgName,
                title = pkgName,
                subtitle = subtitle,
                glyph = "package",
                score = score,
            })
        end
    end

    if #matches == 0 then
        launcher.setResults(query, {
            {
                id = "",
                title = "No matching packages",
                subtitle = "No Nix desktop packages matched '" .. text .. "'",
                glyph = "search-off",
            },
        })
        return
    end

    table.sort(matches, function(a, b)
        return (a.score or 0) > (b.score or 0)
    end)

    -- Cap results to top 50 for optimal UI performance
    local topResults = {}
    local limit = math.min(#matches, 50)
    for i = 1, limit do
        topResults[i] = matches[i]
    end

    launcher.setResults(query, topResults)
end

function onQuery(query: string)
    performSearch(query)
end

function onActivate(id: string)
    if not id or id == "" then
        return
    end

    local script = getLaunchScript()
    noctalia.runAsync({"python3", script, id})
end
