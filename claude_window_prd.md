# PRD — Claude Window

## 1. Overview

**Product name:** Claude Window  
**Platform:** macOS menu bar app  
**Primary goal:** Help users quickly decide whether **now** is a good time to use Claude, with a focus on **maximizing subscription session efficiency** rather than only detecting outages.

Claude Window estimates whether the current time window is favorable for getting more useful work out of Claude before hitting dynamic session limits. It presents the result at a glance through a colored menu bar Claude icon and a compact dropdown with estimated query/token capacity, confidence, and reasoning.

The app also exposes a local API so external tools, scripts, or Claude-adjacent workflows can query the recommendation programmatically.

---

## 2. Problem

Users on Claude subscription plans may experience materially different session efficiency depending on when they use Claude. In peak usage windows, session limits may tighten faster, reducing the amount of useful work that can be extracted from a session. There is no simple official product that shows, at a glance, whether the current moment is likely to be a good window for Claude usage efficiency.

Users therefore lack:

- A fast visual indicator for whether it is a good moment to start a Claude session
- An estimate of how much work they may be able to do before limits become constraining
- A way to incorporate timing, business-hour overlap, holidays, seasonality, and recent reliability signals into that decision
- A programmatic interface other tools can call to make routing decisions

---

## 3. Product Vision

Claude Window should become a **small, chill, always-available utility** that answers one practical question:

> Should I use Claude now, or is this likely a bad time to start a serious session?

The product should be:

- **Instant** — usable at a glance from the menu bar
- **Honest** — explicitly predictive/heuristic, not pretending to know true real-time global usage
- **Useful** — optimized for subscription efficiency first
- **Extensible** — callable locally via API for future automation

---

## 4. Goals

### Primary goals

- Show whether the current moment is a good or bad Claude usage window
- Prioritize **risk of burning through session limits inefficiently**
- Estimate **expected query count** and **expected token capacity** for the current window
- Support multiple Claude surfaces:
  - Claude Desktop
  - Claude Code
  - Claude API
- Let the user choose which surface is reflected in the menu bar state
- Expose a local API so other tools can query the recommendation

### Secondary goals

- Provide a toggle for technical reliability vs usage-efficiency mode
- Factor in holidays, weekends, working-hour overlap, and seasonality
- Learn from user history over time to improve estimates

### Non-goals for v1

- Measuring official real-time global Claude demand directly
- Showing exact true remaining quota from Anthropic
- Scraping hidden/private Claude internals
- Enterprise admin analytics or account-wide billing management

---

## 5. Target User

### Initial target user
A power user on macOS using Claude primarily through **subscription products**, who wants to strategically time usage to maximize the amount of useful work they can get out of a session.

### Likely user traits

- Uses Claude frequently for writing, coding, research, or document-heavy work
- Has experienced session limits tightening at inconvenient moments
- Wants a low-friction visual signal rather than checking status pages manually
- May want to integrate the recommendation into personal workflows or agents

---

## 6. Core Use Cases

### Use case 1 — At-a-glance decision
A user glances at the menu bar and sees the Claude icon is green, meaning this is likely a favorable window for subscription efficiency.

### Use case 2 — Pre-session check
Before starting a long Claude session, the user opens the dropdown and checks:

- current score
- estimated query range
- estimated token range
- confidence
- why the current window is rated this way

### Use case 3 — Surface-specific monitoring
The user configures the menu bar to reflect Claude Desktop only, while still being able to inspect Claude Code and API conditions from the dropdown.

### Use case 4 — Automation
A local script or agent queries the app’s local API and decides whether to route a task to Claude now or delay it.

### Use case 5 — Planning ahead
The user checks the “best next window” section to see when the next favorable period is expected in the next 24 hours.

---

## 7. Product Principles

- **Actionable over decorative** — always answer a user decision
- **Estimate, do not overclaim** — make uncertainty explicit
- **Fast by default** — one glance should be enough for basic use
- **Local-first** — personal settings and telemetry stay on-device where possible
- **Clear separation of modes** — efficiency and reliability are related but different

---

## 8. Functional Requirements

## 8.1 Menu bar presence

The app must live in the macOS menu bar and display a small Claude icon whose color shifts according to the current rating.

### States

- **Green** — efficient window
- **Yellow** — average / mixed window
- **Orange** — elevated limit risk
- **Red** — poor window / avoid for serious session start
- **Gray** — unknown / insufficient data / service unavailable

The icon should reflect the **user-selected primary surface**.

---

## 8.2 Supported surfaces

The product must support independent evaluation for:

- Claude Desktop
- Claude Code
- Claude API

### User controls

The user must be able to:

- choose which surface drives the menu bar icon
- inspect all supported surfaces in the dropdown
- optionally disable unused surfaces from view

