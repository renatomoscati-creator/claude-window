## 2026-04-18 00:00
- produced GTM plan. no file changes. strategy only.

## 2026-04-18 12:00
- removed showForecast toggle state + slider button from DropdownView. ForecastStrip always visible in bestWindowSection.

## 2026-04-18 12:21
- removed SpectrumBar from capacitySection queries row. queries now text-only.

## 2026-04-18 12:35
- rewrote README: product framing, download CTA top, privacy bullets, collapsible build instructions
- updated GitHub repo description + added topics via gh
- saved hero screenshot docs/screenshots/hero.png
- created scripts/build-dmg.sh (needs brew install create-dmg)
- created scripts/homebrew/claude-window.rb cask formula skeleton
- created docs/launch-content.md: Reddit posts, X thread, PH copy, signing checklist
- reverted DEMO_OVERRIDE from LimitEfficiencyScorer.swift

## 2026-04-18 14:00
- removed DEMO_OVERRIDE from LimitEfficiencyScorer.swift. score now real again.

## 2026-04-19 13:45
- updated graphify graph. 422 nodes, 545 edges, 34 communities. new docs/images/code extracted.

## 2026-04-20 00:00
- fixed ForecastStrip frozen at 6pm-6am. wrapped in TimelineView(.everyMinute). ForecastStrip now takes `now: Date` param instead of calling Date() internally.
