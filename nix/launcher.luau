--!nonstrict
-- Nix package launcher provider for Noctalia.
-- High-performance fuzzy search powered by fzf and cached Nix desktop index.

local inFlight: boolean = false
local pendingQuery: string? = nil
local isIndexing: boolean = false

local CACHE_DIR = (noctalia.getenv and noctalia.getenv("XDG_CACHE_HOME"))
if not CACHE_DIR or CACHE_DIR == "" then
    CACHE_DIR = (noctalia.expandPath and noctalia.expandPath("~/.cache")) or os.getenv("HOME") .. "/.cache"
end

local INDEX_TSV = CACHE_DIR .. "/noctalia-nix/nix-desktop-index.tsv"
local COUNT_FILE = CACHE_DIR .. "/noctalia-nix/count.txt"

local cachedCount: number? = nil

local function trim(s: string): string
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function getSearchScript(): string
    local dir = noctalia.pluginDir() or "."
    return dir .. "/search.sh"
end

local function getIndexerScript(): string
    local dir = noctalia.pluginDir() or "."
    return dir .. "/indexer.py"
end

local function getLaunchScript(): string
    local dir = noctalia.pluginDir() or "."
    return dir .. "/launch.py"
end

local function resolveIndexFile(): string?
    if noctalia.fileExists and noctalia.fileExists(INDEX_TSV) then
        return INDEX_TSV
    end
    return nil
end

local function getIndexedCount(): number
    if cachedCount and cachedCount > 0 then
        return cachedCount
    end

    if noctalia.fileExists and noctalia.fileExists(COUNT_FILE) then
        local raw = noctalia.readFile(COUNT_FILE)
        if raw then
            local n = tonumber(trim(raw))
            if n and n > 0 then
                cachedCount = n
                return n
            end
        end
    end

    return 3000
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
            cachedCount = nil -- Invalidate count so it reloads fresh
        else
            noctalia.log("nix-launcher: indexer failed: " .. tostring(result.stderr))
        end

        if callback then
            callback()
        end
    end)
end

-- Check index on plugin load
if not resolveIndexFile() then
    runIndexer()
end

local function executeSearch(query: string)
    local text = trim(query)
    local indexFile = resolveIndexFile()

    if not indexFile then
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
                executeSearch(query)
            end)
            launcher.setResults(query, {
                {
                    id = "",
                    title = "Loading Nix Packages Index...",
                    subtitle = "Initializing cache...",
                    glyph = "refresh",
                },
            })
        end
        return
    end

    if text == "" then
        local count = getIndexedCount()
        launcher.setResults(query, {
            {
                id = "",
                title = "Search Nix Packages",
                subtitle = string.format("Indexed %d desktop packages. Type package or app name...", count),
                glyph = "package",
            },
        })
        return
    end

    inFlight = true
    local searchScript = getSearchScript()

    noctalia.runAsync({"sh", searchScript, text, indexFile, "50"}, function(result)
        inFlight = false

        -- If a newer query arrived while this was executing, process that query
        if pendingQuery ~= nil then
            local nextQuery = pendingQuery
            pendingQuery = nil
            executeSearch(nextQuery)
            return
        end

        if result.exitCode ~= 0 and (not result.stdout or result.stdout == "") then
            launcher.setResults(query, {
                {
                    id = "",
                    title = "Search Error",
                    subtitle = (result.stderr and result.stderr ~= "") and result.stderr or "Search process failed",
                    glyph = "alert-triangle",
                },
            })
            return
        end

        local rawLines = string.split(result.stdout or "", "\n")
        local results = {}
        local rank = 0

        for _, line in ipairs(rawLines) do
            local trimmed = trim(line)
            if trimmed ~= "" then
                rank = rank + 1
                local tab1 = string.find(trimmed, "\t", 1, true)
                local pkg: string
                local subtitle: string

                if tab1 then
                    pkg = string.sub(trimmed, 1, tab1 - 1)
                    local tab2 = string.find(trimmed, "\t", tab1 + 1, true)
                    if tab2 then
                        subtitle = string.sub(trimmed, tab1 + 1, tab2 - 1)
                    else
                        subtitle = string.sub(trimmed, tab1 + 1)
                    end
                else
                    pkg = trimmed
                    subtitle = ""
                end

                table.insert(results, {
                    id = pkg,
                    title = pkg,
                    subtitle = subtitle,
                    glyph = "package",
                    score = 1000 - rank,
                })
            end
        end

        if #results == 0 then
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

        launcher.setResults(query, results)
    end)
end

function onQuery(query: string)
    if inFlight then
        pendingQuery = query
        return
    end

    executeSearch(query)
end

function onActivate(id: string)
    if not id or id == "" then
        return
    end

    local script = getLaunchScript()
    noctalia.runAsync({"python3", script, id})
end
