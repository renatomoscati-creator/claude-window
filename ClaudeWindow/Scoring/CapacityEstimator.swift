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
        let baseQueries = customPlan?.baseQueryLimit ?? plan.baseQueryLimit(for: model)

        // Scale base by efficiency: score=100 → 80% of base, score=0 → 0%.
        // The 0.80 ceiling reserves 20% headroom for burst/overhead.
        let efficiencyFactor = (Double(efficiencyScore) / 100.0) * 0.80
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

        // Model-aware token calculation
        let tokensPerQ = workload.tokensPerQuery(for: model)

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
        let windows = TimingHeuristics.bestOffPeakWindows(
            from: date, lookAheadHours: lookAheadHours, holidayRegions: holidayRegions
        )
        guard let best = windows.first else { return nil }

        let confidence: Confidence = best.pressureScore < 0.2 ? .high
                                   : best.pressureScore < 0.35 ? .medium : .low

        var reasons: [String] = []
        if best.pressureScore < 0.25 {
            reasons.append("US off-hours — minimal estimated demand")
        }
        if best.startHour >= 1 && best.startHour <= 7 {
            reasons.append("Global overnight — lowest multi-region overlap")
        }
        if reasons.isEmpty {
            reasons.append("Relatively low estimated demand for this window")
        }

        return BestWindow(
            startHour: best.startHour,
            endHour: best.endHour,
            confidence: confidence,
            reasons: reasons
        )
    }
}
