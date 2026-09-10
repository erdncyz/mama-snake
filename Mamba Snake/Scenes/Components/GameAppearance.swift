import SwiftUI

enum ArenaTheme: String, CaseIterable, Identifiable {
    case midnight, forest, ocean, dusk

    static let storageKey = "menuTheme"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .midnight: return L10n.string("theme.midnight")
        case .forest: return L10n.string("theme.forest")
        case .ocean: return L10n.string("theme.ocean")
        case .dusk: return L10n.string("theme.dusk")
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

    /// Kart ve krom yüzey rengi — gradyanın ortasına yakın, okunabilir bir ton.
    var surface: Color {
        switch self {
        case .midnight: return Color(red: 0.07, green: 0.12, blue: 0.15)
        case .forest: return Color(red: 0.06, green: 0.16, blue: 0.13)
        case .ocean: return Color(red: 0.05, green: 0.16, blue: 0.26)
        case .dusk: return Color(red: 0.18, green: 0.09, blue: 0.20)
        }
    }

    static func resolved(_ raw: String) -> ArenaTheme {
        ArenaTheme(rawValue: raw) ?? .midnight
    }
}

enum MambaStyle {
    static let mint = Color(red: 0.65, green: 0.96, blue: 0.55)
    static let surface = ArenaTheme.midnight.surface
}

private struct MenuThemeKey: EnvironmentKey {
    static let defaultValue = ArenaTheme.midnight
}

extension EnvironmentValues {
    var menuTheme: ArenaTheme {
        get { self[MenuThemeKey.self] }
        set { self[MenuThemeKey.self] = newValue }
    }
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

// MARK: - Oyun alanı arka planı (görsel)

enum ArenaScene: String, CaseIterable, Identifiable {
    case space, neon, jungle, ocean, lava, dusk

    static let storageKey = "arenaScene"
    var id: String { rawValue }

    var title: String {
        switch self {
        case .space: return L10n.string("arena.space")
        case .neon: return L10n.string("arena.neon")
        case .jungle: return L10n.string("arena.jungle")
        case .ocean: return L10n.string("arena.ocean")
        case .lava: return L10n.string("arena.lava")
        case .dusk: return L10n.string("arena.dusk")
        }
    }

    var imageName: String {
        switch self {
        case .space: return "ArenaBg_space"
        case .neon: return "ArenaBg_neon"
        case .jungle: return "ArenaBg_jungle"
        case .ocean: return "ArenaBg_ocean"
        case .lava: return "ArenaBg_lava"
        case .dusk: return "ArenaBg_dusk"
        }
    }

    static var current: ArenaScene {
        ArenaScene(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .space
    }
}

#if canImport(UIKit)
    extension UIImage {
        /// Asset kataloğu ya da bundle içindeki JPEG'den görsel yükler.
        static func arenaBundled(_ name: String) -> UIImage? {
            if let image = UIImage(named: name) { return image }
            if let url = Bundle.main.url(forResource: name, withExtension: "jpg") {
                return UIImage(contentsOfFile: url.path)
            }
            return nil
        }
    }
#endif

/// Oyun alanının arka planı: seçilen atmosfer görseli + hafif karartma + opsiyonel ızgara.
struct ArenaSceneBackground: View {
    var scene: ArenaScene
    var grid = true

    var body: some View {
        ZStack {
            Color.black
            #if canImport(UIKit)
                if let ui = UIImage.arenaBundled(scene.imageName) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                }
            #endif
            // Oyun elemanlarının okunması için hafif karartma.
            Color.black.opacity(0.22)
            if grid { ArenaGridCanvas() }
        }
        .accessibilityHidden(true)
    }
}

struct ArenaGridCanvas: View {
    var body: some View {
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
            context.stroke(path, with: .color(.white.opacity(0.05)), lineWidth: 0.5)
        }
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

private struct MambaCardModifier: ViewModifier {
    @AppStorage(ArenaTheme.storageKey) private var menuThemeRaw = ArenaTheme.midnight.rawValue

    private var menuTheme: ArenaTheme { ArenaTheme.resolved(menuThemeRaw) }

    func body(content: Content) -> some View {
        content
            .padding(20)
            .background {
                ZStack {
                    ArenaBackground(theme: menuTheme, grid: false)
                    menuTheme.surface.opacity(0.42)
                }
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(.white.opacity(0.10))
            )
    }
}

extension View {
    func mambaCard() -> some View {
        modifier(MambaCardModifier())
    }

