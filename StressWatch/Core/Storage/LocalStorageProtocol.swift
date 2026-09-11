import Foundation

enum AppDataSource: String, Codable {
    case appleHealth
    case demo
}

protocol LocalStorageProtocol {
    func saveStressScore(_ score: StressScore) throws
    func fetchStressScores(from: Date, to: Date) throws -> [StressScore]
    func saveBaseline(_ baseline: Baseline) throws
    func fetchBaseline() throws -> Baseline?
    func deleteOldData(before: Date) throws
    func saveBaselineWindowDays(_ days: Int) throws
    func fetchBaselineWindowDays() throws -> Int
    func savePreferredDataSource(_ source: AppDataSource) throws
    func fetchPreferredDataSource() throws -> AppDataSource
    func saveDailyCheckIn(_ checkIn: DailyWellnessCheckIn) throws
    func fetchDailyCheckIns() throws -> [DailyWellnessCheckIn]
    func fetchTodayCheckIn() throws -> DailyWellnessCheckIn?

    // MARK: - AI 个性化分析（MiniMax）配置
    // 注意：API Key 本身存于 Keychain，这里只持久化开关与模型选择。
    func saveEnableAIAnalysis(_ enabled: Bool) throws
    func fetchEnableAIAnalysis() throws -> Bool
    func saveMiniMaxModel(_ model: String) throws
    func fetchMiniMaxModel() throws -> String
}
