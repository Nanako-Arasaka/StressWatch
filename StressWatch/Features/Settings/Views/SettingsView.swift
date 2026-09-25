import SwiftUI

struct SettingsView: View {
    // MARK: - Properties

    @ObservedObject var viewModel: SettingsViewModel
    @State private var contentVisible = false
    @State private var apiKeyInput: String = ""
    @State private var backendURLInput: String = ""
    @State private var backendTokenInput: String = ""
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Init

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    GlassSectionHeader(
                        title: "设置",
                        subtitle: "Apple Health, Demo Data, privacy",
                        systemImage: "gearshape"
                    )
                    .appStaggeredCard(isVisible: contentVisible, delay: 0, reduceMotion: reduceMotion)

                    settingsHero
                        .appStaggeredCard(isVisible: contentVisible, delay: 0.05, reduceMotion: reduceMotion)

                    GlassCardView(cornerRadius: 28, padding: 18) {
                        VStack(alignment: .leading, spacing: 16) {
                            GlassSectionHeader(
                                title: "Apple Health",
                                subtitle: "授权状态：\(viewModel.healthKitStatusText)",
                                systemImage: "heart.text.square"
                            )

                            Button(action: requestHealthKitAuthorization) {
                                if viewModel.authorizationState == .requesting {
                                    HStack {
                                        ProgressView()
                                        Text("正在请求授权...")
                                    }
                                    .frame(maxWidth: .infinity)
                                } else {
                                    Label("请求 HealthKit 授权", systemImage: "checkmark.shield")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(AppColors.primaryBlue)
                            .disabled(viewModel.authorizationState == .requesting)

                            if let errorMessage = viewModel.errorMessage {
                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(statusMessageColor)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .appStaggeredCard(isVisible: contentVisible, delay: 0.10, reduceMotion: reduceMotion)

                    GlassCardView(cornerRadius: 28, padding: 18) {
                        VStack(alignment: .leading, spacing: 16) {
                            GlassSectionHeader(
                                title: "数据源",
                                subtitle: "当前可在 Apple Health 和演示数据之间切换。",
                                systemImage: "switch.2"
                            )

                            Toggle("使用演示数据", isOn: demoDataBinding)

                            VStack(spacing: 10) {
                                Button("使用 Apple Health") {
                                    print("[SettingsView] tapped useAppleHealth")
                                    Task {
                                        await viewModel.useAppleHealth()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(AppColors.primaryBlue)
                                .frame(maxWidth: .infinity)
                                .disabled(viewModel.authorizationState == .requesting)

                                Button("使用 Demo Data") {
                                    print("[SettingsView] tapped useDemoData")
                                    viewModel.useDemoData()
                                }
                                .buttonStyle(.bordered)
                                .tint(AppColors.primaryBlue)
                                .frame(maxWidth: .infinity)
                                .disabled(viewModel.authorizationState == .requesting)
                            }
                        }
                    }
                    .appStaggeredCard(isVisible: contentVisible, delay: 0.16, reduceMotion: reduceMotion)

                    GlassCardView(cornerRadius: 28, padding: 18) {
                        VStack(alignment: .leading, spacing: 14) {
                            GlassSectionHeader(
                                title: "小米运动健康接入",
                                subtitle: "路径 A：小米数据写入 Apple 健康后，StressWatch 直接读取。",
                                systemImage: "heart.text.square"
                            )

                            VStack(alignment: .leading, spacing: 8) {
                                Text("1. 在「小米运动健康」中开启同步到 Apple 健康（通常在 设置 → 数据同步 / Apple 健康）。")
                                Text("2. 授权写入步数、心率、睡眠等；HRV 是否提供取决于手环与 App 版本。")
                                Text("3. 回到本页点「使用 Apple Health」，Dashboard 会合并所有写入源。")
                            }
                            .font(.footnote)
                            .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                            .fixedSize(horizontal: false, vertical: true)

                            if let detected = viewModel.detectedHealthSources, !detected.isEmpty {
                                Text("已检测写入源：\(detected)")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(AppColors.primaryText(for: colorScheme))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            if let xiaomiNote = viewModel.xiaomiSourceNote {
                                Text(xiaomiNote)
                                    .font(.footnote)
                                    .foregroundStyle(AppColors.primaryBlue)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .appStaggeredCard(isVisible: contentVisible, delay: 0.19, reduceMotion: reduceMotion)

                    GlassCardView(cornerRadius: 28, padding: 18) {
                        VStack(alignment: .leading, spacing: 14) {
                            GlassSectionHeader(
                                title: "Baseline",
                                subtitle: "选择用于个人基线参考的数据窗口。",
                                systemImage: "calendar"
                            )

                            Picker("天数", selection: $viewModel.baselineWindowDays) {
                                Text("7 天").tag(7)
                                Text("14 天").tag(14)
                                Text("30 天").tag(30)
                            }
                            .pickerStyle(.segmented)
                            .tint(AppColors.primaryBlue)
                            .onChange(of: viewModel.baselineWindowDays) { days in
                                print("[SettingsView] tapped baseline \(days)")
                                viewModel.updateBaselineWindow(days)
                            }
                        }
                    }
                    .appStaggeredCard(isVisible: contentVisible, delay: 0.22, reduceMotion: reduceMotion)

                    GlassCardView(cornerRadius: 28, padding: 18) {
                        VStack(alignment: .leading, spacing: 14) {
                            GlassSectionHeader(
                                title: "缓存",
                                subtitle: "仅清除本地保存的趋势参考数据。",
                                systemImage: "externaldrive"
                            )

                            Button(role: .destructive) {
                                print("[SettingsView] tapped clearCache")
                                viewModel.clearAllData()
                            } label: {
                                Label("清除缓存", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                            .tint(AppColors.stressWarm)
                        }
                    }
                    .appStaggeredCard(isVisible: contentVisible, delay: 0.28, reduceMotion: reduceMotion)

                    GlassCardView(cornerRadius: 28, padding: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            GlassSectionHeader(
                                title: "隐私说明",
                                subtitle: "健康数据仅在本机读取和保存，不上传服务器。",
                                systemImage: "lock.shield"
                            )

                            if let errorMessage = viewModel.errorMessage {
                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                            }
                        }
                    }
                    .appStaggeredCard(isVisible: contentVisible, delay: 0.34, reduceMotion: reduceMotion)

                    aiAnalysisCard
                        .appStaggeredCard(isVisible: contentVisible, delay: 0.40, reduceMotion: reduceMotion)

                    GlassCardView(cornerRadius: 22, padding: 14) {
                        Text("本应用仅用于个人健康趋势参考，不提供专业健康判断或紧急用途。如有健康问题，请咨询专业人士。")
                            .font(.footnote)
                            .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                    }
                    .appStaggeredCard(isVisible: contentVisible, delay: 0.46, reduceMotion: reduceMotion)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
            .background(pageBackground)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                apiKeyInput = viewModel.miniMaxAPIKey
                backendURLInput = viewModel.analysisBackendBaseURL
                backendTokenInput = viewModel.analysisBackendToken
                showContent()
            }
        }
    }

    // MARK: - Styling

    private var settingsHero: some View {
        GlassCardView(cornerRadius: 34, padding: 20) {
            HStack(alignment: .center, spacing: 18) {
                ZStack {
                    Circle()
                        .fill(AppColors.softBlue.opacity(colorScheme == .dark ? 0.14 : 0.28))
                        .frame(width: 104, height: 104)
                        .blur(radius: 18)

                    Image("StressWatchLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 78, height: 78)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Local wellness controls")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.primaryText(for: colorScheme))

                    Text("健康数据只在本机读取和保存")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.secondaryText(for: colorScheme))

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                        settingsPill(title: "Data", value: viewModel.useMockData ? "Demo" : "Apple Health", color: AppColors.primaryBlue)
                        settingsPill(title: "HealthKit", value: viewModel.healthKitStatusText, color: statusPillColor)
                    }
                }
            }
        }
    }

    private var statusPillColor: Color {
        switch viewModel.authorizationState {
        case .authorized:
            return AppColors.recoveryBlue
        case .failed, .unavailable:
            return AppColors.stressWarm
        case .idle, .requesting:
            return AppColors.primaryBlue
        }
    }

    private func settingsPill(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.secondaryText(for: colorScheme))

            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.primaryText(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(colorScheme == .dark ? 0.14 : 0.10), in: Capsule())
    }

    private var aiAnalysisCard: some View {
        GlassCardView(cornerRadius: 28, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                GlassSectionHeader(
                    title: "AI 个性化分析",
                    subtitle: "可选：自建分析服务器优先，其次 MiniMax。",
                    systemImage: "brain"
                )

                Toggle("启用 AI 分析", isOn: Binding(
                    get: { viewModel.enableAIAnalysis },
                    set: { viewModel.setEnableAIAnalysis($0) }
                ))

                Text("自建分析服务器（优先）")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryText(for: colorScheme))

                TextField("服务器地址（如 http://115.29.197.244:8090）", text: $backendURLInput)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("服务器 Token（可选）", text: $backendTokenInput)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 10) {
                    Button("保存服务器配置") {
                        viewModel.setAnalysisBackendBaseURL(backendURLInput)
                        viewModel.saveAnalysisBackendToken(backendTokenInput)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.primaryBlue)

                    Button("清除", role: .destructive) {
                        backendURLInput = ""
                        backendTokenInput = ""
                        viewModel.setAnalysisBackendBaseURL("")
                        viewModel.clearAnalysisBackendToken()
                    }
                    .buttonStyle(.bordered)
                    .tint(AppColors.stressWarm)
                }

                Text("MiniMax（备用）")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryText(for: colorScheme))

                SecureField("MiniMax API Key", text: $apiKeyInput)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 10) {
                    Button("保存 Key") {
                        viewModel.saveMiniMaxAPIKey(apiKeyInput)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.primaryBlue)

                    Button("清除", role: .destructive) {
                        apiKeyInput = ""
                        viewModel.clearMiniMaxAPIKey()
                    }
                    .buttonStyle(.bordered)
                    .tint(AppColors.stressWarm)
                }

                Picker("模型", selection: $viewModel.miniMaxModel) {
                    ForEach(MiniMaxModel.allCases, id: \.rawValue) { model in
                        Text(model.displayName).tag(model.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppColors.primaryBlue)
                .onChange(of: viewModel.miniMaxModel) { model in
                    viewModel.setMiniMaxModel(model)
                }

                Text("配置了自建服务器时优先调用它；否则走 MiniMax。健康数据仅以聚合摘要发送，不含姓名与精确日期；Token / Key 保存在本机钥匙串。关闭此功能则完全不调用网络。")
                    .font(.footnote)
                    .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var pageBackground: some View {
        ZStack {
            AppColors.backgroundGradient(for: colorScheme)

            Circle()
                .fill(AppColors.backgroundGlowPrimary(for: colorScheme))
                .frame(width: 260, height: 260)
                .blur(radius: 34)
                .offset(x: -120, y: -260)

            Circle()
                .fill(AppColors.backgroundGlowSecondary(for: colorScheme))
                .frame(width: 300, height: 300)
                .blur(radius: 40)
                .offset(x: 140, y: -80)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var statusMessageColor: Color {
        switch viewModel.authorizationState {
        case .authorized:
            return AppColors.recoveryBlue
        case .failed, .unavailable:
            return AppColors.stressWarm
        case .idle, .requesting:
            return AppColors.secondaryText(for: colorScheme)
        }
    }

    private var demoDataBinding: Binding<Bool> {
        Binding(
            get: {
                viewModel.useMockData
            },
            set: { useDemo in
                if useDemo {
                    print("[SettingsView] tapped useDemoData")
                    viewModel.useDemoData()
                } else {
                    print("[SettingsView] tapped useAppleHealth")
                    Task {
                        await viewModel.useAppleHealth()
                    }
                }
            }
        )
    }

    // MARK: - Actions

    private func requestHealthKitAuthorization() {
        print("[SettingsView] tapped requestHealthKitAuthorization")
        Task {
            await viewModel.requestHealthKitAuthorization()
        }
    }

    private func showContent() {
        withAnimation(AppMotion.cardEntrance(reduceMotion: reduceMotion, delay: 0)) {
            contentVisible = true
        }
    }
}
