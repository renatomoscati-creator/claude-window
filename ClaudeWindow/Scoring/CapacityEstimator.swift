import Foundation

enum CapacityEstimator {

    static func estimate(
        efficiencyScore: Int,
        plan: Plan,
        workload: WorkloadProfile,
        confidence: Confidence,
        customPlan: CustomPlanSettings? = nil
    ) -> QueryCapacity {
        let baseQueries = customPlan?.baseQueryLimit ?? plan.baseQueryLimit

        // Scale base by efficiency: score=100 → 80% of base, score=0 → 0%
        let efficiencyFactor = (Double(efficiencyScore) / 100.0) * 0.80
        let midEstimate = Double(baseQueries) * efficiencyFactor

        let spread: Double
        switch confidence {
        case .high:   spread = 0.15
        case .medium: spread = 0.30
        case .low:    spread = 0.50
        }

        let minQ = Int(max(1, midEstimate * (1 - spread)))
        let maxQ = max(minQ, Int(midEstimate * (1 + spread)))

        return QueryCapacity(
            minQueries: minQ,
            maxQueries: maxQ,
            minTokens: minQ * workload.tokensPerQuery,
            maxTokens: maxQ * workload.tokensPerQuery,
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
