local M = {}

function M.execAction(action, ...)
    local cmd = {"driftwm", "msg", "action", action}
    for _, arg in ipairs({...}) do
        table.insert(cmd, arg)
    end
    noctalia.runAsync(cmd)
end

function M.goToOrigin()
    noctalia.runAsync({"sh", "-c", "driftwm msg bookmark minimap 0 0 && driftwm msg action go-to-bookmark minimap"})
end

function M.parseStateFile(raw)
    if not raw or type(raw) ~= "string" or raw == "" then return nil end

    local res = {
        zoom = 1.0,
        x = 0,
        y = 0,
        output = "",
        outputs = {}
    }

    local cleanRaw = raw
    local startIdx = string.find(raw, "windows=%[")
    if startIdx then
        local jsonStart = startIdx + 8
        local endIdx = string.find(raw, "\nlayers=", jsonStart)
        if not endIdx then endIdx = string.find(raw, "\noutputs.", jsonStart) end
        if endIdx then
            cleanRaw = string.sub(raw, 1, startIdx - 1) .. string.sub(raw, endIdx + 1)
        end
    end

    for line in string.gmatch(cleanRaw, "[^\r\n]+") do
        local key, val = string.match(line, "^([^=]+)=(.*)$")
        if key and val then
            if key == "zoom" then
                res.zoom = tonumber(val) or 1.0
            elseif key == "x" then
                res.x = math.floor(tonumber(val) or 0)
            elseif key == "y" then
                res.y = math.floor(tonumber(val) or 0)
            else
                local outName, prop = string.match(key, "^outputs%.([^%.]+)%.(.+)$")
                if outName and prop then
                    if not res.outputs[outName] then
                        res.outputs[outName] = { name = outName, x = 0, y = 0, zoom = 1.0 }
                    end
                    if prop == "camera_x" then
                        res.outputs[outName].x = math.floor(tonumber(val) or 0)
                    elseif prop == "camera_y" then
                        res.outputs[outName].y = math.floor(tonumber(val) or 0)
                    elseif prop == "zoom" then
                        res.outputs[outName].zoom = tonumber(val) or 1.0
                    end
                end
            end
        end
    end

    if barOutput and res.outputs[barOutput] then
        res.zoom = res.outputs[barOutput].zoom
        res.x = res.outputs[barOutput].x
        res.y = res.outputs[barOutput].y
        res.output = barOutput
    end

    return res
end

function M.readState()
    local raw = noctalia.readFile("/run/user/1000/driftwm/state")
    if not raw then
        return nil, "DriftWM Offline"
    end

    local parsed = M.parseStateFile(raw)
    if not parsed then
        return nil, "Parse Error"
    end

    return parsed
end

return M
