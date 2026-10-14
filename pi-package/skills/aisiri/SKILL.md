---
name: aisiri-mac
description: Control the local macOS machine — open or quit applications, control Music, set volume or brightness, create Reminders or Calendar events, run Shortcuts, read or write the clipboard, take screenshots, lock the screen, and query time, battery, or weather. Use whenever the user asks to operate their Mac or check local system state.
---

# AiSiri macOS control

This package exposes macOS actions as `mac_*` tools backed by the AiSiri CLI
(`aisiri tool <name> '<json>'`).

## Guidelines

- Prefer the `mac_*` tools over generic shell commands for application, media, volume,
  brightness, reminder, calendar, clipboard, and screenshot operations.
- `mac_shell_command` and `mac_run_applescript` are registered only when
  `AISIRI_ENABLE_DANGEROUS=1` is set. Confirm with the user before running them.
- Resolve relative dates such as "tomorrow at 9" into `yyyy-MM-dd HH:mm` before calling
  `mac_create_reminder` or `mac_create_calendar_event`.
- The CLI must be present at `~/.local/bin/aisiri`, or `AISIRI_BIN` must point to it.
- The first call of each kind may trigger a macOS permission prompt (Automation for
  Music/Reminders/Calendar, Accessibility for brightness/lock/type_text). If a tool
  reports a timeout, instruct the user to approve it in
  System Settings → Privacy & Security.

## Common mappings

| User request | Tool |
|---|---|
| Open an application | `mac_open_app` |
| Pause or skip a track | `mac_music_control` |
| Set the volume | `mac_set_volume` |
| Create a reminder | `mac_create_reminder` |
| Current time or battery | `mac_get_datetime`, `mac_system_info` |
| Current track | `mac_now_playing` |