---

## 8.3 Primary operating modes

The app must support two scoring modes.

### Mode A — Limit Risk Mode (default)
Optimized for predicting whether using Claude now is likely to consume session allowance inefficiently.

This is the default mode and the primary product value.

### Mode B — Reliability Mode
Optimized for predicting technical smoothness, based on official service health and recent incident history.

The user must be able to toggle the active mode in the dropdown and in settings.

---

## 8.4 Current window recommendation

The app must produce a clear recommendation state for the selected surface and mode.

### Recommendation labels

- **Efficient window**
- **Average window**
- **High limit-risk window**
- **Poor reliability window**
- **Unknown**

The recommendation must be backed by:

- numeric score
- confidence level
- top contributing reasons

---

## 8.5 Estimated capacity

The app must estimate how much Claude usage a user is likely to get from the current window.

### Outputs

- **Estimated query count range**
- **Estimated token capacity range**
- **Confidence level**

These should always be shown as ranges, not exact values.

### Inputs required from user

- subscription plan
- workload profile
- preferred surface

### Optional user inputs

- average prompt size
- average response size
- typical use case type
- manually observed limit-hit patterns

---

## 8.6 Workload profiles

The app must support simple workload presets to improve estimation quality.

### Initial presets

- Light chat
- Standard writing/research
- Coding
- Long-context analysis
- File-heavy / document-heavy

Each preset should map to internal assumptions about typical token consumption per interaction.

---

## 8.7 Plan configuration

The user must be able to manually enter or select their Claude plan.

### Initial options

- Free
- Pro
- Max
- Custom

For **Custom**, the user can tune base assumptions manually.

Because exact live plan/session mechanics are not publicly exposed in machine-readable form for this use case, the app should treat plan data as user-configured estimation input.

---

## 8.8 Reasoning / explainability

The app must show the top reasons behind the current score.

### Example reasons

- Off-peak US hours
- Weekend effect favorable
- Major regional business-hour overlap currently low
- Recent incident history increases uncertainty
- Current official status operational
- User history suggests better session longevity at this hour

The reasoning should be concise and user-readable.

---

## 8.9 Best next window

The app must estimate the best upcoming Claude usage window within a future time range.

### Initial scope

- next 6 hours
- next 12 hours
- next 24 hours

Output example:

- Best next window: 01:00–05:00 local time
- Confidence: medium
- Why: US off-hours + no expected business-hour overlap spike

---

## 8.10 Local API

The app must expose a lightweight localhost API so external tools can query the recommendation.

### Initial endpoints

- `GET /health`
- `GET /score`
- `GET /recommendation`
- `GET /capacity`
- `GET /best-window`
- `GET /explain`

### Example response

```json
{
  "surface": "desktop",
  "mode": "limit_risk",
  "window_score": 74,
  "state": "efficient",
  "estimated_queries_min": 26,
  "estimated_queries_max": 41,
  "estimated_tokens_min": 190000,
  "estimated_tokens_max": 280000,
  "confidence": "medium",
  "reasons": [
    "Off-peak US hours",
    "No active incident",
    "Favorable weekend adjustment"
  ]
}
```

The API must be local-only by default.

---

## 8.11 Settings

The app must include a settings panel where the user can configure:

- selected Claude plan
- workload profile
- primary displayed surface
- active mode
- refresh interval
- holiday regions
- whether local telemetry is enabled
- whether menu bar notifications are enabled

---

## 9. Data Inputs

## 9.1 Official status inputs

The app should use official Anthropic service health/status information for reliability scoring and as a secondary modifier in efficiency scoring.

### Use cases

- detect active incidents
- detect degraded components
- apply reliability penalties
- lower confidence when service instability exists

---

## 9.2 Heuristic timing inputs

The app should estimate load pressure using modeled demand heuristics such as:

- US working hours
- Europe working hours
- Asia-Pacific working hours
- overlap between major regions
- weekday vs weekend
- public holidays
- seasonal business slowdowns

These are not direct demand measurements; they are predictive proxies.

---

## 9.3 User-local telemetry

The app should optionally collect local historical observations to improve recommendations over time.

### Examples

- times when user hit session limits quickly
- times when user got unusually long sessions
- user-reported good/bad windows
- optional API latency/error data if relevant

For v1, telemetry may be lightweight and mostly user-entered or inferred conservatively.

---

## 10. Scoring Model

The app requires two separate internal scores.

## 10.1 Limit Efficiency Score

Purpose: estimate how favorable the current moment is for maximizing useful Claude session capacity.

### Major inputs

- current local time
- modeled regional business-hour overlap
- weekday/weekend
- holiday status
- seasonal adjustment
- plan configuration
- workload profile
- optional user-local historical outcomes
- optional reliability penalty

