local ffi = require("ffi")
local bit = require("bit")
local C = ffi.C

local android = require("android")
require("ffi/posix_h")
require("ffi/linux_input_h")

local input = {
    -- to trigger refreshes for certain Android framework events:
    device = nil,
    -- NOPs
    open = function() end,
    close = function() end,
    closeAll = function() end,
    fakeTapInput = function() end,
    -- Tell front that we're a custom imp with no concept of paths/fd
    is_ffi = true,
    -- Set to function(code) to capture the next key down event
    capture_callback = nil,
    -- Set to function(event) to observe input events without consuming them.
    -- Used by the plugin's screenshot-friendly controller diagnostics.
    debug_callback = nil,
    supports_input_debug = true,
}

local inputQueue = {}

local function genInputTimeval(ts)
    local timev = { sec = 0, usec = 0 }
    if ts then
        -- If we've got one, trust the native event's timestamp, they're guaranteed to be in the CLOCK_MONOTONIC timebase.
        -- ns to µs
        -- NOTE: Unlike the Java APIs, this is in nanoseconds!
        --       c.f., https://developer.android.com/ndk/reference/group/input#amotionevent_geteventtime
        local us = ts / 1000
        -- TimeVal, how I miss thee...
        timev.sec = math.floor(tonumber(us / 1000000))
        timev.usec = tonumber(us % 1000000)
    else
        -- Otherwise, synthetize one in the same time scale.
        -- TimeVal probably ought to be in base...
        local timespec = ffi.new("struct timespec")
        C.clock_gettime(C.CLOCK_MONOTONIC, timespec)
        timev.sec = tonumber(timespec.tv_sec)
        -- ns to µs
        timev.usec = math.floor(tonumber(timespec.tv_nsec / 1000))
    end

    return timev
end

local function genEmuEvent(evtype, code, value, timev, ts)
    local ev = {
        type = tonumber(evtype),
        code = tonumber(code),
        value = tonumber(value),
        time = timev or genInputTimeval(ts),
    }
    table.insert(inputQueue, ev)
end

-- Gamepad D-pad axis support.
pcall(ffi.cdef, [[ float AMotionEvent_getAxisValue(const void* motion_event, int axis, unsigned int pointer_index); ]])
pcall(ffi.cdef, [[ int AInputEvent_getSource(const void* event); ]])
pcall(ffi.cdef, [[ int AInputEvent_getDeviceId(const void* event); ]])
pcall(ffi.cdef, [[ int AKeyEvent_getScanCode(const void* key_event); ]])
pcall(ffi.cdef, [[ int AKeyEvent_getRepeatCount(const void* key_event); ]])

local function nativeNumber(function_name, event, fallback)
    local ok, value = pcall(function()
        return android.lib[function_name](event)
    end)
    if ok and value ~= nil then return tonumber(value) end
    return fallback
end

local deviceInfoCache = {}

local function getDeviceInfo(device_id)
    if deviceInfoCache[device_id] ~= nil then
        return deviceInfoCache[device_id] or nil
    end

    local ok, info = pcall(function()
        return android.jni:context(android.app.activity.vm, function(jni)
            local device = jni:callStaticObjectMethod(
                "android/view/InputDevice", "getDevice",
                "(I)Landroid/view/InputDevice;", ffi.new("int", device_id))
            if device == nil then return nil end

            local name = jni:callObjectMethod(device, "getName", "()Ljava/lang/String;")
            local descriptor = jni:callObjectMethod(device, "getDescriptor", "()Ljava/lang/String;")
            local result = {
                id = device_id,
                name = name ~= nil and jni:to_string(name) or "unknown",
                descriptor = descriptor ~= nil and jni:to_string(descriptor) or "unknown",
                vendor_id = tonumber(jni:callIntMethod(device, "getVendorId", "()I")),
                product_id = tonumber(jni:callIntMethod(device, "getProductId", "()I")),
                sources = tonumber(jni:callIntMethod(device, "getSources", "()I")),
                keyboard_type = tonumber(jni:callIntMethod(device, "getKeyboardType", "()I")),
                is_virtual = jni:callBooleanMethod(device, "isVirtual", "()Z"),
            }
            if name ~= nil then jni.env[0].DeleteLocalRef(jni.env, name) end
            if descriptor ~= nil then jni.env[0].DeleteLocalRef(jni.env, descriptor) end
            jni.env[0].DeleteLocalRef(jni.env, device)
            return result
        end)
    end)

    -- Cache failures too: identity is supplemental and should never interfere
    -- with capturing the controller event itself.
    deviceInfoCache[device_id] = ok and info or false
    return ok and info or nil
