# Claude Window

A tiny macOS menu-bar app that estimates **when is a good time to use Claude** and **how much capacity you have left in the current session window**. It reads Anthropic's public status page in real time and combines that with timing heuristics (peak hours across US/EU/APAC, weekends, regional holidays) to score the current window and forecast the next 12 hours.

> **Not affiliated with Anthropic.** The usage capacity numbers are calibrated from publicly documented plan limits and community-reported behavior — they are estimates, not guarantees. Reliability/service-health signals come straight from [status.claude.com](https://status.claude.com).

---

## What it does

- **Menu-bar icon** colored by current window state (green/yellow/orange/red).
- **Dropdown** shows:
  - A score 0–100 with confidence band and "Why" explainer.
  - Per-surface scores for Claude Desktop, Claude Code, and Claude API (each has its own load profile).
  - Estimated queries remaining in your 5-hour rolling window for the selected plan + model + workload profile.
  - A **12-hour forecast** of expected load, colored to match the main score.
  - A "Best Next Window" suggestion when the current hour isn't favorable.
- **Local HTTP API** (optional, off by default) on `127.0.0.1:58742` exposing `/score`, `/capacity`, `/recommendation` for scripting. Loopback-only, with an origin allow-list so random websites can't scrape your usage.

## Screenshots

Drop screenshots into `docs/screenshots/` and reference them here:

```
![Dropdown](docs/screenshots/dropdown.png)
![Forecast expanded](docs/screenshots/forecast.png)
![Settings](docs/screenshots/settings.png)
```

## Requirements

- macOS 13 (Ventura) or later
- Xcode 15 or later (for building from source)
- Swift 5.9+

## Quick install

Easiest: **download the latest `.app` from Releases** and drop it into `/Applications`. First launch: right-click → Open to bypass Gatekeeper (unsigned build).

Build from source:
```bash
git clone https://github.com/renatomoscati-creator/claude-window.git
cd "claude-window"
xcodebuild -project ClaudeWindow.xcodeproj -scheme ClaudeWindow -configuration Release build
open ~/Library/Developer/Xcode/DerivedData/ClaudeWindow-*/Build/Products/Release/ClaudeWindow.app
```

Full step-by-step (for AI coding agents): see [docs/INSTALL.md](docs/INSTALL.md).
Full human walkthrough: [Claude Window — Install Guide](https://www.notion.so/345f3861c73181169a93efdd62632faa) on Notion.

## Calibration caveat

A few numbers are heuristic and should be calibrated against your own usage before trusted:

- **Plan token budgets** in [ClaudeWindow/Models/Plan.swift](ClaudeWindow/Models/Plan.swift) — derived from publicly documented ~message-count limits (Pro ≈ 45 msgs / 5h, Max 5× ≈ 225 msgs / 5h, etc.) times a rough 2,000 tokens/query average.
- **Workload profiles** in [ClaudeWindow/Models/WorkloadProfile.swift](ClaudeWindow/Models/WorkloadProfile.swift) — per-model token averages.
- **Surface multipliers** in [ClaudeWindow/Models/Surface.swift](ClaudeWindow/Models/Surface.swift) — Claude Code (×1.15 load) runs longer tool-calling sessions, Claude API (×0.90) is self-paced. These are guesses until real data calibrates them.
- **Max-plan weekly Opus caps** are not yet modeled — the app treats the 5-hour rolling window as the single budget. If you're on Max 20× and use Opus heavily, expect the UI to under-warn about weekly limits.

If you have real usage data and want to tighten these numbers, a PR or issue is welcome.

## Contributing

Tests live in `ClaudeWindowTests/`. Run them with:
```bash
xcodebuild test -project ClaudeWindow.xcodeproj -scheme ClaudeWindow -destination 'platform=macOS'
```

Open an issue before starting a non-trivial change — happy to discuss direction.

## License

[MIT](LICENSE) © 2026 Renato Moscati.

Built and maintained by [@renatomoscati-creator](https://github.com/renatomoscati-creator). Visit for updates and new projects.
