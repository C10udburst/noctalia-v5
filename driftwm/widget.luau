local state = {
    zoom = 1.0,
    x = 0,
    y = 0,
    output = "",
    hasError = false,
    errorMessage = ""
}

local driftwm = require("./driftwm.luau")

local function execDriftAction(actionName)
    driftwm.execAction(actionName)
end

function onWidgetClick()
    noctalia.togglePanel("cloudburst/driftwm:minimap")
end

function onWidgetRightClick()
    execDriftAction("zoom-to-fit")
end

function onWidgetMiddleClick()
    execDriftAction("zoom-reset")
end

function onWidgetScroll(arg1, arg2)
    if arg2 < 0 then
        execDriftAction("zoom-in")
    else
        execDriftAction("zoom-out")
    end
end

local function readDriftWMState()
    local parsed, err = driftwm.readState()
    if err then
        state.hasError = true
        state.errorMessage = err
        return
    end

    state.hasError = false
    state.errorMessage = ""
    state.zoom = parsed.zoom
    state.x = parsed.x
    state.y = parsed.y
    state.output = parsed.output
end

function renderWidget()

    local isVert = false
    if type(barWidget.isVertical) == "function" then
        isVert = barWidget.isVertical()
    elseif type(barWidget.isVertical) == "boolean" then
        isVert = barWidget.isVertical
    end

    local container = isVert and ui.column or ui.row
    local children = {}

    if state.hasError then
        table.insert(children, ui.glyph({
            name = "alert-circle",
            size = 13,
            color = "error"
        }))
        table.insert(children, ui.label({
            text = state.errorMessage,
            fontSize = 11,
            color = "error",
            fontWeight = "bold"
        }))
    else
        table.insert(children, ui.label({
            text = string.format("%.1fx", state.zoom),
            fontSize = 12,
            fontWeight = "bold",
            color = "primary"
        }))

        table.insert(children, ui.label({
            text = string.format("(%d, %d)", state.x, state.y),
            fontSize = 11,
            color = "on_surface_variant"
        }))
    end

    barWidget.render(container({
        gap = 6,
        align = "center",
        onClick = "onWidgetClick",
        onRightClick = "onWidgetRightClick",
        onMiddleClick = "onWidgetMiddleClick",
        onScroll = "onWidgetScroll"
    }, children))
end

function update()
    noctalia.setUpdateInterval(500)
    readDriftWMState()
    renderWidget()
end

function onClick(btn)
    if btn == "right" or btn == 2 or btn == "2" then
        onWidgetRightClick()
    elseif btn == "middle" or btn == 3 or btn == "3" then
        onWidgetMiddleClick()
    else
        onWidgetClick()
    end
end

function onRightClick()
    onWidgetRightClick()
end

function onMiddleClick()
    onWidgetMiddleClick()
end

function onScroll(arg1, arg2)
    onWidgetScroll(arg1, arg2)
end

update()