end

local function emitDebug(event)
    if input.debug_callback then
        -- Diagnostics must never be able to interrupt normal input handling.
        pcall(input.debug_callback, event)
        -- The controller event itself is consumed below so it cannot operate
        -- the diagnostic UI. Leave a harmless sync event in KOReader's input
        -- queue to wake its UI loop and run the scheduled report refresh now,
        -- instead of waiting for the normal long poll timeout.
        genEmuEvent(C.EV_SYN, C.SYN_REPORT, 0)
    end
end

local function debugMotionEvent(motion_event)
    if not input.debug_callback then return end

    local source = nativeNumber("AInputEvent_getSource", motion_event, 0)
    -- Touchscreen input belongs to the diagnostic UI itself, not the
    -- controller report, and must remain usable for Copy/Back/Close.
    if source == 0x00001002 then return end

    local axes = {}
    -- Android currently defines standard controller axes below 48. Reporting
    -- every active one lets us discover controllers that use an unexpected
    -- axis instead of only logging the mappings we already support.
    for axis = 0, 47 do
        local ok, value = pcall(android.lib.AMotionEvent_getAxisValue, motion_event, axis, 0)
        value = ok and tonumber(value) or 0
        if value and math.abs(value) > 0.001 then
            axes[#axes + 1] = { axis = axis, value = value }
        end
    end

    local device_id = nativeNumber("AInputEvent_getDeviceId", motion_event, -1)
    emitDebug{
        kind = "motion",
        action = nativeNumber("AMotionEvent_getAction", motion_event, -1),
        source = source,
        device_id = device_id,
        device_info = getDeviceInfo(device_id),
        axes = axes,
    }
end

local hat_x, hat_y = 0, 0
local trig_l, trig_r = false, false

local function handleHatAxes(motion_event)
    -- Only process gamepad/joystick-source events
    -- AINPUT_SOURCE_JOYSTICK = 0x01000010, AINPUT_SOURCE_GAMEPAD = 0x00000401
    local src = tonumber(android.lib.AInputEvent_getSource(motion_event)) or 0
    if bit.band(src, 0x01000010) == 0 and bit.band(src, 0x00000401) == 0 then return end
    local timev = genInputTimeval(android.lib.AMotionEvent_getEventTime(motion_event))
    -- Read both AXIS_X/Y (0/1, used by some controllers) and AXIS_HAT_X/Y (15/16, used by others e.g. SN30 Pro)
    local ax0 = tonumber(android.lib.AMotionEvent_getAxisValue(motion_event, 0, 0)) or 0
    local ay0 = tonumber(android.lib.AMotionEvent_getAxisValue(motion_event, 1, 0)) or 0
    local ax15 = tonumber(android.lib.AMotionEvent_getAxisValue(motion_event, 15, 0)) or 0
    local ay16 = tonumber(android.lib.AMotionEvent_getAxisValue(motion_event, 16, 0)) or 0
    local raw_x = math.abs(ax15) > math.abs(ax0) and ax15 or ax0
    local raw_y = math.abs(ay16) > math.abs(ay0) and ay16 or ay0
    local nx = raw_x
    local ny = raw_y
    if math.abs(nx) < 0.5 then nx = 0 elseif nx > 0 then nx = 1 else nx = -1 end
    if math.abs(ny) < 0.5 then ny = 0 elseif ny > 0 then ny = 1 else ny = -1 end
    local changed = false
    if nx ~= hat_x then
        if hat_x ~= 0 then genEmuEvent(C.EV_KEY, hat_x < 0 and 21 or 22, 0, timev) end
        if nx ~= 0 then
            local code = nx < 0 and 21 or 22
            genEmuEvent(C.EV_KEY, code, 1, timev)
            if input.capture_callback then
                local cb = input.capture_callback
                input.capture_callback = nil
                cb(code)
            end
        end
        hat_x = nx
        changed = true
    end
    if ny ~= hat_y then
        if hat_y ~= 0 then genEmuEvent(C.EV_KEY, hat_y < 0 and 19 or 20, 0, timev) end
        if ny ~= 0 then
            local code = ny < 0 and 19 or 20
            genEmuEvent(C.EV_KEY, code, 1, timev)
            if input.capture_callback then
                local cb = input.capture_callback
                input.capture_callback = nil
                cb(code)
            end
        end
        hat_y = ny
        changed = true
    end
    -- Analog triggers: L2 = ABS_Z → axis 11 or AXIS_LTRIGGER 17 or AXIS_BRAKE 23
    --                  R2 = ABS_RZ → axis 14 or AXIS_RTRIGGER 18 or AXIS_GAS 22
    -- Map to AKEYCODE_BUTTON_L2 (104) / AKEYCODE_BUTTON_R2 (105)
    local lv = math.max(
        tonumber(android.lib.AMotionEvent_getAxisValue(motion_event, 11, 0)) or 0,
        tonumber(android.lib.AMotionEvent_getAxisValue(motion_event, 17, 0)) or 0,
        tonumber(android.lib.AMotionEvent_getAxisValue(motion_event, 23, 0)) or 0)
    local rv = math.max(
        tonumber(android.lib.AMotionEvent_getAxisValue(motion_event, 14, 0)) or 0,
        tonumber(android.lib.AMotionEvent_getAxisValue(motion_event, 18, 0)) or 0,
        tonumber(android.lib.AMotionEvent_getAxisValue(motion_event, 22, 0)) or 0)
    local nl = lv > 0.1
    local nr = rv > 0.1
    if nl ~= trig_l then
        genEmuEvent(C.EV_KEY, 104, nl and 1 or 0, timev)
        if nl and input.capture_callback then
            local cb = input.capture_callback
            input.capture_callback = nil
            cb(104)
        end
        trig_l = nl
        changed = true
    end
    if nr ~= trig_r then
        genEmuEvent(C.EV_KEY, 105, nr and 1 or 0, timev)
        if nr and input.capture_callback then
            local cb = input.capture_callback
            input.capture_callback = nil
            cb(105)
        end
        trig_r = nr
        changed = true
    end
    if changed then
        genEmuEvent(C.EV_SYN, C.SYN_REPORT, 0, timev)
    end
end

-- Keep track of all the active pointers in the current gesture.
-- *hash*, key is a pointer *id* (i.e., its slot number),
-- value is a boolean, denoting whether the pointer is currently down (e.g., in contact) (true), up (false) or inactive (nil).
local pointers = {}
local function setPointerDown(slot, down)
    if pointers[slot] ~= down then
        pointers[slot] = down
    end
end

local function genTouchDownEvent(event, slot, index)
    local x = android.lib.AMotionEvent_getX(event, index)
    local y = android.lib.AMotionEvent_getY(event, index)
    local timev = genInputTimeval(android.lib.AMotionEvent_getEventTime(event))
    genEmuEvent(C.EV_ABS, C.ABS_MT_SLOT, slot, timev)
    genEmuEvent(C.EV_ABS, C.ABS_MT_TRACKING_ID, slot, timev)
    genEmuEvent(C.EV_ABS, C.ABS_MT_POSITION_X, x, timev)
    genEmuEvent(C.EV_ABS, C.ABS_MT_POSITION_Y, y, timev)
    genEmuEvent(C.EV_SYN, C.SYN_REPORT, 0, timev)
end

local function genTouchUpEvent(event, slot, index)
    local x = android.lib.AMotionEvent_getX(event, index)
    local y = android.lib.AMotionEvent_getY(event, index)
    local timev = genInputTimeval(android.lib.AMotionEvent_getEventTime(event))
    genEmuEvent(C.EV_ABS, C.ABS_MT_SLOT, slot, timev)
    genEmuEvent(C.EV_ABS, C.ABS_MT_TRACKING_ID, -1, timev)
    genEmuEvent(C.EV_ABS, C.ABS_MT_POSITION_X, x, timev)
    genEmuEvent(C.EV_ABS, C.ABS_MT_POSITION_Y, y, timev)
    genEmuEvent(C.EV_SYN, C.SYN_REPORT, 0, timev)
end

local function genTouchMoveEvent(event, timev, slot, index)
    -- NOTE: May return a float for events w/ subpixel precision.
    local x = android.lib.AMotionEvent_getX(event, index)
    local y = android.lib.AMotionEvent_getY(event, index)
    genEmuEvent(C.EV_ABS, C.ABS_MT_SLOT, slot, timev)
    genEmuEvent(C.EV_ABS, C.ABS_MT_POSITION_X, x, timev)
    genEmuEvent(C.EV_ABS, C.ABS_MT_POSITION_Y, y, timev)
end

local function genEndTouchEvent(event, timev)
    genEmuEvent(C.EV_SYN, C.SYN_REPORT, 0, timev)
end

local function genAndroidCancelEvent(event)
    local timev = genInputTimeval(android.lib.AMotionEvent_getEventTime(event))
    -- We piggyback on this EV_MSC code, because our EV_MSC handler already handles it via Device.input:resetState(),
    -- which is *exactly* what we want to happen ;).
    genEmuEvent(C.EV_MSC, C.APP_CMD_LOST_FOCUS, 42, timev)
