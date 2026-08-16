local M = {}
local currentBuf = "A"

local function escapeXml(str)
    if not str then return "" end
    local replacements = {
        ["&"] = "&amp;",
        ["<"] = "&lt;",
        [">"] = "&gt;",
        ['"'] = "&quot;",
        ["'"] = "&apos;"
    }
    return string.gsub(str, "[&<>\'\"]", replacements)
end

local function getClampedFontSize(text, baseSize, winW, winH, maxHRatio)
    local maxH = winH * maxHRatio
    local textLen = text and #text or 1
    if textLen == 0 then textLen = 1 end
    local maxW = (winW * 0.9) / (textLen * 0.6)
    return math.min(baseSize, maxH, maxW)
end

function M.generate(colors)
    local stateFile = "/run/user/1000/driftwm/state"
    local raw = noctalia.readFile(stateFile)
    if not raw or raw == "" then return end

    local windows = {}
    local camX = 0.0
    local camY = 0.0
    local camZoom = 1.0

    for line in string.gmatch(raw, "[^\r\n]+") do
        local lineStr = string.gsub(line, "^%s*(.-)%s*$", "%1")
        if string.sub(lineStr, 1, 8) == "windows=" then
            local jsonData = string.sub(lineStr, 9)
            local decoded = noctalia.json.decode(jsonData)
            if decoded then
                windows = decoded
            end
        elseif string.sub(lineStr, 1, 2) == "x=" then
            camX = tonumber(string.sub(lineStr, 3)) or camX
        elseif string.sub(lineStr, 1, 2) == "y=" then
            camY = tonumber(string.sub(lineStr, 3)) or camY
        elseif string.sub(lineStr, 1, 5) == "zoom=" then
            camZoom = tonumber(string.sub(lineStr, 6)) or camZoom
        end
    end

    local svgWindows = {}
    local minX, maxX, minY, maxY

    for _, w in ipairs(windows) do
        local center_x = w.position[1]
        local center_y_up = w.position[2]
        local size_w = w.size[1]
        local size_h = w.size[2]

        local center_y_down = -center_y_up
        local svg_x = center_x - (size_w / 2)
        local svg_y = center_y_down - (size_h / 2)

        table.insert(svgWindows, {
            svg_x = svg_x,
            svg_y = svg_y,
            center_x = center_x,
            center_y = center_y_down,
            width = size_w,
            height = size_h,
            app_id = w.app_id or "unknown",
            title = w.title or "",
            is_focused = w.is_focused or false,
            suspended = w.suspended or false
        })

        if not minX then
            minX = svg_x
            maxX = svg_x + size_w
            minY = svg_y
            maxY = svg_y + size_h
        else
            minX = math.min(minX, svg_x)
            maxX = math.max(maxX, svg_x + size_w)
            minY = math.min(minY, svg_y)
            maxY = math.max(maxY, svg_y + size_h)
        end
    end

    local viewW = 1920.0 / math.max(0.2, camZoom)
    local viewH = 1080.0 / math.max(0.2, camZoom)
    local camSvgX = camX - (viewW / 2.0)
    local camSvgY = (-camY) - (viewH / 2.0)

    if minX then
        minX = math.min(minX, camSvgX)
        maxX = math.max(maxX, camSvgX + viewW)
        minY = math.min(minY, camSvgY)
        maxY = math.max(maxY, camSvgY + viewH)
    else
        minX, maxX = camSvgX, camSvgX + viewW
        minY, maxY = camSvgY, camSvgY + viewH
    end

    local padding = 120
    minX = minX - padding
    minY = minY - padding
    local width = (maxX - minX) + (padding * 2)
    local height = (maxY - minY) + (padding * 2)

    local canvasDiag = math.sqrt(width * width + height * height)
    local scale = math.max(1.0, canvasDiag / 2000.0)

    -- Toggle buffer A/B in memory for Qt cache busting
    currentBuf = (currentBuf == "A") and "B" or "A"
    local svgPath = "/tmp/driftwm-map-" .. currentBuf .. ".svg"

    local svg = {}
    table.insert(svg, string.format('<svg xmlns="http://www.w3.org/2000/svg" viewBox="%f %f %f %f">\n', minX, minY, width, height))

    -- Draw windows
    for _, w in ipairs(svgWindows) do
        local stroke = colors.onSurface
        local fill = colors.surface
        if w.is_focused then
            stroke = colors.primary
            fill = colors.surfaceVariant
        elseif w.suspended then
            stroke = colors.onSurfaceVariant
            fill = colors.surface
        end

        table.insert(svg, string.format('  <rect x="%f" y="%f" width="%f" height="%f" rx="%f" fill="%s" stroke="%s" stroke-width="%f" />\n',
            w.svg_x, w.svg_y, w.width, w.height, 12 * scale, fill, stroke, 4 * scale))

        local appSize = getClampedFontSize(w.app_id, 28 * scale, w.width, w.height, 0.25)
        local titleSize = getClampedFontSize(w.title, 18 * scale, w.width, w.height, 0.15)

        local appY = w.center_y - (appSize * 0.4)
        local titleY = w.center_y + (titleSize * 0.8)

        local safeAppId = escapeXml(w.app_id)
        local safeTitle = escapeXml(w.title)

        table.insert(svg, string.format('  <text x="%f" y="%f" fill="%s" font-family="sans-serif" font-size="%.1f" font-weight="bold" text-anchor="middle" dominant-baseline="middle">%s</text>\n',
            w.center_x, appY, colors.onSurface, appSize, safeAppId))

        if w.title ~= "" then
            table.insert(svg, string.format('  <text x="%f" y="%f" fill="%s" font-family="sans-serif" font-size="%.1f" text-anchor="middle" dominant-baseline="middle">%s</text>\n',
                w.center_x, titleY, colors.onSurface, titleSize, safeTitle))
        end
    end

    -- Draw active camera viewport frame
    table.insert(svg, string.format('  <rect x="%f" y="%f" width="%f" height="%f" rx="%f" fill="none" stroke="%s" stroke-width="%f" stroke-dasharray="12 6" />\n',
        camSvgX, camSvgY, viewW, viewH, 15 * scale, colors.primary, 4 * scale))
    table.insert(svg, string.format('  <text x="%f" y="%f" fill="%s" font-family="sans-serif" font-size="%.1f" font-weight="bold" text-anchor="middle" dominant-baseline="middle">Camera</text>\n',
        camX, -camY, colors.primary, 20 * scale))

    table.insert(svg, "</svg>\n")

    noctalia.writeFile(svgPath, table.concat(svg, ""))

    -- Return the generated SVG path
    return svgPath
end

return M
