import SwiftUI

struct MenuBarIconView: View {
    let state: WindowState

    var body: some View {
        Image(systemName: "sparkle")
            .symbolRenderingMode(.palette)
            .foregroundStyle(iconColor, .primary)
            .imageScale(.medium)
    }

    private var iconColor: Color {
        switch state {
        case .efficient: return .green
        case .average:   return .yellow
        case .highRisk:  return .orange
        case .poor:      return .red
        case .unknown:   return .gray
        }
    }
}