end

-- NOTE: As far as AMotionEvent_getPointerId is concerned, keep in mind that while the id (e.g., slot) that it returns
--       is constant across a pointer's lifetime (i.e., a single gesture), its index *can* and *will* vary across events!
--       (As it's literally an index to the native MotionEvent array where the data is stored).
-- NOTE: The documentation is not always super clear on the fact that the data is always at index 0 for
--       AMOTION_EVENT_ACTION_DOWN & AMOTION_EVENT_ACTION_UP, so, use the source, Luke! c.f., TouchInputMapper::dispatchMotion @
-- https://android.googlesource.com/platform//frameworks/native/+/master/services/inputflinger/reader/mapper/TouchInputMapper.cpp
local function motionEventHandler(motion_event)
    local source = nativeNumber("AInputEvent_getSource", motion_event, 0)
    debugMotionEvent(motion_event)
    -- Controller motion is recorded above and kept out of KOReader's normal
    -- UI. Touchscreen motion still has to reach the diagnostic controls.
    if input.debug_callback and source ~= 0x00001002 then return end
    pcall(handleHatAxes, motion_event)
    if android.isTouchscreenIgnored() then
        return
    end

    local action = android.lib.AMotionEvent_getAction(motion_event)
    local flags = bit.band(action, C.AMOTION_EVENT_ACTION_MASK)
    if flags == C.AMOTION_EVENT_ACTION_DOWN then
        -- Happens on the *first* contact of a gesture (data is always at index 0),
        local slot = android.lib.AMotionEvent_getPointerId(motion_event, 0)
        setPointerDown(slot, true)
        genTouchDownEvent(motion_event, slot, 0)
    elseif flags == C.AMOTION_EVENT_ACTION_POINTER_DOWN then
        local pointer_index = bit.rshift(
                                        bit.band(action, C.AMOTION_EVENT_ACTION_POINTER_INDEX_MASK),
                                        C.AMOTION_EVENT_ACTION_POINTER_INDEX_SHIFT)
        local slot = android.lib.AMotionEvent_getPointerId(motion_event, pointer_index)
        setPointerDown(slot, true)
        genTouchDownEvent(motion_event, slot, pointer_index)
    elseif flags == C.AMOTION_EVENT_ACTION_UP then
        -- Happens once the *last* contact of a gesture has been lifted (data is always at index 0)
        local slot = android.lib.AMotionEvent_getPointerId(motion_event, 0)
        setPointerDown(slot, false)
        genTouchUpEvent(motion_event, slot, 0)
    elseif flags == C.AMOTION_EVENT_ACTION_POINTER_UP then
        local pointer_index = bit.rshift(
                                        bit.band(action, C.AMOTION_EVENT_ACTION_POINTER_INDEX_MASK),
                                        C.AMOTION_EVENT_ACTION_POINTER_INDEX_SHIFT)
        local slot = android.lib.AMotionEvent_getPointerId(motion_event, pointer_index)
        setPointerDown(slot, false)
        genTouchUpEvent(motion_event, slot, pointer_index)
    elseif flags == C.AMOTION_EVENT_ACTION_MOVE then
        -- There may be multiple pointers involved, only request the ts once
        local timev = genInputTimeval(android.lib.AMotionEvent_getEventTime(motion_event))

        -- This effectively gives us the size of the current MotionEvent array...
        local pointer_count = tonumber(android.lib.AMotionEvent_getPointerCount(motion_event))
        for i = 0, pointer_count - 1 do
            -- So, loop through the array, and if that pointer is still down, move it
            local slot = android.lib.AMotionEvent_getPointerId(motion_event, i)
            if pointers[slot] then
                genTouchMoveEvent(motion_event, timev, slot, i)
            end
        end

        -- Bundle everything in a single input frame
        genEndTouchEvent(motion_event, timev)
    elseif flags == C.AMOTION_EVENT_ACTION_CANCEL then
        -- Invalidate the pointers, and push a custom event to notify front to do the same.
        -- NOTE: We preserve the actual table object to avoid garbage churn,
        --       as we're liable to see a similar amount of slots show up again later.
        for slot, _ in pairs(pointers) do
            pointers[slot] = nil
        end
        genAndroidCancelEvent(motion_event)
    end
end

local function keyEventHandler(key_event)
    local code = android.lib.AKeyEvent_getKeyCode(key_event)
    local action = android.lib.AKeyEvent_getAction(key_event)
    if input.debug_callback then
        local device_id = nativeNumber("AInputEvent_getDeviceId", key_event, -1)
        emitDebug{
            kind = "key",
            action = tonumber(action),
            keycode = tonumber(code),
            scancode = nativeNumber("AKeyEvent_getScanCode", key_event, -1),
            source = nativeNumber("AInputEvent_getSource", key_event, 0),
            device_id = device_id,
            device_info = getDeviceInfo(device_id),
            repeat_count = nativeNumber("AKeyEvent_getRepeatCount", key_event, 0),
        }
        -- Keep diagnostic key presses out of KOReader's normal event queue.
        -- They are still marked handled for Android by the caller.
        return 1
    end
    if input.capture_callback and action == C.AKEY_EVENT_ACTION_DOWN then
        local cb = input.capture_callback
        input.capture_callback = nil
        cb(tonumber(code))
        return 1
    end
    if code == C.AKEYCODE_VOLUME_UP
    or code == C.AKEYCODE_VOLUME_DOWN then
        if android.getVolumeKeysIgnored() then
            return 0 -- event not consumed
        end
    elseif code == C.AKEYCODE_MUTE
    or code == C.AKEYCODE_VOLUME_MUTE then
        if android.getVolumeKeysIgnored() then
            return 0
        else
            return 1
        end
    end
    if code == C.AKEYCODE_BACK and android.isBackButtonIgnored() then
        return 1
    end
    if action == C.AKEY_EVENT_ACTION_DOWN then
        genEmuEvent(C.EV_KEY, code, 1, nil, android.lib.AKeyEvent_getEventTime(key_event))
    elseif action == C.AKEY_EVENT_ACTION_UP then
        genEmuEvent(C.EV_KEY, code, 0, nil, android.lib.AKeyEvent_getEventTime(key_event))
    end
    return 1 -- event consumed
end

local function commandHandler(code, value)
    genEmuEvent(C.EV_MSC, code, value)
end

function input.waitForEvent(sec, usec)
    -- TimeVal's :tomsecs if we were passed one to begin with, otherwise, -1 => block
    local timeout = sec and math.floor(sec * 1000000 + usec + 0.5) / 1000 or -1

    -- Reset the queue
    inputQueue = {}

    -- Will point to the the raw fd number
    local fd     = ffi.new("int[1]")
    -- Will point to the poll events
    local events = ffi.new("int[1]")
    -- Will point to the data passed at addFd/attachLooper time, c.f., the android_poll_source struct definition.
    -- NOTE: Its id field is mostly redundant, as ALooper already returns the ident.
    --       And its process function can be used as a weird delayed callback mechanism, but ALooper already has native callback handling :?.
    --       TL;DR: We don't actually use it here.
    local source = ffi.new("struct android_poll_source*[1]")
    -- NOTE: Much like the C backend, we only process a *single* fd per waitForEvent iteration.
    --       Although, in the Android case, things are a bit more complex, because this is a wrapper around epoll:
    --       the backend actually accumulates every poll event in a single (inner) iteration, and enqueues those in a list.
    --       That list is what the public function processes, and it processes it item by item, returning one item per call.
    --       c.f., https://android.googlesource.com/platform/system/core/+/refs/heads/master/libutils/Looper.cpp
    -- NOTE: We don't use callbacks, so pollOnce is good enough for us, no need to resort to pollAll :).
    local poll_state = android.lib.ALooper_pollOnce(timeout, fd, events, ffi.cast("void**", source))
    if poll_state >= 0 then
        -- NOTE: Since we actually want to process this in Lua-land (i.e., here), and not in C-land,
        --       we do *NOT* make use of the weird delayed callback mechanism afforded by the android_poll_source struct
        --       we pass as the data pointer to ALooper in the glue code when registering a polling source.
        --       Instead, we do everything here, which is why this may look eerily like the C functions
        --       process_cmd & process_input in the glue code.
        --       Sidebar: if you *actually* need to process stuff in C-land ASAP, use ALooper's native callback system.
        if poll_state == C.LOOPER_ID_MAIN then
            -- e.g., source[0].process(android.app, source[0]) where process would point to process_cmd
            local cmd = android.glue.android_app_read_cmd(android.app)
            while cmd ~= -1 do
                android.glue.android_app_pre_exec_cmd(android.app, cmd)
                commandHandler(cmd, 1)
                android.glue.android_app_post_exec_cmd(android.app, cmd)

                -- Should return -1 (EAGAIN) when we've drained the pipe
                cmd = android.glue.android_app_read_cmd(android.app)
            end
        elseif poll_state == C.LOOPER_ID_INPUT then
            -- e.g., source[0].process(android.app, source[0]) where process would point to process_input
            local event = ffi.new("AInputEvent*[1]")
            while android.lib.AInputQueue_getEvent(android.app.inputQueue, event) >= 0 do
                if android.lib.AInputQueue_preDispatchEvent(android.app.inputQueue, event[0]) == 0 then
                    local event_type = android.lib.AInputEvent_getType(event[0])
                    local handled = 1
                    if event_type == C.AINPUT_EVENT_TYPE_MOTION then
                        motionEventHandler(event[0])
                    elseif event_type == C.AINPUT_EVENT_TYPE_KEY then
                        handled = keyEventHandler(event[0])
                    end
                    android.lib.AInputQueue_finishEvent(android.app.inputQueue, event[0], handled)
                end
            end
        elseif poll_state == C.LOOPER_ID_USER then
            local message = ffi.new("unsigned char [4]")
            -- Similarly, read will return -1 (EAGAIN) when we've drained the pipe
            while C.read(fd[0], message, 4) == 4 do
                if message[0] == C.AEVENT_POWER_CONNECTED then
                    commandHandler(C.AEVENT_POWER_CONNECTED, 0)
                elseif message[0] == C.AEVENT_POWER_DISCONNECTED then
                    commandHandler(C.AEVENT_POWER_DISCONNECTED, 0)
                elseif message[0] == C.AEVENT_DOWNLOAD_COMPLETE then
                    commandHandler(C.AEVENT_DOWNLOAD_COMPLETE, 0)
                end
            end
        end
        if android.app.destroyRequested ~= 0 then
            android.LOGI("Engine thread destroy requested!")
            -- Do nothing, if this is set, we've already pushed an APP_CMD_DESTROY event that'll get handled in front.
        end
    elseif poll_state == C.ALOOPER_POLL_TIMEOUT then
        return false, C.ETIME
    elseif poll_state == C.ALOOPER_POLL_ERROR then
        android.LOGE("Encountered a polling error!")
        return
    end
    -- NOTE: We never set callbacks, and we never call wake, so no need to check for ALOOPER_POLL_CALLBACK & ALOOPER_POLL_WAKE

    if #inputQueue > 0 then
        -- We generated some actionable events
        return true, inputQueue
    else
        -- poll returned early, but without an event we actually use.
        -- Back to Input:waitEvent to recompute the timeout
        return false, C.EINTR
    end
end

return input
