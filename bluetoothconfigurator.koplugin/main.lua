local InputContainer = require("ui/widget/container/inputcontainer")
local Event = require("ui/event")
local UIManager = require("ui/uimanager")
local Device = require("device")

local PLUGIN_VERSION = "1.1.0"
local GITHUB_REPO    = "titandrive/bluetoothconfigurator.koplugin"


local BluetoothTurner = InputContainer:extend{
    name = "bluetoothconfigurator",
    is_doc_only = true,
}

-- { id, label, event, arg (optional) }
-- arg=true means pass true; arg=number means pass that number
local ACTIONS = {
    { section = "Navigation" },
    { id = "next_page",               label = "Next Page",                       event = "GotoViewRel",                    arg = 1    },
    { id = "prev_page",               label = "Previous Page",                   event = "GotoViewRel",                    arg = -1   },
    { id = "next_chapter",            label = "Next Chapter",                    event = "GotoNextChapter"                            },
    { id = "prev_chapter",            label = "Previous Chapter",                event = "GotoPrevChapter"                            },
    { id = "first_page",              label = "First Page",                      event = "GoToBeginning"                              },
    { id = "last_page",               label = "Last Page",                       event = "GoToEnd"                                    },
    { id = "go_to",                   label = "Go to Page",                      event = "ShowGotoDialog"                             },
    { id = "skim",                    label = "Skim Document",                   event = "ShowSkimtoDialog"                           },
    { id = "random_page",             label = "Random Page",                     event = "GoToRandomPage"                             },
    { id = "back",                    label = "Back",                            event = "Back"                                       },
    { id = "prev_location",           label = "Previous Location",               event = "GoBackLink",                     arg = true },
    { id = "next_location",           label = "Next Location",                   event = "GoForwardLink",                  arg = true },
    { id = "add_location",            label = "Add Location to History",         event = "AddCurrentLocationToStack",      arg = true },
    { id = "clear_location_history",  label = "Clear Location History",          event = "ClearLocationStack",             arg = true },
    { id = "pin_page",                label = "Pin Current Page",                event = "PinPage"                                    },
    { id = "go_to_pinned",            label = "Go to Pinned Page",               event = "GoToPinnedPage"                             },
    { section = "Bookmarks" },
    { id = "toggle_bookmark",         label = "Toggle Bookmark",                 event = "ToggleBookmark"                             },
    { id = "bookmarks",               label = "Bookmarks",                       event = "ShowBookmark"                               },
    { id = "bookmark_browser",        label = "Bookmark Browser",                event = "ShowBookmarkBrowser"                        },
    { id = "bookmark_search",         label = "Bookmark Search",                 event = "SearchBookmark"                             },
    { id = "prev_bookmark",           label = "Previous Bookmark",               event = "GotoPreviousBookmarkFromPage"               },
    { id = "next_bookmark",           label = "Next Bookmark",                   event = "GotoNextBookmarkFromPage"                   },
    { id = "first_bookmark",          label = "First Bookmark",                  event = "GotoFirstBookmark"                          },
    { id = "last_bookmark",           label = "Last Bookmark",                   event = "GotoLastBookmark"                           },
    { id = "latest_bookmark",         label = "Latest Bookmark",                 event = "GoToLatestBookmark"                         },
    { section = "Display" },
    { id = "night_mode",              label = "Toggle Night Mode",               event = "ToggleNightMode"                            },
    { id = "font_increase",           label = "Increase Font Size",              event = "IncreaseFontSize",               arg = 1    },
    { id = "font_decrease",           label = "Decrease Font Size",              event = "DecreaseFontSize",               arg = 1    },
    { id = "frontlight",              label = "Frontlight Dialog",               event = "ShowFlDialog"                               },
    { id = "toggle_frontlight",       label = "Toggle Frontlight",               event = "ToggleFrontlight"                           },
    { id = "increase_frontlight",     label = "Increase Frontlight",             event = "IncreaseFlIntensity",            arg = 1    },
    { id = "decrease_frontlight",     label = "Decrease Frontlight",             event = "DecreaseFlIntensity",            arg = 1    },
    { id = "toggle_status_bar",       label = "Toggle Status Bar",               event = "ToggleFooterMode"                           },
    { id = "toggle_chapter_progress", label = "Toggle Chapter Progress Bar",     event = "ToggleChapterProgressBar"                   },
    { id = "full_refresh",            label = "Full Screen Refresh",             event = "FullRefresh"                                },
    { section = "Reader" },
    { id = "toc",                     label = "Table of Contents",               event = "ShowToc"                                    },
    { id = "book_map",                label = "Book Map",                        event = "ShowBookMap"                                },
    { id = "page_browser",            label = "Page Browser",                    event = "ShowPageBrowser"                            },
    { id = "show_menu",               label = "Show Menu",                       event = "ShowMenu"                                   },
    { id = "menu_search",             label = "Menu Search",                     event = "MenuSearch"                                 },
    { id = "show_config_menu",        label = "Show Bottom Menu",                event = "ShowConfigMenu"                             },
    { id = "fulltext_search",         label = "Fulltext Search",                 event = "ShowFulltextSearchInput"                    },
    { id = "fulltext_search_results", label = "Last Fulltext Search Results",    event = "ShowFindAllResults"                         },
    { id = "book_status",             label = "Book Status",                     event = "ShowBookStatus"                             },
    { id = "book_info",               label = "Book Information",                event = "ShowBookInfo"                               },
    { id = "book_description",        label = "Book Description",                event = "ShowBookDescription"                        },
    { id = "book_cover",              label = "Book Cover",                      event = "ShowBookCover"                              },
    { id = "translate_page",          label = "Translate Page",                  event = "TranslateCurrentPage"                       },
    { id = "toggle_style_tweaks",     label = "Toggle Style Tweaks",             event = "ToggleStyleTweaks"                          },
    { id = "cycle_highlight_action",  label = "Cycle Highlight Action",          event = "CycleHighlightAction"                       },
    { id = "cycle_highlight_style",   label = "Cycle Highlight Style",           event = "CycleHighlightStyle"                        },
    { id = "toggle_page_turn_dir",    label = "Toggle Page Turn Direction",      event = "ToggleReadingOrder"                         },
    { id = "flush_settings",          label = "Save Book Metadata",              event = "FlushSettings",                  arg = true },
    { id = "export_annotations",      label = "Export Annotations",              event = "ExportAnnotations"                          },
    { id = "screenshot",              label = "Screenshot",                      event = "Screenshot"                                 },
    { section = "Library" },
    { id = "filemanager",             label = "File Browser",                    event = "Home"                                       },
    { id = "history",                 label = "History",                         event = "ShowHist"                                   },
    { id = "history_search",          label = "History Search",                  event = "SearchHistory"                              },
    { id = "favorites",               label = "Favorites",                       event = "ShowColl"                                   },
    { id = "collections",             label = "Collections",                     event = "ShowCollList"                               },
    { id = "collections_search",      label = "Collections Search",              event = "ShowCollectionsSearchDialog"                },
    { id = "open_previous",           label = "Open Previous Document",          event = "OpenLastDoc"                                },
    { id = "open_next_in_folder",     label = "Open Next File in Folder",        event = "OpenNextOrPreviousFileInFolder"             },
    { id = "open_prev_in_folder",     label = "Open Previous File in Folder",    event = "OpenNextOrPreviousFileInFolder", arg = true },
    { id = "notebook_file",           label = "Notebook File",                   event = "ShowNotebookFile"                           },
    { id = "dictionary_lookup",       label = "Dictionary Lookup",               event = "ShowDictionaryLookup"                       },
    { id = "wikipedia_lookup",        label = "Wikipedia Lookup",                event = "ShowWikipediaLookup"                        },
    { section = "Device" },
    { id = "wifi_toggle",             label = "Toggle Wi-Fi",                    event = "ToggleWifi"                                 },
    { id = "toggle_rotation",         label = "Toggle Orientation",              event = "SwapRotation"                               },
    { id = "invert_rotation",         label = "Invert Rotation",                 event = "InvertRotation"                             },
    { id = "rotate_cw",               label = "Rotate 90° CW",                   event = "IterateRotation"                            },
    { id = "rotate_ccw",              label = "Rotate 90° CCW",                  event = "IterateRotation",                arg = true },
    { id = "suspend",                 label = "Sleep",                           event = "RequestSuspend"                             },
    { id = "none",                    label = "None"                                                                                  },
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
    local ButtonDialog = require("ui/widget/buttondialog")
    local panel
    panel = ButtonDialog:new{
        title = "Bluetooth Configurator",
        title_align = "center",
        buttons = {
            {
                {
                    text = "Version: " .. PLUGIN_VERSION,
                    callback = function() end,
                },
            },
            {
                {
                    text = "Check for Updates",
                    callback = function()
                        self:checkForUpdates()
                    end,
                },
            },
            {
                {
                    text = "Back",
                    callback = function()
                        UIManager:close(panel)
                        self:showSettings()
                    end,
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

    UIManager:show(ConfirmBox:new{
        text = "Version " .. latest_ver .. " is available (you have v" .. PLUGIN_VERSION .. "). Install now?",
        ok_text = "Install",
        cancel_text = "Not Now",
        ok_callback = function() self:installUpdate(latest_tag) end,
    })
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
        local picker
        local cat_items = {}
        local current_section = nil
        local sub_items = nil
        local function finalizeSection()
            if current_section and sub_items then
                table.insert(sub_items, 1, {
                    text = "← Back",
                    callback = function() picker:onClose() end,
                })
                cat_items[#cat_items + 1] = {
                    text = current_section,
                    sub_item_table = sub_items,
                }
            end
        end
        for _, action in ipairs(ACTIONS) do
            if action.section then
                finalizeSection()
                current_section = action.section
                sub_items = {}
            elseif current_section then
                local id = action.id
                sub_items[#sub_items + 1] = {
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
        finalizeSection()
        picker = Menu:new{
            title = "Select Action",
            item_table = cat_items,
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

    local title_bar = TitleBar:new{
        width = sw,
        align = "center",
        with_bottom_line = true,
        title = "Configure Bluetooth Controls",
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
            dimen = Geom:new{ w = sw, h = sh - title_h },
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
                    range = Geom:new{ x = 0, y = 0, w = sw, h = sh },
                }
            }
        },
        CenterContainer:new{
            dimen = Geom:new{ x = 0, y = 0, w = sw, h = sh },
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
