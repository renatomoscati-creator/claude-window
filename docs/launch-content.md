# Launch Content — Claude Window

## Item 4: Sign + Notarize (what to do, in order)

**Prerequisites:** Apple Developer Program membership ($99/year).

```bash
# 1. Export a signed .app from Xcode:
#    Product → Archive → Distribute App → Developer ID → Upload

# 2. Or sign from command line after building:
codesign \
  --deep --force --verify --verbose \
  --sign "Developer ID Application: Your Name (TEAMID)" \
  --options runtime \
  --entitlements ClaudeWindow.entitlements \
  dist/ClaudeWindow.app

# 3. Notarize the DMG (after building it):
xcrun notarytool submit dist/ClaudeWindow-1.0.0.dmg \
  --apple-id "your@email.com" \
  --team-id "YOURTEAMID" \
  --password "@keychain:AC_PASSWORD" \
  --wait

# 4. Staple the notarization ticket:
xcrun stapler staple dist/ClaudeWindow-1.0.0.dmg
```

After this: users double-click the DMG. No right-click required. Add "Signed & notarized" to README privacy bullets.

---

## Item 6: Reddit — r/ClaudeAI launch post

**Title:**
> I built a free macOS menu-bar app that tells you when Claude is worth using — here's why I made it

**Body:**
> I kept hitting the same wall: I'd open Claude with a big task, run into sluggish responses or rate limits, and waste 20 minutes. Or I'd avoid it during what turned out to be a perfectly fine window.
>
> So I built a small macOS menu-bar app that combines Anthropic's public status page with timing heuristics (peak hours across US/EU/APAC, weekends, regional patterns) into a 0–100 score. It also estimates how many queries you likely have left in your 5-hour rolling window based on your plan and model.
>
> [GIF of dropdown opening, green state]
>
> What it does:
> - Menu-bar icon: green/yellow/orange/red at a glance
> - Score with a plain-English "why"
> - Separate scores for Claude.ai, Claude Code, and API
> - 12-hour forecast — you can see when to schedule heavy work
> - "Best Next Window" when the current hour isn't favorable
>
> It's not magic — the estimates are heuristic and I've documented exactly what's calibrated vs. guessed. No login required. Nothing leaves your machine. Fully open source (MIT).
>
> Repo + free download: https://github.com/renatomoscati-creator/claude-window
>
> Happy to answer questions about how the scoring works. If you have real usage data that could improve the calibration, a PR would be genuinely useful.

---

## Item 6b: Reddit — r/MacApps (Week 2)

**Title:**
> Claude Window — free menu-bar app for Claude power users (shows real-time score + 12h forecast)

**Body:**
> Built a small utility I've been using personally for a while.
>
> It estimates whether it's currently a good window to use Claude heavily — combining the official Anthropic status page with time-of-day load heuristics into a 0–100 score. Also shows per-surface scores (Claude.ai / Claude Code / API) and a 12-hour bar chart so you can see when to schedule intensive work.
>
> [screenshot]
>
> Free, open source (MIT), no login, nothing sent anywhere. macOS 13+.
>
> https://github.com/renatomoscati-creator/claude-window

---

## Item 6c: Reddit — r/SideProject (Week 2)

**Title:**
> What I learned shipping a macOS menu-bar app outside the App Store

**Body:**
> I recently released Claude Window — a free utility for Claude power users — and learned more about macOS distribution friction than I expected.
>
> The three things that surprised me most:
>
> 1. **"Right-click → Open" is a silent killer.** For non-technical users, seeing Gatekeeper's warning feels like something went wrong, not like an install step. Unsigned builds lose real users here. Worth the $99/year just for this.
>
> 2. **DMG with drag-to-Applications is table stakes.** Shipping a raw zip felt like giving someone a car without wheels. The drag-arrow UI trains the user exactly once and then they never think about it.
>
> 3. **Homebrew Cask is not as hard as it looks.** ~15 lines of Ruby, one tap repo, and `brew install --cask claude-window` works. Worth doing early if your audience is even remotely technical.
>
> If you're building macOS stuff: sign the build before you launch, not after.
>
> The app: https://github.com/renatomoscati-creator/claude-window

---

## Item 7: X — Launch thread

**Tweet 1 (with demo GIF attached):**
> I made a free macOS menu-bar app for Claude power users.
>
> It tells you in real time whether it's a good moment to send heavy work — or better to wait.
>
> Score 0–100. 12-hour forecast. No login. No data sent. MIT open source.
>
> github.com/renatomoscati-creator/claude-window

**Tweet 2:**
> Why this exists: I kept burning time running into Claude rate limits mid-task, or avoiding it during windows that were actually fine.
>
> So it reads Anthropic's public status page + local timing heuristics (US/EU/APAC peak hours, weekends, holidays) and gives you a single number.

**Tweet 3:**
> Separate scores for Claude.ai, Claude Code, and API — each has a different load profile.
>
> Best Next Window tells you exactly when to schedule the heavy stuff.

**Tweet 4:**
> Open source (MIT). Nothing sends data. No Claude account needed.
>
> Estimates are heuristic — I've documented exactly what's calibrated vs. guessed. It's a probability signal, not a guarantee.
>
> Free download + source: github.com/renatomoscati-creator/claude-window

---

## Item 8: Product Hunt

**Name:** Claude Window

**Tagline:**
> Know when Claude is ready for your heaviest work

**Description:**
> Claude Window is a free macOS menu-bar app that tells you in real time whether it's a good moment to use Claude — or better to wait.
>
> It combines Anthropic's public status page with time-of-day load heuristics (US/EU/APAC peaks, weekends, regional holidays) into a 0–100 score with a plain-English reason. It also estimates your remaining query capacity for the current 5-hour rolling window, broken down by plan and model.
>
> **What you see at a glance:**
> - Colored menu-bar icon (green/yellow/orange/red)
> - Score with confidence level and explanation
> - Separate scores for Claude.ai, Claude Code, and API
> - 12-hour forecast chart
> - "Best Next Window" suggestion
> - Estimated queries remaining
>
> **Privacy first:**
> No login. No Claude account. No access to your prompts or conversations. The only network call is to Anthropic's public status page. Everything else is computed locally.
>
> Free. Open source (MIT). macOS 13+.

**First comment (post yourself on launch day):**
> Hey PH! Built this after repeatedly hitting Claude rate limits at the worst possible moment — mid-agent-run, mid-research session, 3 hours into a coding session.
>
> The estimates are heuristic, not magic — I've documented exactly what's calibrated and what's a guess in the repo. Happy to hear if your experience matches or diverges from the scoring.
>
> AMA about how the timing heuristics work, or what I learned shipping a macOS app outside the App Store.

---

## Signing steps checklist

Before any public launch wave, confirm these are done:

- [ ] Apple Developer account active
- [ ] Signing identity created: `Developer ID Application`
- [ ] App signed with `--options runtime` (required for notarization)
- [ ] DMG built via `scripts/build-dmg.sh`
- [ ] DMG notarized via `xcrun notarytool`
- [ ] DMG stapled via `xcrun stapler`
- [ ] Tested on a fresh Mac: double-click opens without warning
- [ ] README updated: remove "right-click → Open" note, add "Signed & notarized"
- [ ] Homebrew cask sha256 updated after final DMG
