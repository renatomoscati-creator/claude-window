import SwiftUI

// MARK: - Spectrum Metric Type

enum SpectrumMetricType {
    case queries
    case tokens
    
    /// Base colors for the spectrum gradient
    var startColor: Color {
        switch self {
        case .queries:
            return .blue
        case .tokens:
            return .purple
        }
    }
    
    var endColor: Color {
        switch self {
        case .queries:
            return .cyan
        case .tokens:
            return .pink
        }
    }
    
    /// Color for the active range indicator
    var activeColor: Color {
        switch self {
        case .queries:
            return .green
        case .tokens:
            return .orange
        }
    }
}

// MARK: - Spectrum Bar View

struct SpectrumBar: View {
    let minValue: Int
    let maxValue: Int
    let maxPossible: Int
    let metricType: SpectrumMetricType
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let startRatio = CGFloat(minValue) / CGFloat(maxPossible)
            let endRatio = CGFloat(maxValue) / CGFloat(maxPossible)
            
            let startX = startRatio * width
            let endX = endRatio * width
            
            ZStack(alignment: .leading) {
                // Background spectrum gradient
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                metricType.startColor.opacity(0.3),
                                metricType.startColor.opacity(0.5),
                                metricType.endColor.opacity(0.5),
                                metricType.endColor.opacity(0.3)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 12)
                
                // Active range highlight
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                metricType.activeColor,
                                metricType.activeColor.opacity(0.9)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(endX - startX, 8), height: 16)
                    .offset(x: startX)
                    .shadow(color: metricType.activeColor.opacity(0.4), radius: 4, x: 0, y: 2)
                
                // Min marker
                Circle()
                    .fill(Color.white)
                    .frame(width: 4, height: 4)
                    .shadow(radius: 1)
                    .offset(x: startX - 2)
                
                // Max marker
                Circle()
                    .fill(Color.white)
                    .frame(width: 4, height: 4)
                    .shadow(radius: 1)
                    .offset(x: endX - 2)
            }
        }
        .frame(height: 16)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        SpectrumBar(
            minValue: 15,
            maxValue: 35,
            maxPossible: 100,
            metricType: .queries
        )
        
        SpectrumBar(
            minValue: 2000,
            maxValue: 8000,
            maxPossible: 15000,
            metricType: .tokens
        )
    }
    .padding()
}
