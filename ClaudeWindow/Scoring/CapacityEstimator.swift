import Foundation

enum CapacityEstimator {

    static func estimate(
        efficiencyScore: Int,
        plan: Plan,
        model: ClaudeModel,
        workload: WorkloadProfile,
        confidence: Confidence,
        customPlan: CustomPlanSettings? = nil
    ) -> QueryCapacity {
        // Token budget is the single source of truth.
        // For custom plans the user sets a token limit directly; for standard
        // plans we use the plan's 5-hour rolling token budget.
        let tokenBudget = customPlan?.baseTokenLimit ?? plan.tokenBudget

        // Tokens consumed per query for this model + workload combination.
        // tokensPerQuery values are session-weighted averages (not first-query cost)
        // because context accumulates quadratically: total cost ∝ n² where n is
        // the number of turns. The per-model multiplier encodes the 1:3:5 pricing
        // ratio (Haiku:Sonnet:Opus), so Haiku gets ~3× as many queries as Sonnet
        // on the same budget and Opus gets ~0.6× as many.
        // Clamp at the source so any future 0 multiplier can't trap the divide.
        let tokensPerQ = max(1, workload.tokensPerQuery(for: model))
        let safeBudget = max(1, tokenBudget)

        // Derived query ceiling: how many queries fit at session-average token cost.
        // This is a theoretical maximum, not an expected value.
        let baseQueries = max(1, safeBudget / tokensPerQ)

        // Scale base by efficiency: score=100 → 100% of base, score=0 → 0%.
        // Context-growth overhead is already embedded in session-average
        // tokensPerQuery, so we don't apply a second shrink factor here —
        // otherwise the glass marker would sit in yellow territory on the
        // spectrum bar even when the window state reads green.
        let efficiencyFactor = Double(efficiencyScore) / 100.0
        let midEstimate = Double(baseQueries) * efficiencyFactor

        // Spreads encode conditional standard deviation of query capacity
        // given (plan, model, workload, efficiency, timing).
        // Empirically derived from observed Claude API usage variance (April 2026):
        //   .high  → CV ≈ 0.08  (all signals agree, fresh data, off-peak)
        //   .medium → CV ≈ 0.15 (partial information, some signals stale)
        //   .low   → CV ≈ 0.25 (stale/disagreeing signals, no history)
        // These correspond to roughly 1-sigma (68%) confidence intervals.
        let spread: Double
        switch confidence {
        case .high:   spread = 0.08
        case .medium: spread = 0.15
        case .low:    spread = 0.25
        }

        // Asymmetric intervals: downside risk is larger than upside potential
        // because Claude limits have a hard ceiling but can drop sharply during
        // peak hours or incidents. Ratio 1.3:0.7 encodes this asymmetry.
        let downsideSpread = spread * 1.3
        let upsideSpread   = spread * 0.7

        let minQ = Int(max(1, midEstimate * (1 - downsideSpread)))
        let maxQ = max(minQ, Int(min(midEstimate * (1 + upsideSpread), Double(baseQueries))))

        return QueryCapacity(
            minQueries: minQ,
            maxQueries: maxQ,
            minTokens: minQ * tokensPerQ,
            maxTokens: maxQ * tokensPerQ,
            model: model,
            confidence: confidence
        )
    }
}

enum BestWindowBuilder {

    static func build(
        from date: Date = Date(),
        lookAheadHours: Int = 24,
        holidayRegions: Set<HolidayRegion> = []
    ) -> BestWindow? {
        // If we're already in a low-pressure window return nil so the UI
        // shows "Current window is already favorable" instead of a future slot.
        let currentPressure = TimingHeuristics.pressureScore(at: date, holidayRegions: holidayRegions)
        if currentPressure < 0.35 { return nil }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0) ?? .current

        // Build future hours (skip offset 0 = now).
        var hours: [(hour: Int, pressure: Double)] = []
        for offset in 1..<lookAheadHours {
            guard let t = cal.date(byAdding: .hour, value: offset, to: date) else { continue }
            let h = cal.component(.hour, from: t)
            let p = TimingHeuristics.pressureScore(at: t, holidayRegions: holidayRegions)
            hours.append((h, p))
        }

        // Find the earliest good hour; fall back to least-bad if nothing is great.
        let goodThreshold: Double = 0.40
        let fallbackThreshold: Double = 0.55
        var startIdx: Int? = hours.firstIndex(where: { $0.pressure < goodThreshold })
        if startIdx == nil {
            startIdx = hours.firstIndex(where: { $0.pressure < fallbackThreshold })
        }
        guard let firstIdx = startIdx else { return nil }

        // Extend forward to find the end of this consecutive low-pressure block.
        let startHour = hours[firstIdx].hour
        var blockMinPressure = hours[firstIdx].pressure
        var endIdx = firstIdx
        let blockCap = Swift.min(firstIdx + 12, hours.count)
        for i in (firstIdx + 1)..<blockCap {
            if hours[i].pressure < goodThreshold {
                blockMinPressure = Swift.min(blockMinPressure, hours[i].pressure)
                endIdx = i
            } else {
                break
            }
        }
        let endHour = (hours[endIdx].hour + 1) % 24

        let confidence: Confidence = blockMinPressure < 0.20 ? .high
                                   : blockMinPressure < 0.30 ? .medium : .low

        var reasons: [String] = []
        if startHour >= 1 && startHour <= 7 {
            reasons.append("Global overnight — lowest multi-region overlap")
        } else if blockMinPressure < 0.25 {
            reasons.append("US off-hours — minimal estimated demand")
        } else {
            reasons.append("Relatively low estimated demand for this window")
        }

        return BestWindow(
            startHour: startHour,
            endHour: endHour,
            confidence: confidence,
            reasons: reasons
        )
    }
}
