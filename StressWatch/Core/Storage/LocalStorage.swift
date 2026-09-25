import Foundation

class LocalStorage: LocalStorageProtocol {
    private let storageDirectory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(storageDirectory: URL) {
        self.storageDirectory = storageDirectory
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        try? FileManager.default.createDirectory(
            at: storageDirectory,
            withIntermediateDirectories: true
        )
    }

    convenience init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let directory = documents?.appendingPathComponent("StressWatch", isDirectory: true)
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("StressWatch", isDirectory: true)
        self.init(storageDirectory: directory)
    }

    func saveStressScore(_ score: StressScore) throws {
        var scores = try loadStressScores()
        let calendar = Calendar.current
        scores.removeAll { calendar.isDate($0.date, inSameDayAs: score.date) }
        scores.append(score)
        scores.sort { $0.date < $1.date }
        try saveStressScores(scores)
    }

    func fetchStressScores(from: Date, to: Date) throws -> [StressScore] {
        try loadStressScores()
            .filter { $0.date >= from && $0.date <= to }
            .sorted { $0.date < $1.date }
    }

    func saveBaseline(_ baseline: Baseline) throws {
        let data = try encoder.encode(baseline)
        try data.write(to: baselineFileURL, options: [.atomic])
    }

    func fetchBaseline() throws -> Baseline? {
        guard FileManager.default.fileExists(atPath: baselineFileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: baselineFileURL)
        return try decoder.decode(Baseline.self, from: data)
    }

    func deleteOldData(before: Date) throws {
        let scores = try loadStressScores().filter { $0.date >= before }
        try saveStressScores(scores)
    }

    func saveBaselineWindowDays(_ days: Int) throws {
        let normalizedDays = [7, 14, 30].contains(days) ? days : 7
        let data = try encoder.encode(normalizedDays)
        try data.write(to: baselineWindowFileURL, options: [.atomic])
    }

    func fetchBaselineWindowDays() throws -> Int {
        guard FileManager.default.fileExists(atPath: baselineWindowFileURL.path) else {
            return 7
        }

        let data = try Data(contentsOf: baselineWindowFileURL)
        let days = try decoder.decode(Int.self, from: data)
        return [7, 14, 30].contains(days) ? days : 7
    }

    func savePreferredDataSource(_ source: AppDataSource) throws {
        let data = try encoder.encode(source)
        try data.write(to: dataSourceFileURL, options: [.atomic])
    }

    func fetchPreferredDataSource() throws -> AppDataSource {
        guard FileManager.default.fileExists(atPath: dataSourceFileURL.path) else {
            return .demo
        }

        let data = try Data(contentsOf: dataSourceFileURL)
        return try decoder.decode(AppDataSource.self, from: data)
    }

    // MARK: - 每日聚合指标（T1.5）

    func saveDailyMetrics(_ metrics: [DailyHealthMetrics]) throws {
        guard !metrics.isEmpty else { return }

        // 按天的 upsert：同一天重复保存只保留最后一次，天然幂等
        // （与 saveStressScore / saveDailyCheckIn 同一套做法）。
        let stored = (try? loadDailyMetrics()) ?? []
        var byDay = Dictionary(uniqueKeysWithValues: stored.map { ($0.day, $0) })
        for day in metrics {
            byDay[day.day] = day
        }

        let merged = byDay.values.sorted { $0.day < $1.day }
        let data = try encoder.encode(merged)
        try writeHealthData(data, to: dailyMetricsFileURL)
    }

    func fetchDailyMetrics(from: Date, to: Date) throws -> [DailyHealthMetrics] {
        try loadDailyMetrics()
            .filter { $0.day >= from && $0.day <= to }
            .sorted { $0.day < $1.day }
    }

    func saveDailyCheckIn(_ checkIn: DailyWellnessCheckIn) throws {
        var checkIns = try loadDailyCheckIns()
        let calendar = Calendar.current
        checkIns.removeAll { calendar.isDate($0.date, inSameDayAs: checkIn.date) }
        checkIns.append(checkIn)
        checkIns.sort { $0.date < $1.date }
        try saveDailyCheckIns(checkIns)
    }

    func fetchDailyCheckIns() throws -> [DailyWellnessCheckIn] {
        try loadDailyCheckIns().sorted { $0.date < $1.date }
    }

    func fetchTodayCheckIn() throws -> DailyWellnessCheckIn? {
        let calendar = Calendar.current
        return try loadDailyCheckIns().first { calendar.isDateInToday($0.date) }
    }

    func saveEnableAIAnalysis(_ enabled: Bool) throws {
        let data = try encoder.encode(enabled)
        try data.write(to: aiEnabledFileURL, options: [.atomic])
    }

    func fetchEnableAIAnalysis() throws -> Bool {
        guard FileManager.default.fileExists(atPath: aiEnabledFileURL.path) else {
            return false
        }

        let data = try Data(contentsOf: aiEnabledFileURL)
        return try decoder.decode(Bool.self, from: data)
    }

    func saveMiniMaxModel(_ model: String) throws {
        let data = try encoder.encode(model)
        try data.write(to: miniMaxModelFileURL, options: [.atomic])
    }

    func fetchMiniMaxModel() throws -> String {
        guard FileManager.default.fileExists(atPath: miniMaxModelFileURL.path) else {
            return ""
        }

        let data = try Data(contentsOf: miniMaxModelFileURL)
        return try decoder.decode(String.self, from: data)
    }

    func saveAnalysisBackendBaseURL(_ url: String) throws {
        let data = try encoder.encode(url)
        try data.write(to: analysisBackendBaseURLFileURL, options: [.atomic])
    }

    func fetchAnalysisBackendBaseURL() throws -> String {
        guard FileManager.default.fileExists(atPath: analysisBackendBaseURLFileURL.path) else {
            return ""
        }

        let data = try Data(contentsOf: analysisBackendBaseURLFileURL)
        return try decoder.decode(String.self, from: data)
    }

    private var stressScoresFileURL: URL {
        storageDirectory.appendingPathComponent("stress_scores.json")
    }

    private var dailyMetricsFileURL: URL {
        storageDirectory.appendingPathComponent("daily_metrics.json")
    }

    private var baselineFileURL: URL {
        storageDirectory.appendingPathComponent("baseline.json")
    }

    private var baselineWindowFileURL: URL {
        storageDirectory.appendingPathComponent("baseline_window_days.json")
    }

    private var dataSourceFileURL: URL {
        storageDirectory.appendingPathComponent("preferred_data_source.json")
    }

    private var dailyCheckInsFileURL: URL {
        storageDirectory.appendingPathComponent("daily_check_ins.json")
    }

    private var aiEnabledFileURL: URL {
        storageDirectory.appendingPathComponent("ai_analysis_enabled.json")
    }

    private var miniMaxModelFileURL: URL {
        storageDirectory.appendingPathComponent("minimax_model.json")
    }

    private var analysisBackendBaseURLFileURL: URL {
        storageDirectory.appendingPathComponent("analysis_backend_base_url.json")
    }

    private func loadStressScores() throws -> [StressScore] {
        guard FileManager.default.fileExists(atPath: stressScoresFileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: stressScoresFileURL)
        return try decoder.decode([StressScore].self, from: data)
    }

    private func saveStressScores(_ scores: [StressScore]) throws {
        let data = try encoder.encode(scores)
        try data.write(to: stressScoresFileURL, options: [.atomic])
    }

    private func loadDailyCheckIns() throws -> [DailyWellnessCheckIn] {
        guard FileManager.default.fileExists(atPath: dailyCheckInsFileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: dailyCheckInsFileURL)
        return try decoder.decode([DailyWellnessCheckIn].self, from: data)
    }

    private func saveDailyCheckIns(_ checkIns: [DailyWellnessCheckIn]) throws {
        let data = try encoder.encode(checkIns)
        try data.write(to: dailyCheckInsFileURL, options: [.atomic])
    }

    // MARK: - 每日聚合指标读写

    /// 解码失败时**先备份再返回空**，不静默丢弃。
    /// 旧实现里 `try? decode` 失败会直接让用户丢失全部历史且毫无提示
    /// （Whoordan 也有同类问题：单文件快照 decode 失败即清空）。
    private func loadDailyMetrics() throws -> [DailyHealthMetrics] {
        guard FileManager.default.fileExists(atPath: dailyMetricsFileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: dailyMetricsFileURL)
        do {
            return try decoder.decode([DailyHealthMetrics].self, from: data)
        } catch {
            Self.backupCorruptedFile(at: dailyMetricsFileURL)
            print("[LocalStorage] daily_metrics.json 解码失败，已备份原文件：\(error)")
            return []
        }
    }

    /// 健康数据落盘：原子写 + 文件级保护。
    /// `.completeUnlessOpen` 表示设备锁屏后文件不可读，直到下次解锁
    /// （Whoordan `LocalStore` 同款设置）。
    private func writeHealthData(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: [.atomic])
        try? (url as NSURL).setResourceValue(
            URLFileProtection.completeUnlessOpen,
            forKey: .fileProtectionKey
        )
    }

    private static func backupCorruptedFile(at url: URL) {
        let suffix = Int(Date().timeIntervalSince1970)
        let backupURL = url.deletingPathExtension()
            .appendingPathExtension("corrupt-\(suffix).json")
        try? FileManager.default.copyItem(at: url, to: backupURL)
    }
}
