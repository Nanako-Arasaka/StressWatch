import SwiftUI

struct LiveStressCard: View {
    let snapshot: LiveStressSnapshot

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GlassCardView(cornerRadius: 30, padding: 20) {
            VStack(alignment: .leading, spacing: 18) {
                header
                scoreRow
                detailGrid
                explanation
                disclaimer
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "waveform.path.ecg.rectangle")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppColors.chartPrimary)
                .frame(width: 38, height: 38)
                .background(AppColors.subtleTealFill(for: colorScheme), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("当前压力趋势参考")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppColors.primaryText(for: colorScheme))

                Text("基于近期 HRV、静息心率和睡眠相对基线")
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryText(for: colorScheme))
            }

            Spacer()

            DataSourceBadge(source: sourceLabel)
        }
    }

    private var scoreRow: some View {
        HStack(alignment: .lastTextBaseline, spacing: 12) {
            Text(scoreText)
                .font(.system(size: 54, weight: .bold, design: .rounded))
                .foregroundStyle(statusColor)
                .appNumericChange(value: scoreText, reduceMotion: reduceMotion)

            Text("/100")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppColors.secondaryText(for: colorScheme))

            Spacer()

            Text(snapshot.status.displayName)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(statusColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(statusColor.opacity(colorScheme == .dark ? 0.16 : 0.12), in: Capsule())
        }
    }

    private var detailGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            liveStressStat(title: "最近 HRV", value: hrvText)
            liveStressStat(title: "相对基线", value: deviationText)
            liveStressStat(title: "数据可信度", value: "\(Int(round(snapshot.dataConfidence)))%")
            liveStressStat(title: "更新时间", value: Self.timeFormatter.string(from: snapshot.lastUpdated))
        }
    }

    private var explanation: some View {
        Text(snapshot.explanation)
            .font(.subheadline)
            .foregroundStyle(AppColors.primaryText(for: colorScheme).opacity(0.82))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var disclaimer: some View {
        Text("仅用于个人健康趋势参考，不提供专业健康判断。")
            .font(.caption)
            .foregroundStyle(AppColors.secondaryText(for: colorScheme))
    }

    private func liveStressStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppColors.secondaryText(for: colorScheme))

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColors.primaryText(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppColors.glassFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var scoreText: String {
        snapshot.score.map { "\(Int(round($0)))" } ?? "--"
    }

    private var hrvText: String {
        snapshot.recentHRV.map { "\(Int(round($0))) ms" } ?? "暂无"
    }

    private var deviationText: String {
        guard let percent = snapshot.hrvDeviationPercent else {
            return "暂无"
        }

        let sign = percent >= 0 ? "+" : ""
        return "\(sign)\(Int(round(percent)))%"
    }

    private var sourceLabel: String {
        snapshot.source == .appleHealth ? "Apple Health" : "Demo Data"
    }

    private var statusColor: Color {
        switch snapshot.status {
        case .recoveryGood:
            return AppColors.recoveryBlue
        case .normal:
            return AppColors.chartPrimary
        case .mildStress:
            return AppColors.chartSecondary
        case .attentionStress, .highStress:
            return AppColors.stressWarm
        case .dataInsufficient:
            return AppColors.secondaryText(for: colorScheme)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
