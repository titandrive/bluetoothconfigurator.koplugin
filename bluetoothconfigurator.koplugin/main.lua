local InputContainer = require("ui/widget/container/inputcontainer")
local Event = require("ui/event")
local UIManager = require("ui/uimanager")
local Device = require("device")

local PLUGIN_VERSION = "1.0.0"
local GITHUB_REPO    = "titandrive/bluetoothconfigurator.koplugin"

local BluetoothTurner = InputContainer:extend{
    name = "bluetoothconfigurator",
    is_doc_only = true,
}

-- { id, label, event, arg (optional) }
-- arg=true means pass true; arg=number means pass that number
local ACTIONS = {
    { section = "Navigation" },
    { id = "next_page",          label = "Next Page",                 event = "GotoViewRel",              arg = 1    },
    { id = "prev_page",          label = "Previous Page",             event = "GotoViewRel",              arg = -1   },
    { id = "next_chapter",       label = "Next Chapter",              event = "GotoNextChapter"                      },
    { id = "prev_chapter",       label = "Previous Chapter",          event = "GotoPrevChapter"                      },
    { id = "first_page",         label = "First Page",                event = "GoToBeginning"                        },
    { id = "last_page",          label = "Last Page",                 event = "GoToEnd"                              },
    { id = "go_to",              label = "Go to Page",                event = "ShowGotoDialog"                       },
    { id = "skim",               label = "Skim Document",             event = "ShowSkimtoDialog"                     },
    { id = "random_page",        label = "Random Page",               event = "GoToRandomPage"                       },
    { id = "back",               label = "Back",                      event = "Back"                                 },
    { id = "prev_location",      label = "Previous Location",         event = "GoBackLink",               arg = true },
    { id = "next_location",      label = "Next Location",             event = "GoForwardLink",            arg = true },
    { section = "Bookmarks" },
    { id = "toggle_bookmark",    label = "Toggle Bookmark",           event = "ToggleBookmark"                       },
    { id = "bookmarks",          label = "Bookmarks",                 event = "ShowBookmark"                         },
    { id = "bookmark_search",    label = "Bookmark Search",           event = "SearchBookmark"                       },
    { id = "prev_bookmark",      label = "Previous Bookmark",         event = "GotoPreviousBookmarkFromPage"         },
    { id = "next_bookmark",      label = "Next Bookmark",             event = "GotoNextBookmarkFromPage"             },
    { section = "Display" },
    { id = "night_mode",         label = "Toggle Night Mode",         event = "ToggleNightMode"                      },
    { id = "font_increase",      label = "Increase Font Size",        event = "IncreaseFontSize",         arg = 1    },
    { id = "font_decrease",      label = "Decrease Font Size",        event = "DecreaseFontSize",         arg = 1    },
    { id = "frontlight",         label = "Frontlight Dialog",         event = "ShowFlDialog"                         },
    { id = "toggle_frontlight",  label = "Toggle Frontlight",         event = "ToggleFrontlight"                     },
    { id = "toggle_status_bar",  label = "Toggle Status Bar",         event = "ToggleFooterMode"                     },
    { id = "full_refresh",       label = "Full Screen Refresh",       event = "FullRefresh"                          },
    { section = "Reader" },
    { id = "toc",                label = "Table of Contents",         event = "ShowToc"                              },
    { id = "show_menu",          label = "Show Menu",                 event = "ShowMenu"                             },
    { id = "show_config_menu",   label = "Show Bottom Menu",          event = "ShowConfigMenu"                       },
    { id = "fulltext_search",    label = "Fulltext Search",           event = "ShowFulltextSearchInput"              },
    { id = "book_status",        label = "Book Status",               event = "ShowBookStatus"                       },
    { id = "book_info",          label = "Book Information",          event = "ShowBookInfo"                         },
    { id = "book_description",   label = "Book Description",          event = "ShowBookDescription"                  },
    { id = "book_cover",         label = "Book Cover",                event = "ShowBookCover"                        },
    { id = "translate_page",     label = "Translate Page",            event = "TranslateCurrentPage"                 },
    { id = "toggle_style_tweaks",label = "Toggle Style Tweaks",       event = "ToggleStyleTweaks"                    },
    { id = "screenshot",         label = "Screenshot",                event = "Screenshot"                           },
    { section = "Library" },
    { id = "filemanager",        label = "File Browser",              event = "Home"                                 },
    { id = "history",            label = "History",                   event = "ShowHist"                             },
    { id = "favorites",          label = "Favorites",                 event = "ShowColl"                             },
    { id = "collections",        label = "Collections",               event = "ShowCollList"                         },
    { id = "open_previous",      label = "Open Previous Document",    event = "OpenLastDoc"                          },
    { id = "dictionary_lookup",  label = "Dictionary Lookup",         event = "ShowDictionaryLookup"                 },
    { id = "wikipedia_lookup",   label = "Wikipedia Lookup",          event = "ShowWikipediaLookup"                  },
    { section = "Device" },
    { id = "wifi_toggle",        label = "Toggle Wi-Fi",              event = "ToggleWifi"                           },
    { id = "suspend",            label = "Sleep",                     event = "RequestSuspend"                       },
    { id = "none",               label = "None"                                                                      },
}

