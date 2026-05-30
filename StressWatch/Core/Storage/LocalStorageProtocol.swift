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
}
