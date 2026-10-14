# pi-aisiri

A [pi](https://pi.dev) package that exposes the AiSiri macOS actions as agent tools.
After installation, pi gains a set of `mac_*` tools for controlling the local machine
(applications, media, volume, brightness, reminders, calendar, shortcuts, clipboard,
screenshots, and system queries), together with an `aisiri-mac` skill that describes
when to use them.

## Prerequisites

Build AiSiri first to produce the CLI:

```bash
cd ..
./build.sh
```

The CLI is installed at `~/.local/bin/aisiri`.

## Installation

```bash
pi install ./pi-package
```

During development the extension can be loaded directly without installing:

```bash
pi -e ./extensions/aisiri.ts -p "现在几点？"
```

## Environment variables

| Variable | Description |
|---|---|
| `AISIRI_BIN` | Path to the `aisiri` executable. Defaults to `~/.local/bin/aisiri`. |
| `AISIRI_ENABLE_DANGEROUS` | Set to `1` to also register `mac_shell_command` and `mac_run_applescript`. Disabled by default. |

## Tools

| Tool | Description |
|---|---|
| `mac_open_app` | Open an application |
| `mac_quit_app` | Quit an application |
| `mac_open_url` | Open a URL in the default browser |
| `mac_web_search` | Search the web |
| `mac_run_shortcut` | Run a Shortcuts shortcut |
| `mac_list_shortcuts` | List shortcuts |
| `mac_set_volume` | Set system output volume (0–100) |
| `mac_get_volume` | Read the current volume |
| `mac_set_brightness` | Adjust screen brightness |
| `mac_music_control` | Control the Music app |
| `mac_now_playing` | Report the current track |
| `mac_create_reminder` | Create a Reminders item |
| `mac_create_calendar_event` | Create a Calendar event |
| `mac_get_datetime` | Report the current date and time |
| `mac_system_info` | Report battery, disk and uptime |
| `mac_clipboard_read` | Read the clipboard |
| `mac_clipboard_write` | Write the clipboard |
| `mac_speak` | Speak text aloud |
| `mac_lock_screen` | Lock the screen |
| `mac_screenshot` | Capture a screenshot |
| `mac_type_text` | Simulate keyboard input |
| `mac_list_running_apps` | List running applications |
| `mac_get_weather` | Query weather for a city |
| `mac_shell_command` | Run a shell command (opt-in) |
| `mac_run_applescript` | Run AppleScript (opt-in) |

Each tool delegates to `aisiri tool <name> '<json>'`, so behaviour matches the app.

## Permissions

The first call of each kind may trigger a macOS authorization prompt: Automation for
Music, Reminders and Calendar; Accessibility for brightness, lock screen and simulated
input. If a tool reports a timeout, grant the permission in
System Settings → Privacy & Security.
