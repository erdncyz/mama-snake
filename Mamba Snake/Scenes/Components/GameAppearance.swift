import SwiftUI

enum ArenaTheme: String, CaseIterable, Identifiable {
    case midnight, forest, ocean, dusk
    var id: String { rawValue }
    var title: String {
        switch self {
        case .midnight: return "Gece"
        case .forest: return "Orman"
        case .ocean: return "Okyanus"
        case .dusk: return "Gün batımı"
        }
    }
    var colors: [Color] {
        switch self {
        case .midnight: return [Color(red: 0.04, green: 0.09, blue: 0.15), Color(red: 0.08, green: 0.18, blue: 0.23)]
        case .forest: return [Color(red: 0.03, green: 0.12, blue: 0.10), Color(red: 0.13, green: 0.28, blue: 0.20)]
        case .ocean: return [Color(red: 0.03, green: 0.10, blue: 0.24), Color(red: 0.06, green: 0.30, blue: 0.36)]
        case .dusk: return [Color(red: 0.15, green: 0.07, blue: 0.23), Color(red: 0.35, green: 0.17, blue: 0.23)]
        }
    }
}

enum MambaStyle {
    static let mint = Color(red: 0.65, green: 0.96, blue: 0.55)
    static let surface = Color(red: 0.07, green: 0.12, blue: 0.15)
}

struct ArenaBackground: View {
    var theme: ArenaTheme
    var grid = true
    var body: some View {
        ZStack {
            LinearGradient(colors: theme.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [MambaStyle.mint.opacity(0.08), .clear], center: .topTrailing, startRadius: 0, endRadius: 480)
            if grid {
                Canvas { context, size in
                    var path = Path()
                    for x in stride(from: CGFloat(0), through: size.width, by: 26) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    for y in stride(from: CGFloat(0), through: size.height, by: 26) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(path, with: .color(.white.opacity(0.045)), lineWidth: 0.5)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct MambaButtonStyle: ButtonStyle {
    var primary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.bold))
            .foregroundStyle(primary ? Color.black : .white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 17)
            .background(primary ? MambaStyle.mint : .white.opacity(0.07), in: RoundedRectangle(cornerRadius: 19))
            .overlay(RoundedRectangle(cornerRadius: 19).stroke(.white.opacity(primary ? 0 : 0.10)))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension View {
    func mambaCard() -> some View {
        self.padding(20)
            .background(MambaStyle.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.09)))
    }
}

struct CustomizationView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("menuTheme") private var menuTheme = ArenaTheme.midnight.rawValue
    @AppStorage("arenaTheme") private var arenaTheme = ArenaTheme.forest.rawValue
    @AppStorage("showArenaGrid") private var showGrid = true
    @AppStorage("soundEnabled") private var soundEnabled = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Senin oyunun.\nSenin atmosferin.")
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        Text("Menüyü ve oyun alanını ayrı ayrı kişiselleştir. Seçimlerin otomatik kaydedilir.")
                            .foregroundStyle(.secondary)
                    }
                    themePicker("MENÜ ARKA PLANI", selection: $menuTheme)
                    themePicker("OYUN ALANI", selection: $arenaTheme)
                    VStack(spacing: 20) {
                        Toggle("Oyun alanında ızgara", isOn: $showGrid)
                        Toggle("Oyun sesleri", isOn: $soundEnabled)
                    }.tint(MambaStyle.mint).mambaCard()
                }
                .padding(24)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .background(ArenaBackground(theme: ArenaTheme(rawValue: menuTheme) ?? .midnight).ignoresSafeArea())
            .navigationTitle("Özelleştir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Bitti") { dismiss() }.tint(MambaStyle.mint) } }
        }
        .preferredColorScheme(.dark)
    }

    private func themePicker(_ title: String, selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.caption.weight(.bold)).tracking(2).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], spacing: 12) {
                ForEach(ArenaTheme.allCases) { theme in
                    Button { selection.wrappedValue = theme.rawValue } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            ArenaBackground(theme: theme).frame(height: 90)
                                .overlay(alignment: .topTrailing) {
                                    if selection.wrappedValue == theme.rawValue {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(MambaStyle.mint).padding(10)
                                    }
                                }
                            Text(theme.title).font(.subheadline.bold()).padding(13)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(selection.wrappedValue == theme.rawValue ? MambaStyle.mint : .white.opacity(0.1), lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection.wrappedValue == theme.rawValue ? .isSelected : [])
                }
            }
        }
    }
}

struct SnakeIllustration: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: w * 0.18, y: h * 0.70))
                    p.addCurve(to: CGPoint(x: w * 0.52, y: h * 0.55), control1: CGPoint(x: w * 0.60, y: h * 1.04), control2: CGPoint(x: w * 0.83, y: h * 0.54))
                    p.addCurve(to: CGPoint(x: w * 0.65, y: h * 0.25), control1: CGPoint(x: w * 0.12, y: h * 0.56), control2: CGPoint(x: w * 0.27, y: h * 0.04))
                }
                .stroke(LinearGradient(colors: [Color.teal, MambaStyle.mint], startPoint: .bottomLeading, endPoint: .topTrailing), style: StrokeStyle(lineWidth: 32, lineCap: .round))
                .shadow(color: MambaStyle.mint.opacity(0.22), radius: 22, y: 8)
                Capsule().fill(MambaStyle.mint).frame(width: 60, height: 40)
                    .overlay(HStack(spacing: 12) { Circle().frame(width: 6, height: 6); Circle().frame(width: 6, height: 6) }.foregroundStyle(Color.black).offset(y: -5))
                    .rotationEffect(.degrees(20))
                    .position(x: w * 0.65, y: h * 0.25)
                Image(systemName: "sparkle").foregroundStyle(MambaStyle.mint).position(x: w * 0.82, y: h * 0.63)
                Circle().fill(Color.orange).frame(width: 10, height: 10).position(x: w * 0.22, y: h * 0.24)
            }
        }
        .accessibilityHidden(true)
    }
}
