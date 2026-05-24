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

    private var stressScoresFileURL: URL {
        storageDirectory.appendingPathComponent("stress_scores.json")
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
}
