import SwiftUI

enum ClockTheme: String, CaseIterable {
    case system = "系统"
    case light = "浅色"
    case dark = "深色"
    case market = "上涨"

    var colorScheme: ColorScheme? {
        switch self {
        case .system, .market: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct MarketPalette {
    let scheme: ColorScheme

    var canvas: Color { color(0xFFF6F5, 0x231419) }
    var surface: Color { color(0xFFFFFF, 0x301C24) }
    var wash: Color { color(0xFFE4E7, 0x4C2632) }
    var border: Color { color(0xEFCDD2, 0x674050) }
    var accent: Color { color(0xC11E3C, 0xFF8194) }
    var ink: Color { color(0x2D171F, 0xFFF0F2) }
    var muted: Color { color(0x77535D, 0xDCB6BF) }

    var cardFill: LinearGradient {
        LinearGradient(colors: [wash, surface], startPoint: .topTrailing, endPoint: .bottomLeading)
    }

    private func color(_ light: UInt32, _ dark: UInt32) -> Color {
        let hex = scheme == .dark ? dark : light
        return Color(red: Double((hex >> 16) & 255) / 255,
                     green: Double((hex >> 8) & 255) / 255,
                     blue: Double(hex & 255) / 255)
    }
}

struct EarningsChart: View {
    let snapshot: SalarySnapshot
    let palette: MarketPalette

    var body: some View {
        Canvas { context, size in
            let plot = CGRect(x: 4, y: 5, width: max(0, size.width - 8), height: max(0, size.height - 10))
            var grid = Path()
            for level in [0.0, 0.5, 1.0] {
                let y = plot.minY + level * plot.height
                grid.move(to: CGPoint(x: plot.minX, y: y))
                grid.addLine(to: CGPoint(x: plot.maxX, y: y))
            }
            context.stroke(grid, with: .color(palette.border), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

            let points = snapshot.earningsTimeline.map {
                CGPoint(x: plot.minX + $0.elapsed * plot.width, y: plot.maxY - $0.earned * plot.height)
            }
            guard let start = points.first, let end = points.last else { return }
            let line = Path { $0.addLines(points) }

            var area = line
            area.addLine(to: CGPoint(x: end.x, y: plot.maxY))
            area.addLine(to: CGPoint(x: start.x, y: plot.maxY))
            area.closeSubpath()
            context.fill(area, with: .linearGradient(
                Gradient(colors: [palette.accent.opacity(0.24), palette.accent.opacity(0.02)]),
                startPoint: CGPoint(x: plot.midX, y: plot.minY), endPoint: CGPoint(x: plot.midX, y: plot.maxY)
            ))
            context.stroke(line, with: .color(palette.accent), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            let marker = Path(ellipseIn: CGRect(x: end.x - 3.5, y: end.y - 3.5, width: 7, height: 7))
            context.fill(marker, with: .color(palette.accent))
            context.stroke(marker, with: .color(palette.surface), lineWidth: 1.25)
        }
        .frame(height: 78)
        .accessibilityHidden(true)
    }
}

struct MarketMiniAmount: View {
    let amount: String
    let progress: Double
    let opacity: Double
    let palette: MarketPalette

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14)
        HStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(palette.wash, in: RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
            Text(amount)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .foregroundStyle(palette.accent)
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.cardFill.opacity(opacity), in: shape)
        .overlay(alignment: .bottomLeading) {
            MarketProgress(progress: progress, palette: palette)
                .frame(height: 2)
                .padding(.horizontal, 13)
                .padding(.bottom, 3)
                .allowsHitTesting(false)
        }
        .overlay { shape.strokeBorder(palette.border.opacity(opacity), lineWidth: 1).allowsHitTesting(false) }
    }
}

struct MarketProgress: View {
    let progress: Double
    let palette: MarketPalette

    var body: some View {
        GeometryReader { geometry in
            Capsule()
                .fill(palette.wash)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(palette.accent)
                        .frame(width: geometry.size.width * progress)
                }
        }
    }
}
