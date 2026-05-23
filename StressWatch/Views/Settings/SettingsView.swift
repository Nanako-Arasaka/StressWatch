import SwiftUI

struct SettingsView: View {
    // MARK: - Properties

    @ObservedObject var viewModel: SettingsViewModel
    @State private var contentVisible = false

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
                    .staggeredSettings(isVisible: contentVisible, delay: 0)

                    GlassCardView {
                        VStack(alignment: .leading, spacing: 16) {
                            GlassSectionHeader(
                                title: "Apple Health",
                                subtitle: "授权状态：\(viewModel.healthKitStatusText)",
                                systemImage: "heart.text.square"
                            )

                            Button(action: requestHealthKitAuthorization) {
                                Label("请求 HealthKit 授权", systemImage: "checkmark.shield")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                    }
                    .staggeredSettings(isVisible: contentVisible, delay: 0.06)

                    GlassCardView {
                        VStack(alignment: .leading, spacing: 16) {
                            GlassSectionHeader(
                                title: "数据源",
                                subtitle: "当前可在 Apple Health 和演示数据之间切换。",
                                systemImage: "switch.2"
                            )

                            Toggle("使用演示数据", isOn: $viewModel.useMockData)
                                .disabled(true)

                            VStack(spacing: 10) {
                                Button("使用 Apple Health") {
                                    Task {
                                        await viewModel.useAppleHealth()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .frame(maxWidth: .infinity)

                                Button("使用 Demo Data") {
                                    viewModel.useDemoData()
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .staggeredSettings(isVisible: contentVisible, delay: 0.12)

                    GlassCardView {
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
                            .onChange(of: viewModel.baselineWindowDays) { days in
                                viewModel.updateBaselineWindow(days)
                            }
                        }
                    }
                    .staggeredSettings(isVisible: contentVisible, delay: 0.18)

                    GlassCardView {
                        VStack(alignment: .leading, spacing: 14) {
                            GlassSectionHeader(
                                title: "缓存",
                                subtitle: "仅清除本地保存的趋势参考数据。",
                                systemImage: "externaldrive"
                            )

                            Button(role: .destructive) {
                                viewModel.clearAllData()
                            } label: {
                                Label("清除缓存", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .staggeredSettings(isVisible: contentVisible, delay: 0.24)

                    GlassCardView {
                        VStack(alignment: .leading, spacing: 10) {
                            GlassSectionHeader(
                                title: "隐私说明",
                                subtitle: "健康数据仅在本机读取和保存，不上传服务器。",
                                systemImage: "lock.shield"
                            )

                            if let errorMessage = viewModel.errorMessage {
                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .staggeredSettings(isVisible: contentVisible, delay: 0.30)

                    GlassCardView(cornerRadius: 20, padding: 14) {
                        Text("本应用仅用于个人健康趋势参考，不提供医疗诊断、治疗建议或紧急用途。如有健康问题，请咨询专业人士。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .staggeredSettings(isVisible: contentVisible, delay: 0.36)
                }
                .padding()
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

    private var pageBackground: some View {
        LinearGradient(
            colors: [
                Color(.systemGroupedBackground),
                Color(.secondarySystemGroupedBackground),
                Color.green.opacity(0.06)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Actions

    private func requestHealthKitAuthorization() {
        Task {
            await viewModel.requestHealthKitAuthorization()
        }
    }

    private func showContent() {
        withAnimation(.easeOut(duration: 0.35)) {
            contentVisible = true
        }
    }
}

// MARK: - Animation Helpers

private extension View {
    func staggeredSettings(isVisible: Bool, delay: Double) -> some View {
        opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 16)
            .animation(.easeOut(duration: 0.35).delay(delay), value: isVisible)
    }
}
