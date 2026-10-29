<p align="right"><b>🇺🇸 English</b> | <a href="FEATURES.md">🇯🇵 日本語</a></p>

# mugen-shell: Features

The details behind each item in the [README](README.en.md) feature list.

## App launcher

- Genre tabs and favorites
- Drop one app onto another to make a group
- Start typing on an empty desktop and the launcher opens, searching for what you type (can be turned off in Settings)
- Right-click menu: open, the app's own actions, add to favorites, open file location, uninstall (pacman / Flatpak / Steam)

## Calendar

- Add and delete events from the month view
- A desktop notification when an event is due (all-day events at 08:00)
- Yura can add, list and delete events for you
- Events also show on the lock screen calendar (you can hide them in Settings)

## Timer

- While it runs, the bar shows the time left
- The alarm sound can be any audio file of your own (silent until you pick one)

## Weather

- No API key needed (Open-Meteo)
- The location comes from your IP automatically, or you can type a place
- Current conditions, a 24-hour forecast and a 7-day forecast
- °C / °F

## Music

- Controls for what's playing (any player playerctl supports)
- Album art as the panel backdrop
- A music visualizer in the bar

## Clipboard

- Search the history and copy an entry again
- Images are kept too, with thumbnails
- Swipe to delete

## Notifications

- Do not disturb
- An option to hide popups while a fullscreen app is up
- Action buttons, swipe to dismiss
- Click the body to jump to the app that sent it
- The latest 50 are kept across restarts

## Screenshots

- Region, window or full screen
- A gallery of your shots: open, copy, delete
- Saved to `mugen-screenshots/` in your Pictures folder

## Wallpapers and colors

- Image and video wallpapers, with a choice of switch effect (wave, fade, wipe, grow, random or none) and its length
- Adjust brightness, saturation and how the wallpaper fits the screen (fill, fit or stretch), for images and videos alike
- Video wallpapers can play slower or faster and with sound, and can pause while a fullscreen window is open or while apps you pick are open
- Slideshow: rotates through your wallpaper folder every 1 to 60 minutes, in order or shuffled, and the colors follow each wallpaper
- The picker has search, and Yura can switch to a random wallpaper
- Colors are generated from the wallpaper and applied to your apps (GTK), window borders and the terminal (kitty) too
- When a panel opens, the bar's backdrop becomes a moving gradient from the wallpaper colors (the music and weather panels have their own; pick from 5 palettes)

## Light / dark

- GTK apps switch along with the shell

## Lock screen

- Clock, calendar, weather, media controls
- Moon phase, and an hourglass that fills over the hour
- An animation that moves as you type
- Power buttons (shut down, sleep, restart, log out) are pressed by holding them

## System controls

- Audio: volume, microphone, output and input device switching
- Backlight, WiFi, Bluetooth
- Airplane mode (shown only on machines with a battery)
- Idle inhibitor: stops screen-off, lock and sleep
- IME, battery, system tray
- The volume and brightness keys bring up their panels

## Keyboard

- Most panels open and work with keybindings; `Super + /` lists them all
- How to change the keybindings is in [SETUP.en.md](SETUP.en.md#keybindings)

## Customization

- Change it all in the Settings window (`Super + ,`), where you can search for any option
- **Appearance**: bar shape, color, size, margins and auto-hide, transparency, blur, animation speed, reduce motion, clock format, first day of the week
- **Wallpaper**: when videos pause, speed and sound, apps that pause them, brightness and saturation, fit, the switch effect, slideshow
- **Sound**: the volume step, notification and timer sounds; drop in audio files of your own to use any sound you like
- **Connectivity**: connect to WiFi and Bluetooth, auto-join and forget saved networks, forget paired devices, airplane mode (only on machines with a battery)
- **Idle & Lock**: time until screen-off, sleep and lock
- **System**: which monitor shows the bar, workspace count, turning Yura off

## Yura

An assistant for the small things on your desktop: it suits working mugen-shell and quick errands rather than heavy work. You can talk to it from the input row in the bar, the chat panel, or a terminal (`mugen-ai chat`).

- Models: local models through Ollama, Claude, Gemini, any OpenAI-compatible API; switch mid-conversation
- Desktop control: "set volume to 30" or "start a 5 minute timer" changes the volume or starts the timer; it can also open apps you have allowed
- Chat panel: attach images or text files, see the reasoning on models that think, edit or retry a message
- Conversation history: reopen past chats
- Long-term memory: what you ask Yura to remember stays with her in later chats
- Desktop awareness: answers with the active window, what's playing and today's events in mind. This is sent to cloud models too (`desktop_state_remote = false` in `config.toml` stops that)
- Name, tone, reply language and system prompt can be changed in Yura's settings
- External MCP servers are supported. Clearing all notifications, deleting events or memories, and external writes (unless the server is marked `trusted = true`) are held for approval
- Also runs as an MCP server, so Claude Desktop or Claude Code can drive mugen-shell (off by default; writes are opted into per category)

How to configure it is in [SETUP.en.md](SETUP.en.md#configuring-mugen-ai).
