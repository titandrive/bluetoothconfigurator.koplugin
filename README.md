# Bluetooth Configurator - A KOReader plugin for Android to configure page turners


## **⚠ BETA — ANDROID ONLY**
>This plugin is **Android** only. Have a Kobo? Try [this](https://github.com/onatbas/bluetooth.koplugin) plugin instead!
>
> **This plugin is in beta. Back up your KOReader directory before installing.**
> It patches KOReader's input handler at runtime and may cause instability.

---

Bluetooth Configurator is a KOReader plugin that lets you easily and intuitively map Bluetooth game controller and page turner buttons to actions within the reader. Not only is this far easier then the official way of using [keymapping](https://github.com/koreader/koreader/wiki/Android-tips-and-tricks#customize-keys), but it provides for more controlls then keymapping allows. It supports standard media keys as well as D-pad/joystick controllers. 

It has been verified to work with both [8BitDo Micro](https://www.8bitdo.com/micro/) as well as a few generic page turners such as [this](https://www.amazon.com/dp/B0B6RBHJFY?ref_=ppx_hzsearch_conn_dt_b_fed_asin_title_3) one, although it should support any similar controller. 

<img src="demo.gif" height="400" /><img height="400" alt="Screenshot_20260611_235123_blurred" src="https://github.com/user-attachments/assets/f8879974-98c3-4f29-898e-1293f69e20a4" /><img height="400" alt="Screenshot_20260611_235129" src="https://github.com/user-attachments/assets/9807d1db-5434-4303-b093-fbe760377932" />


## Requirements

- KOReader on **Android** (not supported on Kindle, Kobo, or other platforms)
- A Bluetooth page turner or controller

## Installation

1. Download or clone this repository
2. Copy the `bluetoothconfigurator.koplugin` folder into your KOReader `plugins` directory
3. Restart KOReader
4. Open a book, then go to the top menu → **Plugins** → **Configure Bluetooth Controls**

## Usage

Open a book and access **Plugins → Configure Bluetooth Controls** to set up your bindings.

- Tap **Add Binding** to create a new binding
- Tap **"tap to set..."**. The plugin will begin listening for your controller.
- Press the desired button you want to pair. The plugin will capture its keycode. 
- Select the action you want it to trigger
- Use the 🗑 icon to remove a binding

Bindings are saved automatically and persist across sessions.

## Supported Actions

Actions are grouped into the following categories:

- **Navigation** — Next/Previous Page, Next/Previous Chapter, First/Last Page, Go to Page, Skim Document, Random Page, Back, Previous/Next Location, Add/Clear Location History, Pin Page, Go to Pinned Page
- **Bookmarks** — Toggle Bookmark, Bookmarks, Bookmark Browser, Bookmark Search, Previous/Next/First/Last/Latest Bookmark
- **Display** — Toggle Night Mode, Increase/Decrease Font Size, Frontlight Dialog, Toggle Frontlight, Increase/Decrease Frontlight, Toggle Status Bar, Toggle Chapter Progress Bar, Full Screen Refresh
- **Reader** — Table of Contents, Book Map, Page Browser, Show Menu, Menu Search, Show Bottom Menu, Fulltext Search, Last Fulltext Search Results, Book Status, Book Information, Book Description, Book Cover, Translate Page, Toggle Style Tweaks, Cycle Highlight Action/Style, Toggle Page Turn Direction, Save Book Metadata, Export Annotations, Screenshot
- **Library** — File Browser, History, History Search, Favorites, Collections, Collections Search, Open Previous Document, Open Next/Previous File in Folder, Notebook File, Dictionary Lookup, Wikipedia Lookup
- **Device** — Toggle Wi-Fi, Toggle Orientation, Invert Rotation, Rotate 90° CW/CCW, Sleep

## Updates

Updates can be checked for and installed from within the plugin. Open a book, then go to **Plugins → Configure Bluetooth Controls**, tap the ⚙ icon in the top right, and select **Check for Updates**. If an update is available you will be prompted to install it. KOReader will need to be restarted for the update to take effect.

## Validated Devices
Although this plugin should work with any Android based E-Reader and bluetooth controller, without issue, it has been validated with the following devices:

### E-Readers / Android Devices 
- Boox Go 7
- Boox Nova 2
- BigMe Hibreak Pro
- Samsumg S26 Ultra

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
