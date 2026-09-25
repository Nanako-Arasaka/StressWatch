import Foundation

/// 相关性引擎：对 `[DailyHealthMetrics]` 中的指标对做 lag 配对 + Pearson/Spearman 交叉验证。
///
/// 设计要点：
/// 1. **带 lag**（Thump 没有）：`x(t)` 与 `y(t + lagDays)` 配对，缺任一侧跳过。
/// 2. **Pearson + Spearman 交叉验证**：两者方向不一致 → 降级为 `.weak`。
/// 3. **样本不足 → `.none` + 明确说"还没观察到"**（不隐藏弱结果）。
/// 4. **`isBeneficial` 按 expectedDirection 判定**（r = -0.7 的 steps↔RHR 是好事，不显示红色）。
/// 5. **`description` 只能由 `AssociationWording` 生成** —— 类型上禁止因果措辞。
///
/// 只 `import Foundation`，纯函数。
struct CorrelationEngine {

    /// 配对样本不足时的分母保护。
    static let epsilon: Double = 1e-12

    // MARK: - Public

    func analyze(
        pairs: [CorrelationPair],
        history: [DailyHealthMetrics]
    ) -> [ObservedAssociation] {
        pairs.map { analyze(pair: $0, history: history) }
    }

    func analyze(
        pair: CorrelationPair,
        history: [DailyHealthMetrics]
    ) -> ObservedAssociation {
        let sorted = history.sorted { $0.day < $1.day }
        let (xValues, yValues) = extractPaired(
            pair: pair, history: sorted
        )
        let pairedDays = xValues.count

        // 样本不足 → 明确说"还没观察到"，不编造
        guard pairedDays >= pair.minimumPairs else {
            return ObservedAssociation(
                pairId: pair.id,
                coefficient: nil,
                strength: .none,
                isBeneficial: false,
                pairedDays: pairedDays,
                lagDays: pair.lagDays,
                description: AssociationWording.notYetClear.describe(
                    xName: pair.x.displayName,
                    yName: pair.y.displayName,
                    direction: "", strength: "",
                    lagDays: pair.lagDays,
                    pairedDays: pairedDays
                ),
                spearmanAgrees: true
            )
        }

        // Pearson
        guard let pearsonR = pearson(xValues, yValues) else {
            return ObservedAssociation(
                pairId: pair.id,
                coefficient: nil,
                strength: .none,
                isBeneficial: false,
                pairedDays: pairedDays,
                lagDays: pair.lagDays,
                description: AssociationWording.notYetClear.describe(
                    xName: pair.x.displayName,
                    yName: pair.y.displayName,
                    direction: "", strength: "",
                    lagDays: pair.lagDays,
                    pairedDays: pairedDays
                ),
                spearmanAgrees: true
            )
        }

        // Spearman 交叉验证
        let spearmanR = spearman(xValues, yValues)
        let agrees: Bool
        if let sR = spearmanR {
            agrees = (sR * pearsonR) > 0 || (abs(pearsonR) < 0.1 && abs(sR) < 0.1)
        } else {
            agrees = true
        }

        var strength = AssociationStrength.from(absR: abs(pearsonR))
        if !agrees && strength != .none {
            strength = .weak // 方向不一致 → 降级
        }

        let isBeneficial = (pearsonR * pair.expectedDirection.sign) > 0

        // 措辞
        let wording: AssociationWording
        switch strength {
        case .none:
            wording = .notYetClear
        case .weak:
            wording = .tendsToCooccur
        case .noticeable:
            wording = .observed
        case .clear, .strong:
            wording = .tracksWith
        }

        let directionText = isBeneficial ? "同向" : "反向"
        let description = wording.describe(
            xName: pair.x.displayName,
            yName: pair.y.displayName,
            direction: directionText,
            strength: strength.displayName,
            lagDays: pair.lagDays,
            pairedDays: pairedDays
        )

        return ObservedAssociation(
            pairId: pair.id,
            coefficient: pearsonR,
            strength: strength,
            isBeneficial: isBeneficial,
            pairedDays: pairedDays,
            lagDays: pair.lagDays,
            description: description,
            spearmanAgrees: agrees
        )
    }

    // MARK: - 配对提取

    /// 按 lagDays 配对：x(t) 与 y(t + lagDays)。
    /// 缺任一侧则跳过。
    private func extractPaired(
        pair: CorrelationPair,
        history: [DailyHealthMetrics]
    ) -> ([Double], [Double]) {
        var xValues: [Double] = []
        var yValues: [Double] = []

        // 构建 day → value 映射
        var xByDay: [Date: Double] = [:]
        var yByDay: [Date: Double] = [:]
        let calendar = Calendar.current

        for day in history {
            if let v = value(for: pair.x, in: day) {
                xByDay[calendar.startOfDay(for: day.day)] = v
            }
            if let v = value(for: pair.y, in: day) {
                yByDay[calendar.startOfDay(for: day.day)] = v
            }
        }

        for (day, x) in xByDay {
            guard let yDay = calendar.date(byAdding: .day, value: pair.lagDays, to: day),
                  let y = yByDay[yDay] else { continue }
            xValues.append(x)
            yValues.append(y)
        }

        return (xValues, yValues)
    }

    private func value(for metric: BaselineMetric, in day: DailyHealthMetrics) -> Double? {
        switch metric {
        case .hrv: return day.hrv?.value
        case .restingHeartRate: return day.restingHeartRate?.value
        case .sleepHours: return day.sleepHours?.value
        case .sleepREMHours: return day.sleepREMHours?.value
        case .sleepDeepHours: return day.sleepDeepHours?.value
        case .steps: return day.steps?.value
        case .activeEnergyKcal: return day.activeEnergyKcal?.value
        case .exerciseMinutes: return day.exerciseMinutes?.value
        case .standHours: return day.standHours?.value
        }
    }

    // MARK: - 统计

    /// Pearson 相关系数。分母为 0 或样本不足返回 nil。
    func pearson(_ x: [Double], _ y: [Double]) -> Double? {
        let n = x.count
        guard n >= 3, n == y.count else { return nil }

        let xMean = x.reduce(0, +) / Double(n)
        let yMean = y.reduce(0, +) / Double(n)

        var sumXY = 0.0
        var sumX2 = 0.0
        var sumY2 = 0.0
        for i in 0..<n {
            let dx = x[i] - xMean
            let dy = y[i] - yMean
            sumXY += dx * dy
            sumX2 += dx * dx
            sumY2 += dy * dy
        }

        let denominator = sqrt(sumX2 * sumY2)
        guard denominator > Self.epsilon else { return nil }
        return sumXY / denominator
    }

    /// Spearman 秩相关（Pearson on ranks）。
    func spearman(_ x: [Double], _ y: [Double]) -> Double? {
        let xRanks = ranks(x)
        let yRanks = ranks(y)
        return pearson(xRanks, yRanks)
    }

    /// 赋秩（1-based，相同值取平均秩）。
    private func ranks(_ values: [Double]) -> [Double] {
        let indexed = values.enumerated().sorted { $0.element < $1.element }
        var result = [Double](repeating: 0, count: values.count)
        var i = 0
        while i < indexed.count {
            var j = i
            // 找相同值的区间
            while j + 1 < indexed.count && indexed[j + 1].element == indexed[i].element {
                j += 1
            }
            let avgRank = (Double(i) + Double(j)) / 2 + 1 // 1-based
            for k in i...j {
                result[indexed[k].offset] = avgRank
            }
            i = j + 1
        }
        return result
    }
}
