local ConfirmBox = require("ui/widget/confirmbox")
local Device = require("device")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")

local Updater = {}

local GITHUB_REPO = "titandrive/bluetoothconfigurator.koplugin"
local PLUGIN_NAME = "Bluetooth Configurator"
local PLUGIN_DIR = "bluetoothconfigurator.koplugin"
local CHECK_INTERVAL = 3600

local cached_version = nil
local cached_zip_url = nil
local last_check_time = nil
local check_in_flight = false

local function get_module_dir()
    local source = debug.getinfo(1, "S").source or ""
    local path = source:match("^@(.+)$")
    if path then
        return path:match("^(.*)/[^/]+$")
    end
end

local function load_meta_from(path)
    if not path then return nil end
    local ok, meta = pcall(dofile, path)
    if ok and meta and meta.version then
        return meta
    end
end

function Updater.getInstalledVersion()
    local meta = load_meta_from((get_module_dir() or "") .. "/_meta.lua")
    if meta and meta.version then
        return tostring(meta.version)
    end

    local ok_main = pcall(function()
        local DataStorage = require("datastorage")
        local meta_path = DataStorage:getDataDir() .. "/plugins/" .. PLUGIN_DIR .. "/_meta.lua"
        meta = load_meta_from(meta_path)
    end)
    if ok_main and meta and meta.version then
        return tostring(meta.version)
    end
    return "unknown"
end

