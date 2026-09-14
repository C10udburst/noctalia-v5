local M = {}

function M.getColors()
    return {
        primary = noctalia.getColor("primary") or "#36a166",
        surface = noctalia.getColor("surface") or "#22221b",
        surfaceVariant = noctalia.getColor("surface_variant") or "#302f27",
        onSurface = noctalia.getColor("on_surface") or "#929181",
        onSurfaceVariant = noctalia.getColor("on_surface_variant") or "#929181"
    }
end

return M
