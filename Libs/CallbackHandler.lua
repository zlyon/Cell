local addonName, Cell = ...

local callbacks = {}

function Cell.RegisterCallback(eventName, onEventFuncName, onEventFunc)
    if not callbacks[eventName] then callbacks[eventName] = {} end
    callbacks[eventName][onEventFuncName] = onEventFunc
end

function Cell.UnregisterCallback(eventName, onEventFuncName)
    if not callbacks[eventName] then return end
    callbacks[eventName][onEventFuncName] = nil
end

function Cell.UnregisterAllCallbacks(eventName)
    if not callbacks[eventName] then return end
    callbacks[eventName] = nil
end

function Cell.Fire(eventName, ...)
    if not callbacks[eventName] then return end

    for onEventFuncName, onEventFunc in pairs(callbacks[eventName]) do
        -- One listener blowing up must not swallow the event for the rest: the frame
        -- refresh paths live in here, and a single error used to leave them stale until
        -- /reload. The error still reaches the default handler (same as Blizzard's own
        -- CallbackHandler), so nothing is hidden silently.
        local ok, err = pcall(onEventFunc, ...)
        if not ok then
            local eh = geterrorhandler and geterrorhandler()
            if eh then
                eh("Cell callback '"..tostring(onEventFuncName).."' ("..tostring(eventName).."): "..tostring(err))
            end
        end
    end
end