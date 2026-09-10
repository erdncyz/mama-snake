import SwiftUI

struct GameOverlayView: View {
    @ObservedObject var gameManager = GameManager.shared
    var onResume: () -> Void
    var onRestart: () -> Void
    var onNextLevel: () -> Void
    var onStart: () -> Void
    var onContinue: () -> Void
    var onMainMenu: () -> Void

    @State private var showInstructions = false
    @State private var showLeaderboard = false
    @State private var showCustomization = false
    @State private var showNicknamePrompt = false
    @State private var tempNickname = ""
    @State private var isEditingFromMenu = false
    @AppStorage("menuTheme") private var menuTheme = ArenaTheme.midnight.rawValue

    var body: some View {
        ZStack {
            if gameManager.showLanding { landingContent }
            if gameManager.isGameOver || gameManager.isLevelComplete {
                modal {
                    Image(systemName: gameManager.isLevelComplete ? "checkmark.seal.fill" : "flag.checkered")
                        .font(.system(size: 46)).foregroundStyle(MambaStyle.mint)
                    Text(gameManager.isLevelComplete ? "Seviye \(gameManager.level) tamamlandı!" : "Bir tur daha?")
                        .font(.system(.largeTitle, design: .rounded).bold())
                    Text(gameManager.isLevelComplete ? "Yeni bir meydan okuma seni bekliyor." : "Her deneme yeni bir rekorun başlangıcı.")
                        .foregroundStyle(.secondary)
                    HStack {
                        metric("SKOR", value: "\(gameManager.score)")
                        Spacer()
                        metric("SEVİYE", value: "\(gameManager.level)")
                        Spacer()
                        metric("REKOR", value: "\(gameManager.highScore)")
                    }.mambaCard()
                    if gameManager.isLevelComplete {
                        Text("+\(gameManager.lastLevelBonus) bölüm bonusu").foregroundStyle(MambaStyle.mint)
                        nextLevelCard
                    }
                    Button(action: gameManager.isLevelComplete ? onNextLevel : onRestart) {
                        Label(gameManager.isLevelComplete ? "Seviye \(gameManager.level + 1) — Başla" : "Tekrar oyna", systemImage: "arrow.right")
                    }.buttonStyle(MambaButtonStyle(primary: true))
                    if !gameManager.isLevelComplete {
                        Button {
                            AdMobService.shared.showRewardedAd { gameManager.revive() }
                        } label: { Label("Reklam izle · +1 can", systemImage: "play.rectangle") }
                            .buttonStyle(MambaButtonStyle())
                    }
                    Button("Liderlik tablosu") { showLeaderboard = true }.buttonStyle(MambaButtonStyle())
                    Button("Ana menü", action: onMainMenu).frame(minHeight: 44).foregroundStyle(.secondary)
                }
            } else if gameManager.isPaused && !gameManager.showLanding {
                modal {
                    Image(systemName: "pause.circle").font(.system(size: 48)).foregroundStyle(MambaStyle.mint)
                    Text("Küçük bir mola").font(.system(.largeTitle, design: .rounded).bold())
                    Text("Hazır olduğunda kaldığın yerden devam et.").foregroundStyle(.secondary)
                    Button(action: onResume) { Label("Devam et", systemImage: "play.fill") }.buttonStyle(MambaButtonStyle(primary: true))
                    Button { showCustomization = true } label: { Label("Özelleştir", systemImage: "slider.horizontal.3") }.buttonStyle(MambaButtonStyle())
                    Button("Ana menü", action: onMainMenu).buttonStyle(MambaButtonStyle())
                }
            } else if !gameManager.isPlaying && !gameManager.showLanding {
                modal {
                    Image(systemName: "heart.fill").font(.system(size: 42)).foregroundStyle(.pink)
                    Text("Pes etmek yok!").font(.system(.largeTitle, design: .rounded).bold())
                    Text("\(gameManager.lives) canın kaldı. Yeni bir rota dene.").foregroundStyle(.secondary)
                    Button("Devam et", action: onContinue).buttonStyle(MambaButtonStyle(primary: true))
                    Button("Ana menü", action: onMainMenu).buttonStyle(MambaButtonStyle())
                }
            }
        }
        .sheet(isPresented: $showLeaderboard) { LeaderboardView(isPresented: $showLeaderboard).preferredColorScheme(.dark) }
        .sheet(isPresented: $showCustomization) { CustomizationView() }
        .sheet(isPresented: $showNicknamePrompt) { nicknameContent }
        .sheet(isPresented: $showInstructions) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Kaydır. Alanı kapat. Rekoru kır.")
                            .font(.system(.title, design: .rounded).bold())
                        Label("Örümceği kaydırarak yönlendir.", systemImage: "hand.draw")
                        Label("Çizgiyi güvenli alana bağla ve alanın %75’ini kapat.", systemImage: "square.dashed.inset.filled")
                        Label("Yılandan ve kendi izinden kaçın.", systemImage: "exclamationmark.shield")
                        Label("Her 10 seviyede bir can kazan.", systemImage: "heart")
                    }.padding(24)
                }
                .background(MambaStyle.surface)
                .navigationTitle("Nasıl oynanır?")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Bitti") { showInstructions = false }
                    }
                }
            }.preferredColorScheme(.dark)
        }
    }

    private var landingContent: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 700
            let compact = geometry.size.height < 720
            let bannerWidth = max(1, min(geometry.size.width - 24, 700))

            ScrollView {
                VStack(spacing: compact ? 14 : 22) {
                    menuHeader
                    Spacer(minLength: 0)
                    if wide {
                        HStack(spacing: 32) {
                            hero(compact: compact).frame(maxWidth: .infinity)
                            menuActions.frame(maxWidth: .infinity)
                        }
                    } else {
                        hero(compact: compact)
                        menuActions
                    }
                    Spacer(minLength: 0)
                    Label("Her 10 seviyede +1 can. Rekor için bir tur daha.", systemImage: "heart.fill")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)
                .frame(maxWidth: 820)
                .frame(minHeight: max(0, geometry.size.height - AdMobBanner.height(for: bannerWidth) - 48))
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 6) {
                    Text("REKLAM")
                        .font(.system(size: 8, weight: .medium)).tracking(2)
                        .foregroundStyle(.secondary)
                    AdMobBanner(width: bannerWidth)
                        .frame(width: bannerWidth, height: AdMobBanner.height(for: bannerWidth))
                }
                .padding(.top, 10)
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity)
                .background(MambaStyle.surface)
                .overlay(alignment: .top) { Color.white.opacity(0.08).frame(height: 1) }
            }
            .background {
                ArenaBackground(theme: ArenaTheme(rawValue: menuTheme) ?? .midnight, grid: false)
                    .ignoresSafeArea()
            }
        }
    }

    private var menuHeader: some View {
        HStack(spacing: 12) {
            Button {
                tempNickname = gameManager.nickname
                isEditingFromMenu = true
                showNicknamePrompt = true
            } label: {
                HStack(spacing: 11) {
                    Text(gameManager.nickname.isEmpty ? "M" : String(gameManager.nickname.prefix(1)).uppercased())
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(MambaStyle.mint)
                        .frame(width: 46, height: 46)
                        .background(MambaStyle.mint.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(MambaStyle.mint.opacity(0.2)))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TEKRAR MERHABA")
                            .font(.system(size: 8, weight: .bold)).tracking(1.5)
                            .foregroundStyle(.white.opacity(0.45))
                        HStack(spacing: 6) {
                            Text(gameManager.nickname.isEmpty ? "Oyuncu" : gameManager.nickname)
                                .font(.system(.headline, design: .rounded).bold()).lineLimit(1)
                            Image(systemName: "pencil").font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Oyuncu profilini düzenle")
            Spacer(minLength: 8)
            Button { showInstructions = true } label: {
                Image(systemName: "questionmark")
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.06), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Nasıl oynanır?")
        }
    }

    private func hero(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(MambaStyle.mint).frame(width: 5, height: 5)
                    Text("MAMBA ARCADE").font(.system(size: 9, weight: .heavy)).tracking(2)
                }.foregroundStyle(MambaStyle.mint)
                Spacer()
                Image(systemName: "sparkle").foregroundStyle(MambaStyle.mint.opacity(0.7))
            }
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mamba\nSnake")
                        .font(.system(size: compact ? 37 : 44, weight: .black, design: .rounded))
                        .tracking(-2).lineSpacing(-6)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Mamba Snake")
                    Text("Alanı fethet.\nRekorunu geride bırak.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                SnakeIllustration()
                    .frame(width: compact ? 120 : 140, height: compact ? 112 : 135)
                    .rotationEffect(.degrees(-12))
            }
            HStack(spacing: 8) {
                Label("%75 alan hedefi", systemImage: "square.dashed.inset.filled")
                Spacer(minLength: 0)
                Label("3 canla başla", systemImage: "heart.fill")
            }
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.65))
            .padding(.top, 12)
            .overlay(alignment: .top) { Color.white.opacity(0.08).frame(height: 1) }
        }
        .padding(22)
        .background {
            ZStack {
                ArenaBackground(theme: ArenaTheme(rawValue: menuTheme) ?? .midnight)
                LinearGradient(colors: [MambaStyle.mint.opacity(0.07), .clear], startPoint: .topTrailing, endPoint: .bottomLeading)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(LinearGradient(colors: [MambaStyle.mint.opacity(0.3), .white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)))
    }

    private var menuActions: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 21)).foregroundStyle(.orange)
                    .frame(width: 44, height: 44)
                    .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    Text("KİŞİSEL REKOR").font(.system(size: 8, weight: .bold)).tracking(1.5).foregroundStyle(.secondary)
                    Text(gameManager.highScore.formatted())
                        .font(.system(size: 26, weight: .black, design: .rounded)).monospacedDigit()
                }
                Spacer()
                Text("Sıradaki rekor\nsenin elinde.")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary).multilineTextAlignment(.trailing)
            }
            .padding(14)
            .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.07)))

            Button(action: requestStart) {
                HStack(spacing: 14) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 19, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Hadi oynayalım")
                            .font(.system(size: 21, weight: .black, design: .rounded))
                        Text("SEVİYE 1’DEN BAŞLA")
                            .font(.system(size: 8, weight: .heavy)).tracking(1.3).opacity(0.55)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right").font(.system(size: 18, weight: .bold))
                }
                .foregroundStyle(Color(red: 0.04, green: 0.16, blue: 0.12))
                .padding(16)
                .background(LinearGradient(colors: [MambaStyle.mint, Color(red: 0.43, green: 0.86, blue: 0.60)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 23))
                .overlay(RoundedRectangle(cornerRadius: 23).stroke(.white.opacity(0.25)))
                .shadow(color: MambaStyle.mint.opacity(0.13), radius: 14, y: 6)
            }.buttonStyle(.plain)

            HStack(spacing: 12) {
                menuTile("Özelleştir", subtitle: "Atmosferini seç", icon: "paintpalette.fill", color: .cyan) { showCustomization = true }
                menuTile("Sıralama", subtitle: "Zirveye oyna", icon: "trophy.fill", color: .orange) { showLeaderboard = true }
            }
        }
    }

    private func menuTile(_ title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon).font(.system(size: 19)).foregroundStyle(color)
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.3))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 15, weight: .bold, design: .rounded))
                    Text(subtitle).font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.08)))
        }.buttonStyle(.plain)
    }

    private var nicknameContent: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Rekorun bir adı olsun.").font(.system(.largeTitle, design: .rounded).bold())
                    Text("Liderlik tablosunda görünecek oyuncu adını seç.").foregroundStyle(.secondary)
                    TextField("Oyuncu adı", text: $tempNickname)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(18).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                        .onChange(of: tempNickname) { _, value in tempNickname = String(value.prefix(PlayerNickname.maxLength)) }
                    Button(isEditingFromMenu ? "Kaydet" : "Hadi başlayalım") {
                        let nickname = PlayerNickname.sanitize(tempNickname)
                        guard !nickname.isEmpty else { return }
                        gameManager.setNickname(nickname)
                        showNicknamePrompt = false
                        if !isEditingFromMenu { onStart() }
                    }
                    .buttonStyle(MambaButtonStyle(primary: true))
                    .disabled(PlayerNickname.sanitize(tempNickname).isEmpty)
                }.padding(24).frame(maxWidth: 500).frame(maxWidth: .infinity)
            }
            .background(MambaStyle.surface.ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { showNicknamePrompt = false } } }
        }.preferredColorScheme(.dark)
    }

    private var nextLevelCard: some View {
        HStack(spacing: 16) {
            Text(String(format: "%02d", gameManager.level + 1))
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(MambaStyle.mint)
                .frame(width: 66, height: 72)
                .background(MambaStyle.mint.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
            VStack(alignment: .leading, spacing: 7) {
                Text("SIRADAKİ MEYDAN OKUMA")
                    .font(.system(size: 9, weight: .heavy)).tracking(1)
                    .foregroundStyle(MambaStyle.mint)
                Label("Daha hızlı yılan", systemImage: "bolt.fill")
                Label("Yılana +1 parça", systemImage: "plus.circle.fill")
                if (gameManager.level + 1) % 10 == 0 {
                    Label("Ödül: +1 can", systemImage: "heart.fill").foregroundStyle(.pink)
                }
            }
            .font(.system(.footnote, design: .rounded).weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(MambaStyle.mint.opacity(0.15)))
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption2.bold()).foregroundStyle(.secondary)
            Text(value).font(.system(.title2, design: .rounded).bold()).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
        }
    }

    private func modal<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 20, content: content)
                    .multilineTextAlignment(.center)
                    .mambaCard().padding(20)
                    .frame(maxWidth: 500)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height)
            }
            .background {
                Color.black.opacity(0.76).ignoresSafeArea()
            }
        }
    }

    private func requestStart() {
        if gameManager.nickname.isEmpty {
            isEditingFromMenu = false
            showNicknamePrompt = true
        } else { onStart() }
    }
}