### Output

- score from 0 to 100
- state label
- confidence
- estimated query range
- estimated token range

---

## 10.2 Reliability Score

Purpose: estimate technical smoothness and short-term service stability.

### Major inputs

- official component status
- unresolved incidents
- recent incident frequency
- optional local observed latency/error patterns

### Output

- score from 0 to 100
- state label
- confidence
- reasons

---

## 10.3 Confidence model

The app should explicitly estimate confidence.

### Confidence should be higher when

- official status data is current
- the scoring signals agree with each other
- user telemetry is sufficient

### Confidence should be lower when

- only calendar heuristics are driving the prediction
- service state is ambiguous
- the app lacks user-specific history

Confidence labels:

- High
- Medium
- Low

---

## 11. UX Requirements

## 11.1 Menu bar icon behavior

The icon must:

- update automatically
- be legible at small size
- show meaningful color state immediately
- remain visually minimal and unobtrusive

---

## 11.2 Dropdown layout

The dropdown should show, in order:

1. Current state and score
2. Selected surface and mode
3. Estimated query range
4. Estimated token range
5. Confidence
6. Top reasons
7. Best next window
8. Quick actions / refresh / settings

---

## 11.3 Onboarding

Initial setup should be short and ask for:

- plan
- primary surface
- workload profile
- holiday region(s)
- whether to enable local telemetry

The user should be able to complete onboarding in under 2 minutes.

---

## 12. Technical Requirements

## 12.1 Platform

- macOS only for initial release
- native desktop implementation preferred

## 12.2 Recommended stack

- **Swift**
- **SwiftUI**
- **MenuBarExtra** for menu bar integration
- local persistence via lightweight database or JSON store
- tiny localhost HTTP server for local API

## 12.3 Performance

The app should:

- launch quickly
- use minimal CPU and memory
- refresh in background without noticeable drain
- degrade gracefully when external data is unavailable

## 12.4 Privacy

- local-first by default
- no external telemetry upload required for core functionality
- all user-entered settings stored locally
- local API disabled or restricted unless explicitly enabled

---

## 13. MVP Scope

## Included in MVP

- macOS menu bar app
- colored Claude icon
- support for Desktop / Code / API surfaces
- user-selectable primary surface
- Limit Risk Mode
- Reliability Mode
- user-configured plan and workload profile
- score + state + confidence
- estimated query/token ranges
- timing/holiday/seasonality heuristics
- official status integration for reliability
- local API endpoints
- best-next-window estimate

## Excluded from MVP

- machine-learned personalization
- exact quota reading
- cloud sync
- mobile app
- cross-provider routing
- multi-user/team support

---

## 14. Future Versions

## V2

- adaptive calibration based on actual user outcomes
- surface-specific historical learning
- notifications when a green window opens
- more granular holiday/business calendars
- richer manual history inputs

## V3

- provider comparison across Claude / OpenAI / Gemini
- routing recommendations for multi-model workflows
- optional MCP/server integration
- predictive session-efficiency curves across the next 24 hours

---

## 15. Success Metrics

## User-value metrics

- user checks app before Claude session start
- user reports improved timing decisions
- user perceives fewer “wasted” session starts during peak windows
- user reports ranges as directionally useful

## Product metrics

- onboarding completion rate
- active daily menu bar opens
- local API call frequency
- % of recommendations with medium or high confidence
- % of sessions where user later confirms recommendation was accurate

---

## 16. Risks

### 1. Overclaiming precision
Risk: users may interpret estimates as official remaining quota.

Mitigation: clearly label outputs as estimates and ranges.

### 2. Weak initial personalization
Risk: early predictions may feel generic.

Mitigation: keep confidence explicit and make the value proposition “rough but useful” at launch.

### 3. Status vs efficiency confusion
Risk: users may conflate technical uptime with session efficiency.

Mitigation: maintain separate modes and separate labels.

### 4. Limited official observability
Risk: no direct public real-time global demand feed exists.

Mitigation: build around reliable official health data plus honest heuristics.

---

## 17. Open Questions

These questions remain for implementation detail, not product definition:

- Should the icon reflect only one selected surface or optionally the worst state across enabled surfaces?
- Should estimated capacity be shown both in raw tokens and in “equivalent medium prompts”?
- How aggressively should the app learn from user history by default?
- Should notifications for favorable windows be included in MVP or deferred to V2?
- Should the local API require a local token/auth mechanism even on localhost?

---

## 18. Initial Release Statement

Claude Window is a macOS menu bar utility that estimates the best times to use Claude, prioritizing subscription usage efficiency and optionally service reliability. It gives the user an immediate visual signal, estimated query/token capacity, and a local API for automation — all in a compact, local-first experience.

