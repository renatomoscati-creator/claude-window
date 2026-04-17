import SwiftUI

// MARK: - Spectrum Metric Type

enum SpectrumMetricType {
    case queries
    case tokens
    /// Per-query cost: green (cheap) → red (expensive), left to right.
    /// Higher value = more expensive = further right = more red.
    case cost

    var gradientColors: [Color] {
        // Hues match the 12-hour forecast bars below so the whole dropdown
        // reads in one palette: solid red / orange / yellow / green, no
        // opacity fade that would desaturate the color.
        switch self {
        case .queries, .tokens:
            // low = red (bad), high = green (good)
            return [.red, .orange, .yellow, .green]
        case .cost:
            // cheap = green (left), expensive = red (right)
            return [.green, .yellow, .orange, .red]
        }
    }

    var glassHighlight: Color { .white }
}

// MARK: - Spectrum Bar View

struct SpectrumBar: View {
    let minValue: Int
    let maxValue: Int
    let maxPossible: Int
    let metricType: SpectrumMetricType
    /// When set, the bar fills with this solid color instead of the rainbow
    /// gradient. Used to tie the queries bar to the current window state so
    /// it reads the same color as the 12-hour forecast and the header badge.
    var tint: Color? = nil

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let startRatio = CGFloat(minValue) / CGFloat(maxPossible)
            let endRatio = CGFloat(maxValue) / CGFloat(maxPossible)

            let startX = startRatio * width
            let endX = endRatio * width

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundGradient)
                    .frame(height: 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                    )

                GlassHighlight(
                    startX: startX,
                    width: max(endX - startX, 12)
                )
            }
        }
        .frame(height: 16)
    }

    private var backgroundGradient: LinearGradient {
        let colors: [Color]
        if let tint {
            // Solid single-hue so the queries bar reads as the same color
            // as the 12-hour forecast bars below — same hue, same value,
            // no rainbow or opacity fade that would desaturate it.
            colors = [tint, tint]
        } else {
            colors = metricType.gradientColors
        }
        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .leading,
            endPoint: .trailing
        )
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
