import SwiftUI

struct SettingsView: View {
    // MARK: - Properties

    @ObservedObject var viewModel: SettingsViewModel
    @State private var contentVisible = false
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

                    GlassCardView(cornerRadius: 22, padding: 14) {
                        Text("本应用仅用于个人健康趋势参考，不提供医疗诊断、治疗建议或紧急用途。如有健康问题，请咨询专业人士。")
                            .font(.footnote)
                            .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                    }
                    .appStaggeredCard(isVisible: contentVisible, delay: 0.40, reduceMotion: reduceMotion)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 118)
            }
            .background(pageBackground)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
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
