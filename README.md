# Bluetooth Configurator - A KOReader plugin for Android to configure page turners


> [!IMPORTANT]
> This plugin is **Android only.** Have a Kobo? Try [this](https://github.com/onatbas/bluetooth.koplugin) plugin instead. Kindle? Try [this](https://gist.github.com/liquidguru/1e9c77f9389cdf23f94d2a94b220c90a).

Bluetooth Configurator is a KOReader plugin that lets you easily and intuitively map Bluetooth game controller, page turner, and hardware keyboard buttons to actions within the reader and file manager. Not only is this far easier than the official way of using [keymapping](https://github.com/koreader/koreader/wiki/Android-tips-and-tricks#customize-keys), but it provides more controls than keymapping allows. It supports standard media keys, hardware keyboards, and D-pad/joystick controllers.

<img src="demo.gif" height="400" />
<img height="400" alt="File manager bindings" src="https://github.com/user-attachments/assets/acf1948d-787d-4c68-bdb3-8037c6e6397e" />

<img height="400" alt="Reader bindings" src="https://github.com/user-attachments/assets/48182716-fa1f-4e11-8129-5cad2847a415" />

<img height="400" alt="Choose action" src="https://github.com/user-attachments/assets/d7e19e4c-82b7-4840-be4e-59f25cc7ac68" />

<img height="400" alt="Common actions" src="https://github.com/user-attachments/assets/06fb398d-e151-4c60-b1d8-01fd66b4064b" />

<img height="400" alt="Actions search" src="https://github.com/user-attachments/assets/50268a43-eb1d-46e4-89c3-84e005f33518" />

<img height="400" alt="Press a button" src="https://github.com/user-attachments/assets/0be03810-e824-472a-98f3-f5f57e20c677" />




## Requirements

- KOReader on **Android** (not supported on Kindle, Kobo, or other platforms)
- A Bluetooth page turner, controller, or device with a hardware keyboard

## Installation

1. Download or clone this repository
2. Copy the `bluetoothconfigurator.koplugin` folder into your KOReader `plugins` directory
3. Restart KOReader
4. Open **Plugins → Bluetooth Configurator** from either the file manager or the reader

## Usage

Bluetooth Configurator keeps separate bindings for the reader and the file manager. Open **Plugins → Bluetooth Configurator** from the area you want to configure:

- Open it from the file manager to edit **File Manager** bindings
- Open it while reading a book to edit **Reader** bindings

- Tap **Add Binding** to create a new binding
- Tap **"tap to set..."**. The plugin will begin listening for your controller, page turner, or keyboard.
- Press the desired button you want to pair. The plugin will capture its keycode.
- Select the action you want it to trigger
- Use the 🗑 icon to remove a binding

Bindings are saved automatically and persist across sessions. The same physical button can be bound to different actions in the reader and file manager.

## Supported Actions

Bluetooth Configurator uses KOReader's built-in dispatcher action list, so any action available elsewhere in KOReader (or added by another plugin, e.g. a registered Profile) is available here too, automatically, without needing a plugin update.

The action picker (tap an existing binding's action to open it) is organized as:

- **Clear Selected Action(s)** — empties the binding without closing the picker
- **Nothing** — explicitly binds no action
- **Common Actions** — a curated shortlist of the actions people bind most often for the current context
- **General / Device / Screen and lights / File browser / Reader** — KOReader's own dispatcher categories, covering everything else

Tapping an action **replaces** whatever was previously bound to that key. Long-pressing an action **toggles** it in the current set: unselected actions are added, and selected actions are removed. A checkmark shows which action (and which category it's in) is currently bound.

Tap the search icon to filter actions live as you type. Selecting an action from the results works the same as selecting it from a category, and tapping outside the search dialog closes it.

When editing File Manager bindings, reader-only categories like Reader, Paging, Rolling, and Document are hidden from the picker. Reader bindings still show the full reader-focused action set.

## Reader and File Manager Bindings

Bluetooth Configurator keeps separate binding sets for the reader and the file manager, matching KOReader's gesture behavior. Open the plugin from the reader to edit reader bindings, or from the file manager to edit file manager bindings.

If you updated from a version before v2.2.0, your existing bindings were migrated into the **Reader** set automatically, and the new **File Manager** bindings started empty.

Bindings are saved in KOReader's settings folder as `settings/bluetoothconfigurator.lua`. On Android, the full path is usually:

```text
/sdcard/koreader/settings/bluetoothconfigurator.lua
```

To back up or move your Bluetooth Configurator setup, copy that file to your backup location or onto another KOReader device. It contains both the **Reader** and **File Manager** binding sets.

When updating from older versions, Bluetooth Configurator automatically migrates any bindings previously stored in KOReader's global `settings.reader.lua` file into `settings/bluetoothconfigurator.lua`. After that migration, the dedicated `bluetoothconfigurator.lua` file is the one to back up.

## Updates

Updates can be checked for and installed from within the plugin. Open a book, then go to **Plugins → Bluetooth Configurator**, tap the ⚙ icon in the top right, and select **Check for Updates**. If an update is available, the plugin shows the release notes before installing. After you choose **Update and restart**, KOReader restarts automatically.

The settings panel also includes **Check for updates on wake**, which controls whether the plugin checks for updates when KOReader wakes or resumes.

## Validated Devices
Although this plugin should work with any Android based E-Reader and bluetooth controller, it has been validated with the following devices:

### E-Readers / Android Devices 
- Boox Go 7 (Color / Black & White)
- Boox Nova 2
- BigMe Hibreak Pro
- Minimal Phone
- Samsung S26 Ultra

### Controllers / Page Turners / Keyboards
- 8BitDo Micro
- 8BitDo FC30
- 8BitDo SN30 Pro
- [Amazon Smart Selfie Ring](https://a.co/d/0aWYZfTW)
- [ADZERD Page Turner Ring](https://a.co/d/09Ze3ATI)

## Testers Needed
As this plugin is in beta, testers are needed and appreciated! If you run into any controllers, hardware keyboards, actions that don't work, or other problems, don't hesitate to create an issue. I am a big proponent of accessibility and want this plugin to work perfectly for everyone. Page turners have been a life saver for me.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## AI Disclosure

This plugin was developed with the assistance of [Claude Code](https://claude.ai/code) (Anthropic). All code was reviewed and tested by the author.
