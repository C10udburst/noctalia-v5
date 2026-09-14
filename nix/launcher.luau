--!nonstrict
-- Nix package launcher provider for Noctalia.
-- Discovers packages with .desktop files via nix-locate, caches in /tmp,
-- searches via noctalia.fuzzyScore, and launches via launch.py.

local items: { any } = {}
local isLoaded: boolean = false
local isIndexing: boolean = false
local pendingQuery: string? = nil

local INDEX_FILE = "/tmp/nix-desktop-index.json"
local MAX_RESULTS = 50

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

local function isSubsequence(pat: string, patLen: number, str: string, strLen: number): boolean
    local p = 1
    for s = 1, strLen do
        if string.byte(str, s) == string.byte(pat, p) then
            p = p + 1
            if p > patLen then
                return true
            end
        end
    end
    return false
end

local function canMatch(pat: string, patLen: number, str: string, strLen: number, c0: string, cLast: string?): boolean
    if patLen > strLen then
        return false
    end
    if not string.find(str, c0, 1, true) then
        return false
    end
    if patLen == 1 then
        return true
    end
    if cLast and not string.find(str, cLast, 1, true) then
        return false
    end
    return isSubsequence(pat, patLen, str, strLen)
end

local function insertTopResult(topList: { any }, item: any, score: number)
    local count = #topList
    if count < MAX_RESULTS then
        local insertIdx = count + 1
        for i = 1, count do
            if score > topList[i].score then
                insertIdx = i
                break
            end
        end
        table.insert(topList, insertIdx, {
            id = item.pkg,
            title = item.pkg,
            subtitle = item.subtitle,
            glyph = "package",
            score = score,
        })
    else
        local insertIdx = MAX_RESULTS
        for i = 1, MAX_RESULTS - 1 do
            if score > topList[i].score then
                insertIdx = i
                break
            end
        end
        table.insert(topList, insertIdx, {
            id = item.pkg,
            title = item.pkg,
            subtitle = item.subtitle,
            glyph = "package",
            score = score,
        })
        topList[MAX_RESULTS + 1] = nil
    end
end

local function tryLoadIndex(): boolean
    if noctalia.fileExists and noctalia.fileExists(INDEX_FILE) then
        local raw = noctalia.readFile(INDEX_FILE)
        if raw and raw ~= "" then
            local parsed, err = noctalia.json.decode(raw)
            if parsed and type(parsed) == "table" then
                for _, item in ipairs(parsed) do
                    local lPkg = item.lower_pkg or string.lower(item.pkg or "")
                    local lSub = item.lower_sub or string.lower(item.subtitle or "")
                    item.lowerPkg = lPkg
                    item.lowerSub = lSub
                    item.pkgLen = #lPkg
                    item.subLen = #lSub
                end
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
                    subtitle = "Initializing cache...",
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

    local patLower = string.lower(text)
    local patLen = #patLower
    local c0 = string.sub(patLower, 1, 1)
    local cLast = (patLen >= 3) and string.sub(patLower, patLen, patLen) or nil

    local hasSpace = string.find(patLower, "%s") ~= nil
    local compactPat = nil
    local compactLen = 0
    local compactC0 = nil
    local compactCLast = nil
    if hasSpace then
        compactPat = string.gsub(patLower, "%s+", "")
        compactLen = #compactPat
        if compactLen > 0 then
            compactC0 = string.sub(compactPat, 1, 1)
            compactCLast = (compactLen >= 3) and string.sub(compactPat, compactLen, compactLen) or nil
        end
    end

    local topResults: { any } = {}
    local minScore = -99999999
    local hasFullList = false

    for _, item in ipairs(items) do
        local pkgName = item.pkg or ""
        local subtitle = item.subtitle or ""
        local lPkg = item.lowerPkg
        local lSub = item.lowerSub
        local pLen = item.pkgLen
        local sLen = item.subLen

        local score = nil

        -- 1. Check if package name can match
        local canPkg = canMatch(patLower, patLen, lPkg, pLen, c0, cLast)
        if not canPkg and hasSpace and compactPat then
            canPkg = canMatch(compactPat, compactLen, lPkg, pLen, compactC0, compactCLast)
        end

        if canPkg then
            score = noctalia.fuzzyScore(text, pkgName)
        end

        -- 2. If no pkg match, check subtitle
        if score == nil and subtitle ~= "" then
            local canSub = canMatch(patLower, patLen, lSub, sLen, c0, cLast)
            if not canSub and hasSpace and compactPat then
                canSub = canMatch(compactPat, compactLen, lSub, sLen, compactC0, compactCLast)
            end

            if canSub then
                local subScore = noctalia.fuzzyScore(text, subtitle)
                if subScore ~= nil then
                    score = subScore - 50
                end
            end
        end

        if score ~= nil then
            if not hasFullList then
                insertTopResult(topResults, item, score)
                if #topResults == MAX_RESULTS then
                    hasFullList = true
                    minScore = topResults[MAX_RESULTS].score
                end
            elseif score > minScore then
                insertTopResult(topResults, item, score)
                minScore = topResults[MAX_RESULTS].score
            end
        end
    end

    if #topResults == 0 then
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
