local M = {}

local function getConfigDir()
    local noctaliaConfigHome = noctalia.getenv("NOCTALIA_CONFIG_HOME")
    if noctaliaConfigHome and noctaliaConfigHome ~= "" then
        return noctaliaConfigHome
    end

    local xdgConfigHome = noctalia.getenv("XDG_CONFIG_HOME")
    if xdgConfigHome and xdgConfigHome ~= "" then
        return xdgConfigHome .. "/noctalia"
    end

    local home = noctalia.getenv("HOME")
    return home .. "/.config/noctalia"
end

local function getStateDir()
    local noctaliaStateHome = noctalia.getenv("NOCTALIA_STATE_HOME")
    if noctaliaStateHome and noctaliaStateHome ~= "" then
        return noctaliaStateHome
    end

    local xdgStateHome = noctalia.getenv("XDG_STATE_HOME")
    if xdgStateHome and xdgStateHome ~= "" then
        return xdgStateHome .. "/noctalia"
    end

    local home = noctalia.getenv("HOME")
    return home .. "/.local/state/noctalia"
end

function M.getColors()
    local theme = noctalia.getSetting("theme")
    local source = theme and theme.source or "custom"
    local mode = theme and theme.mode or "dark"

    local palettePath = nil
    if source == "custom" then
        local custom_palette = theme and theme.custom_palette or "Oxocarbon"
        palettePath = getConfigDir() .. "/palettes/" .. custom_palette .. ".json"
    elseif source == "community" then
        local community_palette = theme and theme.community_palette or "Oxocarbon"
        palettePath = getStateDir() .. "/community-palettes/" .. community_palette .. ".json"
    end

    local colors = {
        primary = "#36a166",
        surface = "#22221b",
        surfaceVariant = "#302f27",
        onSurface = "#929181",
        onSurfaceVariant = "#929181"
    }

    if palettePath then
        local paletteRaw = noctalia.readFile(palettePath)
        if paletteRaw then
            local decoded = noctalia.json.decode(paletteRaw)
            if decoded and decoded[mode] then
                local p = decoded[mode]
                colors.primary = p.mPrimary or colors.primary
                colors.surface = p.mSurface or colors.surface
                colors.surfaceVariant = p.mSurfaceVariant or colors.surfaceVariant
                colors.onSurface = p.mOnSurface or colors.onSurface
                colors.onSurfaceVariant = p.mOnSurfaceVariant or colors.onSurfaceVariant
            end
        end
    end

    return colors
end

return M
