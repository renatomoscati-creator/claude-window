import SwiftUI

// MARK: - Spectrum Metric Type

enum SpectrumMetricType {
    case queries
    case tokens
    
    /// Spectrum goes from red (left) to green (right) for both types
    var gradientColors: [Color] {
        [
            .red.opacity(0.4),
            .red.opacity(0.6),
            .orange.opacity(0.7),
            .yellow.opacity(0.7),
            .green.opacity(0.7),
            .green.opacity(0.4)
        ]
    }
    
    /// Glass highlight color for the active range
    var glassHighlight: Color {
        .white
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
                // Background spectrum gradient (red to green)
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: metricType.gradientColors),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
                
                // Active range highlight - Glass morphism effect
                GlassHighlight(
                    startX: startX,
                    width: max(endX - startX, 12)
                )
            }
        }
        .frame(height: 16)
    }
}

// MARK: - Glass Highlight Component

struct GlassHighlight: View {
    let startX: CGFloat
    let width: CGFloat
    
    var body: some View {
        ZStack {
            // Base glass layer - frosted glass effect
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    .ultraThinMaterial,
                    style: FillStyle()
                )
                .frame(width: width, height: 20)
                .offset(x: startX)
            
            // Glass overlay with gradient
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.2)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: width, height: 20)
                .offset(x: startX)
            
            // Inner highlight for liquid glass effect
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.6),
                            Color.white.opacity(0.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width - 2, height: 10)
                .offset(x: startX)
            
            // Outer glow
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.5),
                            Color.white.opacity(0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .frame(width: width, height: 20)
                .offset(x: startX)
                .shadow(color: .white.opacity(0.3), radius: 3, x: 0, y: 1)
            
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
                .offset(x: startX + width - 2)
        }
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
            minValue: 7500,
            maxValue: 42000,
            maxPossible: 500000,
            metricType: .tokens
        )
    }
    .padding()
    .background(Color.black.opacity(0.3))
}