local ACTIONS_BY_ID = {}
for _, a in ipairs(ACTIONS) do
    if a.id then ACTIONS_BY_ID[a.id] = a end
end

local function executeAction(action_id, ui)
    local action = ACTIONS_BY_ID[action_id]
    if not action or not action.event then return end
    local ev = action.arg ~= nil
        and Event:new(action.event, action.arg)
        or  Event:new(action.event)
    UIManager:broadcastEvent(ev)
end

local DEFAULT_BINDINGS = {
    { keycode = 85, action = "next_page"  },
    { keycode = 87, action = "prev_page"  },
    { keycode = 88, action = "night_mode" },
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
            G_reader_settings:saveSetting("bt_configurator_bindings", cleaned)
            G_reader_settings:saveSetting("bt_configurator_dpad_cleaned", true)
            return cleaned
        end
        return saved
    end
    local copy = {}
    for _, b in ipairs(DEFAULT_BINDINGS) do
        copy[#copy + 1] = { keycode = b.keycode, action = b.action }
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
        if binding then executeAction(binding.action, self.ui) end
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
end

function BluetoothTurner:addToMainMenu(menu_items)
    menu_items.bluetooth_configurator = {
        sorting_hint = "tools",
        text = "Configure Bluetooth Controls",
        callback = function() self:showSettings() end,
    }
end

function BluetoothTurner:showInfoPanel()
    local ButtonDialogTitle = require("ui/widget/buttondialogtitle")
    local panel
    panel = ButtonDialogTitle:new{
        title = "Bluetooth Configurator  v" .. PLUGIN_VERSION,
        buttons = {
            {
                {
                    text = "Check for Updates",
                    callback = function()
                        UIManager:close(panel)
                        self:checkForUpdates()
                    end,
                },
            },
            {
                {
                    text = "Close",
                    callback = function() UIManager:close(panel) end,
                },
            },
        },
    }
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
        url = "https://api.github.com/repos/" .. GITHUB_REPO .. "/releases/latest",
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
    if not ok_parse or not data or not data.tag_name then
        UIManager:show(InfoMessage:new{ text = "Could not parse update response." })
        return
    end

    local latest_tag = data.tag_name
    local latest_ver = latest_tag:match("^v?(.+)$") or latest_tag

    if not self:isNewerVersion(latest_ver, PLUGIN_VERSION) then
        UIManager:show(InfoMessage:new{
            text = "You are up to date (v" .. PLUGIN_VERSION .. ").",
            timeout = 3,
        })
        return
    end

    UIManager:show(ConfirmBox:new{
        text = "Version " .. latest_ver .. " is available (you have v" .. PLUGIN_VERSION .. "). Install now?",
        ok_text = "Install",
        cancel_text = "Not Now",
        ok_callback = function() self:installUpdate(latest_tag) end,
    })
end

function BluetoothTurner:installUpdate(tag)
    local InfoMessage = require("ui/widget/infomessage")
    local ConfirmBox = require("ui/widget/confirmbox")

    local msg = InfoMessage:new{ text = "Downloading update..." }
    UIManager:show(msg)
    UIManager:forceRePaint()

    local _, https = pcall(require, "ssl.https")
    local ltn12 = require("ltn12")

    local base = "https://raw.githubusercontent.com/" .. GITHUB_REPO .. "/" .. tag .. "/bluetoothconfigurator.koplugin/"
    local files = { "_meta.lua", "main.lua", "input_android_patched.lua" }

    for _, fname in ipairs(files) do
        local f = io.open(self.path .. "/" .. fname, "wb")
        if not f then
            UIManager:close(msg)
            UIManager:show(InfoMessage:new{ text = "Update failed: could not write " .. fname })
            return
        end
        local _, fstatus = https.request{
            url = base .. fname,
            method = "GET",
            headers = { ["User-Agent"] = "KOReader-BluetoothConfigurator/" .. PLUGIN_VERSION },
            sink = ltn12.sink.file(f),
        }
        f:close()
        if fstatus ~= 200 then
            UIManager:close(msg)
            UIManager:show(InfoMessage:new{ text = "Update failed: could not download " .. fname })
            return
        end
    end

    UIManager:close(msg)
    UIManager:show(ConfirmBox:new{
        text = "Update installed. Restart KOReader to apply.",
        ok_text = "Restart Now",
        cancel_text = "Later",
        ok_callback = function()
            UIManager:broadcastEvent(Event:new("RequestRestart"))
        end,
    })
end

function BluetoothTurner:showSettings()
    local ButtonDialogTitle = require("ui/widget/buttondialogtitle")
    local InfoMessage = require("ui/widget/infomessage")
    local Menu = require("ui/widget/menu")

    local sw = Device.screen:getWidth()
    local sh = Device.screen:getHeight()
    local col_key = math.floor(sw * 0.44)
    local col_act = math.floor(sw * 0.44)
    local col_del = sw - col_key - col_act

    local dialog

    local function refresh()
        UIManager:close(dialog)
        self:showSettings()
    end

    local function showActionPicker(row_index)
        local items = {}
        local picker
        for _, action in ipairs(ACTIONS) do
            if action.section then
                items[#items + 1] = {
                    text = "── " .. action.section .. " ──",
                    dim = true,
                    callback = function() end,
                }
            else
                local id = action.id
                items[#items + 1] = {
                    text = action.label,
                    callback = function()
                        UIManager:close(picker)
                        self._bindings[row_index].action = id
                        saveBindings(self._bindings)
                        applyBindings(self)
                        self:showSettings()
                    end,
                }
            end
        end
        picker = Menu:new{
            title = "Select Action",
            item_table = items,
            width = sw,
            height = sh,
            close_callback = function() UIManager:close(picker) end,
        }
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
        local action_entry = ACTIONS_BY_ID[binding.action]
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
                text = action_entry and action_entry.label or "?",
                width = col_act,
                callback = function()
                    UIManager:close(dialog)
                    showActionPicker(idx)
                end,
            },
            {
                text = "×",
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
                self._bindings[#self._bindings + 1] = { keycode = nil, action = "none" }
                saveBindings(self._bindings)
                refresh()
            end,
        },
        {
            text = "Close",
            callback = function() UIManager:close(dialog) end,
        },
    }

    dialog = ButtonDialogTitle:new{
        title = "Configure Bluetooth Controls",
        title_align = "center",
        right_icon = "appbar.settings",
        right_icon_tap_callback = function()
            UIManager:close(dialog)
            self:showInfoPanel()
        end,
        buttons = buttons,
        width = sw,
    }
    UIManager:show(dialog)
end

return BluetoothTurner
