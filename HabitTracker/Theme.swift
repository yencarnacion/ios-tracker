import SwiftUI
import HabitCore

enum BloomStyle {
    static let coral = Color(hex: 0xFF557D)
    static let mint = Color(hex: 0x37D7B4)
    static let ink = Color(hex: 0x202B2A)
    static let secondary = Color(hex: 0x7D8585)
    static let canvas = Color(hex: 0xF7F8FA)
    static let pinkTrack = Color(hex: 0xFFDBE8)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}

extension HabitTint {
    var background: Color {
        switch self {
        case .mint: Color(hex: 0xEAF9F5)
        case .rose: Color(hex: 0xFFECEE)
        case .lavender: Color(hex: 0xF1EDFC)
        case .sky: Color(hex: 0xEAF5FC)
        case .peach: Color(hex: 0xFFF1E5)
        case .lemon: Color(hex: 0xFFF8DA)
        }
    }
    var accent: Color {
        switch self {
        case .mint: Color(hex: 0x29BE9D)
        case .rose: BloomStyle.coral
        case .lavender: Color(hex: 0xA084DC)
        case .sky: Color(hex: 0x55B8D7)
        case .peach: Color(hex: 0xEEA357)
        case .lemon: Color(hex: 0xE1B835)
        }
    }
}

struct ProgressRing: View {
    var progress: Double
    var color: Color = BloomStyle.coral
    var track: Color = BloomStyle.pinkTrack
    var lineWidth: CGFloat = 2
    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            if progress > 0 {
                Circle().trim(from: 0, to: min(1, max(0, progress)))
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }.accessibilityHidden(true)
    }
}

struct RoundButton: View {
    let symbol: String
    let label: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 19, weight: .medium))
                .foregroundStyle(BloomStyle.ink).frame(width: 46, height: 46)
                .background(.white.opacity(0.7), in: Circle())
                .overlay(Circle().strokeBorder(.black.opacity(0.07)))
        }.accessibilityLabel(label)
    }
}

struct PrimaryButton: View {
    var title: String
    var symbol: String? = nil
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let symbol { Image(systemName: symbol) }
                Text(title)
            }.font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white).padding(.horizontal, 28).padding(.vertical, 15)
                .background(BloomStyle.coral, in: Capsule())
        }.buttonStyle(.plain)
    }
}

extension Date {
    var dayTitle: String {
        if Calendar.current.isDateInToday(self) { return "Today" }
        if Calendar.current.isDateInYesterday(self) { return "Yesterday" }
        if Calendar.current.isDateInTomorrow(self) { return "Tomorrow" }
        return formatted(.dateTime.month(.abbreviated).day())
    }
}
