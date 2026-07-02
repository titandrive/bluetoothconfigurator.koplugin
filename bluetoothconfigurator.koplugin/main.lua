local InputContainer = require("ui/widget/container/inputcontainer")
local UIManager = require("ui/uimanager")
local Device = require("device")

local PLUGIN_VERSION = "1.3.2"
local GITHUB_REPO    = "titandrive/bluetoothconfigurator.koplugin"


local BluetoothTurner = InputContainer:extend{
    name = "bluetoothconfigurator",
    is_doc_only = true,
}

local Dispatcher
local function getDispatcher()
    if not Dispatcher then
        Dispatcher = require("dispatcher")
    end
    return Dispatcher
end

local LEGACY_DISPATCHER_ACTIONS = {
    next_page               = { page_jmp = 1 },
    prev_page               = { page_jmp = -1 },
    next_chapter            = { next_chapter = true },
    prev_chapter            = { prev_chapter = true },
    first_page              = { first_page = true },
    last_page               = { last_page = true },
    go_to                   = { go_to = true },
    skim                    = { skim = true },
    random_page             = { random_page = true },
    back                    = { back = true },
    prev_location           = { previous_location = true },
    next_location           = { next_location = true },
    add_location            = { add_location_to_history = true },
    clear_location_history  = { clear_location_history = true },
    pin_page                = { pin_current_page = true },
    go_to_pinned            = { go_to_pinned_page = true },
    toggle_bookmark         = { toggle_bookmark = true },
    bookmarks               = { bookmarks = true },
    bookmark_browser        = { bookmark_browser = true },
    bookmark_search         = { bookmark_search = true },
    prev_bookmark           = { prev_bookmark = true },
    next_bookmark           = { next_bookmark = true },
    first_bookmark          = { first_bookmark = true },
    last_bookmark           = { last_bookmark = true },
    latest_bookmark         = { latest_bookmark = true },
    night_mode              = { night_mode = true },
    font_increase           = { increase_font = 1 },
    font_decrease           = { decrease_font = 1 },
    frontlight              = { show_frontlight_dialog = true },
    toggle_frontlight       = { toggle_frontlight = true },
    increase_frontlight     = { increase_frontlight = 1 },
    decrease_frontlight     = { decrease_frontlight = 1 },
    toggle_status_bar       = { toggle_status_bar = true },
    toggle_chapter_progress = { toggle_chapter_progress_bar = true },
    full_refresh            = { full_refresh = true },
    toc                     = { toc = true },
    book_map                = { book_map = true },
    page_browser            = { page_browser = true },
    show_menu               = { show_menu = true },
    menu_search             = { menu_search = true },
    show_config_menu        = { show_config_menu = true },
    fulltext_search         = { fulltext_search = true },
    fulltext_search_results = { fulltext_search_findall_results = true },
    book_status             = { book_status = true },
    book_info               = { book_info = true },
    book_description        = { book_description = true },
    book_cover              = { book_cover = true },
    translate_page          = { translate_page = true },
    toggle_style_tweaks     = { toggle_style_tweaks = true },
    cycle_highlight_action  = { cycle_highlight_action = true },
    cycle_highlight_style   = { cycle_highlight_style = true },
    toggle_page_turn_dir    = { toggle_inverse_reading_order = true },
    flush_settings          = { flush_settings = true },
    export_annotations      = { export_annotations = true },
    screenshot              = { screenshot = true },
    filemanager             = { filemanager = true },
    history                 = { history = true },
    history_search          = { history_search = true },
    favorites               = { favorites = true },
    collections             = { collections = true },
    collections_search      = { collections_search = true },
    open_previous           = { open_previous_document = true },
    open_next_in_folder     = { open_next_document_in_folder = true },
    open_prev_in_folder     = { open_previous_document_in_folder = true },
    notebook_file           = { notebook_file = true },
    dictionary_lookup       = { dictionary_lookup = true },
    wikipedia_lookup        = { wikipedia_lookup = true },
    wifi_toggle             = { toggle_wifi = true },
    toggle_rotation         = { toggle_rotation = true },
    invert_rotation         = { invert_rotation = true },
    rotate_cw               = { iterate_rotation = true },
    rotate_ccw              = { iterate_rotation_ccw = true },
    suspend                 = { suspend = true },
    none                    = {},
}