local function parse_version(v)
    local parts = {}
    for part in tostring(v):gsub("^v", ""):gmatch("([^.]+)") do
        parts[#parts + 1] = tonumber(part) or 0
    end
    return parts
end

local function is_newer(v1, v2)
    local a, b = parse_version(v1), parse_version(v2)
    for i = 1, math.max(#a, #b) do
        local x, y = a[i] or 0, b[i] or 0
        if x > y then return true end
        if x < y then return false end
    end
    return false
end

local function http_get_json(url, user_agent)
    local ok_json, json = pcall(require, "json")
    if not ok_json then return nil end

    local ok_require, http, ltn12, socket, socketutil = pcall(function()
        return require("socket/http"),
            require("ltn12"),
            require("socket"),
            require("socketutil")
    end)
    if ok_require then
        local body = {}
        local ok_req, code = pcall(function()
            socketutil:set_timeout(socketutil.LARGE_BLOCK_TIMEOUT, socketutil.LARGE_TOTAL_TIMEOUT)
            local c = socket.skip(1, http.request({
                url = url,
                method = "GET",
                headers = {
                    ["User-Agent"] = user_agent,
                    ["Accept"] = "application/vnd.github.v3+json",
                },
                sink = ltn12.sink.table(body),
                redirect = true,
            }))
            socketutil:reset_timeout()
            return c
        end)
        if not ok_req then pcall(function() socketutil:reset_timeout() end) end
        if ok_req and code == 200 then
            local ok, data = pcall(json.decode, table.concat(body))
            if ok then return data end
        end
    end

    local handle = io.popen(string.format(
        "curl -s -L -H 'User-Agent: %s' -H 'Accept: application/vnd.github.v3+json' %q",
        user_agent, url))
    if handle then
        local body = handle:read("*a")
        handle:close()
        if body and body ~= "" then
            local ok, data = pcall(json.decode, body)
            if ok then return data end
        end
    end
    return nil
end

local function find_zip_url(release)
    if release and release.assets then
        for _, asset in ipairs(release.assets) do
            if asset.name and asset.name:match("%.zip$") then
                return asset.browser_download_url
            end
        end
    end
    return release and release.zipball_url
end

function Updater.offerReleasesPage(message)
    local url = "https://github.com/" .. GITHUB_REPO .. "/releases"
    if Device:canOpenLink() then
        UIManager:show(ConfirmBox:new{
            text = message .. "\n\nOpen the releases page in a browser?",
            ok_text = "Open",
            ok_callback = function()
                Device:openLink(url)
            end,
        })
    else
        UIManager:show(InfoMessage:new{
            text = message,
            timeout = 3,
        })
    end
end

function Updater.getAvailableUpdate()
    return cached_version, cached_zip_url
end

function Updater.checkBackground(on_update_found)
    if check_in_flight then return end
    local now = os.time()
    if last_check_time and (now - last_check_time) < CHECK_INTERVAL then return end

    local ok_nm, NetworkMgr = pcall(require, "ui/network/manager")
    if not ok_nm or not NetworkMgr:isWifiOn() then return end

    check_in_flight = true
    last_check_time = now

    UIManager:scheduleIn(0.1, function()
        local installed_version = Updater.getInstalledVersion()
        local release = http_get_json(
            "https://api.github.com/repos/" .. GITHUB_REPO .. "/releases/latest",
            "KOReader-BluetoothConfigurator/" .. installed_version)

        check_in_flight = false
        if not release or not release.tag_name then return end
        if release.draft or release.prerelease then return end

        local ver = release.tag_name:gsub("^v", "")
        if is_newer(ver, installed_version) then
            cached_version = ver
            cached_zip_url = find_zip_url(release)
            if on_update_found then on_update_found(ver) end
        else
            cached_version = nil
            cached_zip_url = nil
        end
    end)
end

local function strip_markdown(text)
    text = tostring(text or "")
    text = text:gsub("#+%s*", "")
    text = text:gsub("%*%*(.-)%*%*", "%1")
    text = text:gsub("%*(.-)%*", "%1")
    text = text:gsub("`(.-)`", "%1")
    return text
end

function Updater.check(on_success)
    local NetworkMgr = require("ui/network/manager")
    NetworkMgr:runWhenOnline(function()
        UIManager:show(InfoMessage:new{
            text = "Checking for updates...",
            timeout = 1,
        })

        UIManager:scheduleIn(0.1, function()
            local installed_version = Updater.getInstalledVersion()
            local releases = http_get_json(
                "https://api.github.com/repos/" .. GITHUB_REPO .. "/releases",
                "KOReader-BluetoothConfigurator/" .. installed_version)
            if not releases or #releases == 0 then
                Updater.offerReleasesPage("Could not check for updates.")
                return
            end

            local new_releases = {}
            local latest_zip_url = nil
            for _, rel in ipairs(releases) do
                if not rel.draft and not rel.prerelease and rel.tag_name then
                    local ver = rel.tag_name:gsub("^v", "")
                    if is_newer(ver, installed_version) then
                        new_releases[#new_releases + 1] = rel
                        if not latest_zip_url then
                            latest_zip_url = find_zip_url(rel)
                        end
                    end
                end
            end

            last_check_time = os.time()
            if #new_releases == 0 then
                cached_version = nil
                cached_zip_url = nil
                UIManager:show(InfoMessage:new{
                    text = PLUGIN_NAME .. " is up to date.\n\nVersion: v" .. installed_version,
                    timeout = 3,
                })
                return
            end

            local latest_version = new_releases[1].tag_name:gsub("^v", "")
            cached_version = latest_version
            cached_zip_url = latest_zip_url

            local notes = {}
            for _, rel in ipairs(new_releases) do
                notes[#notes + 1] = "v" .. rel.tag_name:gsub("^v", "")
                    .. "\n" .. strip_markdown(rel.body or "")
            end

            local TextViewer = require("ui/widget/textviewer")
            local viewer
            viewer = TextViewer:new{
                title = "Update available!",
                text = "Installed: v" .. installed_version .. "\n"
                    .. "Latest: v" .. latest_version .. "\n\n"
                    .. table.concat(notes, "\n\n"),
                add_default_buttons = false,
                buttons_table = {{
                    {
                        text = "Close",
                        callback = function()
                            UIManager:close(viewer)
                        end,
                    },
                    {
                        text = "Update and restart",
                        callback = function()
                            UIManager:close(viewer)
                            if not latest_zip_url then
                                Updater.offerReleasesPage("No download available for this release.")
                                return
                            end
                            Updater.install(latest_zip_url, installed_version, latest_version, on_success)
                        end,
                    },
                }},
            }
            UIManager:show(viewer)
        end)
    end)
end

function Updater.install(zip_url, old_version, new_version, on_success)
    local DataStorage = require("datastorage")
    local lfs = require("libs/libkoreader-lfs")

    UIManager:show(InfoMessage:new{
        text = "Downloading update...",
        timeout = 1,
    })

    UIManager:scheduleIn(0.1, function()
        local cache_dir = DataStorage:getSettingsDir() .. "/bluetoothconfigurator_cache"
        if lfs.attributes(cache_dir, "mode") ~= "directory" then
            lfs.mkdir(cache_dir)
        end
        local zip_path = cache_dir .. "/" .. PLUGIN_DIR .. ".zip"

        local downloaded = false
        local ok_require, http, ltn12, socket, socketutil = pcall(function()
            return require("socket/http"),
                require("ltn12"),
                require("socket"),
                require("socketutil")
        end)
        if ok_require then
            local file = io.open(zip_path, "wb")
            if file then
                local ok_dl, code = pcall(function()
                    socketutil:set_timeout(socketutil.FILE_BLOCK_TIMEOUT, socketutil.FILE_TOTAL_TIMEOUT)
                    local c = socket.skip(1, http.request({
                        url = zip_url,
                        method = "GET",
                        headers = {
                            ["User-Agent"] = "KOReader-BluetoothConfigurator/" .. old_version,
                        },
                        sink = ltn12.sink.file(file),
                        redirect = true,
                    }))
                    socketutil:reset_timeout()
                    return c
                end)
                if not ok_dl then pcall(function() socketutil:reset_timeout() end) end
                downloaded = ok_dl and code == 200
            end
        end

        if not downloaded then
            pcall(os.remove, zip_path)
            local ret = os.execute(string.format("curl -sfL -o %q %q", zip_path, zip_url))
            downloaded = ret == 0 or ret == true
        end
        if not downloaded then
            pcall(os.remove, zip_path)
            Updater.offerReleasesPage("Download failed.")
            return
        end

        local plugin_path = DataStorage:getDataDir() .. "/plugins/" .. PLUGIN_DIR
        local ok, err = Device:unpackArchive(zip_path, plugin_path, true)
        pcall(os.remove, zip_path)

        if not ok then
            UIManager:show(InfoMessage:new{
                text = "Installation failed: " .. tostring(err),
                timeout = 5,
            })
            return
        end

        if on_success then pcall(on_success) end

        UIManager:show(InfoMessage:new{
            text = PLUGIN_NAME .. " updated to v" .. new_version .. ".\n\nRestarting KOReader...",
            timeout = 1,
        })
        UIManager:scheduleIn(1, function()
            UIManager:restartKOReader()
        end)
    end)
end

return Updater
