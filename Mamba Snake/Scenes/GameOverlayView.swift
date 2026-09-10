import SwiftUI

struct GameOverlayView: View {
    @ObservedObject var gameManager = GameManager.shared
    var onResume: () -> Void
    var onRestart: () -> Void
    var onNextLevel: () -> Void
    var onStart: () -> Void
    var onContinue: () -> Void
    var onRevive: () -> Void
    var onMainMenu: () -> Void

    @State private var showInstructions = false
    @State private var showLeaderboard = false
    @State private var showCustomization = false
    @State private var showNicknamePrompt = false
    @State private var tempNickname = ""
    @State private var isEditingFromMenu = false
    @AppStorage(ArenaTheme.storageKey) private var menuTheme = ArenaTheme.midnight.rawValue

    var body: some View {
        ZStack {
            if gameManager.showLanding { landingContent }
            if gameManager.isGameOver || gameManager.isLevelComplete {
                modal {
                    Image(systemName: gameManager.isLevelComplete ? "checkmark.seal.fill" : "flag.checkered")
                        .font(.system(size: 46)).foregroundStyle(MambaStyle.mint)
                    Text(
                        gameManager.isLevelComplete
                            ? L10n.string("overlay.level_complete", gameManager.level)
                            : L10n.string("overlay.try_again_title")
                    )
                        .font(.system(.largeTitle, design: .rounded).bold())
                    Text(
                        gameManager.isLevelComplete
                            ? L10n.string("overlay.level_complete_subtitle")
                            : L10n.string("overlay.try_again_subtitle")
                    )
                        .foregroundStyle(.secondary)
                    HStack {
                        metric(L10n.string("common.score"), value: "\(gameManager.score)")
                        Spacer()
                        metric(L10n.string("common.level_label"), value: "\(gameManager.level)")
                        Spacer()
                        metric(L10n.string("common.high_score"), value: "\(gameManager.highScore)")
                    }
                    .padding(16)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.08)))
                    if gameManager.isLevelComplete {
                        Text(L10n.string("overlay.level_bonus", gameManager.lastLevelBonus))
                            .foregroundStyle(MambaStyle.mint)
                        nextLevelCard
                    }
                    Button(action: gameManager.isLevelComplete ? onNextLevel : onRestart) {
                        Label(
                            gameManager.isLevelComplete
                                ? L10n.string("overlay.start_level", gameManager.level + 1)
                                : L10n.string("overlay.play_again"),
                            systemImage: "arrow.right"
                        )
                    }.buttonStyle(MambaButtonStyle(primary: true))
                    if !gameManager.isLevelComplete {
                        Button {
                            AdMobService.shared.showRewardedAd {
                                DispatchQueue.main.async { onRevive() }
                            }
                        } label: { Label(L10n.string("overlay.watch_ad"), systemImage: "play.rectangle") }
                            .buttonStyle(MambaButtonStyle())
                    }
                    Button(L10n.string("overlay.leaderboard")) { showLeaderboard = true }.buttonStyle(MambaButtonStyle())
                    Button(L10n.string("common.main_menu"), action: onMainMenu).frame(minHeight: 44).foregroundStyle(.secondary)
                }
            } else if gameManager.isPaused && !gameManager.showLanding {
                modal {
                    Image(systemName: "pause.circle").font(.system(size: 48)).foregroundStyle(MambaStyle.mint)
                    Text(L10n.string("overlay.pause_title")).font(.system(.largeTitle, design: .rounded).bold())
                    Text(L10n.string("overlay.pause_subtitle")).foregroundStyle(.secondary)
                    Button(action: onResume) { Label(L10n.string("common.continue"), systemImage: "play.fill") }.buttonStyle(MambaButtonStyle(primary: true))
                    Button { showCustomization = true } label: { Label(L10n.string("common.customize"), systemImage: "slider.horizontal.3") }.buttonStyle(MambaButtonStyle())
                    Button(L10n.string("common.main_menu"), action: onMainMenu).buttonStyle(MambaButtonStyle())
                }
            } else if !gameManager.isPlaying && !gameManager.showLanding {
                modal {
                    Image(systemName: "heart.fill").font(.system(size: 42)).foregroundStyle(.pink)
                    Text(L10n.string("overlay.keep_going")).font(.system(.largeTitle, design: .rounded).bold())
                    Text(L10n.string("overlay.lives_left", gameManager.lives)).foregroundStyle(.secondary)
                    Button(L10n.string("common.continue"), action: onContinue).buttonStyle(MambaButtonStyle(primary: true))
                    Button(L10n.string("common.main_menu"), action: onMainMenu).buttonStyle(MambaButtonStyle())
                }
            }
        }
        .sheet(isPresented: $showLeaderboard) { LeaderboardView(isPresented: $showLeaderboard).preferredColorScheme(.dark) }
        .sheet(isPresented: $showCustomization) { CustomizationView() }
        .sheet(isPresented: $showNicknamePrompt) { nicknameContent }
        .sheet(isPresented: $showInstructions) { instructionsContent }
        .menuTheme(ArenaTheme.resolved(menuTheme))
    }

    private var instructionsContent: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    instructionsHero

                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.string("overlay.flow"))
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(1.8)
                            .foregroundStyle(MambaStyle.mint)

                        instructionRow(
                            number: "01",
                            icon: "hand.draw.fill",
                            title: L10n.string("overlay.step_1_title"),
                            detail: L10n.string("overlay.step_1_detail")
                        )
                        instructionRow(
                            number: "02",
                            icon: "square.dashed.inset.filled",
                            title: L10n.string("overlay.step_2_title"),
                            detail: L10n.string("overlay.step_2_detail")
                        )
                        instructionRow(
                            number: "03",
                            icon: "shield.lefthalf.filled",
                            title: L10n.string("overlay.step_3_title"),
                            detail: L10n.string("overlay.step_3_detail")
                        )
                        instructionRow(
                            number: "04",
                            icon: "scope",
                            title: L10n.string("overlay.step_4_title"),
                            detail: L10n.string("overlay.step_4_detail")
                        )
                    }

                    HStack(spacing: 14) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.pink)
                            .frame(width: 44, height: 44)
                            .background(Color.pink.opacity(0.11), in: RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.string("overlay.mastery_reward"))
                                .font(.system(size: 8, weight: .heavy))
                                .tracking(1.4)
                                .foregroundStyle(.pink)
                            Text(L10n.string("overlay.reward_every_ten"))
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        }
                    }
                    .padding(16)
                    .background(Color.pink.opacity(0.06), in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.pink.opacity(0.16)))
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 32)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background {
                ArenaBackground(theme: ArenaTheme.resolved(menuTheme))
                    .ignoresSafeArea()
            }
            .navigationTitle(L10n.string("overlay.how_to_play"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("common.done")) { showInstructions = false }
                        .fontWeight(.bold)
                        .tint(MambaStyle.mint)
                }
            }
        }
        .preferredColorScheme(.dark)
        .menuTheme(ArenaTheme.resolved(menuTheme))
    }

    private var instructionsHero: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Circle().fill(MambaStyle.mint).frame(width: 5, height: 5)
                    Text(L10n.string("overlay.quick_start"))
                        .font(.system(size: 8, weight: .heavy))
                        .tracking(1.6)
                }
                .foregroundStyle(MambaStyle.mint)

                Text(L10n.string("overlay.hero"))
                    .font(.system(size: 31, weight: .black, design: .rounded))
                    .tracking(-1.2)
                    .lineSpacing(-4)
                    .fixedSize(horizontal: false, vertical: true)

                Label(L10n.string("overlay.target"), systemImage: "flag.checkered")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HeroSnake()
                .frame(width: 132, height: 132)
                .rotationEffect(.degrees(-8))
        }
        .padding(20)
        .background {
            ZStack {
                ArenaBackground(theme: ArenaTheme.resolved(menuTheme))
                LinearGradient(
                    colors: [MambaStyle.mint.opacity(0.08), .clear],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(
                    LinearGradient(
                        colors: [MambaStyle.mint.opacity(0.28), .white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private func instructionRow(
        number: String,
        icon: String,
        title: String,
        detail: String
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(MambaStyle.mint.opacity(0.10))
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(MambaStyle.mint)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(title)
                        .font(.system(.headline, design: .rounded).bold())
                    Spacer(minLength: 8)
                    Text(number)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.24))
                }
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)
        }
        .padding(16)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.075)))
        .accessibilityElement(children: .combine)
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
                    Label(L10n.string("overlay.menu_reward_hint"), systemImage: "heart.fill")
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
                    Text(L10n.string("common.ad"))
                        .font(.system(size: 8, weight: .medium)).tracking(2)
                        .foregroundStyle(.secondary)
                    AdMobBanner(width: bannerWidth)
                        .frame(width: bannerWidth, height: AdMobBanner.height(for: bannerWidth))
                }
                .padding(.top, 10)
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.18))
                .overlay(alignment: .top) { Color.white.opacity(0.08).frame(height: 1) }
            }
            .background {
                ArenaBackground(theme: ArenaTheme.resolved(menuTheme), grid: false)
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
                        Text(L10n.string("overlay.welcome_back"))
                            .font(.system(size: 8, weight: .bold)).tracking(1.5)
                            .foregroundStyle(.white.opacity(0.45))
                        HStack(spacing: 6) {
                            Text(gameManager.nickname.isEmpty ? L10n.string("common.player") : gameManager.nickname)
                                .font(.system(.headline, design: .rounded).bold()).lineLimit(1)
                            Image(systemName: "pencil").font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.string("overlay.edit_profile"))
            Spacer(minLength: 8)
            Button {
                AppTipActions.howToPlayTapped()
                showInstructions = true
            } label: {
                Image(systemName: "questionmark")
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.06), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.string("overlay.how_to_play"))
            .howToPlayTipPopover()
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
                    Text(L10n.string("overlay.conquer"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HeroSnake()
                    .frame(width: compact ? 120 : 140, height: compact ? 112 : 135)
                    .rotationEffect(.degrees(-12))
            }
            HStack(spacing: 8) {
                Label(L10n.string("overlay.target"), systemImage: "square.dashed.inset.filled")
                Spacer(minLength: 0)
                Label(L10n.string("overlay.start_lives"), systemImage: "heart.fill")
            }
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.65))
            .padding(.top, 12)
            .overlay(alignment: .top) { Color.white.opacity(0.08).frame(height: 1) }
        }
        .padding(22)
        .background {
            ZStack {
                ArenaBackground(theme: ArenaTheme.resolved(menuTheme))
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
                    Text(L10n.string("overlay.personal_best")).font(.system(size: 8, weight: .bold)).tracking(1.5).foregroundStyle(.secondary)
                    Text(gameManager.highScore.formatted())
                        .font(.system(size: 26, weight: .black, design: .rounded)).monospacedDigit()
                }
                Spacer()
                Text(L10n.string("overlay.next_record"))
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
                        Text(L10n.string("overlay.play_cta"))
                            .font(.system(size: 21, weight: .black, design: .rounded))
                        Text(L10n.string("overlay.start_from_level_one"))
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
                menuTile(L10n.string("common.customize"), subtitle: L10n.string("overlay.customize_subtitle"), icon: "paintpalette.fill", color: .cyan) {
                    AppTipActions.customizeTapped()
                    showCustomization = true
                }
                .customizeTipPopover()
                menuTile(L10n.string("overlay.ranking"), subtitle: L10n.string("overlay.ranking_subtitle"), icon: "trophy.fill", color: .orange) { showLeaderboard = true }
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
                    Text(L10n.string("overlay.nickname_title")).font(.system(.largeTitle, design: .rounded).bold())
                    Text(L10n.string("overlay.nickname_subtitle")).foregroundStyle(.secondary)
                    TextField(L10n.string("overlay.nickname_placeholder"), text: $tempNickname)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(18).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                        .onChange(of: tempNickname) { value in tempNickname = String(value.prefix(PlayerNickname.maxLength)) }
                    Button(
                        isEditingFromMenu
                            ? L10n.string("overlay.save")
                            : L10n.string("overlay.lets_start")
                    ) {
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
            .background {
                ArenaBackground(theme: ArenaTheme.resolved(menuTheme))
                    .ignoresSafeArea()
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L10n.string("common.cancel")) { showNicknamePrompt = false } } }
        }
        .preferredColorScheme(.dark)
        .menuTheme(ArenaTheme.resolved(menuTheme))
    }

    private var nextLevelCard: some View {
        HStack(spacing: 16) {
            Text(String(format: "%02d", gameManager.level + 1))
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(MambaStyle.mint)
                .frame(width: 66, height: 72)
                .background(MambaStyle.mint.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
            VStack(alignment: .leading, spacing: 7) {
                Text(L10n.string("overlay.next_challenge"))
                    .font(.system(size: 9, weight: .heavy)).tracking(1)
                    .foregroundStyle(MambaStyle.mint)
                ForEach(LevelRules.upcomingChanges(entering: gameManager.level + 1), id: \.self) { change in
                    Label(L10n.string(change.titleKey), systemImage: change.icon)
                        .foregroundStyle(change == .extraLife ? Color.pink : Color.primary)
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
                ZStack {
                    Color.black.opacity(0.45)
                    ArenaTheme.resolved(menuTheme).colors[0].opacity(0.40)
                }
                .ignoresSafeArea()
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
