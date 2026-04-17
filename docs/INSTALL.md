# Install guide (for AI coding agents)

This file is optimized for automated installation by a coding agent (Claude Code, Qwen, Cursor, etc.). Each step is a single shell command with no interactive prompts and no hidden dependencies. For a human walkthrough with screenshots, see the Notion guide linked from the app's **Settings → About** tab.

## Preconditions

- Platform: `darwin` (macOS)
- Minimum OS: macOS 13 (Ventura)
- Required tools:
  - `git` (preinstalled on macOS)
  - `xcode-select` CLI tools
  - Xcode 15+ with command-line tools installed
- Network: must be able to reach `github.com` and `status.claude.com`

Check with:
```bash
sw_vers | grep ProductVersion         # expect >= 13.0
xcodebuild -version                    # expect Xcode >= 15
git --version                          # any recent version
```

If `xcodebuild` is missing, install Xcode from the Mac App Store, then:
```bash
sudo xcode-select --install
sudo xcodebuild -license accept
```

## Install steps

```bash
# 1. Pick a parent directory
cd ~/Developer 2>/dev/null || cd ~

# 2. Clone
git clone https://github.com/renatomoscati-creator/claude-window.git
cd claude-window

# 3. Build Release
xcodebuild \
  -project ClaudeWindow.xcodeproj \
  -scheme ClaudeWindow \
  -configuration Release \
  -destination 'platform=macOS' \
  build

# 4. Locate the built .app (path varies by DerivedData hash)
APP_PATH="$(find ~/Library/Developer/Xcode/DerivedData -type d -name 'ClaudeWindow.app' -path '*/Release/*' | head -n 1)"
echo "Built app: $APP_PATH"

# 5. Copy into /Applications
cp -R "$APP_PATH" /Applications/

# 6. Remove the Gatekeeper quarantine attribute (the build is ad-hoc signed)
xattr -cr /Applications/ClaudeWindow.app

# 7. Launch
open /Applications/ClaudeWindow.app
```

## Verify

```bash
# Process should be running
pgrep -x ClaudeWindow && echo "ok: running" || echo "FAIL: not running"

# Menu-bar icon should be visible. Programmatic check (optional):
osascript -e 'tell application "System Events" to return name of every menu bar item of menu bar 1 of application process "ClaudeWindow"' 2>/dev/null || echo "note: menu-bar query requires Accessibility permission"
```

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `xcodebuild: error: Signing requires a development team` | No team selected in project | Set `CODE_SIGN_IDENTITY=-` and `CODE_SIGN_STYLE=Manual` in the xcodebuild command, or open the project in Xcode once and set the team to "Sign to Run Locally" |
| App opens, then closes | macOS killed the unsigned binary | Re-run `xattr -cr /Applications/ClaudeWindow.app` then relaunch |
| Scores stay "—" | Status endpoint unreachable | Curl `https://status.claude.com/api/v2/summary.json` to confirm network; check `/Applications/ClaudeWindow.app/Contents/MacOS/ClaudeWindow` logs via Console.app |
| Settings window opens behind other windows | Known macOS LSUIElement quirk | Already mitigated in code; if it persists, relaunch the app |

## Uninstall

```bash
pkill -x ClaudeWindow 2>/dev/null
rm -rf /Applications/ClaudeWindow.app
defaults delete com.claudewindow.app 2>/dev/null
rm -rf ~/Library/Application\ Support/ClaudeWindow
```

## Run tests

```bash
cd /path/to/claude-window
xcodebuild test \
  -project ClaudeWindow.xcodeproj \
  -scheme ClaudeWindow \
  -destination 'platform=macOS'
```

## Enable the local API (optional)

The app ships a localhost-only HTTP server on port `58742` for scripting integrations (e.g., Raycast, shell scripts, IDE plugins). It's off by default.

1. Open the app, click the menu-bar icon → **Settings** → **Advanced**
2. Toggle **Enable local API (port 58742)**
3. Test:
   ```bash
   curl http://127.0.0.1:58742/score
   curl http://127.0.0.1:58742/capacity
   curl http://127.0.0.1:58742/recommendation
   ```

CORS is restricted to `localhost` / `127.0.0.1` / `::1` origins, so web pages from arbitrary sites cannot read your usage.