local function copyTable(t)
    local copy = {}
    for k, v in pairs(t or {}) do
        copy[k] = type(v) == "table" and copyTable(v) or v
    end
    return copy
end

local function legacyActionToDispatcher(action_id)
    return copyTable(LEGACY_DISPATCHER_ACTIONS[action_id] or {})
end

local function normalizeBinding(binding)
    local changed = false
    if not binding.actions then
        binding.actions = legacyActionToDispatcher(binding.action)
        changed = true
    end
    if binding.action ~= nil then
        binding.action = nil
        changed = true
    end
    return changed
end

local function executeBinding(binding)
    if binding.actions then
        local dispatcher = getDispatcher()
        dispatcher:init()
        dispatcher:execute(binding.actions)
    end
end

local function actionLabel(binding)
    if binding.actions then
        local dispatcher = getDispatcher()
        dispatcher:init()
        return dispatcher:menuTextFunc(binding.actions)
    end
    return "Nothing"
end

local DEFAULT_BINDINGS = {
    { keycode = 85, actions = { page_jmp = 1 } },
    { keycode = 87, actions = { page_jmp = -1 } },
    { keycode = 88, actions = { night_mode = true } },
}

local SLOT = "BTurner_"

local function loadBindings()
    local saved = G_reader_settings:readSetting("bt_configurator_bindings")
    if saved then
        -- One-time cleanup: remove D-pad rows that were auto-added in a previous version
        if not G_reader_settings:readSetting("bt_configurator_dpad_cleaned") then
            local cleaned = {}
            for _, b in ipairs(saved) do
                if not (b.keycode and b.keycode >= 19 and b.keycode <= 22) then
                    cleaned[#cleaned + 1] = b
                end
            end
            G_reader_settings:saveSetting("bt_configurator_dpad_cleaned", true)
            for _, b in ipairs(cleaned) do
                normalizeBinding(b)
            end
            G_reader_settings:saveSetting("bt_configurator_bindings", cleaned)
            return cleaned
        end
        local changed = false
        for _, b in ipairs(saved) do
            changed = normalizeBinding(b) or changed
        end
        if changed then
            G_reader_settings:saveSetting("bt_configurator_bindings", saved)
        end
        return saved
    end
    local copy = {}
    for _, b in ipairs(DEFAULT_BINDINGS) do
        copy[#copy + 1] = { keycode = b.keycode, actions = copyTable(b.actions) }
    end
    return copy
end

local function saveBindings(bindings)
    G_reader_settings:saveSetting("bt_configurator_bindings", bindings)
end

local function applyBindings(plugin)
    local to_clear = {}
    for code, name in pairs(Device.input.event_map) do
        if type(name) == "string" and name:sub(1, #SLOT) == SLOT then
            to_clear[#to_clear + 1] = code
        end
    end
    for _, code in ipairs(to_clear) do
        Device.input.event_map[code] = nil
    end
    plugin.key_events = {}
    for i, binding in ipairs(plugin._bindings) do
        if binding.keycode then
            local name = SLOT .. i
            Device.input.event_map[binding.keycode] = name
            plugin.key_events[name] = { { name } }
        end
    end
end

for i = 1, 16 do
    local slot = i
    BluetoothTurner["on" .. SLOT .. slot] = function(self)
        local binding = self._bindings[slot]
        if binding then executeBinding(binding) end
        return true
    end
end

local KEY_NAMES = {
    [19]  = "D-Pad Up",   [20]  = "D-Pad Down", [21] = "D-Pad Left",
    [22]  = "D-Pad Right",[23]  = "D-Pad Center",
    [85]  = "Play/Pause", [86]  = "Pause",       [87] = "Next Track",
    [88]  = "Prev Track", [89]  = "Rewind",       [90] = "Fast Fwd",
    [91]  = "Mute",       [92]  = "Page Up",      [93] = "Page Down",
    [96]  = "Button A",   [97]  = "Button B",     [99] = "Button X",
    [100] = "Button Y",   [102] = "L1",           [103] = "R1",
    [104] = "L2",           [105] = "R2",
}

local function keycodeLabel(code)
    if not code then return "Tap to set..." end
    local name = KEY_NAMES[code]
    return name and (name .. " (" .. code .. ")") or ("Key " .. code)
end

function BluetoothTurner:init()
    pcall(function()
        if Device:isAndroid() then
            local patched = dofile(self.path .. "/input_android_patched.lua")
            Device.input.input = patched
        end
    end)
    self._bindings = loadBindings()
    applyBindings(self)
    self.ui.menu:registerToMainMenu(self)
end

function BluetoothTurner:onReaderReady()
    applyBindings(self)
    self:backgroundUpdateCheck()
end

function BluetoothTurner:onResume()
    self:backgroundUpdateCheck()
end

local _update_last_check = nil
local _update_in_flight  = false
local UPDATE_INTERVAL    = 3600

function BluetoothTurner:backgroundUpdateCheck()
    if G_reader_settings:isFalse("bt_configurator_auto_update") then return end
    if _update_in_flight then return end
    local now = os.time()
    if _update_last_check and (now - _update_last_check) < UPDATE_INTERVAL then return end

    local ok_nm, NetworkMgr = pcall(require, "ui/network/manager")
    if not ok_nm or not NetworkMgr:isWifiOn() then return end

    _update_in_flight  = true
    _update_last_check = now

    UIManager:scheduleIn(0.1, function()
        local ver = nil
        pcall(function()
            local ok_req, http, ltn12, socket, socketutil = pcall(function()
                return require("socket/http"),
                       require("ltn12"),
                       require("socket"),
                       require("socketutil")
            end)
            if not ok_req then return end
            local body = {}
            local ok_fetch, code = pcall(function()
                socketutil:set_timeout(socketutil.LARGE_BLOCK_TIMEOUT, socketutil.LARGE_TOTAL_TIMEOUT)
                local c = socket.skip(1, http.request({
                    url      = "https://api.github.com/repos/" .. GITHUB_REPO .. "/releases/latest",
                    method   = "GET",
                    headers  = {
                        ["User-Agent"] = "KOReader-BluetoothConfigurator/" .. PLUGIN_VERSION,
                        ["Accept"]     = "application/vnd.github.v3+json",
                    },
                    sink     = ltn12.sink.table(body),
                    redirect = true,
                }))
                socketutil:reset_timeout()
                return c
            end)
            if not ok_fetch then pcall(function() socketutil:reset_timeout() end) return end
            if code ~= 200 then return end
            local ok_json, json = pcall(require, "json")
            if not ok_json then return end
            local ok_parse, data = pcall(json.decode, table.concat(body))
            if not ok_parse or not data or not data.tag_name then return end
            ver = data.tag_name:match("^v?(.+)$") or data.tag_name
        end)
        _update_in_flight = false
        if ver and self:isNewerVersion(ver, PLUGIN_VERSION) then
            local Notification = require("ui/widget/notification")
            Notification:notify("Bluetooth Configurator: v" .. ver .. " available",
                Notification.SOURCE_ALWAYS_SHOW)
        end
    end)
end

function BluetoothTurner:addToMainMenu(menu_items)
    menu_items.bluetooth_configurator = {
        sorting_hint = "tools",
        text = "Bluetooth Configurator",
        callback = function() self:showSettings() end,
    }
end

function BluetoothTurner:showInfoPanel()
    local TitleBar = require("ui/widget/titlebar")
    local ButtonTable = require("ui/widget/buttontable")
    local CenterContainer = require("ui/widget/container/centercontainer")
    local FrameContainer = require("ui/widget/container/framecontainer")
    local MovableContainer = require("ui/widget/container/movablecontainer")
    local VerticalGroup = require("ui/widget/verticalgroup")
    local InputContainer = require("ui/widget/container/inputcontainer")
    local GestureRange = require("ui/gesturerange")
    local Blitbuffer = require("ffi/blitbuffer")
    local Size = require("ui/size")
    local Geom = require("ui/geometry")

    local screen_w = Device.screen:getWidth()
    local screen_h = Device.screen:getHeight()
    local sw = screen_w - 2 * Size.border.window
    local sh = screen_h - 2 * Size.border.window

    local panel

    local title_bar = TitleBar:new{
        width = sw - 2 * Size.padding.button,
        align = "center",
        with_bottom_line = true,
        title = "Bluetooth Configurator",
    }

    local button_table = ButtonTable:new{
        width = sw - 2 * Size.padding.button,
        buttons = {
            {{ text = "Version: " .. PLUGIN_VERSION, callback = function() end }},
            {{ text = "Check for Updates", callback = function() self:checkForUpdates() end }},
            {{ text = "Auto-update: " .. (G_reader_settings:isFalse("bt_configurator_auto_update") and "Off" or "On"),
               callback = function()
                if G_reader_settings:isFalse("bt_configurator_auto_update") then
                    G_reader_settings:delSetting("bt_configurator_auto_update")
                else
                    G_reader_settings:saveSetting("bt_configurator_auto_update", false)
                end
                UIManager:close(panel)
                self:showInfoPanel()
            end }},
            {{ text = "Changelog",         callback = function() self:showChangelog() end }},
            {{ text = "GitHub Page",       callback = function()
                local url = "https://github.com/" .. GITHUB_REPO
                if Device:canOpenLink() then
                    Device:openLink(url)
                else
                    local InfoMessage = require("ui/widget/infomessage")
                    UIManager:show(InfoMessage:new{ text = url })
                end
            end }},
            {{ text = "Back",              callback = function() UIManager:close(panel); self:showSettings() end }},
        },
        zero_sep = false,
    }

    local frame = FrameContainer:new{
        radius = Size.radius.window,
        padding = 0,
        padding_top = 0,
        padding_bottom = 0,
        margin = 0,
        bordersize = Size.border.window,
        background = Blitbuffer.COLOR_WHITE,
        VerticalGroup:new{
            align = "left",
            title_bar,
            button_table,
        },
    }

    local movable = MovableContainer:new{ frame }

    panel = InputContainer:new{
        ges_events = {
            TapClose = {
                GestureRange:new{
                    ges = "tap",
                    range = Geom:new{ x = 0, y = 0, w = screen_w, h = sh },
                }
            }
        },
        CenterContainer:new{
            dimen = Geom:new{ x = 0, y = 0, w = screen_w, h = sh },
            movable,
        }
    }

    function panel:onTapClose(_, ges)
        if ges.pos:notIntersectWith(movable.dimen) then
            UIManager:close(self)
        end
        return true
    end

    UIManager:show(panel)
end

function BluetoothTurner:isNewerVersion(latest, current)
    local function parse(v)
        local a, b, c = v:match("^(%d+)%.(%d+)%.(%d+)")
        return tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0
    end
    local la, lb, lc = parse(latest)
    local ca, cb, cc = parse(current)
    if la ~= ca then return la > ca end
    if lb ~= cb then return lb > cb end
    return lc > cc
end

function BluetoothTurner:showChangelog()
    local InfoMessage = require("ui/widget/infomessage")
    local TitleBar = require("ui/widget/titlebar")
    local ButtonTable = require("ui/widget/buttontable")
    local CenterContainer = require("ui/widget/container/centercontainer")
    local FrameContainer = require("ui/widget/container/framecontainer")
    local MovableContainer = require("ui/widget/container/movablecontainer")
    local ScrollableContainer = require("ui/widget/container/scrollablecontainer")
    local VerticalGroup = require("ui/widget/verticalgroup")
    local InputContainer = require("ui/widget/container/inputcontainer")
    local GestureRange = require("ui/gesturerange")
    local Blitbuffer = require("ffi/blitbuffer")
    local Size = require("ui/size")
    local Geom = require("ui/geometry")

    local fetching = InfoMessage:new{ text = "Fetching changelog..." }
    UIManager:show(fetching)
    UIManager:forceRePaint()

    local ok_https, https = pcall(require, "ssl.https")
    if not ok_https then
        UIManager:close(fetching)
        UIManager:show(InfoMessage:new{ text = "Changelog requires network support." })
        return
    end
    local ltn12 = require("ltn12")

    local sink = {}
    local _, status = https.request{
        url = "https://api.github.com/repos/" .. GITHUB_REPO .. "/releases",
        method = "GET",
        headers = {
            ["User-Agent"] = "KOReader-BluetoothConfigurator/" .. PLUGIN_VERSION,
            ["Accept"] = "application/vnd.github+json",
        },
        sink = ltn12.sink.table(sink),
    }
    UIManager:close(fetching)

    if status ~= 200 then
        UIManager:show(InfoMessage:new{ text = "Could not fetch changelog. (HTTP " .. tostring(status) .. ")" })
        return
    end

    local ok_json, json = pcall(require, "json")
    if not ok_json then
        UIManager:show(InfoMessage:new{ text = "Could not parse changelog response." })
        return
    end
    local ok_parse, data = pcall(json.decode, table.concat(sink))
    if not ok_parse or not data or not data[1] then
        UIManager:show(InfoMessage:new{ text = "Could not parse changelog response." })
        return
    end

    local screen_w = Device.screen:getWidth()
    local screen_h = Device.screen:getHeight()
    local sw = screen_w - 2 * Size.border.window
    local sh = screen_h - 2 * Size.border.window

    local dialog

    local function showReleaseNotes(release)
        local Menu = require("ui/widget/menu")
        local body = (release.body or "No release notes available."):gsub("\r\n", "\n"):gsub("\r", "\n")

        local items = {}
        for line in (body .. "\n"):gmatch("([^\n]*)\n") do
            table.insert(items, { text = line ~= "" and line or " ", callback = function() end })
        end

        local notes_menu = Menu:new{
            title = (release.tag_name or "Release") .. " Release Notes",
            item_table = items,
            width = screen_w,
            height = screen_h,
            is_popout = false,
            is_borderless = true,
            covers_fullscreen = true,
        }
        notes_menu.onMenuSelect = function() end
        UIManager:show(notes_menu)
    end

    local buttons = {}
    for i, release in ipairs(data) do
        if i > 5 then break end
        local tag = release.tag_name or "Unknown"
        local ver = tag:match("^v?(.+)$") or tag
        local tags = {}
        if i == 1 then table.insert(tags, "Latest") end
        if ver == PLUGIN_VERSION then table.insert(tags, "Installed") end
        local label = tag .. (#tags > 0 and "  (" .. table.concat(tags, " \xC2\xB7 ") .. ")" or "")
        local rel = release
        table.insert(buttons, {{ text = label, align = "left", callback = function()
            UIManager:close(dialog)
            showReleaseNotes(rel)
        end }})
    end
    table.insert(buttons, {{ text = "Close", callback = function() UIManager:close(dialog) end }})

    local title_bar = TitleBar:new{
        width = sw - 2 * Size.padding.button,
        align = "center",
        with_bottom_line = true,
        title = "Changelog",
        subtitle = "Installed: v" .. PLUGIN_VERSION,
    }

    local button_table = ButtonTable:new{
        width = sw - 2 * Size.padding.button,
        buttons = buttons,
        zero_sep = false,
    }

    local title_h = title_bar:getSize().h
    local btn_h = button_table:getSize().h
    local content
    if btn_h > sh - title_h then
        content = ScrollableContainer:new{
            dimen = Geom:new{ w = sw - 2 * Size.padding.button, h = sh - title_h },
            button_table,
        }
    else
        content = button_table
    end

    local frame = FrameContainer:new{
        radius = Size.radius.window,
        padding = 0,
        padding_top = 0,
        padding_bottom = 0,
        margin = 0,
        bordersize = Size.border.window,
        background = Blitbuffer.COLOR_WHITE,
        VerticalGroup:new{
            align = "left",
            title_bar,
            content,
        },
    }

    local movable = MovableContainer:new{ frame }

    dialog = InputContainer:new{
        ges_events = {
            TapClose = {
                GestureRange:new{
                    ges = "tap",
                    range = Geom:new{ x = 0, y = 0, w = screen_w, h = sh },
                }
            }
        },
        CenterContainer:new{
            dimen = Geom:new{ x = 0, y = 0, w = screen_w, h = sh },
            movable,
        }
    }

    function dialog:onTapClose(_, ges)
        if ges.pos:notIntersectWith(movable.dimen) then
            UIManager:close(self)
        end
        return true
    end

    UIManager:show(dialog)
end

function BluetoothTurner:checkForUpdates()
    local InfoMessage = require("ui/widget/infomessage")
    local ConfirmBox = require("ui/widget/confirmbox")

    local checking = InfoMessage:new{ text = "Checking for updates..." }
    UIManager:show(checking)
    UIManager:forceRePaint()

    local ok_https, https = pcall(require, "ssl.https")
    if not ok_https then
        UIManager:close(checking)
        UIManager:show(InfoMessage:new{ text = "Update check requires network support." })
        return
    end
    local ltn12 = require("ltn12")

    local sink = {}
    local _, status = https.request{
        url = "https://api.github.com/repos/" .. GITHUB_REPO .. "/releases",
        method = "GET",
        headers = {
            ["User-Agent"] = "KOReader-BluetoothConfigurator/" .. PLUGIN_VERSION,
            ["Accept"] = "application/vnd.github+json",
        },
        sink = ltn12.sink.table(sink),
    }
    UIManager:close(checking)

    if status ~= 200 then
        UIManager:show(InfoMessage:new{ text = "Could not reach update server. (HTTP " .. tostring(status) .. ")" })
        return
    end

    local ok_json, json = pcall(require, "json")
    if not ok_json then
        UIManager:show(InfoMessage:new{ text = "Could not parse update response." })
        return
    end
    local ok_parse, data = pcall(json.decode, table.concat(sink))
    if not ok_parse or not data or not data[1] or not data[1].tag_name then
        UIManager:show(InfoMessage:new{ text = "Could not parse update response." })
        return
    end

    local latest_tag = data[1].tag_name
    local latest_ver = latest_tag:match("^v?(.+)$") or latest_tag

    if not self:isNewerVersion(latest_ver, PLUGIN_VERSION) then
        UIManager:show(InfoMessage:new{
            text = "You are up to date (v" .. PLUGIN_VERSION .. ").",
            timeout = 3,
        })
        return
    end

    local confirm
    confirm = ConfirmBox:new{
        text = "Version " .. latest_ver .. " is available (you have v" .. PLUGIN_VERSION .. "). Install now?",
        ok_text = "Install",
        cancel_text = "Not Now",
        ok_callback = function()
            UIManager:close(confirm)
            self:installUpdate(latest_tag)
        end,
    }
    UIManager:show(confirm)
end

function BluetoothTurner:installUpdate(tag)
    local InfoMessage = require("ui/widget/infomessage")

    local msg = InfoMessage:new{ text = "Downloading update..." }
    UIManager:show(msg)
    UIManager:forceRePaint()

    local ok_https, https = pcall(require, "ssl.https")
    if not ok_https then
        UIManager:close(msg)
        UIManager:show(InfoMessage:new{ text = "Update failed: network support unavailable." })
        return
    end
    local ok_ltn12, ltn12 = pcall(require, "ltn12")
    if not ok_ltn12 then
        UIManager:close(msg)
        UIManager:show(InfoMessage:new{ text = "Update failed: ltn12 unavailable." })
        return
    end

    local base = "https://raw.githubusercontent.com/" .. GITHUB_REPO .. "/" .. tag .. "/bluetoothconfigurator.koplugin/"
    local files = { "_meta.lua", "main.lua", "input_android_patched.lua" }

    for _, fname in ipairs(files) do
        local f = io.open(self.path .. "/" .. fname, "wb")
        if not f then
            UIManager:close(msg)
            UIManager:show(InfoMessage:new{ text = "Update failed: could not write " .. fname })
            return
        end
        local ok_req, fstatus = pcall(function()
            local _, s = https.request{
                url = base .. fname,
                method = "GET",
                headers = { ["User-Agent"] = "KOReader-BluetoothConfigurator/" .. PLUGIN_VERSION },
                sink = ltn12.sink.file(f),
            }
            return s
        end)
        if not ok_req then pcall(function() f:close() end) end
        if not ok_req or fstatus ~= 200 then
            UIManager:close(msg)
            UIManager:show(InfoMessage:new{ text = "Update failed: could not download " .. fname })
            return
        end
    end

    UIManager:close(msg)
    local InfoMessage = require("ui/widget/infomessage")
    UIManager:show(InfoMessage:new{
        text = "Update installed. Please restart KOReader to apply.",
    })
end

function BluetoothTurner:showSettings()
    local TitleBar = require("ui/widget/titlebar")
    local ButtonTable = require("ui/widget/buttontable")
    local CenterContainer = require("ui/widget/container/centercontainer")
    local FrameContainer = require("ui/widget/container/framecontainer")
    local MovableContainer = require("ui/widget/container/movablecontainer")
    local ScrollableContainer = require("ui/widget/container/scrollablecontainer")
    local VerticalGroup = require("ui/widget/verticalgroup")
    local InputContainer = require("ui/widget/container/inputcontainer")
    local GestureRange = require("ui/gesturerange")
    local Blitbuffer = require("ffi/blitbuffer")
    local Size = require("ui/size")
    local Geom = require("ui/geometry")
    local InfoMessage = require("ui/widget/infomessage")
    local Menu = require("ui/widget/menu")

    local screen_w = Device.screen:getWidth()
    local screen_h = Device.screen:getHeight()
    local sw = screen_w - 2 * Size.border.window
    local sh = screen_h - 2 * Size.border.window
    local sep_w = Size.line.medium
    local btn_w = sw - 2 * Size.padding.button
    local col_key = math.floor((btn_w - 2 * sep_w) * 0.44)
    local col_act = math.floor((btn_w - 2 * sep_w) * 0.44)
    local col_del = btn_w - 2 * sep_w - col_key - col_act

    local dialog

    local function refresh()
        UIManager:close(dialog)
        self:showSettings()
    end

    local function showActionPicker(row_index)
        local dispatcher = getDispatcher()
        dispatcher:init()
        local picker_state = { updated = false }
        local binding = self._bindings[row_index]
        binding.actions = binding.actions or legacyActionToDispatcher(binding.action)
        binding.action = nil

        local item_table = {}
        dispatcher:addSubMenu(picker_state, item_table, binding, "actions")

        -- Only one action fires per button press, so drop the format-specific
        -- (epub vs pdf) categories and the multi-action/QuickMenu management
        -- rows dispatcher appends after the categories -- neither applies here.
        local function isExcludedCategory(text)
            return text ~= nil
                and (text:find("Reflowable documents", 1, true) ~= nil
                    or text:find("Fixed layout documents", 1, true) ~= nil)
        end
        local filtered_item_table = {}
        for i, entry in ipairs(item_table) do
            if (i == 1 or entry.sub_item_table) and not isExcludedCategory(entry.text) then
                filtered_item_table[#filtered_item_table + 1] = entry
            end
        end
        item_table = filtered_item_table

        local flat_items = {}
        for _, entry in ipairs(item_table) do
            if entry.sub_item_table then
                for _, sub in ipairs(entry.sub_item_table) do
                    flat_items[#flat_items + 1] = sub
                end
            end
        end

        local picker
        local function doSearch(query)
            query = query and query:lower() or ""
            if query == "" then
                picker:switchItemTable("Select Action", item_table)
                return
            end
            local results = {}
            for _, item in ipairs(flat_items) do
                local text = item.text or (item.text_func and item.text_func()) or ""
                if tostring(text):lower():find(query, 1, true) then
                    results[#results + 1] = item
                end
            end
            if #results == 0 then
                results = {{ text = "No actions found" }}
            end
            table.insert(results, 1, {
                text = "← Back to categories",
                callback = function() doSearch("") end,
            })
            picker:switchItemTable('Search: "' .. query .. '"', results)
        end

        picker = Menu:new{
            title = "Select Action",
            item_table = item_table,
            width = screen_w,
            height = screen_h,
            is_popout = false,
            is_borderless = true,
            covers_fullscreen = true,
            title_bar_left_icon = "appbar.search",
        }
        -- Dispatcher's item callbacks are written for TouchMenu, which invokes
        -- callback(touchmenu_instance) and expands sub_item_table_func for
        -- variant pickers (e.g. "Set highlight action"). The plain Menu widget
        -- calls item.callback() with no argument and ignores sub_item_table_func
        -- entirely, so selecting most actions silently did nothing. Mirror
        -- TouchMenu:onMenuSelect's logic here instead.
        picker.onMenuSelect = function(self_menu, item)
            local sub_item_table = item.sub_item_table_func and item.sub_item_table_func() or item.sub_item_table
            if sub_item_table then
                self_menu.item_table.title = self_menu.title
                table.insert(self_menu.item_table_stack, self_menu.item_table)
                self_menu:switchItemTable(item.text, sub_item_table)
                return true
            end
            if item.callback then
                -- Dispatcher's own menus (Hotkeys/Gestures/Profiles) build a set
                -- of actions and require manually backing out to confirm. This
                -- plugin fires one action per button press, so close and save
                -- as soon as a plain toggle/selection is made. If the callback
                -- opened its own dialog instead (e.g. a numeric value picker for
                -- "Turn pages"), the window stack grows -- leave this menu open
                -- underneath so the user can still back out after finishing there.
                local stack_depth_before = #UIManager._window_stack
                item.callback(self_menu)
                if #UIManager._window_stack > stack_depth_before then
                    if item.checked_func then
                        self_menu:updateItems()
                    end
                else
                    self_menu:onClose()
                end
            end
            return true
        end
        picker.onLeftButtonTap = function()
            local InputDialog = require("ui/widget/inputdialog")
            local search_dialog
            search_dialog = InputDialog:new{
                title = "Search actions",
                input_hint = "Type to filter...",
                buttons = {{
                    {
                        text = "Cancel",
                        callback = function() UIManager:close(search_dialog) end,
                    },
                    {
                        text = "Search",
                        is_enter_default = true,
                        callback = function()
                            local query = search_dialog:getInputText()
                            UIManager:close(search_dialog)
                            doSearch(query)
                        end,
                    },
                }},
            }
            UIManager:show(search_dialog)
            search_dialog:onShowKeyboard()
        end
        picker.onClose = function(self_menu)
            UIManager:close(picker)
            if picker_state.updated then
                saveBindings(self._bindings)
                applyBindings(self)
            end
            self:showSettings()
            return true
        end
        UIManager:show(picker)
    end

    local function startCapture(row_index)
        local msg
        msg = InfoMessage:new{
            text = "Press a button on your page turner...",
            timeout = 10,
            close_callback = function()
                if Device.input.input then
                    Device.input.input.capture_callback = nil
                end
            end,
        }
        UIManager:show(msg)
        if Device.input.input then
            Device.input.input.capture_callback = function(code)
                UIManager:close(msg)
                self._bindings[row_index].keycode = code
                saveBindings(self._bindings)
                applyBindings(self)
                self:showSettings()
            end
        end
    end

    local buttons = {}
    for i, binding in ipairs(self._bindings) do
        local idx = i
        buttons[#buttons + 1] = {
            {
                text = keycodeLabel(binding.keycode),
                width = col_key,
                callback = function()
                    UIManager:close(dialog)
                    startCapture(idx)
                end,
            },
            {
                text = actionLabel(binding),
                width = col_act,
                callback = function()
                    UIManager:close(dialog)
                    showActionPicker(idx)
                end,
            },
            {
                text = "\xEF\x87\xB8",
                width = col_del,
                callback = function()
                    table.remove(self._bindings, idx)
                    saveBindings(self._bindings)
                    applyBindings(self)
                    refresh()
                end,
            },
        }
    end

    buttons[#buttons + 1] = {
        {
            text = "+ Add Binding",
            callback = function()
                self._bindings[#self._bindings + 1] = { keycode = nil, actions = {} }
                saveBindings(self._bindings)
                refresh()
            end,
        },
        {
            text = "Close",
            callback = function() UIManager:close(dialog) end,
        },
    }

    local title_bar = TitleBar:new{
        width = sw - 2 * Size.padding.button,
        align = "center",
        with_bottom_line = true,
        title = "Bluetooth Configurator",
        right_icon = "appbar.settings",
        right_icon_tap_callback = function()
            UIManager:close(dialog)
            self:showInfoPanel()
        end,
    }

    local button_table = ButtonTable:new{
        width = sw - 2 * Size.padding.button,
        buttons = buttons,
        zero_sep = false,
    }

    local title_h = title_bar:getSize().h
    local btn_h = button_table:getSize().h
    local content
    if btn_h > sh - title_h then
        content = ScrollableContainer:new{
            dimen = Geom:new{ w = sw - 2 * Size.padding.button, h = sh - title_h },
            button_table,
        }
    else
        content = button_table
    end

    local frame = FrameContainer:new{
        radius = Size.radius.window,
        padding = 0,
        padding_top = 0,
        padding_bottom = 0,
        margin = 0,
        bordersize = Size.border.window,
        background = Blitbuffer.COLOR_WHITE,
        VerticalGroup:new{
            align = "left",
            title_bar,
            content,
        },
    }

    local movable = MovableContainer:new{ frame }

    dialog = InputContainer:new{
        ges_events = {
            TapClose = {
                GestureRange:new{
                    ges = "tap",
                    range = Geom:new{ x = 0, y = 0, w = screen_w, h = sh },
                }
            }
        },
        CenterContainer:new{
            dimen = Geom:new{ x = 0, y = 0, w = screen_w, h = sh },
            movable,
        }
    }

    function dialog:onTapClose(_, ges)
        if ges.pos:notIntersectWith(movable.dimen) then
            UIManager:close(self)
        end
        return true
    end

    UIManager:show(dialog)
end

return BluetoothTurner
