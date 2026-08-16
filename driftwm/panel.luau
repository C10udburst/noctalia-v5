-- Noctalia Minimap Panel for DriftWM

local state = {
    cameraX = 0,
    cameraY = 0,
    zoom = 1.0,
    lastClickX = 0,
    lastClickY = 0,
    hasError = false,
    errorMessage = "",
    mapPath = "/tmp/driftwm-map-A.svg"
}

local theme = require("./theme.luau")
local driftwm = require("./driftwm.luau")
local map = require("./map.luau")

local function readDriftWMState()
    local parsed, err = driftwm.readState()
    if parsed then
        state.zoom = parsed.zoom
        state.cameraX = parsed.x
        state.cameraY = parsed.y
    end
end

local function refresh()
    readDriftWMState()

    local colors = theme.getColors()
    local svgPath = map.generate(colors)
    if svgPath then
        state.mapPath = svgPath
    end

    renderPanel()
end

function onZoomInClick()
    driftwm.execAction("zoom-in")
    refresh()
end

function onZoomOutClick()
    driftwm.execAction("zoom-out")
    refresh()
end

function onZoomResetClick()
    driftwm.execAction("zoom-reset")
    refresh()
end

function onZoomFitClick()
    driftwm.execAction("zoom-to-fit")
    refresh()
end

function onOriginClick()
    state.lastClickX = 0
    state.lastClickY = 0
    driftwm.goToOrigin()
    refresh()
end

function onRefreshClick()
    refresh()
end

function onPanUp()
    driftwm.execAction("pan-viewport", "up")
    refresh()
end

function onPanDown()
    driftwm.execAction("pan-viewport", "down")
    refresh()
end

function onPanLeft()
    driftwm.execAction("pan-viewport", "left")
    refresh()
end

function onPanRight()
    driftwm.execAction("pan-viewport", "right")
    refresh()
end

function renderPanel()
    local children = {}

    -- 1. Header Title & Camera Coordinates
    table.insert(children, ui.row({
        align = "center",
        justify = "space_between"
    }, {
        ui.row({ gap = 8, align = "center" }, {
            ui.glyph({ name = "map", size = 18, color = "primary" }),
            ui.label({ text = "DriftWM", fontSize = 15, fontWeight = "bold", color = "on_surface" }),
        }),
        ui.row({ gap = 6, align = "center" }, {
            ui.glyph({ name = "camera", size = 18, color = "primary" }),
            ui.label({
                text = string.format("%.1fx", state.zoom),
                fontSize = 12,
                fontWeight = "bold",
                color = "primary"
            }),
            ui.label({
                text = string.format("(%d, %d)", state.cameraX, state.cameraY),
                fontSize = 12,
                color = "on_surface_variant"
            })
        })
    }))

    -- 2. Glyph Controls Toolbar
    table.insert(children, ui.row({
        align = "center",
        justify = "space_between",
        gap = 6,
        onHover = "refresh",
    }, {
        ui.row({ gap = 6, align = "center" }, {
            ui.row({ gap = 4, align = "center", onHover = "refresh", onClick = "onZoomInClick" }, {
                ui.glyph({ name = "plus", size = 14, color = "primary" })
            }),
            ui.row({ gap = 4, align = "center", onHover = "refresh", onClick = "onZoomOutClick" }, {
                ui.glyph({ name = "minus", size = 14, color = "primary" })
            }),
            ui.row({ gap = 4, align = "center", onHover = "refresh", onClick = "onZoomResetClick" }, {
                ui.glyph({ name = "zoom", size = 14, color = "primary" }),
                ui.label({ text = "1.0x", fontSize = 11, color = "primary" })
            }),
            ui.row({ gap = 4, align = "center", onHover = "refresh", onClick = "onZoomFitClick" }, {
                ui.glyph({ name = "zoom-scan", size = 14, color = "primary" }),
                ui.label({ text = "Fit", fontSize = 11, color = "primary" })
            }),
            ui.row({ gap = 4, align = "center", onHover = "refresh", onClick = "onOriginClick" }, {
                ui.glyph({ name = "target", size = 14, color = "primary" }),
                ui.label({ text = "(0,0)", fontSize = 11, color = "primary" })
            })
        }),
        ui.row({ gap = 4, align = "center", onClick = "onRefreshClick" }, {
            ui.glyph({ name = "refresh", size = 14, color = "primary" }),
            ui.label({ text = "Refresh", fontSize = 11, color = "primary" })
        })
    }))

    -- 3. SVG Canvas Map View with Pan Controls
    table.insert(children, ui.column({
        width = 650,
        height = 420,
        align = "center",
        justify = "center",
        gap = 4,
        onHover = "refresh"
    }, {
        -- Up Arrow
        ui.row({
            align = "center",
            justify = "center",
            onClick = "onPanUp",
            onHover = "onPanUp",
            padding = 2,
        }, {
            ui.glyph({ name = "chevron-up", size = 20, color = "primary" })
        }),
        -- Left Arrow + Image + Right Arrow
        ui.row({
            align = "center",
            justify = "center",
            gap = 6,
        }, {
            -- Left Arrow
            ui.row({
                align = "center",
                justify = "center",
                onClick = "onPanLeft",
                onHover = "onPanLeft",
                padding = 2,
            }, {
                ui.glyph({ name = "chevron-left", size = 20, color = "primary" })
            }),
            -- Minimap Image
            ui.image({
                src = state.mapPath,
                path = state.mapPath,
                width = 580,
                height = 340,
                fit = "contain",
                onHover = "refresh",
            }),
            -- Right Arrow
            ui.row({
                align = "center",
                justify = "center",
                onClick = "onPanRight",
                onHover = "onPanRight",
                padding = 2,
            }, {
                ui.glyph({ name = "chevron-right", size = 20, color = "primary" })
            }),
        }),
        -- Down Arrow
        ui.row({
            align = "center",
            justify = "center",
            onClick = "onPanDown",
            onHover = "onPanDown",
            padding = 2,
        }, {
            ui.glyph({ name = "chevron-down", size = 20, color = "primary" })
        }),
    }))

    local tree = ui.column({
        gap = 8,
        padding = 12,
        background = "surface"
    }, children)

    local target = panelWidget or panel
    if target and target.render then
        target.render(tree)
    end

    return tree
end

function render()
    return renderPanel()
end

function update()
    refresh()
    return renderPanel()
end

function onOpen()
    refresh()
    return renderPanel()
end

update()
