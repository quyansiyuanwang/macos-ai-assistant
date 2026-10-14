# AiSiri

A native macOS menu bar assistant powered by an OpenAI-compatible LLM. It supports
direct voice conversation and exposes a set of local system actions (application
control, media, reminders, calendar, and more) that the model can invoke as tools.

Written in Swift. Builds with the Swift toolchain only — no Xcode project required.

- LLM backend: any OpenAI-compatible endpoint (default: DeepSeek `deepseek-flash`)
- Voice input via the Speech framework, speech output via AVSpeechSynthesizer
- Global hotkey (default `Option+Space`) to open the window and start listening
- 25+ local tools for controlling macOS
- Full settings UI; API key, model, voice, conversation, tools and hotkey are configurable
- Optional [pi](https://pi.dev) package that exposes the same actions as agent tools

## Requirements

- macOS 13 or later (developed on macOS 15)
- Swift toolchain (`swift`). If missing, install the Command Line Tools:
  `xcode-select --install`
- An API key for an OpenAI-compatible provider

## Build and install

```bash
./build.sh
```

This compiles a release binary and produces:

| Path | Description |
|---|---|
| `~/Applications/AiSiri.app` | The menu bar application |
| `~/.local/bin/aisiri` | Command-line interface (symlink to the app binary) |
| `~/.config/aisiri/config.json` | Configuration file (created from `config.example.json`) |

The app is ad-hoc code-signed (`codesign --sign -`); no developer account is required.
To verify the signature:

```bash
codesign --verify --verbose ~/Applications/AiSiri.app
```

## Usage

Click the menu bar icon or press the global hotkey to open the chat window. The window
is resizable, remembers its position, and keeps multi-turn conversation context.

### Voice interaction

1. Press `Option+Space` (configurable) or click the microphone button to start recording.
2. The live transcription appears in a status line and does not overwrite the input field.
3. After roughly 1.5 seconds of silence, recording stops automatically. Recording can also
   be stopped manually.
4. The transcription is appended to the input field.
5. Press Enter to send. Pressing Enter while recording stops the recording and sends.
6. Sending releases the microphone immediately; the reply is streamed and spoken.

Transcription and the input field are kept separate, so editing the text and continuing to
speak does not duplicate or overwrite previous content.

### Continuous mode

Enable **Continuous** in the window header. After each spoken reply finishes, the assistant
starts listening again, allowing a fully voice-driven exchange. Closing the window stops
automatic listening.

## Configuration

Open **Settings** from the menu bar context menu, the gear button in the window, or `Cmd+,`.
Changes are saved immediately to `~/.config/aisiri/config.json` (mode `0600`).

### Settings reference

| Tab | Options |
|---|---|
| Model | API base URL, API key, model name, max tokens, temperature, system prompt, connection test |
| Voice | Speech output toggle, language, voice, rate, volume, preview; silence timeout, no-speech timeout, auto-send on silence |
| Conversation | Continuous mode, show tool-call activity |
| Behavior | Hotkey preset, always-on-top, launch at login, open config file, restore defaults |
| Tools | Enable or disable individual tools |

### Config file fields

| Key | Type | Default | Description |
|---|---|---|---|
| `base_url` | string | `https://api.deepseek.com` | OpenAI-compatible API base URL |
| `api_key` | string | `""` | Provider API key |
| `model` | string | `deepseek-flash` | Model identifier |
| `max_tokens` | int | `8192` | Maximum output tokens |
| `temperature` | double | `0.7` | Sampling temperature |
| `system_prompt` | string | built-in | System prompt |
| `voice_enabled` | bool | `true` | Speak replies |
| `voice_language` | string | `zh-CN` | Speech recognition and synthesis language |
| `voice_name` | string | `""` | Voice identifier; empty uses the language default |
| `voice_rate` | double | `0.5` | Speech rate |
| `voice_volume` | double | `1.0` | Speech volume |
| `silence_timeout` | double | `1.5` | Seconds of silence that end recording |
| `no_speech_timeout` | double | `8.0` | Seconds without speech before giving up |
| `auto_send_on_silence` | bool | `false` | Send automatically when recording ends |
| `continuous_mode` | bool | `false` | Listen again after each spoken reply |
| `hotkey` | string | `option+space` | Global hotkey, e.g. `control+space`, `command+shift+space` |
| `show_tool_calls` | bool | `true` | Show tool invocations in the transcript |
| `always_on_top` | bool | `false` | Keep the window above other windows |
| `launch_at_login` | bool | `true` | Register a login item |
| `disabled_tools` | string[] | `[]` | Tool names the model may not use |

### Environment variables

Environment variables override the config file:

| Variable | Overrides |
|---|---|
| `DEEPSEEK_API_KEY` | `api_key` |
| `AISIRI_BASE_URL` | `base_url` |
| `AISIRI_MODEL` | `model` |

## Command-line interface

```bash
aisiri ask "打开计算器，把音量调到30"     # chat + execute tools
aisiri tool get_datetime                  # run a single tool
aisiri tool open_app '{"name":"计算器"}'
aisiri tools                              # list all tools
```

`aisiri ask` also reads the prompt from stdin when no argument is given.

## pi integration

The `pi-package/` directory is a [pi](https://pi.dev) package that registers the local
actions as `mac_*` tools and ships an `aisiri-mac` skill. It calls
`aisiri tool <name> '<json>'`, so the implementation is shared with the app.

```bash
./build.sh                        # produce ~/.local/bin/aisiri
pi install ./pi-package           # install the package
```

See [pi-package/README.md](pi-package/README.md) for details.

## Permissions

macOS prompts on first use of each capability:

| Capability | Permission |
|---|---|
| Voice input | Microphone, Speech Recognition |
| Music, Reminders, Calendar | Automation |
| Brightness, lock screen, simulated input | Accessibility |

If a tool reports a timeout, grant the corresponding permission in
System Settings → Privacy & Security.

## Architecture

```
AiSiri/
├── Sources/AiSiri/
│   ├── main.swift          # GUI / CLI entry point
│   ├── AppDelegate.swift   # menu bar item, chat window, main menu, hotkey, login item
│   ├── ChatView.swift      # chat window, streaming rendering, transcription handling
│   ├── SettingsView.swift  # settings interface
│   ├── Config.swift        # AppSettings model and SettingsStore
│   ├── AIClient.swift      # streaming client and tool-call loop
│   ├── Tools.swift         # local tool implementations
│   ├── Speech.swift        # speech recognition (silence detection) and synthesis
│   ├── HotKey.swift        # configurable global hotkey (Carbon)
│   └── CLI.swift           # aisiri ask / tool / tools
├── pi-package/             # pi package (extension and skill)
├── Resources/              # Info.plist, entitlements
├── config.example.json
├── build.sh
└── LICENSE
```

## License

MIT
