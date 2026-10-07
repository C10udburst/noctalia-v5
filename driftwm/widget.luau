local state = {
    zoom = 1.0,
    x = 0,
    y = 0,
    output = "",
    hasError = false,
    errorMessage = "",
    visible = true
}

local driftwm = require("./driftwm.luau")

local function execDriftAction(actionName)
    if state.hasError then return end
    driftwm.execAction(actionName)
end

function onWidgetClick()
    if state.hasError then return end
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
        -- DriftWM IPC is unreachable (compositor not running, socket/state file
        -- missing, or still initialising). Stay invisible instead of showing an
        -- error capsule in the bar.
        state.hasError = true
        state.errorMessage = err
        return false
    end

    state.hasError = false
    state.errorMessage = ""
    state.zoom = parsed.zoom
    state.x = parsed.x
    state.y = parsed.y
    state.output = parsed.output
    return true
end

local function setBarVisible(visible)
    if state.visible == visible then return end
    state.visible = visible
    if barWidget and type(barWidget.setVisible) == "function" then
        barWidget.setVisible(visible)
    end
end

function renderWidget()
    if state.hasError then
        setBarVisible(false)
        -- Empty tree: nothing to draw even if the host ignores setVisible.
        barWidget.render(ui.row({ gap = 0, align = "center" }, {}))
        return
    end

    setBarVisible(true)

    local isVert = false
    if type(barWidget.isVertical) == "function" then
        isVert = barWidget.isVertical()
    elseif type(barWidget.isVertical) == "boolean" then
        isVert = barWidget.isVertical
    end

    local container = isVert and ui.column or ui.row
    local children = {}

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
