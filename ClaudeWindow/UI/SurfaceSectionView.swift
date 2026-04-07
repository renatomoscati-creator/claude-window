import SwiftUI

struct SurfaceSectionView: View {
    let surface: Surface
    let effScore: WindowScore?
    let relScore: WindowScore?
    let activeMode: OperatingMode

    var body: some View {
        let active = activeMode == .limitRisk ? effScore : relScore
        HStack {
            Circle()
                .fill(stateColor(active?.state ?? .unknown))
                .frame(width: 8, height: 8)
            Text(surface.displayName)
                .font(.caption)
            Spacer()
            Text(active.map { "\($0.score)" } ?? "—")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func stateColor(_ state: WindowState) -> Color {
        switch state {
        case .efficient: return .green
        case .average:   return .yellow
        case .highRisk:  return .orange
        case .poor:      return .red
        case .unknown:   return .gray
        }
    }
}