    func menuTheme(_ theme: ArenaTheme) -> some View {
        environment(\.menuTheme, theme)
    }
}

struct CustomizationView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(ArenaTheme.storageKey) private var menuTheme = ArenaTheme.midnight.rawValue
    @AppStorage(ArenaScene.storageKey) private var arenaScene = ArenaScene.space.rawValue
    @AppStorage("showArenaGrid") private var showGrid = true
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage(SkinDefaults.bugKey) private var bugSkin = BugSkin.spider.rawValue
    @AppStorage(SkinDefaults.snakeKey) private var snakeSkin = SnakeSkin.classic.rawValue
    @AppStorage(AppLanguage.storageKey) private var appLanguage = AppLanguage.system.rawValue

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.string("customize.hero"))
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        Text(L10n.string("customize.subtitle"))
                            .foregroundStyle(.secondary)
                    }
                    languagePicker
                    bugSkinPicker(L10n.string("customize.character"))
                    snakeSkinPicker(L10n.string("customize.snake"))
                    themePicker(L10n.string("customize.menu_background"), selection: $menuTheme)
                    arenaScenePicker(L10n.string("customize.arena"))
                    VStack(spacing: 20) {
                        Toggle(L10n.string("customize.grid"), isOn: $showGrid)
                        Toggle(L10n.string("customize.sound"), isOn: $soundEnabled)
                    }.tint(MambaStyle.mint).mambaCard()
                }
                .padding(24)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
                .id(appLanguage)
            }
            .background(ArenaBackground(theme: ArenaTheme.resolved(menuTheme)).ignoresSafeArea())
            .menuTheme(ArenaTheme.resolved(menuTheme))
            .navigationTitle(L10n.string("customize.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.string("common.done")) { dismiss() }.tint(MambaStyle.mint) } }
        }
        .preferredColorScheme(.dark)
    }

    private var languagePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("language.section"))
                .font(.caption.weight(.bold))
                .tracking(2)
                .foregroundStyle(.secondary)
            Text(L10n.string("language.description"))
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        appLanguage = language.rawValue
                    } label: {
                        Text(language.title)
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.85)
                            .padding(.horizontal, 8)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .background(
                                appLanguage == language.rawValue
                                    ? MambaStyle.mint.opacity(0.16)
                                    : .white.opacity(0.045),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        appLanguage == language.rawValue
                                            ? MambaStyle.mint
                                            : .white.opacity(0.08)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(appLanguage == language.rawValue ? MambaStyle.mint : .white)
                    .accessibilityAddTraits(appLanguage == language.rawValue ? .isSelected : [])
                }
            }
        }
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

    private func arenaScenePicker(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.caption.weight(.bold)).tracking(2).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], spacing: 12) {
                ForEach(ArenaScene.allCases) { scene in
                    Button { arenaScene = scene.rawValue } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            ZStack {
                                Color.black
                                #if canImport(UIKit)
                                    if let ui = UIImage.arenaBundled(scene.imageName) {
                                        Image(uiImage: ui).resizable().scaledToFill()
                                    }
                                #endif
                            }
                            .frame(height: 90)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .contentShape(Rectangle())
                            .overlay(alignment: .topTrailing) {
                                if arenaScene == scene.rawValue {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(MambaStyle.mint).padding(10)
                                }
                            }
                            Text(scene.title).font(.subheadline.bold()).padding(13)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(arenaScene == scene.rawValue ? MambaStyle.mint : .white.opacity(0.1), lineWidth: 2))
                        .contentShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(scene.title)
                    .accessibilityAddTraits(arenaScene == scene.rawValue ? .isSelected : [])
                }
            }
        }
    }

    private func bugSkinPicker(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.caption.weight(.bold)).tracking(2).foregroundStyle(.secondary)
            Text(L10n.string("customize.character_help"))
                .font(.footnote).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(BugSkin.allCases) { skin in
                    skinTile(title: skin.title, isSelected: bugSkin == skin.rawValue) {
                        bugSkin = skin.rawValue
                    } preview: {
                        if skin == .spider {
                            SkinPreview.gif("Spider")
                        } else {
                            SkinPreview.image(skin.imageName ?? "Bug")
                        }
                    }
                }
            }
        }
    }

    private func snakeSkinPicker(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.caption.weight(.bold)).tracking(2).foregroundStyle(.secondary)
            Text(L10n.string("customize.snake_help"))
                .font(.footnote).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                ForEach(SnakeSkin.allCases) { skin in
                    skinTile(title: skin.title, isSelected: snakeSkin == skin.rawValue) {
                        snakeSkin = skin.rawValue
                    } preview: {
                        SkinPreview.image(skin.previewImageName)
                    }
                }
            }
        }
    }

    private func skinTile<Preview: View>(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder preview: () -> Preview
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                preview()
                    .frame(maxWidth: .infinity)
                    .frame(height: 72)
                    .padding(.top, 12)
                    .padding(.horizontal, 10)
                    .clipped()
                HStack(spacing: 4) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(MambaStyle.mint)
                            .accessibilityHidden(true)
                    }
                    Text(title)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity)
            .background(
                (isSelected ? MambaStyle.mint.opacity(0.12) : Color.white.opacity(0.04)),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? MambaStyle.mint : .white.opacity(0.1), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? MambaStyle.mint : .white)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Skin önizleme yardımcısı

enum SkinPreview {
    /// Animasyonlu GIF önizlemesi (pixel-art için keskin ölçekleme).
    @ViewBuilder static func gif(_ name: String) -> some View {
        #if canImport(UIKit)
            GifImageView(gifName: name)
        #else
            Image(systemName: "ant.fill")
        #endif
    }

    /// Asset kataloğu veya bundle görselinden statik önizleme.
    @ViewBuilder static func image(_ name: String) -> some View {
        #if canImport(UIKit)
            if let ui = UIImage(named: name) {
                Image(uiImage: ui)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "hexagon.fill").foregroundStyle(.green)
            }
        #else
            Image(systemName: "hexagon.fill")
        #endif
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

/// Ana ekran maskotu: kullanıcının animasyonlu (GIF'li) yılanı.
/// UIKit yoksa vektör çizime düşer.
struct HeroSnake: View {
    var body: some View {
        #if canImport(UIKit)
            GifImageView(gifName: "LaunchScreen")
                .shadow(color: MambaStyle.mint.opacity(0.28), radius: 18, y: 8)
                .accessibilityHidden(true)
        #else
            SnakeIllustration()
        #endif
    }
}
