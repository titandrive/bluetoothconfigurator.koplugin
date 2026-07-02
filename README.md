# Bluetooth Configurator - A KOReader plugin for Android to configure page turners


## **⚠ BETA — ANDROID ONLY**
>This plugin is **Android** only. Have a Kobo? Try [this](https://github.com/onatbas/bluetooth.koplugin) plugin instead! Kindle? Try [this!](https://gist.github.com/liquidguru/1e9c77f9389cdf23f94d2a94b220c90a)
>
> **This plugin is in beta. Back up your KOReader directory before installing.**
> It patches KOReader's input handler at runtime and may cause instability.

---

Bluetooth Configurator is a KOReader plugin that lets you easily and intuitively map Bluetooth game controller and page turner buttons to actions within the reader. Not only is this far easier then the official way of using [keymapping](https://github.com/koreader/koreader/wiki/Android-tips-and-tricks#customize-keys), but it provides for more controls then keymapping allows. It supports standard media keys as well as D-pad/joystick controllers. 

<img src="demo.gif" height="400" />
<img height="400" alt="Home page" src="https://github.com/user-attachments/assets/96139a80-1841-4c66-9a55-69d50dacba1b" />
<img height="400" alt="Settings page" src="https://github.com/user-attachments/assets/9e112e20-47a4-4aea-af0a-d6b5529a2519" />
<img height="400" alt="Actions categories" src="https://github.com/user-attachments/assets/0f0c97ad-3332-4780-8022-3295d5259d45" />
<img height="400" alt="Actions examples" src="https://github.com/user-attachments/assets/e68ec6c7-21a0-489c-87a1-e4cacac3a428" />
<img height="400" alt="Actions search" src="https://github.com/user-attachments/assets/50268a43-eb1d-46e4-89c3-84e005f33518" />






## Requirements

- KOReader on **Android** (not supported on Kindle, Kobo, or other platforms)
- A Bluetooth page turner or controller

## Installation

1. Download or clone this repository
2. Copy the `bluetoothconfigurator.koplugin` folder into your KOReader `plugins` directory
3. Restart KOReader
4. Open a book, then go to the top menu → **Plugins** → **Bluetooth Configurator**

## Usage

Open a book and access **Plugins → Bluetooth Configurator** to set up your bindings.

- Tap **Add Binding** to create a new binding
- Tap **"tap to set..."**. The plugin will begin listening for your controller.
- Press the desired button you want to pair. The plugin will capture its keycode. 
- Select the action you want it to trigger
- Use the 🗑 icon to remove a binding

Bindings are saved automatically and persist across sessions.

## Supported Actions

Bluetooth Configurator uses KOReader's built-in dispatcher action list. Available actions are grouped by KOReader's dispatcher categories and can include general, device, screen/light, file browser, reader, reflowable document, and fixed layout document actions.

Actions added to KOReader's dispatcher by KOReader updates or other plugins should appear automatically.

## Updates

Updates can be checked for and installed from within the plugin. Open a book, then go to **Plugins → Bluetooth Configurator**, tap the ⚙ icon in the top right, and select **Check for Updates**. If an update is available you will be prompted to install it. KOReader will need to be restarted for the update to take effect.

## Validated Devices
Although this plugin should work with any Android based E-Reader and bluetooth controller, it has been validated with the following devices:

### E-Readers / Android Devices 
- Boox Go 7 (Color / Black & White)
- Boox Nova 2
- BigMe Hibreak Pro
- Samsung S26 Ultra

### Controllers / Page Turners 
- 8BitDo Micro
- 8BitDo FC30
- 8BitDo SN30 Pro
- [Amazon Smart Selfie Ring](https://a.co/d/0aWYZfTW)
- [ADZERD Page Turner Ring](https://a.co/d/09Ze3ATI)

## Testers Needed
As this plugin is in beta, testers are needed and appreciated! If you run into any controllers or actions that don't work, or other problems, don't hesitate to create an issue. I am a big propnent of accessibility and want this plugin to work perfectly for everyone. Page turners have been a life saver for me. 

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## AI Disclosure

This plugin was developed with the assistance of [Claude Code](https://claude.ai/code) (Anthropic). All code was reviewed and tested by the author.
